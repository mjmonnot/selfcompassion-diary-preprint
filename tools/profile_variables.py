"""Aggregate, disclosure-safe profile of the SPSS files in data/raw/.

Reads each .sav with pyreadstat and writes output/variable_profile.json.
For each variable: n non-missing, n distinct (true count and a cap at 25),
min, max, mean, and sample SD. The person id is limited to the distinct
count and the occasions-per-person histogram. Day, weekday, and week/phase
indexes also store cell counts.

Prints roles, labels, and those aggregates only. Does not print rows,
identifiers, free text, or value lists.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd
import pyreadstat

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
OUT = ROOT / "output" / "variable_profile.json"

if ROOT.name != "SelfCompassion-Diary-APHW":
    raise SystemExit(f"Refusing to run outside the project folder: {ROOT}")

# Filename -> {variable name: role}. Set from docs/sav_metadata.json.
# Roles: person_id, day_index, weekday, week_or_phase, design_indicator, measure.
ROLE_OVERRIDES: dict[str, dict[str, str]] = {
    "days.sav": {
        "ID": "person_id",
        "Period": "week_or_phase",
        "CTRLPeriod": "week_or_phase",
        "IntPeriod": "week_or_phase",
        "PostPeriod": "week_or_phase",
        "WD": "weekday",
        "time": "day_index",
        "week": "week_or_phase",
        "meditation": "design_indicator",
    },
    "persons.sav": {
        "ID": "person_id",
    },
}
INDEX_ROLES = {"day_index", "weekday", "week_or_phase", "design_indicator"}

DISTINCT_CAP = 25
CELL_COUNT_MAX = 40
SPSS_EPOCH = datetime(1582, 10, 14)

ID_NAMES = {
    "id",
    "pid",
    "subj",
    "subject",
    "subjectid",
    "subject_id",
    "person",
    "personid",
    "person_id",
    "userid",
    "user_id",
    "caseid",
    "case_id",
    "respid",
    "resp_id",
    "respondent",
    "idnum",
    "id_num",
    "participant",
    "participantid",
    "participant_id",
}
DAY_NAMES = {
    "day",
    "diaryday",
    "diary_day",
    "studyday",
    "study_day",
    "daynum",
    "day_num",
    "dayindex",
    "day_index",
    "occasion",
    "beep",
    "prompt",
    "timepoint",
    "time_point",
}
WEEKDAY_NAMES = {"wday", "weekday", "dow", "dayofweek", "day_of_week"}
PHASE_NAMES = {
    "week",
    "phase",
    "period",
    "wave",
    "condition",
    "intervention",
    "treatment",
    "treat",
    "group",
    "arm",
    "followup",
    "follow_up",
    "stage",
    "session",
}
ID_LABEL = re.compile(
    r"\b(participant|person|subject|respondent|employee)\b.{0,12}\b(id|identifier|code|number)\b",
    re.IGNORECASE,
)
PHASE_VALUE = re.compile(
    r"\b(control|intervention|follow[- ]?up|baseline|meditation|treatment|wait[- ]?list)\b",
    re.IGNORECASE,
)
DATE_FORMAT = re.compile(r"^(DATE|ADATE|EDATE|SDATE|DATETIME|JDATE)", re.IGNORECASE)


def configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def round_or_none(value: float | None, digits: int = 8):
    if value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(number):
        return None
    return round(number, digits)


def sample_sd(values: list[float]) -> float | None:
    n = len(values)
    if n < 2:
        return None
    mean = sum(values) / n
    return math.sqrt(sum((value - mean) ** 2 for value in values) / (n - 1))


def is_integer_like(series: pd.Series) -> bool:
    observed = series.dropna()
    if observed.empty or not pd.api.types.is_numeric_dtype(observed):
        return False
    numeric = pd.to_numeric(observed, errors="coerce").dropna()
    if numeric.empty:
        return False
    return bool((numeric - numeric.round()).abs().max() <= 1e-8)


def count_key(value) -> str:
    if pd.isna(value):
        return "missing"
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "non_numeric"
    if math.isfinite(number) and math.isclose(number, round(number)):
        return str(int(round(number)))
    if math.isfinite(number):
        return str(round(number, 6))
    return "non_finite"


def histogram(counts: pd.Series) -> dict[str, int]:
    tallies = counts.value_counts(dropna=False).sort_index()
    return {count_key(key): int(val) for key, val in tallies.items()}


def variable_kind(name: str, meta) -> str:
    original = str((meta.original_variable_types or {}).get(name) or "")
    readstat_type = str((meta.readstat_variable_types or {}).get(name) or "")
    if readstat_type == "string" or original.upper().startswith("A"):
        return "string"
    if DATE_FORMAT.match(original):
        return "datetime" if original.upper().startswith("DATETIME") else "date"
    if original.upper().startswith("TIME") or original.upper().startswith("DTIME"):
        return "time"
    return "numeric"


def classify(name: str, label: str, value_labels: list[dict], filename: str) -> str:
    override = ROLE_OVERRIDES.get(filename, {}).get(name)
    if override:
        return override
    token = name.strip().lower()
    if token in ID_NAMES or (label and ID_LABEL.search(label)):
        return "person_id"
    if token in WEEKDAY_NAMES:
        return "weekday"
    if token in DAY_NAMES:
        return "day_index"
    if token in PHASE_NAMES:
        return "week_or_phase"
    if any(PHASE_VALUE.search(str(item.get("label") or "")) for item in value_labels):
        return "week_or_phase"
    return "measure"


def serial_to_iso(value: float, with_time: bool) -> str | None:
    try:
        stamp = SPSS_EPOCH + timedelta(seconds=float(value))
    except (OverflowError, ValueError, OSError):
        return None
    if not 1990 <= stamp.year <= 2030:
        return None
    if with_time:
        return stamp.strftime("%Y-%m-%dT%H:%M:%S")
    return stamp.strftime("%Y-%m-%d")


def clock_from_seconds(value: float) -> str | None:
    if not math.isfinite(value) or value < 0 or value >= 86400:
        return None
    seconds = int(round(value))
    hour, rem = divmod(seconds, 3600)
    minute, second = divmod(rem, 60)
    return f"{hour:02d}:{minute:02d}:{second:02d}"


def id_key_series(series: pd.Series) -> pd.Series:
    observed = series.dropna()
    if observed.empty:
        return series
    if pd.api.types.is_numeric_dtype(observed) and is_integer_like(observed):
        numeric = pd.to_numeric(series, errors="coerce")
        return numeric.round().astype("Int64").astype("string")
    return series.astype("string")


def n_equal(left: pd.Series, right: pd.Series) -> dict:
    diff = (pd.to_numeric(left, errors="coerce") - pd.to_numeric(right, errors="coerce")).abs()
    compared = diff.notna()
    return {
        "n_compared": int(compared.sum()),
        "n_equal": int((diff[compared] <= 1e-6).sum()),
    }


def count_frame(row_key: pd.Series, col_key: pd.Series) -> dict[str, dict[str, int]]:
    table = pd.crosstab(row_key, col_key, dropna=False)
    rendered: dict[str, dict[str, int]] = {}
    for row_label, row in table.iterrows():
        rendered[count_key(row_label)] = {
            count_key(col_label): int(value) for col_label, value in row.items()
        }
    return rendered


def nonmissing_histogram(id_keys: pd.Series, values: pd.Series) -> dict:
    paired = pd.DataFrame({"id": id_keys, "value": values}).dropna(subset=["id"])
    counts = paired.groupby("id", sort=False)["value"].apply(lambda series: int(series.notna().sum()))
    return {
        "min": int(counts.min()) if len(counts) else None,
        "max": int(counts.max()) if len(counts) else None,
        "mean": round_or_none(float(counts.mean())) if len(counts) else None,
        "histogram": histogram(counts),
    }


def design_checks(frame: pd.DataFrame, names: list[str], id_keys: pd.Series | None) -> dict:
    checks: dict = {}
    if {"SC", "PS", "EE"}.issubset(names):
        present = frame[["SC", "PS", "EE"]].notna()
        checks["daily_composites"] = {
            "all_three_nonmissing": int(present.all(axis=1).sum()),
            "all_three_missing": int((~present).all(axis=1).sum()),
            "any_missing": int((~present).any(axis=1).sum()),
            "missing_masks_identical": bool(
                present["SC"].equals(present["PS"]) and present["PS"].equals(present["EE"])
            ),
        }
        if id_keys is not None:
            checks["nonmissing_days_per_person"] = {
                name: nonmissing_histogram(id_keys, frame[name]) for name in ("SC", "PS", "EE", "meditation")
            }
    reverse = []
    for reversed_name in names:
        if not (reversed_name.startswith("rSC") or reversed_name.startswith("rPS") or reversed_name.startswith("rEE")):
            continue
        raw_name = reversed_name[1:]
        if raw_name not in names:
            continue
        matched = None
        for constant in (6, 5, 4, 7):
            compared = n_equal(frame[reversed_name], constant - frame[raw_name])
            if compared["n_compared"] and compared["n_equal"] == compared["n_compared"]:
                matched = {"rule": f"{constant} - {raw_name}", **compared}
                break
        if matched is None:
            matched = {"rule": "no constant in {4, 5, 6, 7} fit every compared row", "n_compared": None, "n_equal": None}
        reverse.append({"reversed": reversed_name, "raw": raw_name, **matched})
    if reverse:
        checks["reverse_coding"] = reverse
    composites = []
    daily_sums = {
        "SC": ["SC1", "rSC2", "SC3", "rSC4", "SC5", "rSC6"],
        "PS": ["PS1", "rPS2", "rPS3", "PS4"],
        "EE": ["EE1", "EE2", "EE3", "EE4", "EE5"],
    }
    for target, parts in daily_sums.items():
        if target in names and set(parts).issubset(names):
            total = frame[parts].sum(axis=1, min_count=len(parts))
            composites.append({"target": target, "parts": parts, **n_equal(frame[target], total)})
    if {"TSC", "SC1", "SC26"}.issubset(names):
        parts = []
        for number in range(1, 27):
            reversed_name = f"rSC{number}"
            raw_name = f"SC{number}"
            if reversed_name in names:
                parts.append(frame[reversed_name])
            elif raw_name in names:
                parts.append(frame[raw_name])
        if len(parts) == 26:
            total = sum(parts)
            composites.append(
                {
                    "target": "TSC",
                    "parts": "rSC where present, else SC, for items 1-26",
                    **n_equal(frame["TSC"], total),
                }
            )
    if {"DailyMed", "dailyMed1", "dailyMed2"}.issubset(names):
        composites.append(
            {
                "target": "DailyMed",
                "parts": ["dailyMed1", "dailyMed2"],
                **n_equal(frame["DailyMed"], frame["dailyMed1"] + frame["dailyMed2"]),
            }
        )
    if composites:
        checks["composites_equal_sums"] = composites
    if {"time", "week", "Period"}.issubset(names):
        time = pd.to_numeric(frame["time"], errors="coerce")
        expected_week = time // 7 + 1
        expected_period = pd.Series(1, index=frame.index, dtype="float")
        expected_period = expected_period.mask(time > 6, 2)
        expected_period = expected_period.mask(time > 20, 3)
        checks["index_alignment"] = {
            "week_equals_floor_time_over_7_plus_1": n_equal(frame["week"], expected_week),
            "period_equals_time_bands_0_6_7_20_21_27": n_equal(frame["Period"], expected_period),
            "week_by_period": count_frame(frame["week"], frame["Period"]),
        }
        if "CTRLPeriod" in names and "IntPeriod" in names and "PostPeriod" in names:
            dummy_sum = (
                pd.to_numeric(frame["CTRLPeriod"], errors="coerce")
                + pd.to_numeric(frame["IntPeriod"], errors="coerce")
                + pd.to_numeric(frame["PostPeriod"], errors="coerce")
            )
            checks["index_alignment"]["dummy_sum_equals_1"] = n_equal(dummy_sum, pd.Series(1, index=frame.index))
            checks["index_alignment"]["ctrl_equals_period_1"] = n_equal(
                frame["CTRLPeriod"], (frame["Period"] == 1).astype(float)
            )
            checks["index_alignment"]["int_equals_period_2"] = n_equal(
                frame["IntPeriod"], (frame["Period"] == 2).astype(float)
            )
            checks["index_alignment"]["post_equals_period_3"] = n_equal(
                frame["PostPeriod"], (frame["Period"] == 3).astype(float)
            )
        if "WD" in names:
            residue = (time % 7).round()
            checks["weekday_by_time_mod_7"] = count_frame(residue, frame["WD"])
        if "meditation" in names:
            checks["meditation_by_period"] = count_frame(frame["Period"], frame["meditation"])
        if "SC" in names:
            checks["sc_missing_by_period"] = count_frame(
                frame["Period"], frame["SC"].isna().astype(int)
            )
            if "week" in names:
                mismatch = pd.to_numeric(frame["week"], errors="coerce") != expected_week
                checks["week_period_mismatch_rows"] = {
                    "n_rows": int(mismatch.sum()),
                    "n_period_2": int(((pd.to_numeric(frame["Period"], errors="coerce") == 2) & mismatch).sum()),
                    "n_post_dummy_1": int(((pd.to_numeric(frame["PostPeriod"], errors="coerce") == 1) & mismatch).sum())
                    if "PostPeriod" in names
                    else None,
                    "n_int_dummy_0": int(((pd.to_numeric(frame["IntPeriod"], errors="coerce") == 0) & mismatch).sum())
                    if "IntPeriod" in names
                    else None,
                }
    return checks


def assert_safe(payload: dict) -> None:
    for file_entry in payload["files"]:
        for variable in file_entry["variables"]:
            if variable["role"] == "person_id":
                banned = {"min", "max", "mean", "sd", "distinct_values", "cell_counts", "values"}
                present = banned.intersection(variable)
                if present:
                    raise SystemExit(
                        f"refusing to write identifier stats for {variable['name']}: {sorted(present)}"
                    )
            if variable.get("type") == "string" and any(
                key in variable for key in ("values", "distinct_values", "min", "max")
            ):
                raise SystemExit(f"refusing to write string values for {variable['name']}")


def summarize_file(path: Path) -> dict:
    frame, meta = pyreadstat.read_sav(
        path,
        user_missing=True,
        disable_datetime_conversion=True,
        apply_value_formats=False,
        formats_as_category=False,
        dates_as_pandas_datetime=False,
    )
    names = list(meta.column_names)
    labels = {
        name: (meta.column_labels[index] if meta.column_labels and index < len(meta.column_labels) else "") or ""
        for index, name in enumerate(names)
    }
    value_labels = {
        name: [
            {"value": item_value, "label": item_label}
            for item_value, item_label in (meta.variable_value_labels or {}).get(name, {}).items()
        ]
        for name in names
    }
    roles = {
        name: classify(name, labels[name], value_labels[name], path.name) for name in names
    }
    id_name = next((name for name in names if roles[name] == "person_id"), None)
    if id_name is None:
        token_hits = [
            name
            for name in names
            if re.search(r"(^|_)id($|_)", name.lower()) and variable_kind(name, meta) != "string"
        ]
        if len(token_hits) == 1:
            id_name = token_hits[0]
            roles[id_name] = "person_id"

    id_keys = id_key_series(frame[id_name]) if id_name else None
    rows_per_person = None
    distinct_days_per_person = None
    n_persons = None
    n_missing_id = None
    duplicate_day_persons = None
    if id_keys is not None:
        observed_ids = id_keys.dropna()
        n_persons = int(observed_ids.nunique())
        n_missing_id = int(id_keys.isna().sum())
        sizes = observed_ids.groupby(observed_ids, sort=False).size()
        rows_per_person = {
            "min": int(sizes.min()) if len(sizes) else None,
            "max": int(sizes.max()) if len(sizes) else None,
            "mean": round_or_none(float(sizes.mean())) if len(sizes) else None,
            "sd": round_or_none(sample_sd([float(value) for value in sizes.tolist()])),
            "histogram": histogram(sizes),
        }
        if sum(rows_per_person["histogram"].values()) != n_persons:
            raise SystemExit("rows-per-person histogram does not sum to n_persons")

    day_name = next((name for name in names if roles[name] == "day_index"), None)
    if id_keys is not None and day_name is not None:
        day_values = frame[day_name]
        paired = pd.DataFrame({"id": id_keys, "day": day_values}).dropna()
        if not paired.empty:
            per_person_days = paired.groupby("id", sort=False)["day"].nunique(dropna=True)
            distinct_days_per_person = {
                "min": int(per_person_days.min()),
                "max": int(per_person_days.max()),
                "mean": round_or_none(float(per_person_days.mean())),
                "sd": round_or_none(sample_sd([float(value) for value in per_person_days.tolist()])),
                "histogram": histogram(per_person_days),
            }
            pair_sizes = paired.groupby(["id", "day"], sort=False).size()
            duplicate_ids = pair_sizes[pair_sizes > 1].reset_index()["id"]
            duplicate_day_persons = int(duplicate_ids.nunique())

    repeated = bool(rows_per_person and rows_per_person["max"] and rows_per_person["max"] >= 2)
    variables = []
    for name in names:
        role = roles[name]
        kind = variable_kind(name, meta)
        series = frame[name]
        observed = series.dropna()
        n_nonmissing = int(observed.shape[0])
        n_distinct = int(observed.nunique(dropna=True))
        entry = {
            "name": name,
            "label": labels[name],
            "type": kind,
            "role": role,
            "n_rows": int(series.shape[0]),
            "n_nonmissing": n_nonmissing,
            "n_missing": int(series.shape[0] - n_nonmissing),
            "n_distinct": n_distinct,
            "n_distinct_capped_at_25": min(n_distinct, DISTINCT_CAP),
            "n_distinct_exceeds_25": n_distinct > DISTINCT_CAP,
        }
        if role == "person_id":
            entry["occasions_per_person_histogram"] = (
                rows_per_person["histogram"] if rows_per_person else {}
            )
            variables.append(entry)
            if os.environ.get("PROFILE_QUIET") != "1":
                print(
                    f"ID\t{path.name}\t{name}\tn_distinct={n_distinct}\t"
                    f"hist={json.dumps(entry['occasions_per_person_histogram'], ensure_ascii=False)}",
                    flush=True,
                )
            continue

        if kind == "string":
            lengths = observed.astype("string").str.len()
            entry["max_character_length"] = int(lengths.max()) if n_nonmissing else None
            entry["free_text_values_omitted"] = True
            variables.append(entry)
            if os.environ.get("PROFILE_QUIET") != "1":
                print(
                    f"STRING\t{path.name}\t{name}\tn={n_nonmissing}\t"
                    f"n_distinct={n_distinct}\tvalues_omitted",
                    flush=True,
                )
            continue

        numeric = pd.to_numeric(observed, errors="coerce").dropna()
        if kind in {"date", "datetime", "time"}:
            if n_nonmissing:
                low = float(numeric.min())
                high = float(numeric.max())
                if kind == "time":
                    entry["min"] = clock_from_seconds(low)
                    entry["max"] = clock_from_seconds(high)
                else:
                    entry["min"] = serial_to_iso(low, with_time=(kind == "datetime"))
                    entry["max"] = serial_to_iso(high, with_time=(kind == "datetime"))
                if entry["min"] is None or entry["max"] is None:
                    entry["min"] = None
                    entry["max"] = None
                    entry["endpoint_note"] = "date serial did not fall in 1990-2030; endpoints omitted"
            else:
                entry["min"] = None
                entry["max"] = None
            entry["mean"] = None
            entry["sd"] = None
        else:
            values = [float(value) for value in numeric.tolist()]
            entry["min"] = round_or_none(min(values)) if values else None
            entry["max"] = round_or_none(max(values)) if values else None
            entry["mean"] = round_or_none(sum(values) / len(values)) if values else None
            entry["sd"] = round_or_none(sample_sd(values))
            entry["values_are_integers"] = bool(values) and is_integer_like(numeric)
            if (
                entry["values_are_integers"]
                and entry["min"] is not None
                and entry["max"] is not None
                and n_distinct > 0
            ):
                entry["integer_span_equals_n_distinct"] = int(entry["max"] - entry["min"] + 1) == n_distinct
            else:
                entry["integer_span_equals_n_distinct"] = False

        labeled = bool(value_labels[name])
        low_cardinality = kind == "numeric" and name.lower() != "age" and 0 < n_distinct <= 10
        if role in INDEX_ROLES or labeled or low_cardinality:
            if n_distinct <= CELL_COUNT_MAX:
                counts = histogram(numeric if kind == "numeric" else observed)
                entry["cell_counts"] = counts
                if sum(counts.values()) != n_nonmissing:
                    raise SystemExit(f"cell counts for {name} do not sum to n_nonmissing")
            else:
                entry["cell_counts_omitted"] = f"n_distinct {n_distinct} exceeds {CELL_COUNT_MAX}"

        if repeated and id_keys is not None and kind == "numeric":
            grouped = pd.DataFrame({"id": id_keys, "value": pd.to_numeric(series, errors="coerce")})
            grouped = grouped.dropna(subset=["id"])
            person_means = grouped.groupby("id", sort=False)["value"].mean().dropna()
            if not person_means.empty:
                entry["n_persons_in_person_mean"] = int(person_means.shape[0])
                entry["max_abs_person_mean"] = round_or_none(float(person_means.abs().max()))
                entry["mean_of_person_means"] = round_or_none(float(person_means.mean()))
            within = grouped.groupby("id", sort=False)["value"].nunique(dropna=True)
            entry["n_persons_with_within_variation"] = int((within > 1).sum()) if len(within) else 0
            entry["max_within_person_n_distinct"] = int(within.max()) if len(within) else None

        variables.append(entry)
        if os.environ.get("PROFILE_QUIET") != "1":
            extra = ""
            if "cell_counts" in entry:
                extra = "\tcells=" + json.dumps(entry["cell_counts"], ensure_ascii=False)
            print(
                f"VAR\t{path.name}\t{name}\trole={role}\tn={n_nonmissing}\t"
                f"distinct={n_distinct}\tmin={entry.get('min')}\tmax={entry.get('max')}\t"
                f"mean={entry.get('mean')}\tsd={entry.get('sd')}"
                f"\tmax_abs_person_mean={entry.get('max_abs_person_mean')}"
                f"\twithin_persons={entry.get('n_persons_with_within_variation')}{extra}",
                flush=True,
            )

    design = design_checks(frame, names, id_keys)
    return {
        "design_checks": design,
        "path": path.relative_to(ROOT).as_posix(),
        "sha256": sha256_file(path),
        "n_bytes": path.stat().st_size,
        "n_rows": int(frame.shape[0]),
        "n_columns": int(frame.shape[1]),
        "metadata_n_rows": meta.number_rows,
        "person_id_variable": id_name,
        "day_index_variable": day_name,
        "n_persons": n_persons,
        "n_rows_missing_person_id": n_missing_id,
        "rows_per_person": rows_per_person,
        "distinct_days_per_person": distinct_days_per_person,
        "n_persons_with_duplicate_day_index": duplicate_day_persons,
        "variables": variables,
    }


def overlap(files: list[dict], frames: dict[str, tuple[pd.DataFrame, str]]) -> dict | None:
    if len(frames) < 2:
        return None
    sets = {}
    for name, (keys, id_name) in frames.items():
        sets[name] = set(keys.dropna().astype(str).tolist())
    names = list(sets)
    left, right = names[0], names[1]
    return {
        "left_file": left,
        "right_file": right,
        "left_id": frames[left][1],
        "right_id": frames[right][1],
        "n_only_left": len(sets[left] - sets[right]),
        "n_only_right": len(sets[right] - sets[left]),
        "n_both": len(sets[left] & sets[right]),
    }


def main() -> int:
    configure_stdio()
    paths = sorted(RAW_DIR.glob("*.sav"))
    if not paths:
        print("NO_SAV_FILES", file=sys.stderr)
        return 1
    files = [summarize_file(path) for path in paths]
    id_frames: dict[str, tuple[pd.Series, str]] = {}
    for path, file_entry in zip(paths, files):
        id_name = file_entry["person_id_variable"]
        if not id_name:
            continue
        frame, _meta = pyreadstat.read_sav(
            path,
            usecols=[id_name],
            user_missing=True,
            disable_datetime_conversion=True,
            apply_value_formats=False,
            formats_as_category=False,
        )
        id_frames[path.name] = (id_key_series(frame[id_name]), id_name)
    payload = {
        "sd_definition": "sample SD, divisor n-1, nonmissing values",
        "missing_rule": "pyreadstat user_missing=True; user-defined missing codes are counted as missing",
        "n_distinct_rule": (
            "n_distinct is the full count of nonmissing values. "
            "n_distinct_capped_at_25 is min(n_distinct, 25). Distinct values are not listed. "
            "Day, weekday, week/phase, and design indicators add cell counts when n_distinct is at most 40. "
            "Labeled categoricals and other numeric variables with at most 10 distinct values do too, except age."
        ),
        "person_id_rule": "person id entries contain n_distinct and the occasions-per-person histogram only",
        "centering_rule": (
            "max_abs_person_mean is the largest absolute within-person mean of nonmissing values, "
            "computed only when at least one person has two or more rows. "
            "A value of 0 means the deposited rows are person-mean centered."
        ),
        "files": files,
        "id_overlap": overlap(files, id_frames),
    }
    assert_safe(payload)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote={OUT.relative_to(ROOT).as_posix()}", flush=True)
    print("OVERLAP\t" + json.dumps(payload["id_overlap"], ensure_ascii=False), flush=True)
    for file_entry in files:
        print(
            "PANEL\t"
            + file_entry["path"]
            + "\tpersons="
            + str(file_entry["n_persons"])
            + "\tduplicate_day_persons="
            + str(file_entry["n_persons_with_duplicate_day_index"])
            + "\trows="
            + json.dumps(file_entry["rows_per_person"], ensure_ascii=False)
            + "\tdays="
            + json.dumps(file_entry["distinct_days_per_person"], ensure_ascii=False),
            flush=True,
        )
        print(
            "DESIGN\t"
            + file_entry["path"]
            + "\t"
            + json.dumps(file_entry["design_checks"], ensure_ascii=False),
            flush=True,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

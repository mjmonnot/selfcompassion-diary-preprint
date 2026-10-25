"""Write SPSS metadata for every .sav file under data/raw/.

Uses pyreadstat.read_sav(..., metadataonly=True). Writes names, labels,
value labels, measurement levels, and missing-value definitions to
docs/sav_metadata.json. Prints names and labels only. Never prints rows.
"""

from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import pyreadstat

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
OUT = ROOT / "docs" / "sav_metadata.json"

if ROOT.name != "SelfCompassion-Diary-APHW":
    raise SystemExit(f"Refusing to run outside the project folder: {ROOT}")


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


def json_number(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if not math.isfinite(value):
            return None
        if math.isclose(value, round(value)):
            return int(round(value))
        return round(value, 6)
    return value


def json_safe(value):
    if value is None or isinstance(value, (str, bool, int)):
        return value
    if isinstance(value, float):
        return json_number(value)
    if isinstance(value, dict):
        return {str(key): json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_safe(item) for item in value]
    if hasattr(value, "isoformat"):
        try:
            return value.isoformat()
        except TypeError:
            pass
    if hasattr(value, "items"):
        return {str(key): json_safe(item) for key, item in value.items()}
    return str(value)


def label_pairs(mapping: dict | None) -> list[dict]:
    pairs = []
    for key, label in (mapping or {}).items():
        pairs.append({"value": json_number(key), "label": None if label is None else str(label)})
    return pairs


def metadata_for(path: Path) -> dict:
    frame, meta = pyreadstat.read_sav(path, metadataonly=True)
    if len(frame.index) > 0:
        raise SystemExit(f"metadataonly returned rows for {path.name}; refusing to continue")
    names = list(meta.column_names)
    labels = list(meta.column_labels or [])
    variables = []
    for index, name in enumerate(names):
        label = labels[index] if index < len(labels) else None
        variables.append(
            {
                "position": index + 1,
                "name": name,
                "label": label or "",
                "measure": (meta.variable_measure or {}).get(name),
                "original_type": (meta.original_variable_types or {}).get(name),
                "readstat_type": (meta.readstat_variable_types or {}).get(name),
                "value_labels": label_pairs((meta.variable_value_labels or {}).get(name)),
                "missing_ranges": json_safe((meta.missing_ranges or {}).get(name) or []),
                "missing_user_values": json_safe((meta.missing_user_values or {}).get(name) or []),
            }
        )
        print(f"{path.name}\t{name}\t{label or ''}", flush=True)
    return {
        "file": path.name,
        "local_path": path.relative_to(ROOT).as_posix(),
        "sha256": sha256_file(path),
        "n_bytes": path.stat().st_size,
        "n_rows": meta.number_rows,
        "n_columns": meta.number_columns,
        "file_encoding": meta.file_encoding,
        "file_label": meta.file_label or "",
        "notes": [str(note) for note in (meta.notes or [])],
        "creation_time": json_safe(meta.creation_time),
        "modification_time": json_safe(meta.modification_time),
        "mr_sets": json_safe(meta.mr_sets or {}),
        "variables": variables,
    }


def main() -> int:
    configure_stdio()
    paths = sorted(RAW_DIR.glob("*.sav"))
    if not paths:
        print("NO_SAV_FILES", file=sys.stderr)
        return 1
    payload = {
        "source": "pyreadstat.read_sav(metadataonly=True)",
        "pyreadstat_version": pyreadstat.__version__,
        "files": [metadata_for(path) for path in paths],
    }
    OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote={OUT.relative_to(ROOT).as_posix()} files={len(paths)}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

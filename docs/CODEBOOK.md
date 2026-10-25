# Codebook

Internal codebook for `data/raw/days.sav` and `data/raw/persons.sav` in the Li, Hu, Yang, and Wang (2021) deposit. The OSF node has no README, no wiki, and no codebook file. Names, labels, value labels, measurement levels, and missing-value definitions were read with `pyreadstat.read_sav(path, metadataonly=True)` on 22 October 2026 (pyreadstat 1.3.5). The machine-readable copy is `docs/sav_metadata.json`. The numerical profile is `output/variable_profile.json`, written by `tools/profile_variables.py`. That script read the files and wrote only aggregates. SHA-256 of `days.sav` is `9304c468438bbd1d301d4405c9a4a4096d59b019abd04e6a9b26766a44e1acb4`. SHA-256 of `persons.sav` is `d12dc3d73e037888fd888b3c0305354cef65ccaa409ed004b32e4f5a4b3af949`. Both match `docs/DATA_LOG.md`.

The article full text was not obtained. Scale names, item wordings, and response anchors are not in the deposit. They are also not stated in the Crossref abstract. Ranges below are the observed numeric ranges in the profile. They are not a substitute for the published anchors.

## What the abstract states

Verified against the Crossref abstract for [https://doi.org/10.1111/aphw.12278](https://doi.org/10.1111/aphw.12278) on 22 October 2026. Sixty-five employees completed a four-week study. Week 1 was the control period, weeks 2 and 3 were the intervention period (online self-compassion meditation), and week 4 was the follow-up. The daily constructs named in the abstract are self-compassion, perceived stress, and emotional exhaustion. The abstract also says the intervention effects did not differ by trait self-compassion. The abstract does not name instruments, item counts, or anchors.

## File structure

`days.sav` has 1,820 rows and 32 variables. `persons.sav` has 65 rows and 50 variables. The same 65 identifiers appear in both files. No identifier is in only one file. The profile does not list identifiers.

Every person has 28 rows. `time` takes each integer from 0 through 27 exactly 65 times, and no person repeats a `time` value. The row is a person-day. The cluster is `ID`.

Neither file defines user-missing values. `missing_ranges` and `missing_user_values` are empty for every variable. System missing is the only gap, and it is limited to the daily outcomes and the daily meditation indicator. The person file is complete.

The SPSS measurement level is reported as stored. Several item columns and the stress composite are stored as nominal. That flag is not treated here as a claim about the response scale.

## Days file: design

`Period` is the phase indicator. Its value labels are 1 = control period, 2 = intervention period, 3 = post-intervention period. It matches `time` on all 1,820 rows: `time` 0–6 is period 1 (455 rows), `time` 7–20 is period 2 (910 rows), and `time` 21–27 is period 3 (455 rows). Those blocks are 7, 14, and 7 days.

`time` is labeled “centered on the first day.” The stored values are the integers 0 through 27. Each person has all 28 of them, so the within-person mean is 13.5. The column is an index with its origin on the first day. It is not a person-mean residual.

`week` is unlabeled. It takes values 1, 2, 3, and 4, with 455, 455, 454, and 456 rows. It equals `floor(time / 7) + 1` on 1,819 of 1,820 rows. The one disagreement is a row with `week` = 4 and `Period` = 2. On that same row the intervention dummy is 0 and the post dummy is 1.

`CTRLPeriod` has no label. It equals 1 exactly when `Period` = 1 (455 rows) and equals 0 otherwise. `IntPeriod` is labeled “dummy coding: intervention period.” It equals 1 when `Period` = 2 on 1,819 rows and is 0 on the mismatched row above (909 ones rather than 910). `PostPeriod` is labeled “dummy coding: post-intervention period.” It equals 1 when `Period` = 3 on 1,819 rows and is also 1 on that mismatched row (456 ones rather than 455). The three dummies sum to 1 on every row. `Period` is the phase code that matches the calendar.

`WD` is labeled “weekdays/weekend” and has no value labels. Code 0 falls on `time mod 7` of 0, 1, 2, 3, and 4 (260 rows each; 1,300 rows). Code 1 falls on `time mod 7` of 5 and 6 (260 rows each; 520 rows). Each person therefore has 20 rows coded 0 and 8 rows coded 1, which is the count of weekdays and weekend days in four seven-day blocks. The file does not name the weekday on which `time` = 0 falls.

`meditation` is labeled “meditate today or not,” with 0 = no and 1 = yes. It is 0 on all 455 control rows and all 455 follow-up rows, with no missing values in those periods. In the intervention period it is 1 on 725 rows, 0 on 147 rows, and missing on 38 rows. Nonmissing meditation days per person run from 24 to 28 (*M* = 27.42): 39, 17, 7, 1, and 1 persons have 28, 27, 26, 25, and 24 nonmissing values.

| Name | Label | Level | Coding | Nonmissing *n* |
| --- | --- | --- | --- | ---: |
| `ID` | — | scale | Person cluster. Distinct count only | 1,820 |
| `Period` | — | nominal | 1 control, 2 intervention, 3 post-intervention | 1,820 |
| `CTRLPeriod` | — | nominal | 1 on control rows | 1,820 |
| `IntPeriod` | dummy coding: intervention period | nominal | 1 on 909 rows | 1,820 |
| `PostPeriod` | dummy coding: post-intervention period | nominal | 1 on 456 rows | 1,820 |
| `week` | — | nominal | 1, 2, 3, 4 | 1,820 |
| `time` | centered on the first day | scale | Integers 0–27, origin on the first day | 1,820 |
| `WD` | weekdays/weekend | unknown | 0 weekday block, 1 weekend block | 1,820 |
| `meditation` | meditate today or not | scale | 0 no, 1 yes | 1,782 |

## Days file: daily constructs

The three composites are raw sums of the daily items, on the rows where the items are nonmissing. The maximum absolute within-person mean is 28.82 for `SC`, 10.21 for `PS`, and 20.29 for `EE`. A person-mean centered column would have that quantity at 0. None of the daily columns is person-mean centered.

`SC` is labeled “self-compassion.” It equals `SC1 + rSC2 + SC3 + rSC4 + SC5 + rSC6` on all 1,719 nonmissing rows. Items `SC1`–`SC6` are integers from 1 to 5. The label on `rSC2` is “r means reversed coded.” `rSC2`, `rSC4`, and `rSC6` equal 6 minus the corresponding raw item on all 1,719 rows. `SC` runs from 7 to 30 (*M* = 20.81, *SD* = 3.56) and takes 22 distinct values. Within-person variation is present for 63 of 65 persons.

`PS` is labeled “perveived stress” (spelled that way in the file). It equals `PS1 + rPS2 + rPS3 + PS4` on all 1,719 nonmissing rows. Items are integers from 0 to 4. `rPS2` and `rPS3` equal 4 minus the raw item on all 1,719 rows. `PS` runs from 0 to 16 (*M* = 6.10, *SD* = 2.37) and takes 16 distinct values. Within-person variation is present for 64 of 65 persons. The file stores `PS` as nominal.

`EE` is labeled “emotional exhaustion.” It equals `EE1 + EE2 + EE3 + EE4 + EE5` on all 1,719 nonmissing rows. There is no reversed copy. Items are integers from 0 to 6. `EE` runs from 0 to 30 (*M* = 10.74, *SD* = 5.46) and takes 31 distinct values. Within-person variation is present for 64 of 65 persons.

`SC`, `PS`, and `EE` are missing on the same 101 rows and present on the same 1,719 rows. The item columns share that mask. By `Period`, the missing outcome rows are 10 in the control period, 50 in the intervention period, and 41 in the follow-up. Observed outcome days per person run from 19 to 28 (*M* = 26.45). The counts of persons at 19, 21, 22, 23, 24, 25, 26, 27, and 28 observed days are 1, 2, 2, 2, 6, 5, 4, 9, and 34. No person has 20 observed outcome days. Thirty-four persons have the outcome on all 28 calendar rows.

Item means and value counts are in `output/variable_profile.json`. Observed ranges and nonmissing counts are below. Every daily item has *n* = 1,719.

| Name | Label | Level | Observed range |
| --- | --- | --- | --- |
| `SC` | self-compassion | scale | 7–30 |
| `SC1`–`SC6` | — | nominal | 1–5 |
| `rSC2` | r means reversed coded | nominal | 1–5 |
| `rSC4`, `rSC6` | — | nominal | 1–5 |
| `PS` | perveived stress | nominal | 0–16 |
| `PS1`, `PS2`, `PS3`, `PS4` | — | nominal | 0–4 |
| `rPS2`, `rPS3` | — | nominal | 0–4 |
| `EE` | emotional exhaustion | scale | 0–30 |
| `EE1`–`EE5` | — | nominal | 0–6 |

## Person file

`persons.sav` has one row per person and no missing values. Within-person centering is not identified in a one-row file. The columns are person-level scores as stored.

| Name | Label | Level | Coding or range | *M* | *SD* |
| --- | --- | --- | --- | ---: | ---: |
| `ID` | — | scale | 65 distinct values. Range not reported | — | — |
| `age` | — | scale | 23–51, 24 distinct values | 35.65 | 6.19 |
| `gender` | — | nominal | 1 male (24), 2 female (41) | — | — |
| `marriage` | — | nominal | 1 married (55), 2 single (8), 3 divorced (2) | — | — |
| `education` | — | nominal | 1 without a bachelor degree (9), 2 bachelor degree (35), 3 master degree (19), 4 doctor degree (2) | — | — |
| `job` | — | nominal | See below | — | — |
| `workinghours` | — | nominal | See below | — | — |
| `SES` | socioeconomic status | nominal | Integers 3–8. No value labels and no anchors | 5.83 | 1.18 |
| `TSC` | trait self-compassion | scale | 49–121, 37 distinct values | 85.02 | 13.46 |
| `dailyMed1` | body scan times | nominal | Integers 1–7 | 5.17 | 1.49 |
| `dailyMed2` | self-compassionate times | nominal | Integers 3–7 | 5.97 | 1.10 |
| `DailyMed` | meditation times | nominal | Integers 7–14 | 11.14 | 1.78 |

`job` value labels run from 1 to 15. The codes that occur are 3 salesperson (4), 4 public relations official (2), 6 administrator (2), 7 human resources (1), 8 finance staff (2), 9 civilian (5), 10 research personnel (15), 11 management staff (18), 12 teacher (6), 13 consultant (1), 14 professional (2), and 15 others (7). The label for code 14 is stored as “professional (e.g. accountant, lawer, architect )”. Codes 1 (students), 2 (production personnel), and 5 (customer service staff) are labeled and do not occur.

`workinghours` labels are in Chinese. The glosses are translations of those labels, not a second label from the file: 1 = fewer than 4 hours (4小时以下; 5 persons), 2 = 4–7 hours (15), 3 = 8–11 hours (43), 4 = 12–15 hours (2), 5 = 16 hours or more (16小时及以上; labeled, 0 persons).

`TSC` equals the sum of 26 item scores on all 65 rows. Where a reversed copy exists, the sum uses that copy; otherwise it uses the raw item. Reversed copies are present for items 1, 2, 6, 8, 11, 13, 16, 18, 20, 21, 24, and 25. Each equals 6 minus the raw item on all 65 rows. The label on `rSC1` is “r means reverse coded.” Raw items `SC1`–`SC26` are integers from 1 to 5. The deposit does not name the 26-item instrument. `DailyMed` equals `dailyMed1 + dailyMed2` on all 65 rows. The labels call these counts of times. The file does not say over which days the counts were taken. The upper values, 7 and 14, sit at the length of one intervention week and of the two intervention weeks.

## What is not in the files

The deposit does not contain a between-person treatment arm, a survey timestamp, a named weekday, item text, or published scale citations. It does not contain a lagged copy of any outcome. Lagged scores would have to be built from `ID` and `time`. Person means of the daily sums can be computed from `days.sav`; they have not already been subtracted. The one-row disagreement among `week`, `Period`, and the post dummy is the only break in the phase coding. `Period` and `time` agree throughout.

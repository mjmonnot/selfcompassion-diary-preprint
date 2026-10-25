# Data log

Fetched 22 October 2026 with `tools/fetch_osf.py` (OSF API v2, recursive over storage providers, child components, and folder pages). Manifest time: 2026-10-22T15:58:43Z. The manifest file is `docs/osf_manifest.json`.

## Source

- Project: [https://osf.io/pqf6v/](https://osf.io/pqf6v/) (node `pqf6v`)
- API node: [https://api.osf.io/v2/nodes/pqf6v/](https://api.osf.io/v2/nodes/pqf6v/)
- Storage walked: `osfstorage` only, from [https://api.osf.io/v2/nodes/pqf6v/files/osfstorage/](https://api.osf.io/v2/nodes/pqf6v/files/osfstorage/)
- Child components: none (`/children/` returned an empty list)
- Other providers: none (`/files/` listed only `osfstorage`)
- Wiki pages: none (`/wikis/` returned an empty list)
- Project description: empty. Tags: none
- Created 2021-04-07; modified 2021-04-07
- Project title: Daily interventions and assessments: the effect of online self-compassion meditation on psychological health
- Public: yes. No README, no wiki, and no codebook file are on the node.

## Licence

The node attribute `node_license` is null, and the licence relationship is null. OSF has no licence selected for this project. Reuse of the SPSS files is an open decision for the authors. The article is under Wiley’s terms for the version of record; that statement applies to the article, not to the data files. See `docs/ACCESS.md`.

## Identifiers

The identifiers endpoint returned one DOI, `10.17605/OSF.IO/PQF6V`. On 22 October 2026 that DOI returned HTTP 200 and resolved to [https://osf.io/pqf6v/](https://osf.io/pqf6v/).

## Manifest

Two files, 70,448 bytes. Each local SHA-256 matches the hash OSF stores on the file. Both sizes match the byte counts expected for this node.

| File | Local path | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| days.sav | `data/raw/days.sav` | 61,714 | `9304c468438bbd1d301d4405c9a4a4096d59b019abd04e6a9b26766a44e1acb4` |
| persons.sav | `data/raw/persons.sav` | 8,734 | `d12dc3d73e037888fd888b3c0305354cef65ccaa409ed004b32e4f5a4b3af949` |

OSF file GUIDs: `days.sav` `dr6wn`, `persons.sav` `8rjfv`. SPSS file timestamps in the headers are 2019-12-02 for `days.sav` and 2020-07-09 for `persons.sav`. Those are file-header times, not a respondent field.

## File structure

Variable names, labels, value labels, measurement levels, and missing-value definitions were read with `pyreadstat.read_sav(path, metadataonly=True)` (pyreadstat 1.3.5) and written to `docs/sav_metadata.json`. Aggregates were written by `tools/profile_variables.py` to `output/variable_profile.json`. Neither script prints rows, identifiers, or free text. The variable dictionary is `docs/CODEBOOK.md`.

`days.sav` has 1,820 rows and 32 variables. `persons.sav` has 65 rows and 50 variables. The person identifier matches across the two files for all 65 people, with no identifier in only one file. Every person has 28 rows in `days.sav`, `time` runs from 0 through 27, and no person has a repeated `time` value. Neither file defines user-missing values. System missing is confined to the daily outcome block (101 rows) and the daily meditation indicator (38 rows). The person file has no missing values.

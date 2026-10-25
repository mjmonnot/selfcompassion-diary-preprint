# Diary independent refit: verdict MATCH (2026-10-24 17:04 PT)
Spec: SPEC_FOR_APPRENTICE.txt sha256 52d07c4dddf7c483c615a6869e8f9a5da64c774e621b9e4bc299e5c801932f39 (words and equations only).
Apprentice script: diary_refit_ap.R sha256 14629ecc328db1e9b97095570e9cc45854463806a1f9ace3180ba412db6ac56b, seed 31337. Plumber PASS 16:58.
Run: Sandbox, a single run on days.sav 9304c468 (staged read-only by Fort Knox), exit 0, stdout sha256 456e5489af002b0db8d87145c71fed993ae48c05da9c4dfe21cda521d9c9c15e.
Locked comparison (BS): recomputed by Plumber from the original 4-chain Stan CSVs, block sha256 22d964d86155b2aaf9d751790c5e37167547834c72f1ac9e57da1716ca8a9534 (refit_blacksmith_block.txt). Source CSV hashes are in refit_src_hashes.txt.
Rule (Mastermind): |AP-BS| <= 3*sqrt(mcse_AP^2+mcse_BS^2).

| Quantity | AP | BS | diff | tolerance | result |
|---|---|---|---|---|---|
| H1 b0 mean | -0.001366311 | -0.002000919 | 0.000635 | 0.002467 | MATCH |
| H1 P_dir | 0.48375 | 0.47925 | 0.0045 | 0.02578 | MATCH |
| H2 b0 mean | -0.027212398 | -0.027346981 | 0.000135 | 0.005945 | MATCH |
| H2 P_dir | 0.6475 | 0.651 | 0.0035 | 0.04053 | MATCH |

Convergence:
- AP H1: max rhat 1.00772, min ESS bulk/tail 747/1060.
- AP H2: max rhat 1.00682, sd_b ESS 841/822.
- BS H1: max rhat 1.00733, min ESS 706/1290.
- BS H2: max rhat 1.00640, min ESS 680/780.
- Both sides: 0 divergences and 0 treedepth hits.
- Neither hypothesis is supported (P_dir < .975).
Verdict by Apprentice Plumber (blind recompute); Plumber concurs.

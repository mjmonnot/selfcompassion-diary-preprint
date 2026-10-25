# NEGATIVE_RESULTS.md: SelfCompassion-Diary-APHW (v3 locked fit)
Date: 2026-10-24. Source: protocol/results/results_aggregate.json (sha256 f9ca85b9…c576ae), locked fit run on 2026-10-24 from 12:15:29 to 12:28:36 PT, LOCK.pre_C5_20261024.json d7c77e3c…db58d (LOCK.pre_C6_20261024.json 919cb70293543a3f8a331a817564707217b6fc121c8b5443eadd1dce38753451 (adds R/03_omega.R, C5); current lock: LOCK.json 28b858dde3359245b3962b1869cd30cc1f911a9bcf0c0f04006377311f60a21c). Plumber audit: PASS with conditions (C1).

Rationale: Matt requires every dead end and null result to be logged. No fit reached the pre-set decision rule P(hypothesised direction) ≥ .975 (supported_975 = false for all 13 fits). Every 95% CrI lies within the ±0.2 SD band (inconclusive = false), so these are well-estimated nulls.

Values below are copied from results_aggregate.json (rounded to 3 dp). b is the within-person slope, standardised.

| Fit | Dir | Median | 95% CrI | 90% CrI | P(dir) | P(beyond 0.2 SD) |
|---|---|---|---|---|---|---|
| H1 SC same-day (primary) | >0 | −0.002 | [−0.093, 0.090] | [−0.078, 0.076] | .479 | 0 |
| H2 EE next-day given today's EE (secondary) | <0 | −0.028 | [−0.160, 0.111] | [−0.139, 0.087] | .651 | .007 |
| S1 prior ×2 | >0 | −0.002 | [−0.101, 0.090] | [−0.084, 0.076] | .476 | 0 |
| S1 prior ×0.5 | >0 | −0.001 | [−0.095, 0.091] | [−0.080, 0.075] | .490 | 0 |
| S2 same-row | >0 | −0.023 | [−0.121, 0.075] | [−0.104, 0.061] | .328 | 0 |
| S3 PMM −0.25 SD | >0 | −0.003 | [−0.097, 0.087] | [−0.080, 0.074] | .474 | 0 |
| S3 PMM −0.50 SD | >0 | −0.005 | [−0.099, 0.086] | [−0.084, 0.070] | .455 | 0 |
| S4 H2 prior ×2 | <0 | −0.030 | [−0.170, 0.113] | [−0.147, 0.088] | .661 | .007 |
| S4 H2 prior ×0.5 | <0 | −0.028 | [−0.156, 0.105] | [−0.137, 0.086] | .669 | .005 |
| S4 H2 same-row | <0 | −0.069 | [−0.176, 0.037] | [−0.157, 0.017] | .902 | .007 |
| S4 H2 PMM +0.50 SD | <0 | −0.028 | [−0.161, 0.112] | [−0.138, 0.087] | .648 | .008 |
| S5 Li exclusion | >0 | −0.002 | [−0.093, 0.090] | [−0.078, 0.076] | .479 | 0 |
| S6 observed centering (brms) | >0 | 0.017 | [−0.076, 0.106] | [−0.060, 0.092] | .639 | 0 |

Notes:
- S5 is identical to H1 because no person had fewer than 7 meditation days, so the exclusion removed nobody.
- S6 diagnostics: only R-hat is saved (max 1.004). ESS, divergence and treedepth counts are not saved (see DEVIATIONS.md item 4).
- The aggregate has no H2 PMM −0.25/−0.50 rows and no H1 PMM +0.50 row. Only the rows above were specified and run; nothing is missing relative to the output file.
- 2026-10-24 (Reviewer 2 M2): the manuscript arithmetic "38 + 65 = 103" does not close to the 100 missing in the analysis window. The data are complete; the 3 same-row missing values on day 7 leave the window under previous-day alignment (38 − 3 + 65 = 100). See DEVIATIONS item 11.

## 2026-10-24 13:04 PT: 05 omega run3 failed (lock 48d34e46)
05 (2607677f) exited 1 at line 68: the corrected omega and the std.lv=TRUE refit for the SC items differed by more than 1e-6. The gap size was not printed. The log has NaNs from log(det(sigma_w_1)), clusters with zero within-person variance for every SC item, and 50 empty cases. No omega_v3_diag.json was written. The run2 omega_v3.json stays UNCONFIRMED. Log: protocol/logs/omega_v3_run3.log, sha256 bce63fef45ad2308863c356313aa9216039979cd13fc544e747bdf34d1c14a4a. No code was patched.

## 2026-10-24 13:30 PT: 05 omega run4 (lock C8 400609fc) failed again at the std.lv check
The patched 05 (2570c8fb) exited 1. For the SC items in Period 2, the max abs gap was 4.24e-06, above the 1e-6 tolerance. Both the marker fit and the std.lv fit converged, and both passed post.check. EE was not reached because the script halts at the stopifnot. The PARTIAL omega_v3_diag.json is f4f6e6a0. The log is logs/omega_v3_run4.log, sha256 3460f72e. Nothing was changed.

## 05 omega run5 (C9, rel.tol=1e-12), logged 2026-10-24 16:10 PT
- Ran 14:03:59 to 14:04:59 PDT and exited 1. The 1e-6 gap check failed on Period 2 SC with max_abs_gap 4.241410398e-06, identical to run4. Both fits converged and passed post.check, with 2/2 iterations.
- The gap is unchanged by the 1e-12 tolerance, so optimizer precision is not the cause. A definitional or parameterization difference in the between-level omega is likely (my reading; to be audited).
- Reporting error: I told the team run5 was "running" at 14:04 and didn't catch the exit until Project Manager flagged it at 16:09.

## 05 omega run6 (C10, tolerance <= 1e-4), logged 2026-10-24 16:18 PT
- Ran 16:15:43 to 16:16:26 PDT and exited 1. The SC Period 2 gap check PASSED (4.2414e-06 <= 1e-4). optim.method is "em" for both fits, 2/2 iterations (logged).
- It then halted at a new, never-reached line in diag_model: standardizedSolution() output has no "level" column ("undefined columns selected"). This is a code bug in the post-check reporting block, not an estimation problem. No omega values have been reported. Log fef6f1d2; PARTIAL diag json 79950897.

# RUN_ORDER.md: SelfCompassion-Diary-APHW v3 post-fit scripts (2026-10-24)
Rationale: Plumber post-fit audit O1. Runs share CPU and outputs, so they go strictly one at a time, each at nice 19.
Gate for EVERY run: no run starts without (a) a Plumber PASS, (b) an Apprentice Plumber MATCH and (c) Fort Knox's lock covering the script's hash.

Order (from protocol/): 05 → 06a → 07 same_day → 07 next_day → PAUSE (P_dir MATCH) → 06
1. `nice -n 19 Rscript R/05_omega_run_diag.R data/raw/days.sav > logs/omega_v3_run3.log 2>&1` (corrected omega vs std.lv cross-check tolerance stays 1e-6)
2. `OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 OPENBLAS_NUM_THREADS=2 nice -n 19 Rscript R/06a_regen_draws.R data/raw/days.sav > logs/regen_draws_v3.log 2>&1` (env exported before R starts, as in logs/run.sh; writes results/regen_v3/ACCEPTED_FITS and REJECTED_FITS; exit 1 = H1 or H2 rejected, stop)
3. `nice -n 19 Rscript R/07_fit_ps.R data/raw/days.sav same_day -1 > logs/fit_ps_v3_same_day.log 2>&1`
4. `nice -n 19 Rscript R/07_fit_ps.R data/raw/days.sav next_day -1 > logs/fit_ps_v3_next_day.log 2>&1`
5. **PAUSE** for Apprentice Plumber's P_dir MATCH (recomputed from results/regen_v3/b_within/ against results_aggregate.json, for every fit in ACCEPTED_FITS). Do not start step 6 without it.
6. `nice -n 19 Rscript R/06_aggregates.R data/raw/days.sav > logs/aggregates_v3.log 2>&1`
7. (DRAFT, not yet gated; DEVIATIONS item 12) `OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 OPENBLAS_NUM_THREADS=2 nice -n 19 Rscript R/08_fit_no_nonmed.R data/raw/days.sav > logs/fit_no_nonmed_v3.log 2>&1`

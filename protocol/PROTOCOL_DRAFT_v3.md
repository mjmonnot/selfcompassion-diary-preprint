# PROTOCOL DRAFT: SelfCompassion-Diary-APHW (short methods note)

Status: v3 (Plumber audit fixes; see CHANGES_v3.md). v2 applied Matt's 11:32 AM PT 2026-10-24 decisions, "go with your suggestion"; see CHANGES_v2.md. Draft for Plumber to hash, then for Matt to lock. Written from plans and the codebook only. No data rows were opened. Matt approved the design at 9:40 AM PT on 2026-10-24. protocol_v3.json is the machine-readable copy of this document.

## 1. Scope
Rationale: Li et al. (2021) compared phase means. They never compared days with meditation to days without it (Note 2026-10-24e).
Decision: the primary analysis is D.5, meditation days versus non-meditation days within person. B.2's phase contrasts are dropped. Scale and inertia are additional analyses. The habit framing is dropped.

## 2. Hypotheses
Rationale: Matt asked for one primary test with a direction.
Decision:
- **H1 (primary, one-sided).** On days a person meditates, same-day self-compassion (SC) is higher. Supported if P(b_within > 0) ≥ .975 and the chains converge. Reported beside the rule: posterior median, 90% and 95% CrI, and P(b_within > 0.2 SD).
- **H2 (secondary, one-sided).** Meditating on day t lowers emotional exhaustion (EE) on day t+1, adjusting for EE on day t. Direction is negative: supported if P(b < 0) ≥ .975 and the chains converge; reported beside it: median, 95% CrI and P(b < −0.2 SD). Every sensitivity model is tested in its own hypothesis's direction (S1–S3, S5, S6: > 0; S4: < 0), read from protocol_v3.json.
- **Additional (no decision threshold):** the between-person meditation propensity, the AR(1) term φ, scale, and perceived stress (PS).

## 3. Data window and alignment
Rationale: the meditation item is asked in the morning and covers the "past 24 h" (Li 2021, Procedure).
Decision:
- Analyse Period 2 (time 7–20).
- Meditation for day t is read from row t+1. Same-row alignment is sensitivity analysis S2.
- Under this rule, day 20 would take its value from row 21, which is in Period 3, where every row is coded 0. Day 20's meditation value is therefore set to missing (confirmed by Matt, 11:32 AM PT).

## 4. Model
Rationale: with few days per person, observed person means bias the within/between split. DSEM latent centering avoids that bias (Hamaker & Grasman, 2015; Hamaker et al., 2018).
Decision: a custom Stan model, `dsem_meditation.stan`.
- Meditation ~ Bernoulli(p_i). The within-person part is m_it − p_i.
- Random intercept and a random meditation slope.
- A common AR(1) term on the person-centred lagged outcome.
- Covariates: weekend (WD) and centred time. No person-level covariates.
- Outcomes are z-scored.

## 5. Priors and MCMC
Rationale: these are field-standard settings for a small two-level model, following the WAMBS checklist (Depaoli & van de Schoot, 2017).
Decision:
- Priors: N(0, 0.5) on standardized slopes. Prior sensitivity uses SD 1.0 and SD 0.25.
- Sampling: 4 chains, 1,000 warmup and 1,000 sampling iterations each, adapt_delta .95, max_treedepth 12, seed 20261024.
- Convergence: R-hat < 1.01, bulk and tail ESS > 400, and 0 divergences. If any divergences occur, rerun at adapt_delta .99.
- Posterior predictive checks.

## 6. Missing data
Rationale: missing outcomes are modelled inside the likelihood, which is valid under MAR. A pattern-mixture model tests how far the result depends on that assumption.
Decision:
- MAR is primary.
- Delta-adjusted pattern-mixture (S3/S4): missing SC shifted by −0.25 and −0.50 SD, missing EE by +0.50 SD (EE shift: Matt-approved 2026-10-24 11:53 PT: "Keep both defaults").
- No one is excluded. The number of persons with zero non-meditation days is reported.
- Li's rule excluding persons with fewer than 7 meditations is disclosed and tested only as S5.

## 7. Reliability
Rationale: the daily composites are item sums, and diary data need reliability estimated separately within and between persons (Geldhof et al., 2014).
Decision: two-level CFA in lavaan (MLR) gives within and between omega for SC (SC1, rSC2, SC3, rSC4, SC5, rSC6) and EE (EE1–EE5). Code: `R/03_omega.R`. Deviation: lavaan is 0.7-3, not the planned 0.6.19, because the shared box library is used by other projects; the diary models are brms/Stan, and lavaan is used only here.

## 8. Multiplicity
Rationale: there is a single confirmatory test.
Decision: the family is H1 alone, with no adjustment. H2 is reported as secondary. Additional analyses carry no decision thresholds (Rubin, 2021).

## 9. Consolidated sensitivity list
- S1: prior SD ×2 and ×0.5
- S2: same-row alignment
- S3: pattern-mixture with SC shifted −0.25 and −0.50 SD
- S4: H2 under S1, S2, and an EE shift of +0.50 SD (EE shift Matt-approved 2026-10-24 11:53 PT: "Keep both defaults")
- S5: Li's exclusion rule
- S6 (sensitivity only; never replaces the primary latent-centred model; whole specification Matt-approved 2026-10-24 11:53 PT: "Keep both defaults"): brms, SC z-scored, SC ~ med_wc + med_pm + WD + time_c + (1 + med_wc | ID) + ar(time | ID, p = 1); prior N(0, 0.5) on ALL fixed (class b) coefficients (med_wc, med_pm, WD, time_c); brms defaults for intercept, SDs, correlations, AR and sigma; MCMC settings and seed from protocol_v3.json

## 10. Precision statement
Rationale: the codebook shows 725 meditation days, 147 non-meditation days, and 38 missing person-days across 65 persons, so the within-person estimate will be imprecise.
Decision: no power claim is made. The 95% CrI width and posterior SD are reported. If the 95% CrI spans both 0 and |0.2| SD, the result is called inconclusive (band confirmed by Matt, 11:32 AM PT).

## 11. Files
- `protocol_v3.json` (protocol.json, protocol_v2.json superseded)
- `dsem_meditation.stan`
- `R/01_prepare.R`, `R/02_fit_v3.R` (entry point: `Rscript R/02_fit_v3.R data/raw/days.sav`), `R/03_omega.R`
- SUPERSEDED, do not run: `R/02_fit.R` (v1), `R/02_fit_v2.R` (v2)
- `tests/test_direction_sim.R` (simulated draws only; passed)
- `renv.lock`
- `R/00_syntax_check.R` (simulated data only; passed, and stanc translation succeeded)
- `RENV_SPEC.md`

## 12. Resolved by Matt (11:32 AM PT, 2026-10-24: "go with your suggestion")
1. Alignment: row t+1 maps to day t; day 20 set to missing. (Same-day reference of SC/EE items remains to be checked against Li 2021 Procedure; not a data look.)
2. Decision rule: P(b_within > 0) ≥ .975. This project keeps its own rule; the 11:06 "Only Coach for now" no-cutoff change does not apply here.
3. Pattern-mixture deltas: −0.25 and −0.50 SD for SC. EE +0.50 SD: Matt-approved 2026-10-24 11:53 PT: "Keep both defaults".
4. Inconclusive band: |0.2| SD.
5. S6 specification (observed person-mean centering, N(0, 0.5) on all 4 coefficients): Matt-approved 2026-10-24 11:53 PT: "Keep both defaults".

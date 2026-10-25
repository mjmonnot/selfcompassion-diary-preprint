# ANALYSIS_PLAN — SelfCompassion-Diary-APHW

Written 2026-10-24 by Atlas (analytic strategy) from project documentation only (README, docs/*.md, gate logs, FEASIBILITY, CODEBOOK). No respondent-level row, sealed file, holdout, or free text was opened to write this plan. Governing rules: `/workspace/ml_guardrails.md` (fit on train only; select on train OOF CV; thresholds from 5-fold OOF on the fit set only; test touched once via a single entry point; sealed holdouts refused by code; frozen seeds; NEGATIVE_RESULTS.md) and this project's README. Where this plan and a frozen STUDY_PLAN disagree, the frozen STUDY_PLAN governs.

Owners: **Ledger** = splits/scoring releases; **Forge** = modeling (train only, via Ledger releases); **Sentinel** = audit; **Quill** = manuscript (APA docx); **Verity** = accuracy check; **Matt** = author decisions.

Hypothesis labeling: items quoted from a source carry the file citation. Anything else is marked **PROPOSED - needs Matt's confirmation**. Today's transcripts (Forge's chat, 2026-10-24) contain no project-specific hypotheses; they only set up the agent roles.

## 1. Project summary and status

Li et al. (2021): 28-day diary, N = 65, single-group schedule (week 1 control, weeks 2–3 meditation, week 4 follow-up). No licence; full text not obtained.

**Status:** **ACTIVE**. Reactivated 2026-10-24 per Matt: projects with data are not on hold. All hypotheses remain PROPOSED pending Matt. Prior status: FEASIBILITY only. THEORY_REVIEW v2 §4.4: "Methods note or hold"; novelty risk HIGH; the single-group design identifies no intervention effect.

## 2. Research questions and hypotheses

No sourced hypotheses. FEASIBILITY.md lists feasible models: location-scale with phase, interrupted-time-series DSEM, within-person mlVAR.
- PROPOSED - needs Matt's confirmation: phase-related changes in mean and within-person variability of SC, PS, EE (described, not causal).

## 3. Outcomes and predictors

- Outcomes: daily SC, PS, EE sums. Predictors: `Period` (phase), `WD`, `meditation` (intervention window only), TSC (person level).

## 4. Analytic strategy

Diary → Bayesian multilevel location-scale model with phase in location (and scale); no causal claims. No ML component is planned. The guardrails apply if any prediction work is added later.

## 5. Next actions (owner)

1. Matt — methods note or hold?
2. If opened: obtain the full text (Quill/lit retrieval); Forge drafts the plan; Sentinel gates it.

## 6. Open decisions and gaps for Matt

- Methods note or hold?
- No licence on the deposit; full text not obtained.


## Amendment 2026-10-24
Appended (not rewritten) per Matt's rules relayed via Chad: local-literature-driven methods, recompute from raw, APA/JARS/ML reporting, Ledger/Forge/Sentinel separation, Grok bots only, stems-only manuscript.

### A.1 Hypotheses status
PROPOSED; 'methods note or hold'.

### A.2 Data available (schema level; no rows, no sealed files read)
data: days.sav (day level), persons.sav (person level). Schema-level only.

### A.3 Literature folder and methods â†’ local sources
Yes â€” 4 PDFs (Li_et_al_2021, Kuppens_Allen_Sheeber_2010, Lally_et_al_2010, Wood_Runger_2016) + 3 abstract-only (Hollenstein 2015, Kuppens & Verduyn 2017, Olthof et al. 2020). Added today: none. Still missing: full texts of the three abstract-only items (library), and a local copy of a brms/multilevel methods source (BÃ¼rkner 2017 is OA at JSS; copy from Algorithmic-Management\lit\methods\Burkner_2017_brms.pdf).

Analytic strategy derives from these local PDFs (filenames under `lit\`):
- Design and outcomes: Li_et_al_2021 (source study).
- Emotional inertia (lagged autocorrelation): Kuppens_Allen_Sheeber_2010.
- Habit/automaticity trajectories (if used): Lally_et_al_2010, Wood_Runger_2016.

### A.4 Recompute from raw (owner: Forge; numbers checked by Verity)
- Forge recomputes the source study's day/person descriptives and phase contrasts from days.sav/persons.sav; Verity checks against Li et al. (2021).
- Existing .py/.R outputs and reported tables are treated as **unverified** until recomputed; any discrepancy goes to NEGATIVE_RESULTS.md / a discrepancy log, not silently corrected.
- Forge works only on train/raw data released by Ledger; Ledger owns splits and scoring; Sentinel audits leakage and seal integrity; roles stay separate (/workspace/ml_guardrails.md).
- Verity independently re-derives every reported number (N, means/SDs, estimates, CIs, p, fit indices) from Forge's logged run artifacts before any number enters a table.

### A.5 Reporting checklist (owner: Sentinel at audit; Quill at write-up)
- [ ] APA 7 + JARS-Quant (Appelbaum et al., 2018) â€” `_methods_lit\standards\Appelbaum_2018_JARS-Quant.pdf`
- [ ] Single-case / within-person design items (phase definitions, autocorrelation handling).
- [ ] ML items where any predictive model is used: TRIPOD+AI (Collins et al., 2024 â€” `_methods_lit\standards\Collins_2024_TRIPOD-AI-Checklist.pdf`) and REFORMS/leakage checks (Kapoor & Narayanan, 2023/2024, PDFs in Algorithmic-Management and ChatGPT `lit\methods*`): train-only fitting, OOF selection, single test touch, frozen seeds, NEGATIVE_RESULTS.md.
- [ ] Every claim-bearing citation maps to a PDF on disk (or is flagged in LIBRARY_RETRIEVAL_NEEDED.md).

### A.6 Manuscript status
Manuscript text stays at **stems only** (section headings + one-line stems, no results prose, no numbers) until Matt approves. Quill does not draft full text before that approval.

### A.7 Next action
Matt: methods note vs hold; Forge: replication recompute.


## Amendment 2026-10-24b: Opened by Matt
Status: **ACTIVE** (Matt, 2026-10-24: "open all projects on hold"). Supersedes the hold/"methods note" status above; earlier sections are kept unchanged.
All hypotheses below are **PROPOSED â€” for Matt to confirm** before Sentinel freezes them. PDFs marked (copied) were copied today from other Research Streams lit folders.

### B.2 Hypotheses (PROPOSED, ranked)
Opened as a **full project** (not a methods note).
- **Primary H1:** Daily self-compassion is higher in the two intervention (meditation) weeks than in the control week (within-person phase contrast; design from Li_et_al_2021).
- H2: Daily perceived stress and emotional exhaustion are lower in intervention weeks than in the control week.
- H3: Within-person day-to-day variability (scale) of self-compassion is lower in intervention weeks (location-scale extension).
- H4: Emotional inertia (lag-1 autoregression) of stress/exhaustion is lower in intervention weeks (Kuppens_Allen_Sheeber_2010).
- H5: Gains in self-compassion persist into the follow-up week.
Caveat: phases are ordered in time, so contrasts are within-person and descriptive, not causal.

### B.3 Locked analytic strategy (each method â†’ local PDF)
- **Model:** Bayesian two-level location-scale model in brms: phase (control/intervention/follow-up), weekday as fixed effects in location and scale; random person intercepts in both â€” Burkner_2017_brms.pdf (copied), Burkner_2018_Advanced_Bayesian_multilevel_brms.pdf (copied).
- **Centering:** day-level predictors person-mean centered â€” Hamaker_2015_To_center_or_not.pdf (copied).
- **H4:** lag-1 AR term by phase (DSEM-style) â€” Hamaker_et_al_2018_Frontiers_Intensive_Longitudinal_DSEM.pdf (copied); Kuppens_Allen_Sheeber_2010.pdf.
- **Estimator:** NUTS/HMC (brms/Stan), 4 chains, frozen seeds; weakly informative priors reported and checked per WAMBS â€” Depaoli_2017_WAMBS_checklist.pdf (copied).
- **Missing data:** missing days handled by the likelihood (MAR); compliance by phase reported; persons with < 3 days per phase flagged in sensitivity.
- **Multiplicity:** H1 primary; secondary outcomes (SC/PS/EE Ã— location/scale) reported as a family with posterior probabilities and 95% CrIs, no selective emphasis â€” Rubin_2021_When_to_adjust_alpha.pdf (copied).
- **Robustness:** frequentist lme4-type location-only model; prior sensitivity; excluding the follow-up week; linear time trend added to separate phase from time.
- **JARS items:** Bayesian reporting per Kruschke_2021_Bayesian_analysis_reporting.pdf (copied) (priors, convergence R-hat/ESS, posterior predictive checks), compliance per phase, ICCs.

### B.4 Recompute rule
All estimates recomputed from raw by Forge; existing outputs are not trusted until Verity confirms them.

### B.5 ML component and Ledger split
No ML component. If one is ever added: Ledger split by person ID (grouped), seed 20261024, stratified by baseline trait self-compassion (TSC) tertile; Forge fits on train only.

### B.6 Next actions (owners)
1. **Forge** â€” schema-level checks first (variable names, types, value ranges from metadata, N of persons/occasions from codebook), then replicate Li et al. (2021) phase means/SDs and their reported phase effects from raw. Train/raw only; no sealed files exist for this project.
2. **Verity** â€” independently checks every number Forge reports against the source paper / descriptive tables; discrepancies logged, not smoothed.
3. **Sentinel** â€” audits the frozen plan, code, seeds and any split before any confirmatory run; confirmatory run only after Sentinel sign-off and Matt's confirmation of B.2.
4. **Quill** â€” manuscript stems only (headings + one-line stems, no results prose) until Matt approves.
5. **Matt** â€” confirm/re-rank B.2; resolve gaps in B.7.

### B.7 Gaps needing Matt
- Confirm full project and H1 as primary.
- Full texts of Hollenstein 2015, Kuppens & Verduyn 2017, Olthof 2020 are abstract-only (library).
- Sample size/persons is small (from Li et al.); a scale model may be underpowered â€” accept as secondary?


## Lit retrieval update (2026-10-24, Grok Bot; legal open copies only, no Sci-Hub/LibGen)
- FOUND Olthof et al. 2020 -> lit/Olthof_etal_2020_Complexity_Early_Warning_ClinPsychSci.pdf (published OA)
- FOUND Kuppens & Verduyn 2017 -> lit/Kuppens_Verduyn_2017_Emotion_Dynamics_CurrOpinPsych.pdf (published, author page)
- NOT FOUND Hollenstein 2015 Emotion Review (no OA copy located)
- Burkner 2017 already present at lit/methods/Burkner_2017_brms.pdf


---

## Amendment 2026-10-24d: Novelty mandate

Source: Matt Monnot, relayed via Forge on 2026-10-24. Verbatim: "No replication unless it's only to check data integrity. Replication studies don't get published; the goal is new, novel uses of the data for new research questions." Everything above this amendment stays in force. Where this amendment conflicts with it, this amendment controls.

### D.1 Replication steps are demoted to integrity checks
Every earlier step that says "replicate", "reproduce", "recompute published estimates", or "replication recompute" (including A.4, A.7 and B.6 step 1 where present) now means a **data-integrity check only**:
- what is checked: N of persons and occasions, item ranges, missing-value codes, missingness counts, and composite reconstruction against the codebook and the published sample description;
- who checks: an unsealed runner, from aggregate output only (no row is printed or read by a bot);
- what is reported: pass or fail with the discrepancy, in an internal integrity log. It is **never reported as a result**, never tabled in the manuscript, and never tested as a hypothesis;
- a published effect estimate is not re-estimated as a deliverable. If a published coefficient is needed to sanity-check coding, it is compared once in the integrity log and goes no further.

### D.2 Constraints carried forward
No bot opens data rows. No cloud agents. No ML train/test split for confirmatory work. Grok bots only. The manuscript stays at section stems until Matt opens it. All hypotheses below are PROPOSED for Matt and are not frozen until he approves them.

### D.3 Prior use of these data
Li et al. (2021, *Applied Psychology: Health and Well-Being*, doi 10.1111/aphw.12278; OpenAlex W3154628384) tested mean phase effects (control week, intervention, follow-up) on daily self-compassion, stress and exhaustion, and moderation by trait SC. OpenAlex lists 23 citing works; none reuses the data. THEORY_REVIEW rates novelty risk HIGH and notes that Li, Hu, Ding et al. (2026) ran DSEM on a **new** sample, so this question has not been asked of these data. The Li 2021 full text must be checked for any meditation-day analysis before freezing (GAP).

### D.4 Candidate novel RQs (ranked)
1. **PRIMARY: Day-level adherence.** Within the intervention period, on days a person meditates, are same-day self-compassion higher and next-day exhaustion lower than on that person's non-meditation days? Li analysed phase means, not daily adherence.
2. **Exhaustion inertia by regime.** Does the day-to-day autoregression of exhaustion differ between the control week, the intervention and the follow-up (the THEORY_REVIEW surviving angle)?
3. **Coupling change.** Does the within-person SC-to-stress coupling strengthen across phases?

### D.5 Primary RQ specification (PROPOSED for Matt)
- H1 (PROPOSED): within-person meditation day (`meditation` = yes) is associated with higher same-day `SC`.
- H2 (PROPOSED): within-person meditation day is associated with lower next-day `EE`, controlling for today's `EE`.
- H3 (PROPOSED, exploratory): the person-level meditation rate (between-person) is associated with lower mean `EE` across the intervention period.
- Model: two-level model, days in persons, restricted to `Period` = 2 (days 7-20). Meditation is split into a person-mean-centred within part and a person-mean between part. Lag-1 `EE` is included for H2. `WD` (weekday/weekend) and `time` are covariates, and AR(1) residuals are used. Bayesian or REML estimation; no ML split.
- Variables (codebook only): `ID`, `Period`, `time`, `WD`, `meditation`, `SC`, `PS`, `EE` (day file); `TSC`, age, gender, hours (person file, as covariates only).
- N: 65 persons; 725 meditation-yes, 147 no and 38 missing person-days in the intervention period. With only 147 no-days, the power for H1/H2 is limited, and this is reported (GAP).
- Novelty evidence: no citing reuse; the published paper reports phase means; the DSEM paper uses a different sample.


## Note 2026-10-24e: gap resolution (Grok Bot; documents and literature only, no data rows opened)
- Li et al. (2021) full text (lit/Li_et_al_2021_Online_selfcompassion_meditation.pdf), Method and Results. The analysis uses two HLM specifications only: (a) time trends within each period, controlling for weekday versus weekend (Eq. 1-2), and (b) contrasts between periods (control days 1-7, intervention days 8-21, follow-up days 22-28; Eq. 3-4). Trait self-compassion enters as a level-2 moderator.
- The morning yes/no item ("whether they performed the meditation or not during the past 24 h") is described in Procedure. No analysis uses it as a predictor: there is no comparison of meditation days with non-meditation days, no adherence or dose analysis and no lagged next-day effect.
- Decision: the day-level adherence primary RQ is not in Li 2021. **The primary is unchanged.** The low power from the 147 no-days remains a reported limitation.

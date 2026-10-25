# 06a_regen_draws.R (2026-10-24, Blacksmith). NOT locked; DO NOT run before Plumber audit + Fort Knox lock
# + approval of the disclosed deviation (DEVIATIONS item 9).
# Rationale: the locked 12:15:29 fit saved summaries only (fits_summary.rds, results_aggregate.json); its
# CmdStan CSVs were in an R tempdir deleted at exit. The only CSVs left in /tmp (RtmpOo8cj2, 12:11-12:16)
# are from the ORPHANED launch (last set incomplete, unhashed) and must not be used.
# Decision (Mastermind, analysis lead): regenerate draws by running the locked R/02_fit_v3.R unedited, same
# seed (protocol_v3.json mcmc.seed), with CmdStan CSVs written to a persistent dir. The locked file is only
# sourced; its run_all() and fit_one() bodies run unchanged. A thin wrapper around fit_one() only sets
# cmdstanr's documented option `cmdstanr_output_dir` per fit before delegating to the locked fit_one().
# Reproduction check (A1 + Plumber D3, per-fit exact): (1) whole-file sha256 == locked f9ca85b9...576ae -> all
# 13 fits accepted; (2) else each fit entry of locked and regenerated files is re-serialized exactly as the locked
# writer does (jsonlite::toJSON, auto_unbox=TRUE, digits=6; summary already dropped) and a fit is accepted only on
# an identical string (no tolerance); a 'describe' mismatch rejects all. Writes ACCEPTED_FITS / REJECTED_FITS
# (one key per line); exit 1 only if H1_primary or H2_secondary is rejected.
# Thread env (A2b): BLAS threads are fixed at R startup, so RUN_ORDER step 2 exports OMP/MKL/OPENBLAS=2 before R.
# Usage (from protocol/): nice -n 19 Rscript R/06a_regen_draws.R data/raw/days.sav > logs/regen_draws_v3.log 2>&1
options(warn = 1)
# A2: thread environment exactly as logs/run.sh (OMP/MKL/OpenBLAS = 2), inherited by CmdStan.
Sys.setenv(OMP_NUM_THREADS = "2", MKL_NUM_THREADS = "2", OPENBLAS_NUM_THREADS = "2")
suppressPackageStartupMessages({library(jsonlite); library(digest)})
LOCKED <- c("R/02_fit_v3.R" = "5e6c352e5de60a98baf066e2dd665ed036619317c3476d960abd427aae6e4d3e",
            "R/01_prepare.R" = "7163c1cd28ec49b5f3a47444b5f31409db2fe4057469488f9660c9c355e565a8",
            "dsem_meditation.stan" = "02e4cfc55cce376ac08d1b32e86736936f6668d06b5b1c14558f29f2104ccd23",
            "protocol_v3.json" = "a5bf59c3447ecfbcb2d24771cb24735dfe8d8674b5558c2b29f12f514beaf85e",
            "results/results_aggregate.json" = "f9ca85b9660b1f6a4a9356023c98e908dc613b184e0706c9bfb6daf701c576ae")
for (f in names(LOCKED)) if (!identical(digest(file = f, algo = "sha256"), LOCKED[[f]])) stop("hash mismatch: ", f)
OUT <- "results/regen_v3"; DRAWS <- file.path(OUT, "draws")
if (dir.exists(OUT)) stop(OUT, " already exists; refusing to overwrite")
LOCKED_AGG_SHA <- "f9ca85b9660b1f6a4a9356023c98e908dc613b184e0706c9bfb6daf701c576ae"
source("R/02_fit_v3.R")   # locked; sys.nframe() guard means run_all() is not auto-called
fit_one_locked <- fit_one
KEY <- c("H1 SC same-day (one-sided, >0)" = "H1_primary", "H2 EE next-day | today's EE (one-sided, <0)" = "H2_secondary")
fit_one <- function(sd, label, sign) {
  key <- if (label %in% names(KEY)) KEY[[label]] else label
  d <- file.path(DRAWS, key); dir.create(d, showWarnings = FALSE); options(cmdstanr_output_dir = d)
  fit_one_locked(sd, label, sign)
}
# S6 is fitted by brms (rstan backend; cmdstanr_output_dir does NOT apply). Thin wrapper around the locked
# fit_S6(): calls it unchanged and keeps the brmsfit (saved as RDS) so its draws persist.
fit_S6_locked <- fit_S6
S6_FIT <- NULL
fit_S6 <- function(w, seed = mc$seed) {
  f <- fit_S6_locked(w, seed = seed)
  S6_FIT <<- f; saveRDS(f, file.path(DRAWS, "S6_observed_centering_brmsfit.rds")); f
}
# Aggregate key -> draws subfolder (fit_one label) for the 12 Stan fits; S6 via the brmsfit.
STAN_KEYS <- c(H1_primary = "H1_primary", H2_secondary = "H2_secondary", S1_prior_x2 = "S1_prior_x2",
  S1_prior_x05 = "S1_prior_x05", S2_same_row = "S2_same_row", S3_pmm_m025 = "S3_pmm_m025", S3_pmm_m050 = "S3_pmm_m050",
  S4_H2_prior_x2 = "S4_H2_prior_x2", S4_H2_prior_x05 = "S4_H2_prior_x05", S4_H2_same_row = "S4_H2_same_row",
  S4_H2_pmm_p050 = "S4_H2_pmm_p050", S5_li_exclusion = "S5")
N_DRAWS <- P$mcmc$chains * P$mcmc$iter_sampling   # 4 x 1000 = 4000 per fit
write_b_within <- function(accepted) {
  bd <- file.path(OUT, "b_within"); dir.create(bd)
  one <- function(key, x, src) {
    stopifnot(length(x) == N_DRAWS, !anyNA(x))
    f <- file.path(bd, paste0(key, ".csv")); write.csv(data.frame(b_within = x), f, row.names = FALSE)
    list(fit = key, file = f, source_variable = src, n_draws = length(x), sha256 = digest(file = f, algo = "sha256"))
  }
  man <- lapply(intersect(names(STAN_KEYS), accepted), function(k) {
    csv <- list.files(file.path(DRAWS, STAN_KEYS[[k]]), pattern = "\\.csv$", full.names = TRUE)
    stopifnot(length(csv) == P$mcmc$chains)
    d <- cmdstanr::read_cmdstan_csv(csv, variables = "b_within")$post_warmup_draws
    one(k, as.numeric(posterior::extract_variable_matrix(d, "b_within")), "b_within (Stan)")
  })
  if ("S6_observed_centering" %in% accepted) { stopifnot(!is.null(S6_FIT))
  man[[length(man) + 1]] <- one("S6_observed_centering", as.numeric(posterior::as_draws_df(S6_FIT)$b_med_wc), "b_med_wc (brms)") }
  stopifnot(length(man) == length(accepted))
  write_json(list(created = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), n_fits = length(man),
                  accepted_fits = accepted, rejected_fits = setdiff(ALL_FITS, accepted),
                  draws_per_fit = N_DRAWS, files = man), file.path(OUT, "B_WITHIN_MANIFEST.json"), auto_unbox = TRUE, pretty = TRUE)
}

ALL_FITS <- c(names(STAN_KEYS), "S6_observed_centering")
# D3 comparison. Fit entries: top-level H1_primary, H2_secondary; each element of top-level 'sensitivity'.
ser <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, digits = 6))
fit_entries <- function(j) c(j[c("H1_primary", "H2_secondary")], j$sensitivity)
compare_aggregates <- function(locked_file, regen_file, locked_sha = LOCKED_AGG_SHA) {
  if (identical(digest(file = regen_file, algo = "sha256"), locked_sha))
    return(list(mode = "whole_file_sha256", accepted = ALL_FITS))
  L <- jsonlite::fromJSON(locked_file, simplifyVector = FALSE); R <- jsonlite::fromJSON(regen_file, simplifyVector = FALSE)
  if (!identical(ser(L$describe), ser(R$describe))) return(list(mode = "describe_mismatch", accepted = character(0)))
  lf <- fit_entries(L); rf <- fit_entries(R)
  acc <- Filter(function(k) !is.null(lf[[k]]) && !is.null(rf[[k]]) && identical(ser(lf[[k]]), ser(rf[[k]])), ALL_FITS)
  list(mode = "per_fit_reserialized", accepted = acc)
}
main <- function(days_path) {
  cat("start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
  sha <- digest(file = days_path, algo = "sha256"); cat("days.sav sha256:", sha, "\n")
  if (!identical(sha, P$data$days_sha256)) stop("days.sav sha256 mismatch")
  cv <- as.character(cmdstanr::cmdstan_version()); if (!identical(cv, "2.40.0")) stop("CmdStan ", cv, " != 2.40.0")
  dir.create(DRAWS, recursive = TRUE)   # only after all hash and version checks pass
  run_all(days_path, out_dir = OUT)
  csv <- list.files(DRAWS, pattern = "\\.(csv|rds)$", recursive = TRUE, full.names = TRUE)
  man <- data.frame(file = csv, sha256 = vapply(csv, digest, "", file = TRUE, algo = "sha256"), row.names = NULL)
  write_json(list(created = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), seed = P$mcmc$seed, days_sha256 = sha,
                  n_fits_dirs = length(list.dirs(DRAWS, recursive = FALSE)), files = man),
             file.path(OUT, "DRAWS_MANIFEST.json"), auto_unbox = TRUE, pretty = TRUE)
  # A1/D3: whole-file sha256, else per-fit exact re-serialized comparison.
  rsha <- digest(file = file.path(OUT, "results_aggregate.json"), algo = "sha256")
  cmp <- compare_aggregates("results/results_aggregate.json", file.path(OUT, "results_aggregate.json"))
  acc <- cmp$accepted; rej <- setdiff(ALL_FITS, acc)
  cat("regenerated sha256:", rsha, "| locked:", LOCKED_AGG_SHA, "| mode:", cmp$mode, "\n")
  cat("ACCEPTED_FITS:", acc, "\nREJECTED_FITS:", rej, "\n")
  writeLines(acc, file.path(OUT, "ACCEPTED_FITS")); writeLines(rej, file.path(OUT, "REJECTED_FITS"))
  print(sessionInfo()); cat("cmdstan_version:", cv, "\n")
  if (length(acc)) write_b_within(acc)   # b_within CSVs only for accepted fits
  cat("end:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
  if (!all(c("H1_primary", "H2_secondary") %in% acc)) { cat("H1/H2 not reproduced: Table 4/Figure 2 BLOCKED\n"); quit(status = 1) }
}
if (sys.nframe() == 0) main(commandArgs(TRUE)[1])

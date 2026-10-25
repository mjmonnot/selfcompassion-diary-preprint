# 08_fit_no_nonmed.R (2026-10-24, Blacksmith). DRAFT, NOT locked, NOT run. Needs Plumber PASS + Apprentice MATCH +
# Fort Knox lock. SENSITIVITY, NOT HYPOTHESES (DEVIATIONS item 12; Reviewer 2 M3).
# Rationale: 12 persons have no non-meditation day in the window (describe$n_zero_no_days), so their person slopes
# are informed only by the population distribution. This refits H1 and H2 without them, reusing the locked
# R/02_fit_v3.R fit_one(), to_stan() and dsem_meditation.stan unedited (same priors, sampler settings, seed, signs).
# Exclusion rule: drop IDs with zero med_day == 0 rows under the locked previous_day alignment (same rule as
# 01_prepare.R describe_window). No decision claim; reported as posterior shift vs H1/H2.
# Usage (from protocol/): OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 OPENBLAS_NUM_THREADS=2 nice -n 19 Rscript R/08_fit_no_nonmed.R data/raw/days.sav > logs/fit_no_nonmed_v3.log 2>&1
options(warn = 1)
suppressPackageStartupMessages({library(jsonlite); library(digest)})
LOCKED <- c("R/02_fit_v3.R" = "5e6c352e5de60a98baf066e2dd665ed036619317c3476d960abd427aae6e4d3e",
            "R/01_prepare.R" = "7163c1cd28ec49b5f3a47444b5f31409db2fe4057469488f9660c9c355e565a8",
            "dsem_meditation.stan" = "02e4cfc55cce376ac08d1b32e86736936f6668d06b5b1c14558f29f2104ccd23",
            "protocol_v3.json" = "a5bf59c3447ecfbcb2d24771cb24735dfe8d8674b5558c2b29f12f514beaf85e")
for (f in names(LOCKED)) if (!identical(digest(file = f, algo = "sha256"), LOCKED[[f]])) stop("hash mismatch: ", f)
OUT <- "results/no_nonmed_v3"; if (dir.exists(OUT)) stop(OUT, " already exists; refusing to overwrite")
source("R/02_fit_v3.R")   # locked; run_all() not auto-called
main <- function(days_path) {
  cat("start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
  sha <- digest(file = days_path, algo = "sha256"); if (!identical(sha, P$data$days_sha256)) stop("days.sav sha256 mismatch")
  cv <- as.character(cmdstanr::cmdstan_version()); if (!identical(cv, "2.40.0")) stop("CmdStan ", cv, " != 2.40.0")
  w <- prepare_days(haven::read_sav(days_path), "previous_day")
  n_no <- tapply(w$med_day == 0, w$ID, sum, na.rm = TRUE); keep <- names(n_no)[n_no > 0]
  stopifnot(length(n_no) - length(keep) == 12, length(keep) == 53)   # N1: exactly 12 dropped, 53 kept
  wk <- w[w$ID %in% keep, ]
  dir.create(file.path(OUT, "draws"), recursive = TRUE)
  run <- function(key, sd, sign) { d <- file.path(OUT, "draws", key); dir.create(d); options(cmdstanr_output_dir = d)
    r <- fit_one(sd, key, sign); r[setdiff(names(r), c("summary", "supported_975", "inconclusive"))] }   # N2: no decision fields
  res <- list(label = "sensitivity, not hypotheses (M3: persons with >= 1 non-meditation day only)",
              describe = describe_window(wk), n_persons_dropped = length(n_no) - length(keep),
              H1_no_nonmed = run("H1_no_nonmed", to_stan(wk, "SC"), P$hypotheses$H1_primary$sign),
              H2_no_nonmed = run("H2_no_nonmed", to_stan(wk, "EE", lag_med = TRUE), P$hypotheses$H2_secondary$sign))
  csv <- list.files(file.path(OUT, "draws"), pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  write_json(list(files = data.frame(file = csv, sha256 = vapply(csv, digest, "", file = TRUE, algo = "sha256"), row.names = NULL)),
             file.path(OUT, "DRAWS_MANIFEST.json"), auto_unbox = TRUE, pretty = TRUE)
  write_json(res, file.path(OUT, "no_nonmed_summary.json"), auto_unbox = TRUE, digits = 6, pretty = TRUE)
  print(sessionInfo()); cat("cmdstan_version:", cv, "\nend:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
}
if (sys.nframe() == 0) main(commandArgs(TRUE)[1])

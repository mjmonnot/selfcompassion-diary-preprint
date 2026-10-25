# 07_fit_ps.R (2026-10-24, Blacksmith). NOT locked; DO NOT run before Plumber audit + Fort Knox lock.
# Rationale: protocol_v3.json additional_analyses lists "PS as outcome" (line 52), pre-specified, with no
# decision threshold (PROTOCOL_DRAFT_v3.md line 14). Approved to run by Mastermind (analysis lead).
# The protocol does NOT state the PS predictor timing, lag, or direction, so they are REQUIRED arguments
# (no default): spec = same_day (H1 structure: to_stan(w,"PS")) or next_day (H2 structure:
# to_stan(w,"PS",lag_med=TRUE), AR = today's PS); sign = -1 or 1 (used only for P(direction); not a test).
# Decision: reuse the locked fit_one() and dsem_meditation.stan unedited (same priors, sampler settings,
# seed from protocol_v3.json); a thin wrapper only sets cmdstanr_output_dir so the draws persist.
# Usage (from protocol/): nice -n 19 Rscript R/07_fit_ps.R data/raw/days.sav <same_day|next_day> <-1|1> > logs/fit_ps_v3_<spec>.log 2>&1
# Analysis lead (Mastermind) decision: run BOTH timings, Period 2 window, sign -1; P(<0) is the reported directional P.
options(warn = 1)
suppressPackageStartupMessages({library(jsonlite); library(digest)})
LOCKED <- c("R/02_fit_v3.R" = "5e6c352e5de60a98baf066e2dd665ed036619317c3476d960abd427aae6e4d3e",
            "R/01_prepare.R" = "7163c1cd28ec49b5f3a47444b5f31409db2fe4057469488f9660c9c355e565a8",
            "dsem_meditation.stan" = "02e4cfc55cce376ac08d1b32e86736936f6668d06b5b1c14558f29f2104ccd23",
            "protocol_v3.json" = "a5bf59c3447ecfbcb2d24771cb24735dfe8d8674b5558c2b29f12f514beaf85e")
for (f in names(LOCKED)) if (!identical(digest(file = f, algo = "sha256"), LOCKED[[f]])) stop("hash mismatch: ", f)
ROOT <- "results/ps_v3"   # per-timing subfolders: results/ps_v3/<spec>/ (own draws, manifest, summary)
source("R/02_fit_v3.R")   # locked (sources 01_prepare.R); sys.nframe() guard: run_all() not called

main <- function(days_path, spec, sign) {
  spec <- match.arg(spec, c("same_day", "next_day")); sign <- as.integer(sign); stopifnot(sign %in% c(-1L, 1L))
  OUT <- file.path(ROOT, spec); DRAWS <- file.path(OUT, "draws")
  if (dir.exists(OUT)) stop(OUT, " already exists; refusing to overwrite")
  cat("start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
  sha <- digest(file = days_path, algo = "sha256"); cat("days.sav sha256:", sha, "\n")
  if (!identical(sha, P$data$days_sha256)) stop("days.sav sha256 mismatch")
  dir.create(DRAWS, recursive = TRUE)  # only after all hash checks pass; creates results/ps_v3/<spec>/draws
  days <- haven::read_sav(days_path)
  w <- prepare_days(days, "previous_day")          # same window/alignment as H1/H2
  sd <- if (spec == "same_day") to_stan(w, "PS") else to_stan(w, "PS", lag_med = TRUE)
  options(cmdstanr_output_dir = DRAWS)
  r <- fit_one(sd, paste0("PS_", spec), sign)      # locked function, unchanged
  csv <- list.files(DRAWS, pattern = "\\.csv$", full.names = TRUE)
  stopifnot(length(csv) == P$mcmc$chains)
  sdg <- cmdstanr::read_cmdstan_csv(csv, variables = "")$post_warmup_sampler_diagnostics
  td <- posterior::extract_variable_matrix(sdg, "treedepth__")
  man <- data.frame(file = csv, sha256 = vapply(csv, digest, "", file = TRUE, algo = "sha256"), row.names = NULL)
  write_json(list(created = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), seed = P$mcmc$seed, days_sha256 = sha, files = man),
             file.path(OUT, "DRAWS_MANIFEST.json"), auto_unbox = TRUE, pretty = TRUE)
  res <- c(list(label = "EXPLORATORY additional analysis; timing/sign set after H1/H2 results were known; not confirmatory", spec = spec, window = "Period 2, previous_day alignment", sign_for_p_dir = sign, protocol_basis = "protocol_v3.json additional_analyses: 'PS as outcome'",
                n_persondays = sd$N, n_persons = sd$J, PS_missing = sd$N_mis,
                treedepth_max_hits = sum(td >= P$mcmc$max_treedepth), max_treedepth = P$mcmc$max_treedepth),
           r[setdiff(names(r), c("summary", "supported_975", "inconclusive"))], list(summary = r$summary))  # P2: no decision flags
  write_json(res, file.path(OUT, "ps_summary.json"), auto_unbox = TRUE, digits = NA, pretty = TRUE)
  str(res[setdiff(names(res), "summary")]); print(r$summary)
  print(sessionInfo()); cat("cmdstan_version:", as.character(cmdstanr::cmdstan_version()), "\n")
  cat("end:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
}
if (sys.nframe() == 0) { a <- commandArgs(TRUE); if (length(a) != 3) stop("usage: 07_fit_ps.R <days.sav> <same_day|next_day> <-1|1>"); main(a[1], a[2], a[3]) }

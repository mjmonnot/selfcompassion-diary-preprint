# 04_omega_run.R (2026-10-24, Blacksmith). Driver for the locked R/03_omega.R; NOT locked. Needs Plumber audit + Fort Knox lock before running.
# Rationale: 03_omega.R only defines ml_omega() and item lists; this driver loads days.sav exactly as the
# v3 fit does (R/01_prepare.R prepare_days(), previous_day alignment, Period 2 window) and computes
# within/between omega for SC and EE in two windows (Period 2 primary; all 28 days per protocol_v3.json) (Geldhof, Preacher & Zyphur 2014). PS is descriptive only: not computed.
# Usage (from protocol/): nice -n 19 Rscript R/04_omega_run.R data/raw/days.sav > logs/omega_v3_run.log 2>&1
suppressPackageStartupMessages({library(jsonlite); library(digest)})
P <- fromJSON("protocol_v3.json")
source("R/01_prepare.R")   # locked; sets SEED and loads haven/dplyr
source("R/03_omega.R")     # locked; defines ml_omega, SC_items, EE_items, PS_items
set.seed(P$mcmc$seed)

main <- function(days_path, out = "results/omega_v3.json") {
  cat("start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
  sha <- digest(file = days_path, algo = "sha256")
  cat("days.sav sha256:", sha, "\n")
  if (!identical(sha, P$data$days_sha256)) stop("days.sav sha256 does not match protocol_v3.json; aborting")
  days <- haven::read_sav(days_path)
  # Window 1 (primary): Period 2 analysis window, exactly as the v3 fit (prepare_days previous_day).
  w <- as.data.frame(prepare_days(days, "previous_day"))
  # Window 2: all 28 diary days (protocol_v3.json: 'all 28 days and Period 2 reported'). Built from the
  # raw loaded days.sav, same labels-zapping as prepare_days, no Period filter, no lag/lead (omega is
  # same-day item structure), so no rows are dropped by any alignment step.
  a28 <- days |> dplyr::mutate(dplyr::across(dplyr::everything(), ~ as.numeric(haven::zap_labels(.x)))) |>
    dplyr::arrange(ID, time) |> as.data.frame()
  for (nm in c("w", "a28")) {
    miss <- setdiff(c("ID", SC_items, EE_items), names(get(nm)))
    if (length(miss)) stop(nm, ": missing item columns: ", paste(miss, collapse = ", "))
  }
  win <- function(d, label) list(label = label, n_rows = nrow(d), n_clusters = length(unique(d$ID)),
                                 SC = as.list(ml_omega(d, SC_items)), EE = as.list(ml_omega(d, EE_items)))
  res <- list(
    date = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), seed = P$mcmc$seed, days_sha256 = sha,
    estimator = "lavaan two-level CFA, MLR, missing=ml",
    period2_primary = win(w, "Period 2 (time 7-20), prepare_days(previous_day)"),
    all28_days = win(a28, "all 28 diary days, raw items, no Period filter, no lag"),
    PS = "descriptive only per R/03_omega.R; not computed",
    lavaan_version = as.character(packageVersion("lavaan")))
  dir.create(dirname(out), showWarnings = FALSE)
  write_json(res, out, auto_unbox = TRUE, digits = NA, pretty = TRUE)
  print(res[c("period2_primary", "all28_days")])
  cat("warnings:\n"); print(warnings())
  print(sessionInfo())
  cat("cmdstan_version:", tryCatch(as.character(cmdstanr::cmdstan_version()), error = function(e) paste("unavailable:", conditionMessage(e))), "\n")
  cat("end:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
}
if (sys.nframe() == 0) { a <- commandArgs(TRUE); main(a[1]) }

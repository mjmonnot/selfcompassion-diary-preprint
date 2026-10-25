# Rationale: one script, one entry point, frozen seed and MCMC settings from protocol.json.
# Decision: fit primary (SC same-day), secondary (EE next-day) and the consolidated sensitivity list.
suppressPackageStartupMessages({library(cmdstanr); library(jsonlite); library(posterior)})
source("R/01_prepare.R")
P <- fromJSON("protocol.json")
mc <- P$mcmc

fit_one <- function(sd, label) {
  mod <- cmdstan_model("dsem_meditation.stan")
  f <- mod$sample(data = sd, seed = mc$seed, chains = mc$chains, parallel_chains = mc$parallel_chains,
                  iter_warmup = mc$iter_warmup, iter_sampling = mc$iter_sampling,
                  adapt_delta = mc$adapt_delta, max_treedepth = mc$max_treedepth, refresh = 0)
  s <- f$summary(c("b_within","b0","g","phi","sd_b","sigma"))
  dr <- as_draws_df(f$draws("b_within"))$b_within
  conv <- all(s$rhat < mc$rhat_max, na.rm = TRUE) && all(s$ess_bulk > mc$ess_min & s$ess_tail > mc$ess_min, na.rm = TRUE)
  div <- sum(f$diagnostic_summary()$num_divergent)
  list(label = label, converged = conv, divergences = div,
       est = median(dr), ci95 = quantile(dr, c(.025,.975)), ci90 = quantile(dr, c(.05,.95)),
       p_pos = mean(dr > 0), p_neg = mean(dr < 0), summary = as.data.frame(s))
}

run_all <- function(days_path, out_dir = "results") {
  dir.create(out_dir, showWarnings = FALSE)
  days <- haven::read_sav(days_path)
  w  <- prepare_days(days, "previous_day")
  ws <- prepare_days(days, "same_row")
  res <- list(describe = describe_window(w))
  res$H1_primary   <- fit_one(to_stan(w, "SC"), "H1 SC same-day (one-sided, >0)")
  res$H2_secondary <- fit_one(to_stan(w, "EE", lag_med = TRUE), "H2 EE next-day | today's EE (one-sided, <0)")
  sens <- list(
    S1_prior_x2   = to_stan(w, "SC", slope_sd = 1.0),
    S1_prior_x05  = to_stan(w, "SC", slope_sd = 0.25),
    S2_same_row   = to_stan(ws, "SC"),
    S3_pmm_m025   = to_stan(w, "SC", delta = -0.25),
    S3_pmm_m050   = to_stan(w, "SC", delta = -0.50),
    S4_H2_prior_x2  = to_stan(w, "EE", lag_med = TRUE, slope_sd = 1.0),
    S4_H2_prior_x05 = to_stan(w, "EE", lag_med = TRUE, slope_sd = 0.25),
    S4_H2_same_row  = to_stan(ws, "EE", lag_med = TRUE),
    S4_H2_pmm_p050  = to_stan(w, "EE", lag_med = TRUE, delta = 0.50))
  res$sensitivity <- Map(fit_one, sens, names(sens))
  # S5: Li-style exclusion (< 7 meditation days) -> refit on the reduced set
  keep <- names(which(tapply(w$med_day == 1, w$ID, sum, na.rm = TRUE) >= 7))
  res$sensitivity$S5_li_exclusion <- fit_one(to_stan(w[w$ID %in% keep, ], "SC"), "S5")
  saveRDS(res, file.path(out_dir, "fits_summary.rds"))
  write_json(lapply(res, function(r) if (is.list(r)) r[setdiff(names(r), "summary")] else r),
             file.path(out_dir, "results_aggregate.json"), auto_unbox = TRUE, digits = 6)
  invisible(res)
}
if (sys.nframe() == 0) { a <- commandArgs(TRUE); run_all(a[1]) }

# v3 (2026-10-24): supersedes R/02_fit.R (v1) and R/02_fit_v2.R. Direction per hypothesis from protocol_v3.json.
# Rationale: one script, one entry point, frozen seed and MCMC settings from protocol.json.
# Decision: fit primary (SC same-day), secondary (EE next-day) and the consolidated sensitivity list.
suppressPackageStartupMessages({library(cmdstanr); library(jsonlite); library(posterior)})
source("R/01_prepare.R")
P <- fromJSON("protocol_v3.json")
mc <- P$mcmc

# Pure decision/summary function (testable on simulated draws). sign = +1 for '>0', -1 for '<0'.
summarise_draws_dir <- function(dr, sign, conv = TRUE, div = 0L, thr = 0.975, band = 0.2) {
  stopifnot(sign %in% c(1, -1))
  q <- quantile(dr, c(.025, .05, .5, .95, .975))
  p_dir <- mean(sign * dr > 0)
  list(sign = sign, median = unname(q[3]), ci95 = unname(q[c(1,5)]), ci90 = unname(q[c(2,4)]),
       p_pos = mean(dr > 0), p_neg = mean(dr < 0),
       p_dir = p_dir,                               # P(effect in hypothesised direction)
       p_beyond_band = mean(sign * dr > band),      # P(effect > 0.2 SD in hypothesised direction)
       supported_975 = isTRUE(conv) && div == 0 && p_dir >= thr,
       inconclusive = q[1] < 0 && q[5] > 0 && (q[1] < -band || q[5] > band))
}

fit_one <- function(sd, label, sign) {
  mod <- cmdstan_model("dsem_meditation.stan")
  f <- mod$sample(data = sd, seed = mc$seed, chains = mc$chains, parallel_chains = mc$parallel_chains,
                  iter_warmup = mc$iter_warmup, iter_sampling = mc$iter_sampling,
                  adapt_delta = mc$adapt_delta, max_treedepth = mc$max_treedepth, refresh = 0)
  s <- f$summary(c("b_within","b0","g","phi","sd_b","sigma"))
  dr <- as_draws_df(f$draws("b_within"))$b_within
  conv <- all(s$rhat < mc$rhat_max, na.rm = TRUE) && all(s$ess_bulk > mc$ess_min & s$ess_tail > mc$ess_min, na.rm = TRUE)
  div <- sum(f$diagnostic_summary()$num_divergent)
  c(list(label = label, converged = conv, divergences = div),
    summarise_draws_dir(dr, sign, conv, div, thr = P$decision_threshold, band = P$inconclusive_band_sd),
    list(summary = as.data.frame(s)))
}

# S6 (sensitivity only; specification = Blacksmith default, NOT Matt-approved, pending Matt): observed person-mean centering, brms, ar(time|ID).
# Never replaces the primary latent-centred Stan model.
fit_S6 <- function(w, seed = mc$seed) {  # seed from protocol_v3.json mcmc.seed
  w <- w |> dplyr::group_by(ID) |> dplyr::mutate(med_pm = mean(med_day, na.rm = TRUE),
                                                   med_wc = med_day - med_pm, time_c = (time - 13.5) / 7) |> dplyr::ungroup() |> dplyr::mutate(SC = as.numeric(scale(SC))) |> dplyr::ungroup()
  brms::brm(SC ~ med_wc + med_pm + WD + time_c + (1 + med_wc | ID) + ar(time = time, gr = ID, p = 1),
            data = w, prior = brms::set_prior("normal(0, 0.5)", class = "b"),  # applies to ALL b coefs: med_wc, med_pm, WD, time_c
            chains = mc$chains, iter = mc$iter_warmup + mc$iter_sampling, warmup = mc$iter_warmup, seed = seed,
            control = list(adapt_delta = mc$adapt_delta, max_treedepth = mc$max_treedepth), refresh = 0)
}

run_all <- function(days_path, out_dir = "results") {
  dir.create(out_dir, showWarnings = FALSE)
  days <- haven::read_sav(days_path)
  w  <- prepare_days(days, "previous_day")
  ws <- prepare_days(days, "same_row")
  res <- list(describe = describe_window(w))
  sH1 <- P$hypotheses$H1_primary$sign; sH2 <- P$hypotheses$H2_secondary$sign
  res$H1_primary   <- fit_one(to_stan(w, "SC"), "H1 SC same-day (one-sided, >0)", sH1)
  res$H2_secondary <- fit_one(to_stan(w, "EE", lag_med = TRUE), "H2 EE next-day | today's EE (one-sided, <0)", sH2)
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
  sd_dir <- P$sensitivity_direction
  sgn <- ifelse(startsWith(names(sens), "S4"), sd_dir$S4, sd_dir[[1]])  # S1-S3 follow H1 (+1); S4 follows H2 (-1)
  sgn[!startsWith(names(sens), "S4")] <- sH1
  res$sensitivity <- Map(fit_one, sens, names(sens), sgn)
  # S5: Li-style exclusion (< 7 meditation days) -> refit on the reduced set
  keep <- names(which(tapply(w$med_day == 1, w$ID, sum, na.rm = TRUE) >= 7))
  res$sensitivity$S5_li_exclusion <- fit_one(to_stan(w[w$ID %in% keep, ], "SC"), "S5", sd_dir$S5)
  f6 <- fit_S6(w)  # S6 sensitivity only
  d6 <- as_draws_df(f6)$b_med_wc
  res$sensitivity$S6_observed_centering <- c(list(label = "S6", rhat_max = max(brms::rhat(f6), na.rm = TRUE)),
       summarise_draws_dir(d6, sd_dir$S6, thr = P$decision_threshold, band = P$inconclusive_band_sd))
  saveRDS(res, file.path(out_dir, "fits_summary.rds"))
  write_json(lapply(res, function(r) if (is.list(r)) r[setdiff(names(r), "summary")] else r),
             file.path(out_dir, "results_aggregate.json"), auto_unbox = TRUE, digits = 6)
  invisible(res)
}
if (sys.nframe() == 0) { a <- commandArgs(TRUE); run_all(a[1]) }

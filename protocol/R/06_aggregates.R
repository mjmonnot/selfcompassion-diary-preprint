# 06_aggregates.R (2026-10-24, Blacksmith). NOT locked; needs Plumber audit + Fort Knox lock before running.
# Rationale: manuscript Table 1 (descriptives), Table 4 (additional parameters) and Figure 2 (PPC) from the
# locked v3 fit with NO refit. Draw-based parts read only hash-manifested draws from results/regen_v3
# (06a_regen_draws.R, disclosed deviation item 9); if absent or unreproduced they are recorded as BLOCKED.
# Usage (from protocol/): nice -n 19 Rscript R/06_aggregates.R data/raw/days.sav > logs/aggregates_v3.log 2>&1
options(warn = 1)
suppressPackageStartupMessages({library(jsonlite); library(digest); library(posterior); library(lme4)})
P <- fromJSON("protocol_v3.json")
source("R/01_prepare.R")   # locked
set.seed(P$mcmc$seed)
SAVED <- c("results/fits_summary.rds" = "53acd8383110aa2ae7ac851cbcfdaf8771fcfe85623c2c5de02d7c9c362536c1",
           "results/results_aggregate.json" = "f9ca85b9660b1f6a4a9356023c98e908dc613b184e0706c9bfb6daf701c576ae")
REGEN <- "results/regen_v3"
BAND <- P$inconclusive_band_sd   # 0.2; protocol_v3.json: outcome z-scored on observed analysis-window values (total SD units)

# M2 (Reviewer 2): exclusion/alignment flow, counts only, via the locked prepare_days().
exclusion_flow <- function(days) {
  tab <- function(x) list(yes = sum(x == 1, na.rm = TRUE), no = sum(x == 0, na.rm = TRUE), missing = sum(is.na(x)))
  d <- days |> dplyr::mutate(dplyr::across(dplyr::everything(), ~ as.numeric(haven::zap_labels(.x)))) |> dplyr::arrange(ID, time)
  p2 <- d[d$Period == 2, ]
  ld <- d |> dplyr::group_by(ID) |> dplyr::mutate(m = dplyr::lead(meditation)) |> dplyr::ungroup() |> dplyr::filter(Period == 2)
  w <- prepare_days(days, "previous_day")
  list(label = "descriptive; not confirmatory", all_rows = nrow(d), all_persons = length(unique(d$ID)),
       period2 = list(rows = nrow(p2), persons = length(unique(p2$ID)), days = length(unique(p2$time))),
       step1_same_row_period2 = tab(p2$meditation),
       step1_day7_rows_leaving_window = tab(p2$meditation[p2$time == 7]),
       step2_after_lead_shift = tab(ld$m),
       step2_day20_rows_reading_period3 = tab(ld$m[ld$time == 20]),
       step3_final_previous_day = tab(w$med_day),
       persons_zero_no_days = sum(tapply(w$med_day == 0, w$ID, sum, na.rm = TRUE) == 0),
       note = "missing 38 (same-row) - 3 (day-7 missing leave the window) + 65 (day 20 set NA) = 100")
}
# C2/C3 (Reviewer 2): per-draw ROPE probability and within-person rescaling for H1/H2.
rope_rescale <- function(dr) {
  dm <- as_draws_matrix(subset_draws(dr, variable = c("b_within", "sigma")))
  b <- as.numeric(dm[, "b_within"]); sg <- as.numeric(dm[, "sigma"]); r <- b / sg
  q <- function(x) unname(quantile(x, c(.025, .5, .975)))
  list(label = "descriptive, post hoc; not confirmatory",
       P_abs_b_lt_band = mean(abs(b) < BAND), band_sd = BAND, band_scale = "total SD (z-scored over observed analysis-window values)",
       b_over_sigma = list(median = q(r)[2], ci95 = q(r)[c(1, 3)], P_abs_lt_band = mean(abs(r) < BAND),
         unit_note = "b/sigma is in within-person residual-SD units, not total SD; the 0.2 cut-off on this scale is post hoc"),
       sigma = list(median = q(sg)[2], ci95 = q(sg)[c(1, 3)]),
       sigma_definition = "dsem_meditation.stan sigma: within-person residual (innovation) SD after AR(1), total-SD units",
       n_draws = length(b))
}

table1 <- function(d) {
  one <- function(v) {
    x <- d[[v]]; icc <- tryCatch({
      m <- lmer(stats::as.formula(paste(v, "~ 1 + (1|ID)")), data = d, REML = TRUE)
      vc <- as.data.frame(VarCorr(m)); vc$vcov[1] / sum(vc$vcov) }, error = function(e) paste("error:", conditionMessage(e)))
    list(M = mean(x, na.rm = TRUE), SD = sd(x, na.rm = TRUE), ICC1 = icc,
         n_obs = sum(!is.na(x)), n_missing = sum(is.na(x)), pct_missing = 100 * mean(is.na(x)))
  }
  list(n_rows = nrow(d), n_clusters = length(unique(d$ID)), SC = one("SC"), EE = one("EE"), PS = one("PS"))
}

# Reads one fit's regenerated CSVs; verifies each against DRAWS_MANIFEST.json.
read_fit <- function(key, man) {
  f <- man$file[startsWith(man$file, file.path(REGEN, "draws", key, ""))]
  if (!length(f)) stop("no draws for ", key)
  for (i in f) if (!identical(digest(file = i, algo = "sha256"), man$sha256[man$file == i])) stop("draw hash mismatch: ", i)
  cmdstanr::read_cmdstan_csv(f, variables = NULL)$post_warmup_draws
}
par_summary <- function(dr, vars) {
  s <- summarise_draws(subset_draws(dr, variable = vars), median, ~quantile2(.x, c(.025, .975)), rhat, ess_bulk, ess_tail)
  lapply(split(s, s$variable), function(r) as.list(r[-1]))
}

# PPC (Figure 2): one-step-ahead replicated y from saved draws via the Stan likelihood (dsem_meditation.stan
# model block), conditioning on observed/imputed lagged y. Stats: mean, SD, lag-1 autocorrelation.
ppc <- function(dr, sd, ndraw = 400) {
  dm <- as_draws_matrix(dr); idx <- round(seq(1, nrow(dm), length.out = ndraw))
  J <- sd$J; ac1 <- function(y) { yl <- c(NA, y[-length(y)]); yl[sd$first == 1] <- NA; stats::cor(y, yl, use = "complete.obs") }
  obs_y <- ifelse(sd$y_miss == 1, NA, sd$y_obs_fill)
  st <- t(vapply(idx, function(k) {
    g <- function(v) as.numeric(dm[k, v]); a <- as.numeric(dm[k, sprintf("a[%d]", 1:J)]); b <- as.numeric(dm[k, sprintf("b[%d]", 1:J)]); p <- as.numeric(dm[k, sprintf("p[%d]", 1:J)])
    ymis <- if (sd$N_mis > 0) as.numeric(dm[k, sprintf("y_mis[%d]", 1:sd$N_mis)]) else numeric(0)
    y <- ifelse(sd$y_miss == 1, ymis[pmax(sd$mis_idx, 1)], sd$y_obs_fill); j <- sd$id
    w <- ifelse(sd$m_miss == 1, 0, sd$m - p[j])
    mu <- a[j] + b[j] * w + g("g") * (p[j] - 0.5) + g("c_wd") * sd$wd + g("c_t") * sd$tc + (if (sd$use_xlag) g("c_x") * sd$xlag else 0)
    ylag <- c(NA, y[-sd$N]); mu <- mu + ifelse(sd$first == 1, 0, g("phi") * (ylag - a[j]))
    yr <- stats::rnorm(sd$N, mu, g("sigma")); yr[sd$y_miss == 1] <- NA
    c(mean = mean(yr, na.rm = TRUE), sd = stats::sd(yr, na.rm = TRUE), ac1 = ac1(yr))
  }, numeric(3)))
  o <- c(mean = mean(obs_y, na.rm = TRUE), sd = stats::sd(obs_y, na.rm = TRUE), ac1 = ac1(obs_y))
  list(observed = as.list(o), n_rep_draws = ndraw,
       rep = lapply(colnames(st), function(s) list(stat = s, median = median(st[, s]),
              q025 = unname(quantile(st[, s], .025)), q975 = unname(quantile(st[, s], .975)),
              ppp = mean(st[, s] >= o[[s]]))), rep_matrix = st)
}

main <- function(days_path, out = "results/aggregates_v3.json", fig = "results/figure2_ppc_v3.png") {
  cat("start:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
  sha <- digest(file = days_path, algo = "sha256"); cat("days.sav sha256:", sha, "\n")
  if (!identical(sha, P$data$days_sha256)) stop("days.sav sha256 mismatch")
  for (f in names(SAVED)) if (!identical(digest(file = f, algo = "sha256"), SAVED[[f]])) stop("saved fit file hash mismatch: ", f)
  days <- haven::read_sav(days_path)
  w <- as.data.frame(prepare_days(days, "previous_day"))
  a28 <- days |> dplyr::mutate(dplyr::across(dplyr::everything(), ~ as.numeric(haven::zap_labels(.x)))) |> as.data.frame()
  res <- list(date = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), seed = P$mcmc$seed, days_sha256 = sha,
              table1 = list(period2_primary = table1(w), all28_days = table1(a28),
                            note = "raw composite scale; ICC1 = between variance / total, lme4 intercept-only REML"))
  # Table 4 / Figure 2 need draws. Saved locked outputs hold summaries only (q5/q95, i.e. 90%), no draws.
  res$table4_from_saved_summaries_90pct <- lapply(readRDS("results/fits_summary.rds")[c("H1_primary", "H2_secondary")],
      function(r) r$summary[r$summary$variable %in% c("g", "phi", "sigma", "sd_b"), ])
  # Table 4 PS models: R/07_fit_ps.R, both timings (DEVIATIONS item 10), each hash-checked and BLOCKED separately.
  res$table4_PS_model <- lapply(c(same_day = "same_day", next_day = "next_day"), function(sp) {
    dir <- file.path("results/ps_v3", sp); psm <- file.path(dir, "DRAWS_MANIFEST.json")
    lab <- "EXPLORATORY additional analysis; timing/sign set after H1/H2 results were known; not confirmatory"
    if (!file.exists(psm)) return(list(label = lab, spec = sp, status = paste0("BLOCKED: no PS draws in ", dir, " (R/07_fit_ps.R ", sp, " not run)")))
    pm <- as.data.frame(fromJSON(psm)$files)
    for (i in pm$file) if (!identical(digest(file = i, algo = "sha256"), pm$sha256[pm$file == i])) stop("PS draw hash mismatch: ", i)
    dps <- cmdstanr::read_cmdstan_csv(pm$file)$post_warmup_draws
    list(label = lab, spec = sp, status = "OK", reported_directional_P = "P(<0) (sign -1)",
         fit_summary = (function(x) x[setdiff(names(x), c("supported_975", "inconclusive"))])(fromJSON(file.path(dir, "ps_summary.json"))),
         params_95 = par_summary(dps, c("b_within", "phi", "g", "sigma", "sd_b")))
  })
  mf <- file.path(REGEN, "DRAWS_MANIFEST.json")
  # G2 (Plumber D3): per-fit acceptance from 06a. Table 4/Figure 2 need H1_primary AND H2_secondary accepted.
  af <- file.path(REGEN, "ACCEPTED_FITS"); rf <- file.path(REGEN, "REJECTED_FITS")
  acc <- if (file.exists(af)) readLines(af) else character(0); rej <- if (file.exists(rf)) readLines(rf) else character(0)
  ok <- file.exists(mf) && file.exists(af) && file.exists(rf) && all(c("H1_primary", "H2_secondary") %in% acc)
  res$regen_status <- list(accepted_fits = acc, rejected_fits = rej,
    rejected_note = if (length(rej)) "draws not reproduced; locked summary in results_aggregate.json stands" else NULL)
  res$exclusion_flow <- exclusion_flow(days)
  if (!ok) {
    res$table4_draws <- res$figure2_ppc <- "BLOCKED: regen_v3 draws missing or H1/H2 not in ACCEPTED_FITS (see DEVIATIONS item 9)"
    res$C2_C3_rope_rescaled <- "BLOCKED: needs accepted H1/H2 draws"
  } else {
    man <- as.data.frame(fromJSON(mf)$files)
    sdl <- list(H1_primary = to_stan(w, "SC"), H2_secondary = to_stan(w, "EE", lag_med = TRUE))
    res$table4_draws <- list(); res$figure2_ppc <- list(); res$C2_C3_rope_rescaled <- list()
    png(fig, width = 1800, height = 1100, res = 150); op <- par(mfrow = c(2, 3))
    for (k in names(sdl)) {
      dr <- read_fit(k, man)
      res$table4_draws[[k]] <- par_summary(dr, c("phi", "g", "sigma", "sd_b"))
      res$C2_C3_rope_rescaled[[k]] <- rope_rescale(dr)
      pp <- ppc(dr, sdl[[k]]); m <- pp$rep_matrix; pp$rep_matrix <- NULL; res$figure2_ppc[[k]] <- pp
      for (s in colnames(m)) { hist(m[, s], breaks = 30, main = paste(k, s), xlab = "replicated"); abline(v = pp$observed[[s]], lwd = 2, col = 2) }
    }
    par(op); dev.off(); res$figure2_file <- fig; res$figure2_sha256 <- digest(file = fig, algo = "sha256")
  }
  write_json(res, out, auto_unbox = TRUE, digits = NA, pretty = TRUE, null = "null")
  str(res, max.level = 3)
  print(sessionInfo()); cat("cmdstan_version:", tryCatch(as.character(cmdstanr::cmdstan_version()), error = function(e) conditionMessage(e)), "\n")
  cat("end:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n")
}
if (sys.nframe() == 0) main(commandArgs(TRUE)[1])

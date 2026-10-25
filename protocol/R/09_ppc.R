# 09_ppc.R (2026-10-24, Blacksmith). NEW, NOT locked; needs Fort Knox plan, Plumber PASS, Apprentice MATCH, lock.
# Rationale: posterior predictive checks are standard for a Bayesian DSEM; Mastermind (17:13 PT) asked for a minimal
#   PPC: replicated daily-outcome distributions and replicated within-person SD vs observed, H1 and H2, from the
#   locked, hash-manifested regen_v3 draws only (no refit). Generative step mirrors the locked dsem_meditation.stan
#   likelihood exactly as in locked R/06_aggregates.R ppc() (one-step-ahead, conditioning on observed/imputed lag y).
# Decision: aggregate-only JSON (quantiles + posterior predictive p-values) and one PNG; no row-level output.
#   Hard cutoff (Mastermind): if not locked and verified by 21:30 PT, the figure is dropped from the manuscript.
# Usage (from protocol/): nice -n 19 Rscript R/09_ppc.R data/raw/days.sav > logs/ppc_v3.log 2>&1
# Self-test on SIMULATED data only: nice -n 19 Rscript R/09_ppc.R --self-test
options(warn = 1)
suppressPackageStartupMessages({library(jsonlite); library(digest); library(posterior)})
REGEN <- "results/regen_v3"; OUTDIR <- "results/ppc_v3"
QS <- c(.05, .25, .50, .75, .95)

# One replicated y vector per draw k (same mean structure as locked 06 ppc()).
rep_y <- function(dm, k, sd) {
  J <- sd$J; g <- function(v) as.numeric(dm[k, v])
  a <- as.numeric(dm[k, sprintf("a[%d]", 1:J)]); b <- as.numeric(dm[k, sprintf("b[%d]", 1:J)]); p <- as.numeric(dm[k, sprintf("p[%d]", 1:J)])
  ymis <- if (sd$N_mis > 0) as.numeric(dm[k, sprintf("y_mis[%d]", 1:sd$N_mis)]) else numeric(0)
  y <- ifelse(sd$y_miss == 1, ymis[pmax(sd$mis_idx, 1)], sd$y_obs_fill); j <- sd$id
  w <- ifelse(sd$m_miss == 1, 0, sd$m - p[j])
  mu <- a[j] + b[j] * w + g("g") * (p[j] - 0.5) + g("c_wd") * sd$wd + g("c_t") * sd$tc + (if (sd$use_xlag) g("c_x") * sd$xlag else 0)
  ylag <- c(NA, y[-sd$N]); mu <- mu + ifelse(sd$first == 1, 0, g("phi") * (ylag - a[j]))
  yr <- stats::rnorm(sd$N, mu, g("sigma")); yr[sd$y_miss == 1] <- NA; yr
}
# Within-person SD: mean over persons of each person's SD of non-missing days (persons with >= 2 days).
wsd <- function(y, id) { s <- tapply(y, id, function(v) if (sum(!is.na(v)) >= 2) stats::sd(v, na.rm = TRUE) else NA); mean(s, na.rm = TRUE) }

ppc_fit <- function(dm, sd, ndraw = 400, ndens = 50) {
  idx <- round(seq(1, nrow(dm), length.out = min(ndraw, nrow(dm))))
  obs <- ifelse(sd$y_miss == 1, NA, sd$y_obs_fill)
  oq <- unname(quantile(obs, QS, na.rm = TRUE)); ow <- wsd(obs, sd$id)
  grid <- seq(min(obs, na.rm = TRUE) - 1, max(obs, na.rm = TRUE) + 1, length.out = 256)
  dens <- function(v) stats::approx(stats::density(v[!is.na(v)]), xout = grid, rule = 2)$y
  RQ <- matrix(NA, length(idx), length(QS)); RW <- numeric(length(idx)); D <- matrix(NA, 0, length(grid))
  for (i in seq_along(idx)) {
    yr <- rep_y(dm, idx[i], sd); RQ[i, ] <- quantile(yr, QS, na.rm = TRUE); RW[i] <- wsd(yr, sd$id)
    if (i <= ndens) D <- rbind(D, dens(yr))
  }
  s3 <- function(x) list(median = median(x), q025 = unname(quantile(x, .025)), q975 = unname(quantile(x, .975)))
  list(n_rep_draws = length(idx), scale = "z-scored outcome (to_stan standardize)",
       daily_quantiles = lapply(seq_along(QS), function(q) c(list(quantile = QS[q], observed = oq[q]), s3(RQ[, q]), ppp = mean(RQ[, q] >= oq[q]))),
       within_person_sd = c(list(observed = ow), s3(RW), ppp = mean(RW >= ow)),
       .plot = list(grid = grid, obs_dens = dens(obs), rep_dens = D, rep_wsd = RW, obs_wsd = ow))
}

run_all <- function(fits, outdir) {
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  fig <- file.path(outdir, "figure_ppc_v3.png"); res <- list(date = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), fits = list())
  png(fig, width = 1600, height = 1200, res = 150); op <- par(mfrow = c(length(fits), 2))
  for (k in names(fits)) {
    pp <- ppc_fit(fits[[k]]$dm, fits[[k]]$sd); pl <- pp$.plot; pp$.plot <- NULL; res$fits[[k]] <- pp
    matplot(pl$grid, t(pl$rep_dens), type = "l", lty = 1, col = grDevices::adjustcolor("steelblue", .25),
            main = paste(k, "daily outcome"), xlab = "y (z)", ylab = "density")
    lines(pl$grid, pl$obs_dens, lwd = 2, col = 2)
    hist(pl$rep_wsd, breaks = 30, main = paste(k, "within-person SD"), xlab = "replicated", xlim = range(c(pl$rep_wsd, pl$obs_wsd)))
    abline(v = pl$obs_wsd, lwd = 2, col = 2)
  }
  par(op); dev.off()
  res$figure_file <- fig; res$figure_sha256 <- digest(file = fig, algo = "sha256")
  out <- file.path(outdir, "ppc_v3.json"); write_json(res, out, auto_unbox = TRUE, digits = NA, pretty = TRUE)
  cat("wrote", out, "and", fig, "\n"); invisible(res)
}

main <- function(days_path) {
  P <- fromJSON("protocol_v3.json"); source("R/01_prepare.R"); set.seed(P$mcmc$seed)
  sha <- digest(file = days_path, algo = "sha256"); if (!identical(sha, P$data$days_sha256)) stop("days.sav sha256 mismatch")
  acc <- readLines(file.path(REGEN, "ACCEPTED_FITS")); if (!all(c("H1_primary", "H2_secondary") %in% acc)) stop("H1/H2 not accepted")
  man <- as.data.frame(fromJSON(file.path(REGEN, "DRAWS_MANIFEST.json"))$files)
  w <- as.data.frame(prepare_days(haven::read_sav(days_path), "previous_day"))
  sdl <- list(H1_primary = to_stan(w, "SC"), H2_secondary = to_stan(w, "EE", lag_med = TRUE))
  fits <- lapply(names(sdl), function(k) {
    f <- man$file[startsWith(man$file, file.path(REGEN, "draws", k, ""))]; if (!length(f)) stop("no draws for ", k)
    for (i in f) if (!identical(digest(file = i, algo = "sha256"), man$sha256[man$file == i])) stop("draw hash mismatch: ", i)
    list(dm = as_draws_matrix(cmdstanr::read_cmdstan_csv(f, variables = NULL)$post_warmup_draws), sd = sdl[[k]])
  }); names(fits) <- names(sdl)
  run_all(fits, OUTDIR)
}

# SIMULATED-only self-test: fake data as in R/00_syntax_check.R, fake draws; no real rows, no real draws.
self_test <- function(outdir = file.path(tempdir(), "ppc_selftest")) {
  set.seed(20261024L); source("R/01_prepare.R")
  sim <- expand.grid(time = 0:27, ID = 1:12)
  sim$Period <- ifelse(sim$time < 7, 1, ifelse(sim$time < 21, 2, 3)); sim$WD <- as.integer(sim$time %% 7 >= 5)
  sim$meditation <- ifelse(sim$Period == 2, rbinom(nrow(sim), 1, .8), 0)
  sim$SC <- rnorm(nrow(sim), 20, 3); sim$EE <- rnorm(nrow(sim), 10, 4); sim$PS <- rnorm(nrow(sim), 8, 2)
  sim$SC[sample(nrow(sim), 10)] <- NA
  w <- prepare_days(sim); sdl <- list(H1_primary = to_stan(w, "SC"), H2_secondary = to_stan(w, "EE", lag_med = TRUE))
  fake <- function(sd, n = 100) {
    nm <- c("g", "c_wd", "c_t", "c_x", "phi", "sigma", sprintf("a[%d]", 1:sd$J), sprintf("b[%d]", 1:sd$J), sprintf("p[%d]", 1:sd$J),
            if (sd$N_mis > 0) sprintf("y_mis[%d]", 1:sd$N_mis))
    m <- matrix(rnorm(n * length(nm), 0, .3), n, dimnames = list(NULL, nm)); m[, "sigma"] <- abs(m[, "sigma"]) + .5
    m[, grep("^p\\[", nm)] <- runif(n * sd$J, .2, .9); as_draws_matrix(m)
  }
  r <- run_all(lapply(sdl, function(sd) list(dm = fake(sd), sd = sd)), outdir)
  stopifnot(length(r$fits) == 2, all(vapply(r$fits, function(f) is.finite(f$within_person_sd$ppp), TRUE)), file.exists(r$figure_file))
  cat("PPC_SELFTEST_OK\n")
}

if (sys.nframe() == 0) { a <- commandArgs(TRUE); if (identical(a[1], "--self-test")) self_test() else main(a[1]) }

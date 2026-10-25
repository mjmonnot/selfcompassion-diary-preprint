# Syntax check only, on SIMULATED data (no real rows). Parses R, translates Stan (no sampling).
set.seed(20261024L)
for (f in c("R/01_prepare.R","R/02_fit.R","R/03_omega.R")) invisible(parse(f))
source("R/01_prepare.R"); source("R/03_omega.R")
sim <- expand.grid(time = 0:27, ID = 1:12)
sim$Period <- ifelse(sim$time < 7, 1, ifelse(sim$time < 21, 2, 3)); sim$WD <- as.integer(sim$time %% 7 >= 5)
sim$meditation <- ifelse(sim$Period == 2, rbinom(nrow(sim), 1, .8), 0)
sim$SC <- rnorm(nrow(sim), 20, 3); sim$EE <- rnorm(nrow(sim), 10, 4); sim$PS <- rnorm(nrow(sim), 8, 2)
sim$SC[sample(nrow(sim), 10)] <- NA
w <- prepare_days(sim); sd <- to_stan(w, "SC"); sd2 <- to_stan(w, "EE", lag_med = TRUE)
str(describe_window(w))
stopifnot(sd$N == nrow(w), sd2$N == nrow(w) - 12)
ok <- rstan::stanc("dsem_meditation.stan")$status; cat("stanc:", ok, "\n")
cat("SYNTAX_OK\n")

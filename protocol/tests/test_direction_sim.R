# Simulated draws only. Checks that the decision direction follows each hypothesis's sign in protocol_v3.json.
suppressPackageStartupMessages(library(jsonlite))
P <- fromJSON("protocol_v3.json")
src <- readLines("R/02_fit_v3.R"); i <- grep("^summarise_draws_dir", src); j <- i + which(src[(i+1):length(src)] == "}")[1]
eval(parse(text = src[i:j]))
set.seed(P$mcmc$seed)
neg <- rnorm(4000, -0.4, 0.1); pos <- rnorm(4000, 0.4, 0.1); nul <- rnorm(4000, 0, 0.3)
sH1 <- P$hypotheses$H1_primary$sign; sH2 <- P$hypotheses$H2_secondary$sign
stopifnot(sH1 == 1, sH2 == -1, P$sensitivity_direction$S4 == -1)
stopifnot(summarise_draws_dir(pos, sH1)$supported_975, !summarise_draws_dir(neg, sH1)$supported_975)
stopifnot(summarise_draws_dir(neg, sH2)$supported_975, !summarise_draws_dir(pos, sH2)$supported_975)
stopifnot(summarise_draws_dir(neg, P$sensitivity_direction$S4)$supported_975)
stopifnot(!summarise_draws_dir(nul, sH1)$supported_975, summarise_draws_dir(nul, sH1)$inconclusive)
stopifnot(!summarise_draws_dir(pos, sH1, conv = FALSE)$supported_975, !summarise_draws_dir(pos, sH1, div = 1)$supported_975)
r <- summarise_draws_dir(neg, sH2); stopifnot(r$p_beyond_band > .9, abs(r$median + 0.4) < .02)
cat("direction tests passed\n"); str(r)

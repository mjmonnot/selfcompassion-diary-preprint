# Self-test of 06a D3 comparison logic on toy JSON (no data, no sampling). Run: nice -n 19 Rscript tests/test_06a_compare.R
suppressPackageStartupMessages({library(jsonlite); library(digest)})
ex <- parse("R/06a_regen_draws.R"); keep <- c("STAN_KEYS", "ALL_FITS", "ser", "fit_entries", "compare_aggregates")
for (e in ex) if (is.call(e) && identical(e[[1]], as.name("<-")) && as.character(e[[2]]) %in% keep) eval(e, globalenv())
fit <- function(v) list(label = "x", median = v, p_pos = 0.9)
base <- list(describe = list(n = 132L), H1_primary = fit(0.123456), H2_secondary = fit(-0.1),
             sensitivity = setNames(lapply(seq_along(ALL_FITS[-(1:2)]), function(i) fit(i / 7)), ALL_FITS[-(1:2)]))
w <- function(x) { f <- tempfile(fileext = ".json"); write_json(x, f, auto_unbox = TRUE, digits = 6); f }
L <- w(base); Ls <- digest(file = L, algo = "sha256")
r1 <- compare_aggregates(L, w(base), Ls); stopifnot(r1$mode == "whole_file_sha256", length(r1$accepted) == 13)
b3 <- base; b3$sensitivity$S6_observed_centering$median <- 0.51
r3 <- compare_aggregates(L, w(b3), "nomatch"); stopifnot(r3$mode == "per_fit_reserialized", length(r3$accepted) == 12, !"S6_observed_centering" %in% r3$accepted)
b4 <- base; b4$H1_primary$p_pos <- 0.91
r4 <- compare_aggregates(L, w(b4), "nomatch"); stopifnot(!"H1_primary" %in% r4$accepted, length(r4$accepted) == 12)
b5 <- base; b5$describe$n <- 133L
r5 <- compare_aggregates(L, w(b5), "nomatch"); stopifnot(r5$mode == "describe_mismatch", length(r5$accepted) == 0)
b6 <- base; b6$sensitivity$S5_li_exclusion <- NULL
r6 <- compare_aggregates(L, w(b6), "nomatch"); stopifnot(!"S5_li_exclusion" %in% r6$accepted, length(r6$accepted) == 12)
r7 <- compare_aggregates(L, w(base), "nomatch"); stopifnot(length(r7$accepted) == 13)  # identical content, sha path skipped
cat("test_06a_compare: ALL PASS\n")

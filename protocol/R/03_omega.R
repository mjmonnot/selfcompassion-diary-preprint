# Rationale: daily composites are sums of SC1-6 (rSC2/4/6 reversed) and EE1-5; reliability must be
# split within/between for diary data (Geldhof, Preacher & Zyphur 2014, Psych Methods; Lai 2021).
# Decision: two-level CFA in lavaan (MLR), one factor per level; omega_w and omega_b from loadings.
suppressPackageStartupMessages(library(lavaan))
ml_omega <- function(dat, items, cluster = "ID") {
  f <- paste("f =~", paste(items, collapse = " + "))
  m <- paste0("level: 1\n", sub("f", "fw", f), "\nlevel: 2\n", sub("f", "fb", f))
  fit <- sem(m, data = dat, cluster = cluster, estimator = "MLR", missing = "ml")
  pe <- parameterEstimates(fit)
  om <- function(lv, lev) {
    l <- pe$est[pe$lhs == lv & pe$op == "=~"]
    th <- pe$est[pe$op == "~~" & pe$lhs %in% items & pe$lhs == pe$rhs & pe$level == lev]
    sum(l)^2 / (sum(l)^2 + sum(th))
  }
  c(omega_within = om("fw", 1), omega_between = om("fb", 2))
}
SC_items <- c("SC1","rSC2","SC3","rSC4","SC5","rSC6")   # reversed copies per codebook
EE_items <- paste0("EE", 1:5)
PS_items <- c("PS1","rPS2","rPS3","PS4")                 # descriptive only

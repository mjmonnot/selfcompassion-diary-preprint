# Rationale: all derivations are coded from the codebook (docs/CODEBOOK.md, sav metadata) only;
# no bot views rows. The runner (Sandbox) executes after Plumber hashes and Matt locks.
# Decision: build the analysis window (Period 2, time 7-20) with the locked alignment rule.
suppressPackageStartupMessages({library(haven); library(dplyr)})
SEED <- 20261024L; set.seed(SEED)

prepare_days <- function(days, alignment = c("previous_day", "same_row")) {
  alignment <- match.arg(alignment)
  stopifnot(all(c("ID","Period","time","WD","meditation","SC","EE","PS") %in% names(days)))
  d <- days |> mutate(across(everything(), ~ as.numeric(zap_labels(.x)))) |> arrange(ID, time)
  # Alignment (Matt 9:40 AM PT): the morning yes/no item ("past 24 h", Li 2021 Procedure)
  # describes the PREVIOUS diary day, so meditation for day t is read from row t+1.
  # Same-row alignment is a sensitivity analysis (S2).
  d <- d |> group_by(ID) |>
    mutate(med_day = if (alignment == "previous_day") lead(meditation) else meditation) |>
    ungroup()
  # Window: intervention days time 7-20 (Period 2 per codebook; Period, not week/IntPeriod dummies).
  w <- d |> filter(Period == 2)
  # Day 20 under previous_day alignment reads row 21 (Period 3), where meditation is 0 by
  # construction on every row (codebook) -> treated as missing, not as a true "no".
  if (alignment == "previous_day") w <- w |> mutate(med_day = ifelse(time == 20, NA, med_day))
  w
}

standardize <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)

to_stan <- function(w, outcome = "SC", lag_med = FALSE, slope_sd = 0.5, delta = 0) {
  w <- w |> arrange(ID, time) |> group_by(ID) |>
    mutate(m_use = if (lag_med) lag(med_day) else med_day,
           first = as.integer(row_number() == 1)) |> ungroup()
  if (lag_med) w <- w |> group_by(ID) |> filter(row_number() > 1) |>
      mutate(first = as.integer(row_number() == 1)) |> ungroup()   # next-day model: day t+1 outcome on day t meditation, AR = today's EE
  y <- standardize(w[[outcome]]); ym <- as.integer(is.na(y))
  mis_idx <- integer(nrow(w)); mis_idx[ym == 1] <- seq_len(sum(ym))
  ids <- as.integer(factor(w$ID))
  list(N = nrow(w), J = max(ids), id = ids, first = w$first,
       y_obs_fill = ifelse(is.na(y), 0, y), y_miss = ym, N_mis = sum(ym), mis_idx = mis_idx,
       m = ifelse(is.na(w$m_use), 0L, as.integer(w$m_use)), m_miss = as.integer(is.na(w$m_use)),
       wd = w$WD, tc = (w$time - 13.5) / 7, xlag = rep(0, nrow(w)), use_xlag = 0L,
       slope_sd = slope_sd, delta = delta)
}

# Aggregate-only descriptives written for the report (counts, never rows).
describe_window <- function(w) {
  pp <- w |> group_by(ID) |> summarise(n_yes = sum(med_day == 1, na.rm = TRUE),
                                       n_no = sum(med_day == 0, na.rm = TRUE))
  list(n_persons = nrow(pp), n_zero_no_days = sum(pp$n_no == 0),   # kept, and reported (Matt)
       n_lt7_meditations = sum(pp$n_yes < 7),                     # Li's exclusion rule, disclosed only
       yes = sum(pp$n_yes), no = sum(pp$n_no), med_missing = sum(is.na(w$med_day)),
       SC_missing = sum(is.na(w$SC)), EE_missing = sum(is.na(w$EE)))
}

// DSEM-style two-level model, days within persons, latent person-mean centering.
// Rationale: Hamaker & Grasman 2015 / Hamaker et al. 2018 (DSEM) show observed person means
// bias within/between splits with few days (Nickell/Ludtke bias); latent centering avoids it.
// y_it = a_i + b_i * (m_it - p_i) + g * p_i + c_wd*WD + c_t*time + phi*(y_lag - a_i_lagmean) + e
// m_it ~ bernoulli(p_i); p_i = inv_logit(alpha_i) latent meditation propensity (between part).
// Missing y (and lagged y) are parameters (MAR, full-likelihood); delta shifts their mean (pattern-mixture).
data {
  int<lower=1> N;                 // person-days in analysis window (incl. missing)
  int<lower=1> J;                 // persons
  array[N] int<lower=1,upper=J> id;
  array[N] int<lower=0,upper=1> first; // 1 = first day of person's window (no lag)
  vector[N] y_obs_fill;           // standardized outcome, missing filled with 0 (ignored)
  array[N] int<lower=0,upper=1> y_miss;
  int<lower=0> N_mis;
  array[N] int<lower=0> mis_idx;  // position in y_mis (0 if observed)
  array[N] int<lower=0,upper=1> m;      // meditation (aligned), filled 0 if missing
  array[N] int<lower=0,upper=1> m_miss;
  vector[N] wd; vector[N] tc;     // weekend dummy, centered time
  vector[N] xlag;                 // extra lagged covariate (today's EE for next-day model), 0 if unused
  int<lower=0,upper=1> use_xlag;
  real<lower=0> slope_sd;         // prior SD on standardized slopes (0.5; sensitivity 1.0 / 0.25)
  real delta;                     // MNAR shift for missing y in SD units (0 = MAR)
}
parameters {
  real a0; real<lower=0> sd_a; vector[J] za;
  real b0; real<lower=0> sd_b; vector[J] zb;
  cholesky_factor_corr[2] L;
  real g; real c_wd; real c_t; real c_x;
  real<lower=-1,upper=1> phi;
  real<lower=0> sigma;
  real mu_alpha; real<lower=0> sd_alpha; vector[J] zalpha;
  vector[N_mis] y_mis;
}
transformed parameters {
  matrix[J,2] re = (diag_pre_multiply([sd_a, sd_b]', L) * append_row(za', zb'))';
  vector[J] a = a0 + re[,1];
  vector[J] b = b0 + re[,2];
  vector[J] p = inv_logit(mu_alpha + sd_alpha * zalpha);
}
model {
  vector[N] y;
  for (n in 1:N) y[n] = y_miss[n] ? y_mis[mis_idx[n]] : y_obs_fill[n];
  a0 ~ normal(0, 1); b0 ~ normal(0, slope_sd); g ~ normal(0, slope_sd);
  c_wd ~ normal(0, slope_sd); c_t ~ normal(0, slope_sd); c_x ~ normal(0, slope_sd);
  phi ~ normal(0, 0.5);
  sd_a ~ normal(0, 1); sd_b ~ normal(0, 0.5); sigma ~ normal(0, 1);
  L ~ lkj_corr_cholesky(2);
  za ~ std_normal(); zb ~ std_normal(); zalpha ~ std_normal();
  mu_alpha ~ normal(0, 1.5); sd_alpha ~ normal(0, 1);
  for (n in 1:N) {
    int j = id[n];
    real w = m_miss[n] ? 0 : (m[n] - p[j]);   // missing meditation contributes no within info
    real mu = a[j] + b[j] * w + g * (p[j] - 0.5) + c_wd * wd[n] + c_t * tc[n]
              + (use_xlag ? c_x * xlag[n] : 0);
    if (!first[n]) mu += phi * (y[n-1] - a[j]);
    if (!m_miss[n]) m[n] ~ bernoulli(p[j]);
    if (y_miss[n]) y[n] ~ normal(mu + delta, sigma);
    else y[n] ~ normal(mu, sigma);
  }
}
generated quantities {
  real b_within = b0;                 // primary estimand (fixed within-person meditation slope, SD units)
  real pr_pos = b0 > 0;               // posterior P(b_within > 0) = mean(pr_pos)
  real pr_neg = b0 < 0;
}

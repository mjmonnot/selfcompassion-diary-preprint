# Version pins and renv lock spec

Rationale: the box has these versions installed now (checked 2026-10-24), and a lock that names exact versions makes the run reproducible.
Decision: the runner (Sandbox) runs `renv::init(bare=TRUE); renv::install(c("cmdstanr@0.9.0","brms@2.22.0","rstan@2.32.7","lavaan@0.7-3","haven","dplyr","posterior","jsonlite")); renv::snapshot()` inside `protocol/`, records `cmdstanr::cmdstan_version()` into protocol.json, and hands renv.lock to Plumber for hashing. R 4.5.0. Unpinned packages (haven, dplyr, posterior, jsonlite) are pinned at whatever version the snapshot records.


Update 2026-10-24 (v3): Blacksmith generated renv.lock with renv::snapshot(type='implicit') from the installed box library (R 4.5.0, CmdStan 2.40.0). Deviation: lavaan is 0.7-3, not 0.6.19, because the shared box library is used by other projects; the diary models are brms. The runner does not regenerate the lock; Plumber hashes it before the first fit.

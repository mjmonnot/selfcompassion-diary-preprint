# 05 omega supplement notes (2026-10-24 16:24 PT, per Mastermind)
- The all-28-days SC two-level solution was inadmissible: SC5's between-level residual variance was nonpositive (post.check FALSE). Its omega is not reported (Kolenikov & Bollen, 2012), and the Period 2 estimates are primary.
- SC1 has no within-cluster variance in some clusters (lavaan data warning).
- The omega cross-check tolerance was set post hoc at |gap| <= 1e-4 (D-g). Observed gaps: P2 SC 4.24e-6, P2 EE 1.23e-6. Both omega values are reported in omega_v3_diag.json.
- lavaan's auxiliary level-wise saturated-model warnings affect fit statistics only; no level-specific fit indices are reported. 50 empty cases carry no FIML information.

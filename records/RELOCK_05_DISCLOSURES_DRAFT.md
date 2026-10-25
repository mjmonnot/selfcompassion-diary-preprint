# Draft disclosures for the 05 relock (to fold into DEVIATIONS at relock; DEVIATIONS itself is not edited now)
- D-a (order change): 05 failed at 13:04 PT (std.lv cross-check). With Plumber's approval, 06a and 07 ran first, under lock 48d34e46. 05 is re-run after the patch.
- D-b (partial output): the patched 05 writes a PARTIAL omega_v3_diag.json to the final path after each item set. A successful run overwrites it. If the stopifnot halts, the file stays with status "PARTIAL".
- D-c (S6 label): S6_observed_centering.csv has the column header b_within, but its source parameter is brms b_med_wc (mapped in 06a).
- D-d (Heywood risk): a dry test gave omega_between of 1.0004. If the real run gives a Heywood or out-of-range value, it is reported as is and not fixed.

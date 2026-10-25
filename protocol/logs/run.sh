#!/bin/bash
export OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 OPENBLAS_NUM_THREADS=2
date '+start %F %T %Z'; s=$(date +%s)
nice -n 19 Rscript R/02_fit_v3.R data/raw/days.sav
echo "exit $?"; echo "elapsed_s $(( $(date +%s)-s ))"; date '+end %F %T %Z'

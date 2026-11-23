#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation/independent
out=pilot_results.tsv
: > $out
run() { VARS=$1 python3 -u tg_pilot.py $2 5 $3 900 2>&1 | grep -P '^\d' >> $out; }
run ours_n0,ours,ours_checked,casaal 2 24
run ours_n0,ours,ours_checked,casaal 2 25
run ours_checked,casaal,ours 3 24
run casaal 3 25
run ours_checked,casaal,ours 4 24
run ours_checked,casaal,ours 4 25
echo ALLDONE >> $out

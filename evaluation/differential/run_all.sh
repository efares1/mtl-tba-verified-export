#!/bin/bash
# full differential run (WSL): benchmark patterns, then the 100 random formulas
cd "$(dirname "$0")" || exit 1
rm -f diff_bench.tsv disagreements_bench.txt diff_random.tsv disagreements_random.txt
touch diff_bench.tsv disagreements_bench.txt diff_random.tsv disagreements_random.txt
python3 run_diff.py bench 20000 11 > bench.log 2>&1
python3 run_diff.py random 6000 12 > random.log 2>&1
touch all.done

#!/bin/bash
# Runs all baseline workloads sequentially (WSL).  Usage: bash run_all.sh
cd "$(dirname "$0")" || exit 1
IDS="F1 F2 F3b F4 F5 F6 F7 F8 F9 F10 F11 F12 F14 R1 R2 R3 N1 N2 N3 N4"
python3 run_baselines.py 300 ref $IDS > ref.log 2>&1
python3 run_baselines.py 300 free $IDS > free.log 2>&1
python3 run_baselines.py 300 resp_ok R1 R2 R3 > resp_ok.log 2>&1
python3 run_baselines.py 300 resp_bad R1 R2 R3 > resp_bad.log 2>&1
ALLCOPY=1 python3 run_baselines.py 300 resp_ok R1 R2 R3 > resp_ok_ac.log 2>&1
ALLCOPY=1 python3 run_baselines.py 300 resp_bad R1 R2 R3 > resp_bad_ac.log 2>&1
touch all.done

#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation
python3 tck_export_policy.py 300 > policy_done.log 2>&1
cp tck_export_policy.tsv tck_export_policy_completed.tsv
python3 tck_export_policy.py 120 R2 R3 R4 R5 R6 N4 N5 N6 F14 > policy_rest.log 2>&1
touch policy_all.done

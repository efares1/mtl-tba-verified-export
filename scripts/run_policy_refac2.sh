#!/bin/bash
pkill -f run_policy_refac.sh; pkill -f tck_export_policy.py; pkill -x tck-liveness
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation
REFPOLICY=allcopy OUTNAME=tck_policy_refac2 python3 tck_export_policy.py 300 R4 R5 R6 R7 R8 N4 N5 N6 N7 N8 > policy_refac2.log 2>&1
touch policy_refac2.done

#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation
REFPOLICY=allcopy OUTNAME=tck_policy_refac3 ONLYVARS=opt_allcopy python3 tck_export_policy.py 300 R5 R6 R7 R8 N4 N5 N6 N7 N8 > policy_refac3.log 2>&1
touch policy_refac3.done

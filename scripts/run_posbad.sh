#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation
WORKLOAD=posbad OUTNAME=tck_posbad ONLYVARS=opt_allcopy,opt_maxdelay python3 tck_export_policy.py 120 R2 R3 R4 R5 R6 R7 R8 2>&1 | cut -f1-9

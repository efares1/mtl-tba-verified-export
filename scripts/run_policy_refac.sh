#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation
REFPOLICY=allcopy OUTNAME=tck_policy_refac python3 tck_export_policy.py 300 F1 F2 F3b F4 F5 F6 F7 F8 F9 F10 F11 F12 F14 R1 R2 R3 R4 R5 R6 R7 R8 N1 N2 N3 N4 N5 N6 N7 N8 > policy_refac.log 2>&1
touch policy_refac.done

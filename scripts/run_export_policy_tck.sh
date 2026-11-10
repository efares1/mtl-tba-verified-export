#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation && python3 tck_export_policy.py "${1:-300}" "${@:2}" 2>&1

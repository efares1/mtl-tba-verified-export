#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation && python3 casaal_then_optimizer.py "${1:-300}" "${@:2}" 2>&1

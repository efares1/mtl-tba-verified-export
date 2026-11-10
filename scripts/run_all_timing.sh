#!/bin/bash
# Final timing chain with the final binary: auto on all patterns, low/any on all patterns, then N8 alone.
D=/mnt/c/Users/user/Desktop/JSS_paper
bash $D/scripts/build_tool.sh > /dev/null 2>&1
bash $D/scripts/auto_times.sh
LIM=30 bash $D/scripts/level_feature_check.sh
bash $D/scripts/n8_final.sh
touch $D/evaluation/all_timing.done

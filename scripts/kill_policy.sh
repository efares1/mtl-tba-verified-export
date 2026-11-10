#!/bin/bash
for p in $(ps -eo pid,args | grep -E 'run_policy_refac2|tck_export_policy|tck-liveness' | grep -v grep | awk '{print $1}'); do kill -9 $p; done
sleep 1; ps -eo pid,args | grep -E 'tck|policy' | grep -v grep | wc -l

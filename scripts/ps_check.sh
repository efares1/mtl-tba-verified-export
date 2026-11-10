#!/bin/bash
ps -eo pid,etime,args | grep -E 'tck_export|casaal_then|tck-liveness|run_export_policy|run_policy' | grep -v grep | cut -c1-150

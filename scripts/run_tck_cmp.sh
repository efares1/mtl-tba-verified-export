#!/bin/bash
cd "$(dirname "$0")/../evaluation" || exit 1
(cd ../tool && dune build 2>&1 | tail -3)
bash run_tck_vs_casaal.sh 2>&1 | tail -150

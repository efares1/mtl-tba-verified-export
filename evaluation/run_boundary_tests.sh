#!/bin/bash
# Produce the automata of boundary_tests.tsv (run in WSL, after run_full_eval.sh
# or run_tool_eval.sh has built the tool), then check them with
#     python3 check_boundaries.py boundary_out
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
mkdir -p "$HERE/boundary_out"
grep -v '^#' "$HERE/boundary_tests.tsv" | while IFS=$'\t' read -r id req neg word exp; do
  [ -z "$id" ] && continue
  (cd "$HERE/boundary_out" && "$EXE" -nopdf -o "$id" "$neg" > /dev/null)
done
python3 "$HERE/check_boundaries.py" "$HERE/boundary_out"

#!/bin/bash
# Symbolic transition counts with the optimizer disabled (-n 0) and enabled,
# at Spot levels small (the default) and low, for every benchmark configuration.
#
#   EXE=<mtl2tba.exe> bash run_symbolic_before_after.sh
#   python3 make_symbolic_before_after.py
#
# Writes symbolic_before_after.raw (one line per configuration and level:
# id, level, [stats of -n 0], [stats of the default run]).  Each run is limited
# to 300 seconds; an empty bracket means the run did not finish.
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
FORMULAS=${FORMULAS:-"$HERE/formulas.tsv"}
OUT="$HERE/symbolic_before_after.raw"
: > "$OUT"
grep -v '^#' "$FORMULAS" | while IFS=$'\t' read -r id desc ours cas; do
  [ -z "$id" ] && continue
  d=$(mktemp -d); cd "$d"
  for lvl in small low; do
    a=$(timeout 300 "$EXE" -spot-level $lvl -n 0 -nopdf -stats -o a "$ours" 2>/dev/null)
    b=$(timeout 300 "$EXE" -spot-level $lvl      -nopdf -stats -o b "$ours" 2>/dev/null)
    printf '%s\t%s\t[%s]\t[%s]\n' "$id" "$lvl" "$a" "$b" >> "$OUT"
  done
  cd /; rm -rf "$d"
done

#!/bin/bash
# ONLY="F8 R1": only these configurations; the rows go to <file>.only (merge_rows.py)
# Check of the trusted interface between the extracted code and Spot, on
# every configuration of formulas.tsv (option -check of mtl2tba):
#   1. printing of T(f): Spot reads the infix text given to ltl2tgba and the
#      prefix (LBT) text written by a second, independent printer of the same
#      extracted formula; both are normalized by ltlfilt and compared;
#   2. reader of the LBTT output: the automaton built by the reader, written
#      in the HOA format, is compared with the raw output of Spot by
#      autfilt --equivalent-to (same atomic propositions, all independent).
# Writes interface_check.tsv.  Limits: LIMIT (tool, 300 s), EQLIMIT (600 s).
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
LIMIT=${LIMIT:-300}
EQLIMIT=${EQLIMIT:-600}
W=$(mktemp -d)
trap 'rm -rf -- "$W"' EXIT
OUT="$HERE/interface_check.tsv"
[ -n "$ONLY" ] && OUT="$OUT.only"
printf 'id\tprinter\treader\n' > "$OUT"
chmod +x "$HERE/spot_tee.sh"
grep -v '^#' "$HERE/formulas.tsv" | while IFS=$'\t' read -r id desc ours cas; do
  [ -n "$ONLY" ] && ! [[ " $ONLY " == *" $id "* ]] && continue
  [ -z "$id" ] && continue
  rm -f "$W"/*
  (cd "$W" && SPOT_SAVE="$W/s" timeout "$LIMIT" "$EXE" -nopdf -check "$W/c" \
      -spot "$HERE/spot_tee.sh" -o out "$ours" > /dev/null 2>&1)
  if [ ! -s "$W/c_ba.hoa" ]; then
    printf '%s\tSpot timeout\tSpot timeout\n' "$id" >> "$OUT"; echo "$id: Spot timeout"; continue
  fi
  a=$(ltlfilt --lbt -F "$W/s.ltl")
  b=$(ltlfilt --lbt-input --lbt -F "$W/c_ltl.lbt")
  if [ -n "$a" ] && [ "$a" = "$b" ]; then pr=same; else pr=DIFFERENT; fi
  timeout "$EQLIMIT" autfilt -q "$W/c_ba.hoa" --equivalent-to="$W/s.lbtt"
  case $? in 0) rd=equivalent ;; 124) rd="equivalence timeout" ;; *) rd=NOT-EQUIVALENT ;; esac
  printf '%s\t%s\t%s\n' "$id" "$pr" "$rd" >> "$OUT"
  echo "$id: $pr / $rd"
done
column -t -s $'\t' "$OUT"

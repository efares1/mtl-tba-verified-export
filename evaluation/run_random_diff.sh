#!/bin/bash
# Differential test of mtl2tba against CASAAL on the random formulas of
# random_formulas.tsv (generated with their CASAAL automata by
# random_formulas.py).  For every formula phi, with TChecker (couvscc):
#   P1  mtl2tba(phi) x CASAAL(!phi)   must be empty
#   P2  CASAAL(phi)  x mtl2tba(!phi)  must be empty
#   S   mtl2tba(phi) x mtl2tba(!phi)  must be empty
# A non-empty product means that the two tools disagree on some timed word
# (one event per position, strictly increasing and divergent timestamps,
# clocks starting at 0 at time 0).  Writes random_diff.tsv; limit LIMIT
# (default 120 s) per tool run and per check.
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
TCK=${TCK:-"$HOME/local/bin/tck-liveness"}
LIMIT=${LIMIT:-120}
W=$(mktemp -d)
OUT=${OUT:-"$HERE/random_diff.tsv"}   # ONLY=<id>: a single formula
printf 'id\tformula\tP1\tP2\tS\tinit_free\n' > "$OUT"
EVENTS=p,q,r
check() {
  lab=$(python3 "$HERE/tck_product.py" "$W/m.tck" "$EVENTS" "$@" 2>/dev/null) || { echo "convert error"; return; }
  r=$(timeout "$LIMIT" "$TCK" -a couvscc -l "$lab" "$W/m.tck" 2>&1 | grep -E '^CYCLE')
  case "$r" in
    "CYCLE false") echo empty ;;
    "CYCLE true") echo NONEMPTY ;;
    *) echo timeout ;;
  esac
}
grep -v '^#' "$HERE/random_formulas.tsv" | while IFS=$'\t' read -r id ours cas; do
  [ -z "$id" ] && continue
  [ -n "$ONLY" ] && [ "$id" != "$ONLY" ] && continue
  C="$HERE/casaal_out_rand"
  if [ ! -f "$C/$id.gv" ] || [ ! -f "$C/${id}_neg.gv" ]; then
    printf '%s\t%s\tCASAAL failed\t\t\t\n' "$id" "$ours" >> "$OUT"; continue
  fi
  st=$(cd "$W" && timeout "$LIMIT" "$EXE" -stats -nopdf -o pos "$ours" 2>/dev/null) || {
    printf '%s\t%s\ttool timeout\t\t\t\n' "$id" "$ours" >> "$OUT"; continue; }
  (cd "$W" && timeout "$LIMIT" "$EXE" -nopdf -o neg "!($ours)" > /dev/null 2>&1) || {
    printf '%s\t%s\ttool timeout (negation)\t\t\t\n' "$id" "$ours" >> "$OUT"; continue; }
  ifree=$(echo "$st" | cut -f20)
  p1=$(check A:"$W/pos.xml" B:"$C/${id}_neg.gv")
  p2=$(check B:"$C/$id.gv" C:"$W/neg.xml")
  sc=$(check A:"$W/pos.xml" C:"$W/neg.xml")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$ours" "$p1" "$p2" "$sc" "$ifree" >> "$OUT"
  echo "$id: $p1 $p2 $sc (init_free $ifree)"
done
rm -rf "$W"
python3 - "$OUT" <<'PY'
import csv, sys, collections
rows = list(csv.DictReader(open(sys.argv[1]), delimiter='\t'))
print(collections.Counter((r['P1'], r['P2'], r['S']) for r in rows))
PY

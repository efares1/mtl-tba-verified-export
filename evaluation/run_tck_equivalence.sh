#!/bin/bash
# ONLY="F8 R1": only these configurations; the rows go to <file>.only (merge_rows.py)
# Cross-tool check of the languages of mtl2tba and CASAAL, with the timed
# Buchi emptiness checker of TChecker (tck-liveness, couvscc), on every
# configuration whose CASAAL encoding is exact.  For a formula phi:
#   P1  mtl2tba(phi)    x CASAAL(!phi)     must be empty
#   P2  CASAAL(phi)     x mtl2tba(!phi)    must be empty
#   S   mtl2tba(phi)    x mtl2tba(!phi)    must be empty (self-consistency)
#   C   mtl2tba(phi)    x CASAAL(phi)      non-empty unless phi is unsatisfiable
# The products read infinite timed words with one event per position and
# strictly increasing, divergent timestamps; clocks start at 0 at time 0
# (conventional acceptance, as in UPPAAL).  Requires TChecker in ~/local/bin
# and the CASAAL automata of phi and of !phi (run_casaal.py --exclusive,
# run_casaal_neg.py) in casaal_out_x/ and casaal_out_neg/.
# Writes tck_equivalence.tsv.  Limit per check: LIMIT (default 600 s).
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
TCK=${TCK:-"$HOME/local/bin/tck-liveness"}
LIMIT=${LIMIT:-600}
W=$(mktemp -d)
OUT="$HERE/tck_equivalence.tsv"
[ -n "$ONLY" ] && OUT="$OUT.only"
printf 'id\tP1\tP2\tS\tC\n' > "$OUT"
check() {  # expected empty -> "empty" / "NONEMPTY"; or raw for the control
  lab=$(python3 "$HERE/tck_product.py" "$W/m.tck" "$EVENTS" "$@") || { echo "convert error"; return; }
  r=$(timeout "$LIMIT" "$TCK" -a couvscc -l "$lab" "$W/m.tck" 2>&1 | grep -E '^CYCLE')
  case "$r" in
    "CYCLE false") echo empty ;;
    "CYCLE true") echo NONEMPTY ;;
    *) echo timeout ;;
  esac
}
grep -v '^#' "$HERE/formulas.tsv" | while IFS=$'\t' read -r id desc ours cas; do
  [ -n "$ONLY" ] && ! [[ " $ONLY " == *" $id "* ]] && continue
  [ -z "$id" ] && continue
  case "$cas" in "~"*|"-") continue;; esac
  [ -f "$HERE/casaal_out_x/$id.gv" ] && [ -f "$HERE/casaal_out_neg/$id.gv" ] || continue
  EVENTS=$(python3 -c "import re,sys; print(','.join(sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', sys.argv[1])) - {'true','false'})))" "$ours")
  (cd "$W" && timeout "$LIMIT" "$EXE" -nopdf -o pos "$ours" > /dev/null 2>&1) || { printf '%s\ttool timeout\t\t\t\n' "$id" >> "$OUT"; echo "$id: tool timeout"; continue; }
  (cd "$W" && timeout "$LIMIT" "$EXE" -nopdf -o neg "!($ours)" > /dev/null 2>&1) || { printf '%s\ttool timeout (negation)\t\t\t\n' "$id" >> "$OUT"; echo "$id: tool timeout"; continue; }
  p1=$(check A:"$W/pos.xml" B:"$HERE/casaal_out_neg/$id.gv")
  p2=$(check B:"$HERE/casaal_out_x/$id.gv" C:"$W/neg.xml")
  sc=$(check A:"$W/pos.xml" C:"$W/neg.xml")
  ct=$(check A:"$W/pos.xml" B:"$HERE/casaal_out_x/$id.gv")
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$p1" "$p2" "$sc" "$ct" >> "$OUT"
  echo "$id: $p1 $p2 $sc $ct"
done
rm -rf "$W"
column -t -s $'\t' "$OUT"

#!/bin/bash
# Same checks as run_tck_equivalence.sh, on the automaton obtained by
# relaxation and reset completion (mtl2tba -tba, <base>_tba.dot), for the
# configurations whose exported automaton contains difference constraints,
# on which tck-liveness does not terminate within the limit.  The automaton
# after reset completion has no invariant and no difference constraint; the
# passes that follow it are proved in Coq.
#     IDS="F14 R2 R3" bash run_tck_compiled.sh
# Writes tck_compiled.tsv.  Limit per check: LIMIT (default 600 s).
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
TCK=${TCK:-"$HOME/local/bin/tck-liveness"}
LIMIT=${LIMIT:-600}
IDS=${IDS:-"F14 R2 R3 R4 R5 R6 R7 R8"}
W=$(mktemp -d)
OUT="$HERE/tck_compiled.tsv"
printf 'id\tP1\tP2\tS\tC\n' > "$OUT"
check() {
  lab=$(python3 "$HERE/tck_product.py" "$W/m.tck" "$EVENTS" "$@") || { echo "convert error"; return; }
  r=$(timeout "$LIMIT" "$TCK" -a couvscc -l "$lab" "$W/m.tck" 2>&1 | grep -E '^CYCLE')
  case "$r" in
    "CYCLE false") echo empty ;;
    "CYCLE true") echo NONEMPTY ;;
    *) echo timeout ;;
  esac
}
for id in $IDS; do
  line=$(grep "^$id	" "$HERE/formulas.tsv")
  ours=$(echo "$line" | cut -f3)
  EVENTS=$(python3 -c "import re,sys; print(','.join(sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', sys.argv[1])) - {'true','false'})))" "$ours")
  rm -f "$W"/*
  (cd "$W" && timeout "$LIMIT" "$EXE" -nopdf -tba -o pos "$ours" > /dev/null 2>&1)
  (cd "$W" && timeout "$LIMIT" "$EXE" -nopdf -tba -o neg "!($ours)" > /dev/null 2>&1)
  if [ ! -s "$W/pos_tba.dot" ] || [ ! -s "$W/neg_tba.dot" ]; then
    printf '%s\ttool timeout\t\t\t\n' "$id" >> "$OUT"; echo "$id: tool timeout"; continue
  fi
  p1=$(check A:"$W/pos_tba.dot" B:"$HERE/casaal_out_neg/$id.gv")
  p2=$(check B:"$HERE/casaal_out_x/$id.gv" C:"$W/neg_tba.dot")
  sc=$(check A:"$W/pos_tba.dot" C:"$W/neg_tba.dot")
  ct=$(check A:"$W/pos_tba.dot" B:"$HERE/casaal_out_x/$id.gv")
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$p1" "$p2" "$sc" "$ct" >> "$OUT"
  echo "$id: $p1 $p2 $sc $ct"
done
rm -rf "$W"
column -t -s $'\t' "$OUT"

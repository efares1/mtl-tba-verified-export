#!/bin/bash
# Model-checking cost of the automaton of the NEGATED requirement, ours (optimized,
# exported by mtl2tba) versus CASAAL's, on the same product with TChecker
# (tck-liveness, couvscc): stored/visited states and time.
#   mode "sat": negation automaton alone (+ time-structure processes Z, D)
#   mode resp_ok / resp_bad: composed with the system models of the case study
#                            (only for F1, events p,q)
# Writes tck_vs_casaal.tsv.  LIMIT seconds per check (default 120).
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
TCK=${TCK:-"$HOME/local/bin/tck-liveness"}
LIMIT=${LIMIT:-120}
W=$(mktemp -d)
OUT="$HERE/tck_vs_casaal.tsv"
[ -n "$ONLY" ] && OUT="$OUT.only"
printf 'id\tmode\ttool\tverdict\tstored\tvisited\ttransitions\tseconds\n' > "$OUT"
run() {  # id mode tool events args...
  local id=$1 mode=$2 tool=$3 ev=$4; shift 4
  lab=$(python3 "$HERE/tck_product.py" "$W/m.tck" "$ev" "$@") || { echo "convert error $id $mode $tool"; return; }
  res=$( { timeout "$LIMIT" "$TCK" -a couvscc -l "$lab" "$W/m.tck" 2>&1; } )
  v=$(echo "$res" | grep -E '^CYCLE' | awk '{print $2}'); [ -n "$v" ] || v=timeout
  st=$(echo "$res" | awk '$1=="STORED_STATES"{print $2}')
  vs=$(echo "$res" | awk '$1=="VISITED_STATES"{print $2}')
  vt=$(echo "$res" | awk '$1=="VISITED_TRANSITIONS"{print $2}')
  tm=$(echo "$res" | awk '$1=="RUNNING_TIME_SECONDS"{print $2}')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$mode" "$tool" "$v" "${st:-NA}" "${vs:-NA}" "${vt:-NA}" "${tm:-NA}" | tee -a "$OUT"
}
grep -v '^#' "$HERE/formulas.tsv" | while IFS=$'\t' read -r id desc ours cas; do
  [ -n "$ONLY" ] && ! [[ " $ONLY " == *" $id "* ]] && continue
  case "$cas" in "~"*|"-"|"") continue;; esac
  [ -f "$HERE/casaal_out_neg/$id.gv" ] || continue
  EVENTS=$(python3 -c "import re,sys; print(','.join(sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', sys.argv[1])) - {'true','false'})))" "$ours")
  (cd "$W" && timeout "$LIMIT" "$EXE" -nopdf -o neg "!($ours)" > /dev/null 2>&1) || { echo "$id: tool timeout"; continue; }
  run "$id" sat ours "$EVENTS" "P:$W/neg.xml"
  run "$id" sat casaal "$EVENTS" "P:$HERE/casaal_out_neg/$id.gv"
  if [ "$id" = F1 ]; then
    for s in resp_ok resp_bad; do
      python3 "$HERE/tck_normalize_system.py" "$HERE/case_study/models/${s}_alone.xml" "$W/${s}_system.xml"
      run "$id" "$s" ours "$EVENTS" "P:$W/neg.xml" "SYS:$W/${s}_system.xml"
      run "$id" "$s" casaal "$EVENTS" "P:$HERE/casaal_out_neg/$id.gv" "SYS:$W/${s}_system.xml"
    done
  fi
done
rm -rf "$W"

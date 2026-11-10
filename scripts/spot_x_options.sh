#!/bin/bash
# Spot -x options on the simplified clocked formula of a pattern.
# usage: spot_x_options.sh ID [level]
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
id=${1:-N6}; lvl=${2:-any}
W=$(mktemp -d); cd $W
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
$EXE -nopdf -v -simp -spot-level any -n 0 -o r "!($f)" 2>err >/dev/null &
pid=$!; sleep 1; kill $pid 2>/dev/null; wait $pid 2>/dev/null
grep "clocked LTL:" err | sed 's/.*clocked LTL: //' > f.ltl
echo "$id formula bytes $(wc -c < f.ltl), level --$lvl"
run() {
  s=$(date +%s.%N)
  timeout 150 ltl2tgba -B --$lvl $1 --stats='%s states %e edges' -F f.ltl > st.txt 2>/dev/null; rc=$?
  e=$(date +%s.%N)
  printf "%-28s %7.2f s  rc=%d  %s\n" "$1" "$(echo "$e - $s" | bc)" $rc "$(cat st.txt)"
}
run ""
for o in tls-impl=0 tls-impl=1 tls-impl=3 ltl-split=0 comp-susp=1 branch-post=0 branch-post=1 exprop scc-filter=0 simul=0 wdba-minimize=0 relabel-bool=4 relabel-bool=0 tba-det=0 ba-simul=0 degen-lskip=0; do
  run "-x $o"
done

#!/bin/bash
# Stage timing of mtl2tba on the negation of a benchmark formula from formulas.tsv.
# usage: profile_id.sh ID [real|passes|export] [extra mtl2tba options]
#   real    : the installed tool (stats columns spot_s, opt_s, exp_s, total_s)
#   passes  : a copy with per-pass timing of optimize_step
#   export  : a copy with per-stage timing of export
D=/mnt/c/Users/user/Desktop/JSS_paper
id=$1; mode=${2:-real}; shift; shift
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
EXE=$D/tool/_build/default/src/mtl2tba.exe
if [ $mode != real ]; then
  P=$HOME/prof_tool; rm -rf $P; mkdir -p $P
  cp -r $D/tool/src $D/tool/dune-project $P/
  cd $P
  if [ $mode = passes ]; then snip=$D/scripts/step_snippet.ml; pat="^let optimize_step root a"
  else snip=$D/scripts/export_snippet.ml; pat="^let export root a"; fi
  s=$(grep -n "$pat" src/optim.ml | cut -d: -f1)
  e=$(awk -v s=$s 'NR>s && /^$/ {print NR; exit}' src/optim.ml)
  head -n $((s-1)) src/optim.ml > src/optim.new; cat $snip >> src/optim.new
  tail -n +$e src/optim.ml >> src/optim.new; mv src/optim.new src/optim.ml
  eval "$(opam env 2>/dev/null)"; dune build 2>&1 | head -20
  EXE=$P/_build/default/src/mtl2tba.exe
fi
W=$(mktemp -d); cd $W
$EXE -stats-header | tr '\t' ' ' | cut -d' ' -f1-4,5-8,12-14,17-19
/usr/bin/time -f "wall %es maxrss %MKB" timeout 1500 $EXE -nopdf -stats "$@" -o r "!($f)" 2>&1 | tr '\t' ' ' | cut -c1-260

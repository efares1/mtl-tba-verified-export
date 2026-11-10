#!/bin/bash
# Per-stage timing of the export on the positive requirement of N bounded responses.
# Works on a COPY of the tool (the real extracted optim.ml is not modified).
# usage: profile_export.sh N
D=/mnt/c/Users/user/Desktop/JSS_paper
n=$1
P=$HOME/prof_tool
rm -rf $P; mkdir -p $P
cp -r $D/tool/src $D/tool/dune-project $P/ 2>/dev/null
cd $P
s=$(grep -n "^let export root a" src/optim.ml | cut -d: -f1)
e=$(awk -v s=$s 'NR>s && /^$/ {print NR; exit}' src/optim.ml)
head -n $((s-1)) src/optim.ml > src/optim.new
cat $D/scripts/export_snippet.ml >> src/optim.new
tail -n +$e src/optim.ml >> src/optim.new
mv src/optim.new src/optim.ml
eval "$(opam env 2>/dev/null)"
dune build 2>&1 | head -20
f=""
for i in $(seq 1 $n); do
  [ -n "$f" ] && f="$f & "
  f="$f[](a$i -> <>[<=5] b$i)"
done
W=$(mktemp -d); cd $W
$P/_build/default/src/mtl2tba.exe -nopdf -stats -o r "$f" 2>&1 | tr '\t' ' ' | cut -c1-200

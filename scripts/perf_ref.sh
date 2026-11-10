#!/bin/bash
# Where does mtl2tba spend its time on the positive requirement of N bounded responses?
# usage: perf_ref.sh N
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
n=$1; f=""
for i in $(seq 1 $n); do
  [ -n "$f" ] && f="$f & "
  f="$f[](a$i -> <>[<=5] b$i)"
done
W=$(mktemp -d); cd $W
for opt in "-compile-only" "-n 0" ""; do
  echo "== options: [$opt]"
  $EXE -nopdf -stats $opt -o r "$f" | tr '\t' ' ' | tail -1
done
which perf >/dev/null 2>&1 && { echo "== perf"; perf record -g -o perf.data $EXE -nopdf -o r "$f" >/dev/null 2>&1; perf report -i perf.data --no-children --stdio 2>/dev/null | grep -v '^#' | grep '%' | head -25; } || echo "perf not available"

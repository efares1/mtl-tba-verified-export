#!/bin/bash
# time mtl2tba on the POSITIVE requirement (the reference system): profile_ref.sh N
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
n=$1; shift; f=""
for i in $(seq 1 $n); do
  [ -n "$f" ] && f="$f & "
  f="$f[](a$i -> <>[<=5] b$i)"
done
W=$(mktemp -d); cd $W
$EXE -stats-header | tr '\t' ' ' | cut -d' ' -f1-4,12-14
/usr/bin/time -f "wall %es maxrss %MKB" timeout 300 $EXE -nopdf -stats "$@" -o r "$f" 2>&1 | cut -c1-300 | tail -3

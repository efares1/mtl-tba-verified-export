#!/bin/bash
# Profile mtl2tba on n bounded responses: usage profile_gen.sh N [extra mtl2tba options]
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
n=$1; shift
f=""
for i in $(seq 1 $n); do
  [ -n "$f" ] && f="$f & "
  f="$f[](a$i -> <>[<=5] b$i)"
done
W=$(mktemp -d); cd $W
$EXE -stats-header
/usr/bin/time -f "wall %es maxrss %MKB" timeout 900 $EXE -nopdf -stats "$@" -o r "!($f)" 2>&1 | cut -c1-400 | tail -4

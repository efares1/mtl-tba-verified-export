#!/bin/bash
# Split the time of mtl2tba between ltl2tgba and the reader (DNF of the guards).
# usage: profile_spot.sh N
D=/mnt/c/Users/user/Desktop/JSS_paper
EXE=$D/tool/_build/default/src/mtl2tba.exe
n=$1
f=""
for i in $(seq 1 $n); do
  [ -n "$f" ] && f="$f & "
  f="$f[](a$i -> <>[<=5] b$i)"
done
W=$(mktemp -d); cd $W
$EXE -nopdf -check chk -o r "!($f)" > /dev/null 2>&1
ls -l chk_ltl.lbt | awk '{print "ltl size bytes:", $5}'
/usr/bin/time -f "ltl2tgba only: wall %es maxrss %MKB" ltl2tgba --lbt-input -B --small --lbtt=t -F chk_ltl.lbt > out.lbtt 2> err.txt
tail -1 err.txt
ls -l out.lbtt | awk '{print "lbtt bytes:", $5}'
grep -c . out.lbtt | awk '{print "lbtt lines:", $1}'

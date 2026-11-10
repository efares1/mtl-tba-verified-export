#!/bin/bash
# Time ltl2tgba on the clocked-LTL formula of N bounded responses under several settings.
# usage: profile_spot_levels.sh N
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
for lvl in $LEVELS; do
  opts="-B --$lvl"
  s=$(date +%s.%N)
  timeout 600 ltl2tgba --lbt-input $opts --stats="%s states %e edges %a acc sets" -F chk_ltl.lbt > res.txt 2> err.txt
  rc=$?
  e=$(date +%s.%N)
  printf "%-14s rc=%s  %6.2fs  %s\n" "$opts" "$rc" "$(echo "$e - $s" | bc)" "$(head -1 res.txt)"
done

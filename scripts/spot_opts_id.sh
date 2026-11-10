#!/bin/bash
# Time ltl2tgba alone on the clocked-LTL formula of the negation of a benchmark pattern,
# under several option sets.  usage: spot_opts_id.sh ID [timeout_s]
D=/mnt/c/Users/user/Desktop/JSS_paper
id=$1; lim=${2:-120}
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
EXE=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
$EXE -nopdf -check chk -o r "!($f)" > /dev/null 2>&1
echo "ltl bytes: $(wc -c < chk_ltl.lbt)"
run() {
  s=$(date +%s.%N)
  timeout $lim ltl2tgba --lbt-input "$@" --stats="%s states %e edges %a acc sets" -F chk_ltl.lbt > res.txt 2> err.txt
  rc=$?
  e=$(date +%s.%N)
  printf "%-52s rc=%s %7.2fs  %s\n" "$*" "$rc" "$(echo "$e - $s" | bc)" "$(head -1 res.txt)"
}
run -B --low
run -B --low -x tls-impl=0
run -B --low -x ltl-split=0
run -B --low -x tls-impl=0,ltl-split=0
run -B --low -x comp-susp=0
run -B --any
run -B --any -x ltl-split=0
run --low
run -B --low --relabel-bool=0

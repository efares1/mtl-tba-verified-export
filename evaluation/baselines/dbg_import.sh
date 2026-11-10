#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
EV=$D/evaluation
OPT=~/tool_copy/_build/default/src/tba_opt.exe
mkdir -p /tmp/dbgi && cd /tmp/dbgi
echo "== gv N1"; cat $EV/casaal_out_neg/N1.gv
python3 $EV/casaal_to_tba.py $EV/casaal_out_neg/N1.gv n1.tba p1
echo "== tba"; cat n1.tba
$OPT -o n1x -n 0 n1.tba
echo "== xml locations/transitions"
grep -o '<name>[^<]*</name>' n1x.xml | tr '\n' ' '; echo
grep -o '<transition>.*</transition>' n1x.xml | head -20 | sed 's/<label kind="//g' | cut -c1-200

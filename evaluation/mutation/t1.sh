#!/bin/bash
MUT=/mnt/c/Users/user/Desktop/JSS_paper/evaluation/mutation
EV=/mnt/c/Users/user/Desktop/JSS_paper/evaluation
X=$HOME/mut/exe
mkdir -p /tmp/t1 && cd /tmp/t1
$X/base_tba_opt.exe -o rt -dump rt.opt.tba $EV/red_test.tba
python3 $MUT/to_canon.py tba $EV/red_test.tba in.can
python3 $MUT/to_canon.py tba rt.opt.tba opt.can
python3 $MUT/to_canon.py xml rt.xml p,q xml.can
cat in.can xml.can
time $X/lang_cmp in.can opt.can 1000 1
time $X/lang_cmp in.can xml.can 1000 1

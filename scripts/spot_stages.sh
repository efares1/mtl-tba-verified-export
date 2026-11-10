#!/bin/bash
# Time the stages of Spot on the simplified clocked formula of N7.
cd $HOME/perf_spot
t() { local s=$(date +%s.%N); "$@" > o.txt 2>/dev/null; local rc=$?; local e=$(date +%s.%N); printf "%6.2f s rc=%d  %s | %s\n" "$(echo "$e - $s" | bc)" $rc "$*" "$(head -c 60 o.txt | tr '\n' ' ')"; }
t ltlfilt -F f.ltl --size
t ltlfilt -F f.ltl --simplify --size
t ltlfilt -F f.ltl --simplify=3 --size
t ltl2tgba --any --tgba -x ba-simul=0 --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0 --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0,tls-impl=0 --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0,ltl-split=0 --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0,scc-filter=0 --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0,exprop --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0,relabel-bool=1 --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0,branch-post=0 --stats='%s st %e ed' -F f.ltl
t ltl2tgba --any -B -x ba-simul=0,comp-susp=1 --stats='%s st %e ed' -F f.ltl

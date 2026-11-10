#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
W=$HOME/perf_spot; mkdir -p $W; cd $W
cp $D/evaluation/spot_formula_N7.ltl f.ltl
perf record -F 200 -g -o perf.data ltl2tgba -B --any -x ba-simul=0 --hoa -F f.ltl > o.hoa 2> rec.err; tail -2 rec.err
echo "=== top symbols (self)"
perf report -i perf.data --no-children --stdio -g none --percent-limit 1.5 2>/dev/null | grep -v '^#' | grep -v '^$' | cut -c1-170 | head -40
echo "=== by shared object"
perf report -i perf.data --no-children --stdio --sort dso -g none 2>/dev/null | grep -v '^#' | grep -v '^$' | head -8

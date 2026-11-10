#!/bin/bash
cd $HOME/perf_spot
grep -m1 "^AP:" o.hoa | cut -c1-300
grep -m1 "^AP:" o.hoa | awk '{print "AP count:", $2}'
echo "edge label length stats (chars):"
awk '/^\[/ {n++; l+=length($0)} END {print n " edges, avg " l/n " chars per edge line"}' o.hoa
echo "distinct atom kinds in the formula:"
tr -c 'A-Za-z0-9_' '\n' < f.ltl | grep -E '^(x|rst|unch|c|p|q)[A-Za-z0-9_]*$' | sort | uniq -c | sort -rn | head -12
head -c 600 f.ltl; echo

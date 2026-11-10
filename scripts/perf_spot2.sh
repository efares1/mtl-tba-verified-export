#!/bin/bash
cd $HOME/perf_spot
echo "=== inclusive (children), libspot symbols"
perf report -i perf.data --children --stdio -g none --percent-limit 4 2>/dev/null | grep -v '^#' | grep -v '^$' | grep -E "libspot|ltl2tgba" | cut -c1-210 | head -30

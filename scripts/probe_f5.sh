#!/bin/bash
cd "$(dirname "$0")/../tool" || exit 1
EXE=_build/default/src/mtl2tba.exe
mkdir -p /tmp/probe
F='[](p -> <>[>=2] q)'
echo "==== F5 with -v"
"$EXE" -v -nopdf -o /tmp/probe/f5 "$F" 2>&1 | head -40
echo "==== stats header"
"$EXE" -stats-header
"$EXE" -stats -nopdf -o /tmp/probe/f5s "$F" 2>&1 | tail -2

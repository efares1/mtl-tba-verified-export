#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
E=$D/tool/_build/default/src/mtl2tba.exe
mkdir -p /tmp/diff1 && cd /tmp/diff1
$E -nopdf -o f1 "$1" >/dev/null
cat f1.xml

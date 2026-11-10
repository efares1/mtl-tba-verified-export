#!/bin/bash
cd /mnt/c/Users/user/Desktop/JSS_paper/tool
eval "$(opam env 2>/dev/null)"
dune build 2>&1 | tail -15
ls -l _build/default/src/mtl2tba.exe
./_build/default/src/mtl2tba.exe -help 2>&1 | grep -A3 "spot-level"

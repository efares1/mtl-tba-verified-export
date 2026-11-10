#!/bin/bash
# Build a copy of the tool in ~/tool_copy (does not touch tool/_build).
D=/mnt/c/Users/user/Desktop/JSS_paper
P=$HOME/tool_copy; rm -rf $P; mkdir -p $P
cp -r $D/tool/src $D/tool/dune-project $P/
cd $P
eval "$(opam env 2>/dev/null)"
dune build 2>&1 | head -30
ls -l $P/_build/default/src/mtl2tba.exe

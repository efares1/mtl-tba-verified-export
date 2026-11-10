#!/bin/bash
# debug: does ours F1 contain invariants; what does stripping change
D=/mnt/c/Users/user/Desktop/JSS_paper
E=$D/tool/_build/default/src/mtl2tba.exe
mkdir -p /tmp/dbg && cd /tmp/dbg
$E -nopdf -o f1 '!([](p -> <>[<=5] q))' >/dev/null
echo "invariants in ours:"; grep -o '<label kind="invariant">[^<]*' f1.xml | head
echo "locations:"; grep -o '<name>[^<]*</name>' f1.xml | tr '\n' ' '; echo
python3 $D/evaluation/tck_product.py m.tck p,q REF:$D/evaluation/casaal_out_neg/F1.gv NEG:f1.xml >/dev/null
grep -c '^location' m.tck; grep -c '^edge' m.tck
grep 'invariant' m.tck | head

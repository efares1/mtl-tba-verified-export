#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper; E=$D/evaluation; X=$HOME/tool_copy/_build/default/src/tba_opt.exe
W=$HOME/inspect_imp; rm -rf $W; mkdir -p $W; cd $W
id=${1:-F5}
python3 $E/casaal_to_tba.py $E/casaal_out_neg/$id.gv c.tba p,q
$X -n 0 -o n0 c.tba
echo "--- casaal gv"; cat $E/casaal_out_neg/$id.gv
echo "--- xml (invariants?)"; grep -c 'kind="invariant"' n0.xml; grep -o 'kind="invariant"[^<]*<' n0.xml | head -5; grep -c "<transition" n0.xml

#!/bin/bash
# build a copy of the tool and try the importer on a few CASAAL automata
bash /mnt/c/Users/user/Desktop/JSS_paper/scripts/build_copy.sh
D=/mnt/c/Users/user/Desktop/JSS_paper; E=$D/evaluation; X=$HOME/tool_copy/_build/default/src/tba_opt.exe
W=$(mktemp -d); cd $W
for id in "$@"; do
  python3 $E/casaal_to_tba.py $E/casaal_out_neg/$id.gv $id.tba || { echo "$id: not converted"; continue; }
  echo "== $id: $(head -c 0 /dev/null)"; head -3 $id.tba | cut -c1-100
  $X -o $id $id.tba
  $X -n 0 -o ${id}_n0 $id.tba
done

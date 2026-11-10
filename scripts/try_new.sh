#!/bin/bash
D=/mnt/c/Users/user/Desktop/JSS_paper
W=$(mktemp -d); cd $W
$D/tool/_build/default/src/mtl2tba.exe -nopdf -o t '[](a -> <>[<=5] b)' 2>&1 | head -5
echo "rc=$?"
diff <(sed -n 1,40p $D/tool/src/optim.ml) <(sed -n 1,40p $HOME/optim_previous.ml) | head -10
diff $D/tool/src/optim.ml $HOME/optim_previous.ml | head -40

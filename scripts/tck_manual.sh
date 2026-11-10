#!/bin/bash
E=/mnt/c/Users/user/Desktop/JSS_paper/evaluation; X=/mnt/c/Users/user/Desktop/JSS_paper/tool/_build/default/src/mtl2tba.exe
TCK=$HOME/local/bin/tck-liveness
W=$(mktemp -d); cd $W
f='[](a1 -> <>[<=5] b1) & [](a2 -> <>[<=5] b2)'
$X -nopdf -o pos "$f" >/dev/null
python3 $E/make_resp_system.py 2 sys0.xml bad; python3 $E/tck_normalize_system.py sys0.xml sys.xml
lab=$(python3 $E/tck_product.py m.tck a1,a2,b1,b2 SYS:sys.xml NEG:pos.xml); echo "labels: $lab" | cut -c1-200
time (timeout 60 $TCK -a couvscc -l "$lab" m.tck 2>&1 | head -20)
echo "exit: $?"
grep -c "x[0-9] - x[0-9]" m.tck; grep -m3 "x[0-9] - x[0-9]" m.tck

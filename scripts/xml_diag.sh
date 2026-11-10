#!/bin/bash
E=/mnt/c/Users/user/Desktop/JSS_paper; X=$E/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
$X -nopdf -o md '![](a1 -> <>[<=5] b1) | !([](a2 -> <>[<=5] b2))' >/dev/null 2>&1
f='[](a1 -> <>[<=5] b1) & [](a2 -> <>[<=5] b2) & [](a3 -> <>[<=5] b3) & [](a4 -> <>[<=5] b4)'
$X -nopdf -o md "!($f)"; $X -nopdf -all-copy -o ac "!($f)"
for b in md ac; do echo $b; grep -o 'kind="guard">[^<]*<' $b.xml | grep -c -E 'x[0-9]+ *(-|&lt;|&gt;)[^&]*x[0-9]' ; grep -o 'kind="guard">[^<]*<' $b.xml | grep -E 'x[0-9]+ - x' | head -3; done

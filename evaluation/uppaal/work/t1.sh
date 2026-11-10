cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation/uppaal/work
E=/mnt/c/Users/user/Desktop/JSS_paper/tool/_build/default/src/mtl2tba.exe
$E -nopdf -o f1 "!([](p -> <>[<=5] q))"
$E -nopdf -n 0 -o f1n0 "!([](p -> <>[<=5] q))"
$E -nopdf -all-copy -o f1ac "!([](p -> <>[<=5] q))"
O=$HOME/tool_copy/_build/default/src/tba_opt.exe
$O -o c1 c.tba; $O -n 0 -o c0 c.tba; $O -all-copy -o cac c.tba
ls

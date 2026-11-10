cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation/uppaal/work
EV=/mnt/c/Users/user/Desktop/JSS_paper/evaluation
M=/mnt/c/Users/user/Desktop/JSS_paper/evaluation/uppaal/models
E=/mnt/c/Users/user/Desktop/JSS_paper/tool/_build/default/src/mtl2tba.exe
TCK=$HOME/local/bin/tck-liveness
run() { # id formula events gvfile  
  id=$1; f=$2; ev=$3
  rm -f ref.xml; $E -nopdf -all-copy -o ref "$f" >/dev/null 2>&1
  # variants of the NEG automaton: casaal gv original, plain-XML (my converter), casaal through our export, ours
  for v in gv plain n0 opt ours; do
    case $v in
      gv) neg=$EV/casaal_out_neg/$id.gv;;
      plain) sed -n '/<template>/,/<\/template>/p' $M/${id}_free_casaal_plain.xml > /dev/null; neg=$M/${id}_free_casaal_plain.xml;;
      n0) neg=$M/${id}_free_casaal_n0.xml;;
      opt) neg=$M/${id}_free_casaal_opt.xml;;
      ours) neg=$M/${id}_free_ours_default.xml;;
    esac
    # keep only the Property template for tck_product (it picks template Property)
    lab=$(python3 $EV/tck_product.py m.tck $ev REF:ref.xml NEG:$neg 2>&1 | tail -1)
    out=$(timeout 120 $TCK -a couvscc -l "$lab" m.tck 2>&1)
    echo "$id $v $(echo "$out" | grep -E '^(CYCLE|STORED_STATES)' | tr '\n' ' ')"
  done
}
run F1 '[](p -> <>[<=5] q)' p,q
run F5 '[](p -> <>[>=2] q)' p,q
run R2 '[](a1 -> <>[<=5] b1) & [](a2 -> <>[<=5] b2)' a1,b1,a2,b2
run R3 '[](a1 -> <>[<=5] b1) & [](a2 -> <>[<=5] b2) & [](a3 -> <>[<=5] b3)' a1,b1,a2,b2,a3,b3

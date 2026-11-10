cd /mnt/c/Users/user/Desktop/JSS_paper/evaluation/uppaal/work
E=/mnt/c/Users/user/Desktop/JSS_paper/tool/_build/default/src/mtl2tba.exe
awk -F'\t' '!/^#/ && NF>=4 {print $1"\t"$3}' ../../formulas.tsv | while IFS=$'\t' read id f; do
  case $id in F1|F2|F3b|F4|F5|F6|F7|F8|F9|F10|F11|F12|R1|R2|R3|N1|N2|N3) ;; *) continue;; esac
  $E -nopdf -o t_$id "!($f)" >/dev/null 2>&1
  printf "%s\t%s\t%s\n" $id "$(grep -c 'kind="invariant"' t_$id.xml)" "$(grep -c '<location ' t_$id.xml)"
done

#!/bin/bash
# Time the parts of init_free on the export of a benchmark pattern (works on a copy).
# usage: profile_initfree.sh ID [mtl2tba options]
D=/mnt/c/Users/user/Desktop/JSS_paper
id=$1; shift
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
P=$HOME/prof_tool; rm -rf $P; mkdir -p $P
cp -r $D/tool/src $D/tool/dune-project $P/
cd $P
cat > patch.ml <<'EOF'
  let free =
    let tm name f = let t0 = Unix.gettimeofday () in let r = f () in
      Printf.eprintf "INITFREE %-12s %8.3f s\n%!" name (Unix.gettimeofday () -. t0); r in
    Printf.eprintf "INITFREE dta_nstates=%d dta_trans=%d clocks=%d\n%!"
      d.dta_nstates (List.length d.dta_trans) (List.length (all_clocks root));
    let tbl = tm "inv_table" (fun () -> inv_table root d) in
    let r = List.for_all (fun x ->
      let s = tm "live_set" (fun () -> live_set root d tbl x) in
      Printf.eprintf "INITFREE   |S|=%d\n%!" (List.length s);
      tm "live_ok" (fun () -> live_ok root d tbl x s)) (all_clocks root) in r in
EOF
ln=$(grep -n "let free = init_free root d in" src/mtl2tba.ml | cut -d: -f1)
head -n $((ln-1)) src/mtl2tba.ml > src/new.ml; cat patch.ml >> src/new.ml
tail -n +$((ln+1)) src/mtl2tba.ml >> src/new.ml; mv src/new.ml src/mtl2tba.ml
eval "$(opam env 2>/dev/null)"; dune build 2>&1 | head -20
W=$(mktemp -d); cd $W
$P/_build/default/src/mtl2tba.exe -nopdf "$@" -o r "!($f)" 2>&1 | grep INITFREE > $W/if.txt
awk -f /mnt/c/Users/user/Desktop/JSS_paper/scripts/initfree_sum.awk $W/if.txt

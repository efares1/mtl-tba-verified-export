#!/bin/bash
# Time the steps between Spot's output and the optimizer (copy of the tool).
# usage: profile_reader.sh ID [mtl2tba options]
D=/mnt/c/Users/user/Desktop/JSS_paper
id=$1; shift
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
P=$HOME/prof_tool; rm -rf $P; mkdir -p $P
cp -r $D/tool/src $D/tool/dune-project $P/
cd $P
sed -i 's|  let ba = to_pbuchi lbtt atom_of in|  let tm name f = let t0 = Unix.gettimeofday () in let r = f () in Printf.eprintf "READER %-14s %8.3f s\\n%!" name (Unix.gettimeofday () -. t0); r in\n  let ba = tm "to_pbuchi" (fun () -> to_pbuchi lbtt atom_of) in|' src/mtl2tba.ml
sed -i 's|  let tba = compile_with root ba in|  let tba = tm "compile_with" (fun () -> compile_with root ba) in|' src/mtl2tba.ml
sed -i 's|  let (s0, t0, c0) = size_tba tba in|  let (s0, t0, c0) = tm "size_tba" (fun () -> size_tba tba) in|' src/mtl2tba.ml
sed -i 's|  let (s1, t1, c1) = size_tba opt in|  let (s1, t1, c1) = tm "size_tba(opt)" (fun () -> size_tba opt) in|' src/mtl2tba.ml
eval "$(opam env 2>/dev/null)"; dune build 2>&1 | head -20
W=$(mktemp -d); cd $W
$P/_build/default/src/mtl2tba.exe -nopdf "$@" -o r "!($f)" 2>&1 | grep READER

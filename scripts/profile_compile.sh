#!/bin/bash
# Time relax and complete separately (compile_with = complete (relax F A)), on a copy of the tool.
# usage: profile_compile.sh ID [mtl2tba options]
D=/mnt/c/Users/user/Desktop/JSS_paper
id=$1; shift
f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
P=$HOME/prof_tool; rm -rf $P; mkdir -p $P
cp -r $D/tool/src $D/tool/dune-project $P/
cd $P
grep -n "^let compile_with\|^let relax \|^let complete \|^let consistent\|^let comp_resets\|^let keep_lit" src/optim.ml
sed -n "$(grep -n '^let compile_with' src/optim.ml | cut -d: -f1),+3p" src/optim.ml
sed -i 's|  let tba = compile_with root ba in|  let tm name f = let t0 = Unix.gettimeofday () in let r = f () in Printf.eprintf "COMPILE %-10s %8.3f s\\n%!" name (Unix.gettimeofday () -. t0); r in\n  let rl = tm "relax" (fun () -> relax root (ltl_atoms root (t root)) ba) in\n  let nt = List.length rl.pb_trans in Printf.eprintf "COMPILE relaxed transitions %d, max label %d\\n%!" nt (List.fold_left (fun m t -> max m (List.length t.pt_label)) 0 rl.pb_trans);\n  let _ = tm "consistent" (fun () -> List.for_all (fun t -> consistent root t.pt_label) ba.pb_trans) in\n  let tba = tm "complete" (fun () -> complete root rl) in|' src/mtl2tba.ml
eval "$(opam env 2>/dev/null)"; dune build 2>&1 | head -20
W=$(mktemp -d); cd $W
$P/_build/default/src/mtl2tba.exe -nopdf -compile-only "$@" -o r "!($f)" 2>&1 | grep COMPILE

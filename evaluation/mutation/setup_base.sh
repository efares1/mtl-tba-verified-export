#!/bin/bash
# Build pristine scratch copy of the tool (with an extra -dump option in tba_opt) in ~/mut/base.
D=/mnt/c/Users/user/Desktop/JSS_paper
P=$HOME/mut/base; rm -rf $P; mkdir -p $P $HOME/mut/exe
cp -r $D/tool/src $D/tool/dune-project $P/
python3 - <<'PY'
import os
p=os.path.expanduser('~/mut/base/src/tba_opt.ml')
s=open(p).read()
s=s.replace('let stats = ref false\n','let stats = ref false\nlet dump = ref ""\n',1)
s=s.replace('  ("-stats", Arg.Set stats,','  ("-dump", Arg.Set_string dump, "<file> write the optimized TBA (before export) in the input format");\n  ("-stats", Arg.Set stats,',1)
NL=chr(10)
code = '''  if !dump <> "" then begin
    let ci c = let rec idx i = function [] -> -1 | y :: l -> if y = c then i else idx (i + 1) l in idx 0 clocks in
    let oc = open_out !dump in
    Printf.fprintf oc "events %s\nclocks %d\ninit %d\nstates %d\nacc %s\n"
      (String.concat " " !evs) !ncl opt.tba_init opt.tba_nstates
      (String.concat " " (List.map string_of_int opt.tba_accepting));
    let cs = function CLe -> "<=" | CLt -> "<" | CGe -> ">=" | CGt -> ">" | CEq -> "==" in
    List.iter (fun t ->
      Printf.fprintf oc "t %d %d | %s | %s | %s\n" t.bt_source t.bt_target
        (String.concat " " (List.map (fun (a, b) -> string_of_int a ^ (if b then "+" else "-")) t.bt_label))
        (String.concat " " (List.filter_map (Option.map (fun k -> Printf.sprintf "%d%s%g" (ci k.guard_clock) (cs k.guard_comparison) k.guard_bound)) t.bt_guard))
        (String.concat " " (List.map (fun c -> string_of_int (ci c)) t.bt_resets))) opt.tba_transitions;
    close_out oc
  end;
'''
code=code.replace('\n','\n')
anchor='  let (s1, t1, c1) = size_tba opt in\n'
assert anchor in s
s=s.replace(anchor, anchor+code,1)
open(p,'w').write(s)
PY
cd $P
eval "$(opam env 2>/dev/null)"
dune build 2>&1 | head -20
cp _build/default/src/tba_opt.exe $HOME/mut/exe/base_tba_opt.exe
cp _build/default/src/mtl2tba.exe $HOME/mut/exe/base_mtl2tba.exe
ls -l $HOME/mut/exe

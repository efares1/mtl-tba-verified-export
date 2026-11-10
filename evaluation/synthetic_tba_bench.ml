(*
   Synthetic, translator-independent exercise of the checked-in extracted
   generic TBA optimizer/export functions.  The input automata below are
   constructed directly as Optim.tBA records; this script does not parse an
   external format and does not call the MTL/Spot front end.

   Build from the repository root (WSL):
     ocamlc -w -a -c tool/src/optim.ml -o tmp/optim.cmo
     ocamlc -w -a -I tmp -o tmp/synthetic_tba_bench.exe \
       tmp/optim.cmo evaluation/synthetic_tba_bench.ml
     tmp/synthetic_tba_bench.exe

   The emitted `stage` rows are sequential pass measurements within each
   round, not independent one-pass ablations.  The harness checks, for every
   input and every round, that its explicit pass sequence is structurally
   equal to Optim.optimize_step on that input.
*)

open Optim

let p = MAtom 0
let q = MAtom 1
let r = MAtom 2

let cx = MUhatLe (3., p, q)
let cy = MRhatGe (4., q, r)
let cz = MUhatLt (5., r, p)
let cw = MRhatGt (6., p, r)
let cu = MUhatGe (7., q, p)
let cv = MRhatLe (8., r, q)
let root = MAnd (cx, MAnd (cy, MAnd (cz, MAnd (cw, MAnd (cu, cv)))))

let c clock comparison bound =
  Some { guard_clock = clock; guard_comparison = comparison; guard_bound = bound }

let le clock bound = c clock CLe bound
let ge clock bound = c clock CGe bound

let edge ?(label = []) ?(guard = []) ?(resets = []) src dst =
  { bt_source = src; bt_label = label; bt_guard = guard;
    bt_resets = resets; bt_target = dst }

let automaton n init transitions accepting =
  { tba_nstates = n; tba_init = init;
    tba_transitions = transitions; tba_accepting = accepting }

let models =
  [
    ("stable", automaton 1 0
       [edge ~label:[(0, true)] 0 0] [0]);

    ("redundant_guard", automaton 2 0
       [edge ~label:[(0, true)] ~guard:[le cx 5.; le cx 3.] ~resets:[cx] 0 1;
        edge ~guard:[le cx 5.] 1 1] [1]);

    ("contradictory_guard", automaton 2 0
       [edge ~label:[(0, true)] ~guard:[ge cx 3.; le cx 2.] 0 1;
        edge 1 1] [1]);

    ("unsatisfiable_label", automaton 2 0
       [edge ~label:[(0, true); (0, false)] 0 1; edge 1 1] [1]);

    ("isolated_source", automaton 3 0
       [edge ~label:[(0, true)] 0 0; edge ~label:[(1, true)] 2 1] [0; 1]);

    ("dead_reset", automaton 2 0
       [edge ~label:[(0, true)] ~resets:[cz] 0 1;
        edge ~resets:[cz] 1 1] [1]);

    (* The only later uses of cx are the tautological lower bound cx >= 0.
       Normalization removes that guard before dead-reset analysis, allowing
       the incoming reset to be deleted in the same composite round. *)
    ("normalization_dead_reset", automaton 2 0
       [edge ~label:[(0, true)] ~resets:[cx] 0 1;
        edge ~label:[(1, true)] ~guard:[ge cx 0.] 1 1] [1]);

    ("synchronous_clock_merge", automaton 2 0
       [edge ~label:[(0, true)] ~resets:[cx; cy] 0 1;
        edge ~label:[(1, true)] ~guard:[le cx 4.] 1 1;
        edge ~label:[(2, true)] ~guard:[le cy 6.] 1 1] [1]);

    ("duplicate_transition", automaton 2 0
       [edge ~label:[(0, true)] ~guard:[le cx 5.] ~resets:[cx] 0 1;
        edge ~label:[(0, true)] ~guard:[le cx 3.] ~resets:[cx] 0 1;
        edge ~guard:[le cx 6.] 1 1] [1]);

    ("equivalent_locations", automaton 3 0
       [edge ~label:[(0, true)] 0 1; edge ~label:[(0, true)] 0 2;
        edge ~label:[(1, true)] 1 1; edge ~label:[(1, true)] 2 2] [1; 2]);

    (* Export groups same-key alternatives into a disjunctive invariant at
       state 1. The unreset incoming edge makes the branch-selection guards
       depend on both clocks and exercise the clock-difference case. *)
    ("disjunctive_invariant_export", automaton 3 0
       [edge ~label:[(0, true)] 0 1;
        edge ~label:[(1, true)] ~guard:[le cx 3.] 1 1;
        edge ~label:[(1, true)] ~guard:[le cy 4.] 1 1] [1]);

    (* Every edge leaving state 1 bounds cx, so the synthesized upper
       invariant tightens the incoming edge from cx <= 5 to cx <= 2. *)
    ("backward_tightening", automaton 2 0
       [edge ~label:[(0, true)] ~guard:[le cx 5.] 0 1;
        edge ~label:[(1, true)] ~guard:[le cx 2.] 1 1] [1]);

    (* The incoming edge gives cx >= 2 at state 1. Forward propagation adds
       that lower bound to the outgoing edge, which already has cx <= 5. *)
    ("forward_lower_bound", automaton 3 0
       [edge ~label:[(0, true)] ~guard:[ge cx 2.] 0 1;
        edge ~label:[(1, true)] ~guard:[le cx 5.] 1 2;
        edge ~label:[(2, true)] 2 2] [2]);

    (* At location 1, the x<=10 branch prevents backward synthesis from
       tightening the incoming x>=2 edge to x<=1. Forward propagation copies
       x>=2 onto both outgoing edges, making only x<=1 contradictory. Removing
       that edge lets no-incoming-source pruning peel the downstream chain;
       the x<=10 branch reaches a time-divergent accepting loop. *)
    ("forward_contradiction_cascade", automaton 6 0
       [edge ~label:[(3, true)] 0 0;
        edge ~label:[(0, true)] ~guard:[ge cx 2.] 0 1;
        edge ~label:[(1, true)] ~guard:[le cx 1.] 1 2;
        edge ~label:[(2, true)] ~guard:[le cx 10.] 1 3;
        edge ~label:[(3, true)] 2 4;
        edge ~label:[(0, false)] 4 5;
        edge ~label:[(0, true)] 3 3] [0; 3]);

    (* Backward synthesis tightens the incoming lower-bound edge using the
       upper guard on the first branch step.  After that contradiction is
       removed, source-without-incoming pruning peels the remaining chain. *)
    ("backward_contradiction_cascade", automaton 5 0
       [edge ~label:[(3, true)] 0 0;
        edge ~label:[(0, true)] ~guard:[ge cx 2.] 0 1;
        edge ~label:[(1, true)] ~guard:[le cx 1.] 1 2;
        edge ~label:[(2, true)] ~guard:[le cx 1.] 2 3;
        edge ~label:[(0, false)] ~guard:[le cx 1.] 3 4] [0]);

    (* x and y are reset synchronously on every initial edge. The safe branch
       is a time-divergent accepting cycle; merging x and y exposes the
       contradictory guard on the other branch, removed in a later round. *)
    ("clock_merge_contradiction_cascade", automaton 5 0
       [edge ~label:[(3, true)] ~resets:[cx; cy] 0 1;
        edge ~label:[(3, true)] ~guard:[le cx 10.; le cy 10.]
          ~resets:[cx; cy] 1 1;
        edge ~label:[(0, true)] ~resets:[cx; cy] 0 2;
        edge ~label:[(1, true)] ~guard:[ge cx 5.; le cy 3.] 2 3;
        edge ~label:[(2, true)] 3 4] [1]);
  ]

(* Size-parameterized synthetic families exercise scaling independently of the
   translator.  They remain synthetic semantic records, not imported models. *)
let parameterized_models =
  let duplicate k =
    ("duplicate_" ^ string_of_int k,
     automaton 2 0
       (List.init k (fun _ -> edge ~label:[(0, true)] 0 1)
        @ [edge ~label:[(1, true)] 1 1]) [1])
  in
  let unreachable k =
    ("unreachable_cascade_" ^ string_of_int k,
     automaton (k + 2) 0
       (edge ~label:[(0, true)] 0 0 ::
        List.init k (fun j ->
          edge ~label:[(1, true)] (j + 1) (j + 2))) [0])
  in
  let redundant_bounds k =
    ("redundant_bounds_" ^ string_of_int k,
     automaton 2 0
       [edge ~label:[(0, true)]
          ~guard:(List.init k (fun j -> le cx (float_of_int (k - j)))) 0 1;
        edge ~label:[(1, true)] 1 1] [1])
  in
  let sync_clocks k =
    let clocks = [cx; cy; cz; cw; cu; cv] |> List.filteri (fun i _ -> i < k) in
    let labels i = [(0, i land 1 <> 0); (1, i land 2 <> 0); (2, i land 4 <> 0)] in
    ("synchronous_clocks_" ^ string_of_int k,
     automaton 2 0
       (edge ~label:[(0, true)] ~resets:clocks 0 1 ::
        List.mapi (fun i x ->
          edge ~label:(labels i) ~guard:[le x (float_of_int (i + 2))] 1 1) clocks)
       [1])
  in
  let disjunction k =
    let clocks = [cx; cy; cz; cw; cu; cv] |> List.filteri (fun i _ -> i < k) in
    let labels i = [(0, i land 1 <> 0); (1, i land 2 <> 0); (2, i land 4 <> 0)] in
    ("invariant_disjunction_" ^ string_of_int k,
     automaton 2 0
       (edge ~label:[(0, true)] 0 1 ::
        List.mapi (fun i x ->
          edge ~label:(labels i) ~guard:[le x (float_of_int (i + 2))] 1 1) clocks)
       [1])
  in
  List.map duplicate [1; 2; 4; 8; 16; 32]
  @ List.map unreachable [1; 2; 4; 8; 16; 32; 50; 51; 64]
  @ List.map redundant_bounds [1; 2; 4; 8; 16]
  @ List.map sync_clocks [2; 3; 4; 6]
  @ List.map disjunction [2; 3; 4; 6]

let reachable_count a =
  let rec visit todo seen =
    match todo with
    | [] -> List.length seen
    | s :: rest when List.mem s seen -> visit rest seen
    | s :: rest ->
        let next = List.filter_map
            (fun t -> if t.bt_source = s then Some t.bt_target else None)
            a.tba_transitions in
        visit (next @ rest) (s :: seen)
  in
  visit [a.tba_init] []

let unique_clocks clocks =
  List.fold_left
    (fun acc x -> if List.exists (clock_eq_dec root x) acc then acc else x :: acc)
    [] clocks

let tba_counts a =
  let guards = List.concat_map
      (fun t -> List.filter_map (fun x -> x) t.bt_guard) a.tba_transitions in
  let clocks = List.concat_map
      (fun t -> t.bt_resets @ List.map (fun k -> k.guard_clock) (List.filter_map Fun.id t.bt_guard))
      a.tba_transitions
      |> unique_clocks in
  let resets = List.fold_left (fun n t -> n + List.length t.bt_resets) 0 a.tba_transitions in
  let inv = add_two_sided_invariants root a in
  let inv_bounds = ref 0 and inv_locs = ref 0 in
  for s = 0 to a.tba_nstates - 1 do
    let count = List.fold_left
        (fun n x -> match inv.tbail_up s x with Some _ -> n + 1 | None -> n)
        0 (timed_subformulas root) in
    if count > 0 then incr inv_locs;
    inv_bounds := !inv_bounds + count
  done;
  (a.tba_nstates, reachable_count a, List.length a.tba_transitions,
   List.length clocks, resets, List.length guards, !inv_locs, !inv_bounds)

let dta_counts d =
  let guards = List.concat_map (fun t -> List.concat t.dt_guard) d.dta_trans in
  let resets = List.fold_left (fun n t -> n + List.length t.dt_resets) 0 d.dta_trans in
  let diffs = List.fold_left
      (fun n -> function DDiff _ -> n + 1 | DSingle _ -> n) 0 guards in
  let clocks =
    List.concat_map (fun t ->
      t.dt_resets @ List.concat_map (fun conj ->
        List.concat_map (function
          | DSingle k -> [k.guard_clock]
          | DDiff (x, y, _) -> [x; y]) conj) t.dt_guard) d.dta_trans
    |> unique_clocks in
  let inv_locs = ref 0 and inv_bounds = ref 0 in
  for s = 0 to d.dta_nstates - 1 do
    match d.dta_inv s with
    | None -> ()
    | Some us ->
        if us <> [] then incr inv_locs;
        inv_bounds := !inv_bounds + List.fold_left (fun n u -> n + List.length u) 0 us
  done;
  let rec visit todo seen =
    match todo with
    | [] -> List.length seen
    | s :: rest when List.mem s seen -> visit rest seen
    | s :: rest ->
        let next = List.filter_map
            (fun t -> if t.dt_src = s then Some t.dt_tgt else None)
            d.dta_trans in
        visit (next @ rest) (s :: seen)
  in
  (d.dta_nstates, visit [d.dta_init] [], List.length d.dta_trans, List.length clocks, resets,
   List.length guards, !inv_locs, !inv_bounds, diffs)

let emit_header () =
  print_endline
    "model\tround\tstage\tlocations\treachable\ttransitions\tclocks\tresets\tguard_atoms\tinvariant_locations\tinvariant_atoms\tdifference_atoms\tseconds\tocaml_heap_capacity_cumulative_MiB"

let emit_tba model round stage a seconds =
  let (locs, reach, trans, clocks, resets, guards, inv_locs, inv_atoms) = tba_counts a in
  let heap = float_of_int (Gc.quick_stat ()).top_heap_words *. float_of_int Sys.word_size /. 8. /. 1048576. in
  Printf.printf "%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t0\t%.6f\t%.3f\n%!"
    model round stage locs reach trans clocks resets guards inv_locs inv_atoms seconds heap

let emit_dta model round stage d seconds =
  let (locs, reach, trans, clocks, resets, guards, inv_locs, inv_atoms, diffs) = dta_counts d in
  let heap = float_of_int (Gc.quick_stat ()).top_heap_words *. float_of_int Sys.word_size /. 8. /. 1048576. in
  Printf.printf "%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.3f\n%!"
    model round stage locs reach trans clocks resets guards inv_locs inv_atoms diffs seconds heap

let measured model round name f a =
  let t0 = Unix.gettimeofday () in
  let a' = f root a in
  let elapsed = Unix.gettimeofday () -. t0 in
  emit_tba model round name a' elapsed;
  a'

let round model round_no a =
  let t0 = Unix.gettimeofday () in
  let b = measured model round_no "backward" propagate a in
  let b = measured model round_no "forward" forward b in
  let b = measured model round_no "contradictory" remove_contradictory b in
  let b = measured model round_no "unsatisfiable_label" remove_unsat b in
  let b = measured model round_no "source_without_incoming" remove_unreachable b in
  let b = measured model round_no "normalize_1" normalize b in
  let b = measured model round_no "dead_resets" remove_dead_resets b in
  let b = measured model round_no "normalize_2" normalize b in
  let b = measured model round_no "synchronous_clocks" merge_all b in
  let b = measured model round_no "normalize_3" normalize b in
  let b = measured model round_no "transition_subsumption" merge_trans b in
  let b = measured model round_no "equivalent_locations" merge_states_all b in
  let reference = optimize_step root a in
  if b <> reference then failwith (model ^ ": profiled round differs from optimize_step");
  emit_tba model round_no "round_end" b (Unix.gettimeofday () -. t0);
  b

let rec optimize_until_stable rounds a =
  if rounds >= 50 then a, rounds else
  let b = optimize_step root a in
  if b = a then b, rounds else optimize_until_stable (rounds + 1) b

let average_time repetitions f =
  let t0 = Unix.gettimeofday () in
  for _ = 1 to repetitions do ignore (f ()) done;
  (Unix.gettimeofday () -. t0) /. float_of_int repetitions

let profile model a =
  emit_tba model 0 "input" a 0.;
  let rec iterate round_no a =
    if round_no >= 50 then begin
      emit_tba model round_no "round_cap" a 0.; a
    end else begin
      let b = round model (round_no + 1) a in
      let changed = b <> a in
      if changed then iterate (round_no + 1) b else a
    end
  in
  let optimized = iterate 0 a in
  let repetitions = 200 in
  let (unprofiled, rounds) = optimize_until_stable 0 a in
  if optimized <> unprofiled then failwith (model ^ ": profiled and unprofiled optimizers differ");
  let optimize_avg = average_time repetitions (fun () -> optimize_until_stable 0 a) in
  emit_tba model rounds ("unprofiled_optimize_avg_" ^ string_of_int repetitions)
    unprofiled optimize_avg;
  let exported = export root optimized in
  let export_avg = average_time repetitions (fun () -> export root optimized) in
  emit_dta model 0 ("explicit_export_avg_" ^ string_of_int repetitions)
    exported export_avg;
  let symbolic = Optim.symbolic root exported in
  Printf.eprintf "%s\tfinal_symbolic_transitions\t%d\n%!"
    model (List.length symbolic.sdta_trans);
  optimized, exported

(* One-pass ablations are kept separate from the verified optimize_step.  Each
   ablation composes only the remaining extracted, individually verified
   passes; this is a structural measurement, not a Rocq theorem about this
   driver. *)
let ablation_passes =
  ["none"; "synthesis_backward"; "forward"; "contradictory"; "unsatisfiable_label";
   "source_without_incoming"; "normalization"; "dead_resets";
   "synchronous_clocks"; "transition_subsumption"; "equivalent_locations"]

let ablated_step omitted a =
  let run name f a = if omitted = name then a else f root a in
  let b = run "synthesis_backward" propagate a in
  let b = run "forward" forward b in
  let b = run "contradictory" remove_contradictory b in
  let b = run "unsatisfiable_label" remove_unsat b in
  let b = run "source_without_incoming" remove_unreachable b in
  let b = run "normalization" normalize b in
  let b = run "dead_resets" remove_dead_resets b in
  let b = run "normalization" normalize b in
  let b = run "synchronous_clocks" merge_all b in
  let b = run "normalization" normalize b in
  let b = run "transition_subsumption" merge_trans b in
  run "equivalent_locations" merge_states_all b

let ablation_fix omitted a =
  let rec loop changed_rounds a =
    if changed_rounds >= 50 then a, changed_rounds, false
    else
      let b = ablated_step omitted a in
      if b = a then a, changed_rounds, true
      else loop (changed_rounds + 1) b
  in
  loop 0 a

let profile_ablation model a =
  let repetitions = 200 in
  let (in_locs, in_reach, in_edges, in_clocks, _, _, _, _) = tba_counts a in
  List.iter (fun omitted ->
    let result, rounds, stable = ablation_fix omitted a in
    if omitted = "none" && result <> optimize root rounds a then
      failwith (model ^ ": full ablation differs from extracted optimize");
    let seconds = average_time repetitions (fun () -> ablation_fix omitted a) in
    let (out_locs, out_reach, out_edges, out_clocks, _, _, _, _) = tba_counts result in
    Printf.printf "%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.8f\n%!"
      model omitted in_locs in_reach in_edges in_clocks out_locs out_reach
      out_edges out_clocks rounds (if stable then 1 else 0) seconds
  ) ablation_passes

let compare_exports model a =
  let optimized, rounds = optimize_until_stable 0 a in
  let repetitions = 200 in
  let emit variant f =
    let elapsed = average_time repetitions (fun () -> ignore (f root optimized)) in
    let result = f root optimized in
    let (locs, reach, trans, clocks, resets, guards, inv_locs, inv_atoms, diffs) =
      dta_counts result in
    let symbolic_trans = List.length (Optim.symbolic root result).sdta_trans in
    Printf.printf "%s\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.8f\n%!"
      model rounds variant locs reach trans clocks resets guards inv_locs
      inv_atoms diffs symbolic_trans elapsed
  in
  emit "max_delay" export;
  emit "all_copy" export_all

let comparison_string = function
  | CLe -> "<=" | CLt -> "<" | CGe -> ">=" | CGt -> ">" | CEq -> "="

let clock_index x =
  let clocks = unique_clocks (timed_subformulas root) |> List.rev in
  let rec find i = function
    | [] -> "?"
    | y :: ys -> if clock_eq_dec root x y then string_of_int i else find (i + 1) ys
  in find 0 clocks

let show_guard g =
  let atoms = List.filter_map Fun.id g in
  if atoms = [] then "true"
  else String.concat " & " (List.map (fun k ->
    Printf.sprintf "x%s %s %g" (clock_index k.guard_clock)
      (comparison_string k.guard_comparison) k.guard_bound) atoms)

let show_label lits =
  if lits = [] then "true"
  else String.concat " & " (List.map (fun (a, positive) ->
    (if positive then "" else "!") ^
    (match a with 0 -> "p" | 1 -> "q" | 2 -> "r" | _ -> "a" ^ string_of_int a)) lits)

let show_tba phase a =
  Printf.printf "AUTOMATON\t%s\tnstates=%d\tinit=%d\taccepting=%s\n"
    phase a.tba_nstates a.tba_init
    (String.concat "," (List.map string_of_int a.tba_accepting));
  List.iteri (fun i t ->
    let resets = if t.bt_resets = [] then "-" else
      String.concat "," (List.map (fun x -> "x" ^ clock_index x) t.bt_resets) in
    Printf.printf "EDGE\t%s\te%d\t%d --[%s ; %s ; reset %s]--> %d\n"
      phase i t.bt_source (show_label t.bt_label) (show_guard t.bt_guard)
      resets t.bt_target) a.tba_transitions

let profiled_step model round_no a =
  let phases = [
    ("backward_bound_synthesis", propagate);
    ("forward_lower_bounds", forward);
    ("contradiction_removal", remove_contradictory);
    ("unsatisfiable_label_removal", remove_unsat);
    ("unreachable_source_removal", remove_unreachable);
    ("guard_normalization_1", normalize);
    ("dead_reset_removal", remove_dead_resets);
    ("guard_normalization_2", normalize);
    ("synchronous_clock_merge", merge_all);
    ("guard_normalization_3", normalize);
    ("transition_subsumption", merge_trans);
    ("equivalent_location_merge", merge_states_all)
  ] in
  let result = List.fold_left (fun current (name, f) ->
    let next = f root current in
    show_tba (Printf.sprintf "round_%d_%s" round_no name) next;
    next) a phases in
  if result <> optimize_step root a then
    failwith (model ^ ": described pass sequence differs from optimize_step");
  result

let describe model a =
  show_tba (model ^ "_input") a;
  let rec loop round_no current =
    if round_no >= 50 then Printf.printf "STATUS\t%s\tround_cap\t50\n" model
    else
      let next = profiled_step model (round_no + 1) current in
      if next = current then Printf.printf "STATUS\t%s\tstable_after_%d_changed_rounds\n" model round_no
      else begin
        show_tba (Printf.sprintf "%s_after_round_%d" model (round_no + 1)) next;
        loop (round_no + 1) next
      end
  in loop 0 a

let cap_probe model a =
  let rec rounds n current =
    if n = 0 then current else rounds (n - 1) (optimize_step root current)
  in
  let after_50 = rounds 50 a in
  let after_51 = optimize_step root after_50 in
  let after_52 = optimize_step root after_51 in
  let (_, _, input_edges, _, _, _, _, _) = tba_counts a in
  let (_, _, cap_edges, _, _, _, _, _) = tba_counts after_50 in
  let (_, _, next_edges, _, _, _, _, _) = tba_counts after_51 in
  let (_, _, final_edges, _, _, _, _, _) = tba_counts after_52 in
  Printf.printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n%!"
    model input_edges cap_edges (if after_51 <> after_50 then 1 else 0)
    next_edges (if after_52 <> after_51 then 1 else 0) final_edges
    (if after_52 = after_51 then 1 else 0)

let () =
  if Array.length Sys.argv > 1 && Sys.argv.(1) = "--parameterized" then begin
    emit_header ();
    let selected =
      if Array.length Sys.argv <= 2 then parameterized_models
      else List.filter (fun (name, _) -> name = Sys.argv.(2)) parameterized_models
    in
    if selected = [] then invalid_arg "unknown parameterized synthetic model";
    List.iter (fun (name, a) -> ignore (profile name a)) selected
  end else if Array.length Sys.argv > 1 && Sys.argv.(1) = "--compare-export" then begin
    print_endline
      "model\toptimize_rounds\tvariant\tlocations\treachable\ttransitions\tclocks\tresets\tguard_atoms\tinvariant_locations\tinvariant_atoms\tdifference_atoms\tsymbolic_transitions\tmean_seconds_200";
    let selected =
      if Array.length Sys.argv <= 2 then models
      else List.filter (fun (name, _) -> name = Sys.argv.(2)) models
    in
    if selected = [] then invalid_arg ("unknown synthetic model: " ^ Sys.argv.(2));
    List.iter (fun (name, a) -> compare_exports name a) selected
  end else if Array.length Sys.argv > 1 && Sys.argv.(1) = "--compare-parameterized" then begin
    print_endline
      "model\toptimize_rounds\tvariant\tlocations\treachable\ttransitions\tclocks\tresets\tguard_atoms\tinvariant_locations\tinvariant_atoms\tdifference_atoms\tsymbolic_transitions\tmean_seconds_200";
    let selected =
      if Array.length Sys.argv <= 2 then parameterized_models
      else List.filter (fun (name, _) -> name = Sys.argv.(2)) parameterized_models
    in
    if selected = [] then invalid_arg ("unknown parameterized model: " ^ Sys.argv.(2));
    List.iter (fun (name, a) -> compare_exports name a) selected
  end else if Array.length Sys.argv > 1 && Sys.argv.(1) = "--ablation" then begin
    print_endline
      "model\tvariant\tin_locations\tin_reachable\tin_transitions\tin_clocks\tout_locations\tout_reachable\tout_transitions\tout_clocks\tchanged_rounds\tstable\tmean_seconds_200";
    let selected =
      if Array.length Sys.argv <= 2 then models
      else List.filter (fun (name, _) -> name = Sys.argv.(2)) models
    in
    if selected = [] then invalid_arg ("unknown synthetic model: " ^ Sys.argv.(2));
    List.iter (fun (name, a) -> profile_ablation name a) selected
  end else if Array.length Sys.argv > 1 && Sys.argv.(1) = "--describe" then begin
    let selected =
      if Array.length Sys.argv <= 2 then models
      else List.filter (fun (name, _) -> name = Sys.argv.(2)) models
    in
    if selected = [] then invalid_arg ("unknown synthetic model: " ^ Sys.argv.(2));
    List.iter (fun (name, a) -> describe name a) selected
  end else if Array.length Sys.argv > 1 && Sys.argv.(1) = "--cap-probe" then begin
    print_endline "model\tinput_transitions\tafter50_transitions\tchanged_at51\tafter51_transitions\tchanged_at52\tafter52_transitions\tstable_after51_changed_rounds";
    let selected =
      if Array.length Sys.argv <= 2 then parameterized_models
      else List.filter (fun (name, _) -> name = Sys.argv.(2)) parameterized_models
    in
    if selected = [] then invalid_arg ("unknown parameterized model: " ^ Sys.argv.(2));
    List.iter (fun (name, a) -> cap_probe name a) selected
  end else begin
    emit_header ();
    let selected =
      if Array.length Sys.argv = 1 then models
      else List.filter (fun (name, _) -> name = Sys.argv.(1)) models
    in
    if selected = [] then invalid_arg ("unknown synthetic model: " ^ Sys.argv.(1));
    List.iter (fun (name, a) -> ignore (profile name a)) selected
  end

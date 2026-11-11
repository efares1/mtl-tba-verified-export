(* mtl2tba: from an MTL(0,inf) formula to a timed automaton for UPPAAL.

     mtl2tba [options] 'formula'

   Chain:
     1. parsing                                    (prototype: lexer, parser, Mtl)
        negation normal form                       (extracted from Coq: neg)
     2. derivation of the ordinary timed operators (extracted from Coq: MUle, ...)
        lower bounds under []<> and <>[] removed   (extracted from Coq: recur)
     3. clocked-LTL translation T                  (extracted from Coq)
        weak until in upper-bounded hatted clauses (extracted from Coq: weak)
     4. LTL -> Buchi automaton                     (Spot, ltl2tgba)
     5. relaxation and reset completion            (extracted from Coq: compile_with)
     6. optimization, iterated to a fixpoint       (extracted from Coq: optimize)
     7. export: conjunctive guards and invariants  (extracted from Coq: export)
     8. UPPAAL (.xml) and Graphviz (.dot) output

   Steps 2, 3, 5, 6, 7 are proved correct in Coq (MTL_to_TBA_correct_with,
   optimize_accepts, export_accepts), assuming that Spot is correct. *)

open Optim

let out = ref "out"
let spot = ref "ltl2tgba"
let spot_level = ref "auto"
let spot_budget = ref 5.0
let spot_x = ref ""
let spot_format = ref "hoa"
let spot_fallback_used = ref false
let with_init = ref false
let rounds = ref 50
let alloc_on = ref false
let prune_on = ref false
let prune_split = ref false
let alloc_fuzz = ref 0
let alloc_unchecked = ref false
let verbose = ref false
let dump_tba = ref false
let recur_on = ref true
let formula = ref ""
let stats = ref false
let pdf = ref true
let dot_cmd = ref "dot"
let simp = ref false
let check = ref ""
let weak_until = ref true
let all_copy_export = ref false
let explicit_neg = ref true
let compile_only = ref false

let stats_header = String.concat "	"
  [ "formula_clocks"; "spot_states"; "spot_trans"; "spot_s";
    "comp_locs"; "comp_trans"; "comp_clocks";
    "opt_rounds"; "opt_locs"; "opt_trans"; "opt_clocks";
    "exp_locs"; "exp_trans"; "exp_clocks"; "exp_invs"; "exp_diffs";
    "opt_s"; "exp_s"; "total_s"; "init_free"; "sym_trans" ]

let speclist = [
  ("-o", Arg.Set_string out, "<base> output files <base>.xml and <base>.dot (default: out)");
  ("-simp", Arg.Set simp, " simplify the trivial operands of the clocked-LTL formula before Spot (proved; Spot does it anyway)");
  ("-noweak", Arg.Clear weak_until, " for measurements only: keep a strong Until in the clauses of upper-bounded hatted Until instead of the weak until of the translation");
  ("-norecur", Arg.Clear recur_on, " keep the lower bounds under []<> and <>[]; by default []<>[>=d] p is rewritten into []<> p and <>[][>=d] p into <>[] p (and likewise with >), which holds under time divergence (proved: MTL_to_exported_correct0_recur_weak_with)");
  ("-init", Arg.Set with_init, " add an initialization event _init_ fixing the time origin");
  ("-n", Arg.Set_int rounds, "<n> maximal number of optimization rounds (default: 50; 0 disables optimization)");
  ("-spot", Arg.Set_string spot, "<cmd> LTL-to-Buchi command (default: ltl2tgba)");
  ("-spot-level", Arg.Set_string spot_level,
   "<l> Spot post-processing level: auto (default), low, any, medium, high or small.     auto runs low and, if Spot has not finished after -spot-budget seconds,     stops it and runs `any`, with Spot's simulation reductions off (-x ba-simul=0), on the simplified formula (as with -simp); this is     fast on the nested requirements, where low is slow, and on the conjunctions     of bounded responses, where any is slow. An explicit level is used as given");
  ("-spot-format", Arg.Set_string spot_format,
   "<f> format read from Spot: hoa (default, symbolic guards, faster for Spot to print) or lbtt");
  ("-spot-x", Arg.Set_string spot_x,
   "<opts> extra options passed to Spot as -x <opts> (for instance ba-simul=0)");
  ("-spot-budget", Arg.Set_float spot_budget,
   "<s> seconds that auto gives to low before it falls back to any (default: 5)");
  ("-nopdf", Arg.Clear pdf, " do not run Graphviz to produce <base>.pdf from <base>.dot");
  ("-explicit-neg", Arg.Set explicit_neg, " print the negated event atom !e as the negation of the quoted atom, !\"e\" (default); Spot then knows that e and !e exclude each other. The backend contract of the proof is required only on the action-consistent words (action_consistent), in which !e is the complement of e");
  ("-indep-neg", Arg.Clear explicit_neg, " print the negated event atom !e as the independent quoted atom \"!e\" (the contract then holds on all propositional words, which is stronger than needed)");
  ("-prune-split", Arg.Unit (fun () -> prune_on := true; prune_split := true), " like -prune, but first split every transition into one transition per cell of letters (verified, split_cells_accepts); makes the domination test exact but can multiply transitions");
  ("-prune", Arg.Set prune_on, " after the optimization, drop dominated transitions (verified checker Optim.prune_pass, Coq prune_pass_accepts; the simulation in prune.ml is untrusted and its result is checked)");
  ("-alloc", Arg.Set alloc_on, " after the optimization, reuse clocks by liveness (verified checker Optim.alloc_pass, Coq alloc_pass_accepts; the colouring in alloc.ml is untrusted and its result is checked)");
  ("-alloc-fuzz", Arg.Set_int alloc_fuzz, "<seed> (testing of the checker) with -alloc, replace the allocation by a random one with this seed; the checker still decides");
  ("-alloc-unchecked", Arg.Set alloc_unchecked, " (testing of the checker) with -alloc, apply the allocation even when the checker rejects it; UNSOUND, never use for results");
  ("-all-copy", Arg.Set all_copy_export, " use the separately verified nondeterministic all-copy invariant split for export (experimental comparison mode)");
  ("-dot", Arg.Set_string dot_cmd, "<cmd> Graphviz command (default: dot)");
  ("-tba", Arg.Set dump_tba, " also write <base>_tba.dot and <base>_opt.dot");
  ("-check", Arg.Set_string check, "<base> also write <base>_ltl.lbt (the clocked-LTL formula, in prefix notation, by a second printer) and <base>_ba.hoa (the automaton built by the reader), for the validation of the trusted interface with Spot");
    ("-compile-only", Arg.Set compile_only, " stop after reset completion: compute compile(f) of the article, without the optimization and the export of the follow-up development; with -tba write <base>_tba.dot, with -stats print the first seven measures (see -stats-header) and the total time");
  ("-v", Arg.Set verbose, " print the intermediate results");
  ("-stats", Arg.Set stats, " print one tab-separated line of measures (see -stats-header)");
  ("-stats-header", Arg.Unit (fun () -> print_endline stats_header; exit 0), " print the header of -stats");
]
let usage = "mtl2tba [options] 'formula'"

let log fmt = Printf.ksprintf (fun s -> if !verbose then prerr_endline s) fmt
let fail fmt = Printf.ksprintf (fun s -> prerr_endline ("mtl2tba: " ^ s); exit 1) fmt

(* ------------------------------------------------------------------ *)
(* 1-2. Formula                                                        *)

let parse_formula s =
  try Parser.form Lexer.read (Lexing.from_string s) with
  | Lexer.SyntaxError m -> fail "syntax error: %s" m
  | Parser.Error -> fail "syntax error in %S" s

let event_tbl : (string, int) Hashtbl.t = Hashtbl.create 16
let event_names : (int, string) Hashtbl.t = Hashtbl.create 16
let event s =
  match Hashtbl.find_opt event_tbl s with
  | Some i -> i
  | None ->
    let i = Hashtbl.length event_tbl in
    Hashtbl.add event_tbl s i; Hashtbl.add event_names i s; i

(* Prototype formulas to the formulas of the Coq development; the ordinary
   timed operators are derived by the extracted definitions. *)
(* Bounds are integers in [0, 2^30].  They, their sums with one another,
   their differences, and their negations are then exactly represented by
   OCaml floats (53-bit mantissa) and fit in the 32-bit integers of UPPAAL, so
   that the floating-point realization of the real numbers of the proof is
   exact on every value the extracted code computes. *)
let max_bound = 1 lsl 30

let bound (d : int) : float =
  if d < 0 || d > max_bound then
    fail "bound %d outside the supported range [0, %d]" d max_bound;
  float d

let rec conv (f : Mtl.mtl) : mtl =
  let b2 c p q = (conv p, conv q, c) in
  match f with
  | Mtl.True -> MTrue
  | Mtl.False -> MFalse
  | Mtl.Event s -> MAtom (event s)
  | Mtl.NEvent s -> MNotAtom (event s)
  | Mtl.Next p -> MNext (conv p)
  | Mtl.Not p -> neg (conv p)
  | Mtl.And (p, q) -> MAnd (conv p, conv q)
  | Mtl.Or (p, q) -> MOr (conv p, conv q)
  | Mtl.Until (c, p, q) ->
    let (p, q, c) = b2 c p q in
    (match c with
     | Mtl.Untimed | Mtl.GE 0 -> MU (p, q)
     | Mtl.LE d -> mUle (bound d) p q
     | Mtl.LT d -> mUlt (bound d) p q
     | Mtl.GE d -> mUge (bound d) p q
     | Mtl.GT d -> mUgt (bound d) p q)
  | Mtl.Release (c, p, q) ->
    let (p, q, c) = b2 c p q in
    (match c with
     | Mtl.Untimed | Mtl.GE 0 -> MR (p, q)
     | Mtl.LE d -> mRle (bound d) p q
     | Mtl.LT d -> mRlt (bound d) p q
     | Mtl.GE d -> mRge (bound d) p q
     | Mtl.GT d -> mRgt (bound d) p q)
  | Mtl.XUntil (c, p, q) ->
    let (p, q, c) = b2 c p q in
    (match c with
     | Mtl.Untimed | Mtl.GE 0 -> MNext (MU (p, q))
     | Mtl.LE d -> MUhatLe (bound d, p, q)
     | Mtl.LT d -> MUhatLt (bound d, p, q)
     | Mtl.GE d -> MUhatGe (bound d, p, q)
     | Mtl.GT d -> MUhatGt (bound d, p, q))
  | Mtl.XRelease (c, p, q) ->
    let (p, q, c) = b2 c p q in
    (match c with
     | Mtl.Untimed | Mtl.GE 0 -> MNext (MR (p, q))
     | Mtl.LE d -> MRhatLe (bound d, p, q)
     | Mtl.LT d -> MRhatLt (bound d, p, q)
     | Mtl.GE d -> MRhatGe (bound d, p, q)
     | Mtl.GT d -> MRhatGt (bound d, p, q))

(* [well_formed] of the Coq development *)
let rec well_formed = function
  | MTrue | MFalse | MAtom _ | MNotAtom _ -> true
  | MAnd (p, q) | MOr (p, q) | MU (p, q) | MR (p, q) -> well_formed p && well_formed q
  | MNext p -> well_formed p
  | MUhatLe (d, p, q) | MRhatLe (d, p, q) -> d >= 0. && well_formed p && well_formed q
  | MUhatGe (d, p, q) | MRhatGe (d, p, q) | MUhatLt (d, p, q) | MUhatGt (d, p, q)
  | MRhatLt (d, p, q) | MRhatGt (d, p, q) -> d > 0. && well_formed p && well_formed q

(* ------------------------------------------------------------------ *)
(* 3-4. Clocked LTL and Spot                                           *)

let clocks_of root =
  let rec dedup acc = function
    | [] -> List.rev acc
    | x :: l -> if List.mem x acc then dedup acc l else dedup (x :: acc) l in
  dedup [] (timed_subformulas root)

let clock_name clocks x =
  let rec idx i = function
    | [] -> "x?"
    | y :: l -> if y = x then "x" ^ string_of_int i else idx (i + 1) l in
  idx 0 clocks

let atom_name clocks = function
  | LAct a -> Hashtbl.find event_names a
  | LNAct a -> "!" ^ Hashtbl.find event_names a
  | LCLe (x, d) -> Printf.sprintf "%s <= %s" (clock_name clocks x) (Output.num d)
  | LCLt (x, d) -> Printf.sprintf "%s < %s" (clock_name clocks x) (Output.num d)
  | LCGe (x, d) -> Printf.sprintf "%s >= %s" (clock_name clocks x) (Output.num d)
  | LCGt (x, d) -> Printf.sprintf "%s > %s" (clock_name clocks x) (Output.num d)
  | LRst x -> Printf.sprintf "rst(%s)" (clock_name clocks x)
  | LUnch x -> Printf.sprintf "unch(%s)" (clock_name clocks x)

(* By default the negated event !e is printed as the negation of the quoted
   atom, !"e", and every other atom as a quoted proposition: the contract of
   the Coq development (action_consistent) is required only on the words in
   which !e is the complement of e.  With -indep-neg the negated event is a
   separate quoted atom "!e", independent of "e". *)
let negated_event s =
  if !explicit_neg && String.length s > 1 && s.[0] = '!'
  then Some (String.sub s 1 (String.length s - 1)) else None

let rec spot_formula nm = function
  | LTrue -> "true"
  | LFalse -> "false"
  | LAtom a ->
    (match negated_event (nm a) with
     | Some e -> "!\"" ^ e ^ "\""
     | None -> "\"" ^ nm a ^ "\"")
  | LAnd (p, q) -> "(" ^ spot_formula nm p ^ " & " ^ spot_formula nm q ^ ")"
  | LOr (p, q) -> "(" ^ spot_formula nm p ^ " | " ^ spot_formula nm q ^ ")"
  | LNext p -> "X(" ^ spot_formula nm p ^ ")"
  | LUntil (p, q) -> "(" ^ spot_formula nm p ^ " U " ^ spot_formula nm q ^ ")"
  | LRelease (p, q) -> "(" ^ spot_formula nm p ^ " R " ^ spot_formula nm q ^ ")"

(* Second printer of the clocked-LTL formula, in the prefix (LBT) notation
   of Spot, written independently of [spot_formula]: comparing what Spot
   reads from both texts checks the printing of T(f) (option -check). *)
let rec lbt_formula nm = function
  | LTrue -> "t"
  | LFalse -> "f"
  | LAtom a ->
    (match negated_event (nm a) with
     | Some e -> "! \"" ^ e ^ "\""
     | None -> "\"" ^ nm a ^ "\"")
  | LAnd (p, q) -> "& " ^ lbt_formula nm p ^ " " ^ lbt_formula nm q
  | LOr (p, q) -> "| " ^ lbt_formula nm p ^ " " ^ lbt_formula nm q
  | LNext p -> "X " ^ lbt_formula nm p
  | LUntil (p, q) -> "U " ^ lbt_formula nm p ^ " " ^ lbt_formula nm q
  | LRelease (p, q) -> "V " ^ lbt_formula nm p ^ " " ^ lbt_formula nm q

(* The propositional Buchi automaton built by the reader, in the HOA format,
   with state-based acceptance: comparing it with the raw output of Spot
   (autfilt --equivalent-to) checks the reader (option -check). *)
let hoa_of_pbuchi nm (b : pBuchi) =
  let aps = List.sort_uniq compare
      (List.concat_map (fun t -> List.map (fun (a, _) -> nm a) t.pt_label) b.pb_trans) in
  let idx s =
    let rec go i = function [] -> assert false | x :: l -> if x = s then i else go (i + 1) l in
    go 0 aps in
  let buf = Buffer.create 4096 in
  let pr fmt = Printf.bprintf buf fmt in
  pr "HOA: v1\nStates: %d\nStart: %d\n" b.pb_nstates b.pb_init;
  pr "AP: %d%s\n" (List.length aps)
    (String.concat "" (List.map (fun s -> " \"" ^ s ^ "\"") aps));
  pr "acc-name: Buchi\nAcceptance: 1 Inf(0)\nproperties: state-acc\n--BODY--\n";
  for s = 0 to b.pb_nstates - 1 do
    pr "State: %d%s\n" s (if List.mem s b.pb_accepting then " {0}" else "");
    List.iter (fun t ->
        if t.pt_src = s then begin
          let lit (a, pos) = (if pos then "" else "!") ^ string_of_int (idx (nm a)) in
          let lab = match t.pt_label with
            | [] -> "t" | l -> String.concat "&" (List.map lit l) in
          pr "[%s] %d\n" lab t.pt_tgt
        end) b.pb_trans
  done;
  pr "--END--\n";
  Buffer.contents buf

let read_file f = In_channel.with_open_bin f In_channel.input_all

(* One run of Spot at [level] on [ltl_text]; [limit] is a time limit in
   seconds after which Spot is killed and [None] is returned. *)
let spot_once ?(extra = "") level ltl_text limit =
  let fin = Filename.temp_file "mtl2tba" ".ltl" in
  let fout = Filename.temp_file "mtl2tba" ".lbtt" in
  Out_channel.with_open_bin fin (fun oc -> output_string oc ltl_text);
  let xs = String.concat "," (List.filter (fun x -> x <> "") [ !spot_x; extra ]) in
  let xopt = if xs = "" then "" else " -x " ^ Filename.quote xs in
  let fmt = if !spot_format = "lbtt" then "--lbtt=t" else "--hoa" in
  let cmd = Printf.sprintf "exec %s -B --%s%s %s -F %s > %s" !spot level xopt fmt
      (Filename.quote fin) (Filename.quote fout) in
  log "command: %s" cmd;
  let result =
    match limit with
    | None ->
      if Sys.command cmd <> 0 then fail "the command %s failed (is Spot installed?)" !spot;
      Some (read_file fout)
    | Some secs ->
      let pid = Unix.create_process "/bin/sh" [| "sh"; "-c"; cmd |]
          Unix.stdin Unix.stdout Unix.stderr in
      let t0 = Unix.gettimeofday () in
      let rec wait () =
        match Unix.waitpid [Unix.WNOHANG] pid with
        | (0, _) ->
          if Unix.gettimeofday () -. t0 > secs then begin
            Unix.kill pid Sys.sigkill; ignore (Unix.waitpid [] pid); None
          end else (Unix.sleepf 0.01; wait ())
        | (_, Unix.WEXITED 0) -> Some (read_file fout)
        | _ -> fail "the command %s failed (is Spot installed?)" !spot in
      wait () in
  Sys.remove fin; Sys.remove fout;
  result

(* [simplified ()] is the text of the simplified formula, used by the
   fallback of the automatic choice. *)
let run_spot ltl_text simplified =
  if not (List.mem !spot_format ["hoa"; "lbtt"]) then fail "unknown Spot format %s (hoa, lbtt)" !spot_format;
  if not (List.mem !spot_level ["auto"; "small"; "high"; "medium"; "low"; "any"]) then
    fail "unknown Spot level %s (auto, small, high, medium, low, any)" !spot_level;
  if !spot_level <> "auto" then
    Option.get (spot_once !spot_level ltl_text None)
  else
    match spot_once "low" ltl_text (Some !spot_budget) with
    | Some r -> r
    | None ->
      log "Spot (low) did not finish in %g s: falling back to the simplified formula and level any" !spot_budget;
      spot_fallback_used := true;
      Option.get (spot_once ~extra:"ba-simul=0" "any" (simplified ()) None)

(* The Spot automaton as a propositional Buchi automaton of the Coq
   development.  With state-based output (-B), the marked transitions are
   the transitions leaving accepting states; otherwise, states are
   duplicated according to the mark of the entering transition. *)
let to_pbuchi (a : Lbtt_read.automaton) (atom_of : string -> latom) : pBuchi =
  let open Lbtt_read in
  let lits c = List.map (fun (s, b) -> (atom_of s, b)) c in
  let srcs = List.sort_uniq compare (List.map (fun t -> t.src) a.trans) in
  let state_based =
    (not a.trans_based) ||
    List.for_all (fun s ->
        let ts = List.filter (fun t -> t.src = s) a.trans in
        List.for_all (fun t -> t.marked) ts || not (List.exists (fun t -> t.marked) ts)) srcs in
  if state_based then
    let acc = if a.trans_based
      then List.sort_uniq compare (List.filter_map (fun t -> if t.marked then Some t.src else None) a.trans)
      else a.accepting in
    { pb_nstates = a.nstates; pb_init = a.init; pb_accepting = acc;
      pb_trans = List.concat_map (fun t ->
          List.map (fun c -> { pt_src = t.src; pt_label = lits c; pt_tgt = t.dst }) t.cubes)
          a.trans }
  else
    let n = a.nstates in
    { pb_nstates = 2 * n; pb_init = a.init; pb_accepting = List.init n (fun s -> s + n);
      pb_trans = List.concat_map (fun t ->
          let dst = if t.marked then t.dst + n else t.dst in
          List.concat_map (fun src ->
              List.map (fun c -> { pt_src = src; pt_label = lits c; pt_tgt = dst }) t.cubes)
            [ t.src; t.src + n ]) a.trans }

(* ------------------------------------------------------------------ *)
(* Main                                                                *)

let size_tba (a : tBA) =
  let locs = Output.reachable a.tba_init (fun s ->
      List.filter_map (fun t -> if t.bt_source = s then Some t.bt_target else None)
        a.tba_transitions) in
  let trs = List.filter (fun t -> List.mem t.bt_source locs) a.tba_transitions in
  let clks = List.sort_uniq compare
      (List.concat_map (fun t ->
           t.bt_resets @ List.filter_map (Option.map (fun k -> k.guard_clock)) t.bt_guard) trs) in
  (List.length locs, List.length trs, List.length clks)

let () =
  Arg.parse speclist (fun s -> formula := s) usage;
  if !formula = "" then (Arg.usage speclist usage; exit 1);
  (* 1-2 *)
  let t_start = Unix.gettimeofday () in
  let f = parse_formula !formula in
  let f = if !with_init then Mtl2mtl.add_init (Mtl.push_neg f) else f in
  log "formula: %s" (Format.asprintf "%a" Mtl.pp_mtl f);
  List.iter (fun e -> ignore (event e)) (Mtl.get_evts f);
  let root = conv f in
  if not (well_formed root) then
    fail "the formula is not well formed (bounds [<0] and [>0] are not allowed)";
  (* proved rewriting of the lower bounds under []<> and <>[]
     (Coq: recur_correct, MTL_to_exported_correct0_recur_weak_with) *)
  let root = if !recur_on then recur root else root in
  let clocks = clocks_of root in
  let nm a = atom_name clocks a in
  log "clocks: %s" (String.concat ", " (List.mapi (fun i _ -> "x" ^ string_of_int i) clocks));
  (* 3 *)
  let ltl = t root in
  (* proved simplification (Coq: ltl_simp_correct); the atoms of T f are kept
     in atom_tbl, a superset of those of the simplified formula *)
  (* proved rewriting into a weak until (Coq: MTL_to_exported_correct_weak_with) *)
  let ltl_sent = if !weak_until then weak root ltl else ltl in
  let ltl_sent = if !simp then ltl_simp root ltl_sent else ltl_sent in
  let ltl_text = spot_formula nm ltl_sent in
  log "clocked LTL: %s" ltl_text;
  let atom_tbl = Hashtbl.create 16 in
  List.iter (fun a -> Hashtbl.replace atom_tbl (nm a) a) (ltl_atoms root ltl);
  (* with -explicit-neg Spot sees !e as the negation of the atom e, which
     may then occur in its output although only !e occurs in T f *)
  if !explicit_neg then
    List.iter (function
        | LNAct e ->
          let n = Hashtbl.find event_names e in
          if not (Hashtbl.mem atom_tbl n) then Hashtbl.replace atom_tbl n (LAct e)
        | _ -> ()) (ltl_atoms root ltl);
  let atom_of s = match Hashtbl.find_opt atom_tbl s with
    | Some a -> a | None -> fail "unknown atom %S in the output of Spot" s in
  (* 4 *)
  let t_spot0 = Unix.gettimeofday () in
  let ltl_simplified () = if !simp then ltl_text else spot_formula nm (ltl_simp root ltl_sent) in
  let spot_text = run_spot ltl_text ltl_simplified in
  let lbtt = if !spot_format = "lbtt" then Lbtt_read.parse spot_text
    else Lbtt_read.parse_hoa spot_text in
  (* the formula Spot translated, for the check files below *)
  let ltl_sent = if !spot_fallback_used && not !simp then ltl_simp root ltl_sent else ltl_sent in
  let t_spot = Unix.gettimeofday () -. t_spot0 in
  log "Spot: %d states, %d transitions" lbtt.Lbtt_read.nstates
    (List.length lbtt.Lbtt_read.trans);
  let ba = to_pbuchi lbtt atom_of in
  if !check <> "" then begin
    Out_channel.with_open_bin (!check ^ "_ltl.lbt") (fun oc ->
        output_string oc (lbt_formula nm ltl_sent);
        output_string oc "\n");
    Out_channel.with_open_bin (!check ^ "_ba.hoa") (fun oc ->
        output_string oc (hoa_of_pbuchi nm ba))
  end;
  (* 5 *)
  let tba = compile_with_fast root ba in
  let (s0, t0, c0) = size_tba tba in
    log "after reset completion: %d locations, %d transitions" s0 t0;
  if !compile_only then begin
    let names = {
      Output.clock_name = clock_name clocks;
      event_name = (fun a -> Hashtbl.find event_names a);
      events = List.sort compare (Hashtbl.fold (fun _ i l -> i :: l) event_tbl []);
    } in
    if !dump_tba then
      Out_channel.with_open_bin (!out ^ "_tba.dot")
        (fun oc -> Output.dot_tba oc names tba);
    let total = Unix.gettimeofday () -. t_start in
    if !stats then
      print_endline (String.concat "\t"
        (List.map string_of_int
           [ List.length clocks; lbtt.Lbtt_read.nstates;
             List.fold_left (fun n t -> n + List.length t.Lbtt_read.cubes) 0
               lbtt.Lbtt_read.trans ]
         @ [ Printf.sprintf "%.3f" t_spot ]
         @ List.map string_of_int [ s0; t0; c0 ]
         @ [ Printf.sprintf "%.3f" total ]))
    else
      Printf.printf "%s: compile(f): %d locations, %d transitions, %d clocks\n"
        !formula s0 t0 c0;
    exit 0
  end;
  (* 6 *)
  (* rounds until nothing changes, at most !rounds *)
  let rec fix k a =
    if k >= !rounds then (k, a, false)
    else
      let a' = optimize root 1 a in
      if a' = a then (k, a, true) else fix (k + 1) a' in
  let t_opt0 = Unix.gettimeofday () in
  let (k, opt, stable) = fix 0 tba in
  let t_opt = Unix.gettimeofday () -. t_opt0 in
  if not stable && !rounds > 0 then
    prerr_endline
      "warning: optimization round cap reached; structural stability beyond the cap was not checked";
  let opt =
    if not !prune_on then opt
    else begin
      let (_, pre, _) = size_tba opt in
      let opt = if !prune_split then split_cells root opt else opt in
      let (_, post_split, _) = size_tba opt in
      let (s, l, l2, kp) = Prune.certify root opt in
      log "dominated-transition pruning: certificate accepted by the checker: %b" (prune_ok root s l l2 kp opt);
      let opt = prune_pass root (fun _ -> (((s, l), l2), kp)) opt in
      let (_, fin, _) = size_tba opt in
      Printf.eprintf "PRUNESTATS	%d	%d	%d	%d
" pre post_split (post_split - fin) fin;
      opt
    end in
  let opt =
    if not !alloc_on then opt
    else begin
      let (al, lv) = Alloc.certify_gen !alloc_fuzz root opt in
      let ok = alloc_ok root al lv opt in
      log "clock allocation: certificate accepted by the checker: %b" ok;
      if !alloc_unchecked then allocate_clocks root al opt
      else alloc_pass root (fun _ -> (al, lv)) opt
    end in
  let (s1, t1, c1) = size_tba opt in
  log "after %d optimization rounds: %d locations, %d transitions" k s1 t1;
  (* 7 *)
  let t_exp0 = Unix.gettimeofday () in
  let d = if !all_copy_export then export_all root opt else export root opt in
  let t_exp = Unix.gettimeofday () -. t_exp0 in
  (* verified check of Coq theorem init_free_accepts0: no clock is read
     before its first reset, so that the automaton accepts the same words
     when every clock starts at 0 at time 0, as in UPPAAL *)
  let t_free0 = Unix.gettimeofday () in
  let free = init_free root d in
  log "initial-value check (init_free): %b, %.3f s" free (Unix.gettimeofday () -. t_free0);
  (* 8 *)
  let names = {
    Output.clock_name = clock_name clocks;
    event_name = (fun a -> Hashtbl.find event_names a);
    events = List.sort compare (Hashtbl.fold (fun _ i l -> i :: l) event_tbl []);
  } in
  let write file pr = Out_channel.with_open_bin file (fun oc -> pr oc) in
  write (!out ^ ".xml") (fun oc -> Output.uppaal_dta oc names d);
  (* symbolic automaton (Coq: symbolic, MTL_to_symbolic_correct_with) for the
     drawing; the UPPAAL model keeps one edge per event and conjunctive guards *)
  let sd = symbolic root d in
  write (!out ^ ".dot") (fun oc -> Output.dot_sdta oc names sd);
  (* Graphviz: <base>.dot -> <base>.pdf *)
  let to_pdf base =
    let cmd = Printf.sprintf "%s -Tpdf %s -o %s" !dot_cmd
        (Filename.quote (base ^ ".dot")) (Filename.quote (base ^ ".pdf")) in
    log "command: %s" cmd;
    if Sys.command cmd <> 0 then
      prerr_endline ("mtl2tba: warning: the command " ^ !dot_cmd ^ " failed, no pdf produced") in
  if !dump_tba then begin
    write (!out ^ "_tba.dot") (fun oc -> Output.dot_tba oc names tba);
    write (!out ^ "_opt.dot") (fun oc -> Output.dot_tba oc names opt);
    if !pdf then (to_pdf (!out ^ "_tba"); to_pdf (!out ^ "_opt"))
  end;
  if !pdf then to_pdf !out;
  let locs = Output.dta_locations d in
  let dtrs = List.filter (fun t -> List.mem t.dt_src locs) d.dta_trans in
  let ninv = List.length (List.filter (fun s -> Output.invariant_s names " && " d s <> None) locs) in
  let ndiff = List.fold_left (fun n t ->
      n + List.length (List.filter (function DDiff _ -> true | _ -> false) (List.concat t.dt_guard)))
      0 dtrs in
  let nclk = List.length (Output.used_clocks d locs) in
  if !stats then
    print_endline (String.concat "	" (List.map string_of_int
      [ List.length clocks; lbtt.Lbtt_read.nstates;
        List.fold_left (fun n t -> n + List.length t.Lbtt_read.cubes) 0 lbtt.Lbtt_read.trans ]
      @ [ Printf.sprintf "%.3f" t_spot ]
      @ List.map string_of_int [ s0; t0; c0; k; s1; t1; c1;
                                 List.length locs; List.length dtrs; nclk; ninv; ndiff ]
      @ [ Printf.sprintf "%.3f" t_opt; Printf.sprintf "%.3f" t_exp;
          Printf.sprintf "%.3f" (Unix.gettimeofday () -. t_start);
          if free then "1" else "0";
          string_of_int (List.length (Output.sdta_reachable_trans sd)) ]))
  else
    Printf.printf "%s: %d clocks, %d locations, %d transitions (%d symbolic) -> %s.xml, %s.dot%s
"
      !formula nclk (List.length locs) (List.length dtrs)
      (List.length (Output.sdta_reachable_trans sd)) !out !out
      (if !pdf then ", " ^ !out ^ ".pdf" else "");
  if not free && not !stats then
    prerr_endline "mtl2tba: warning: a clock may be read before its first reset; \
the result for clocks starting at 0 (as in UPPAAL) is not covered by \
theorem MTL_to_exported_correct0_with"

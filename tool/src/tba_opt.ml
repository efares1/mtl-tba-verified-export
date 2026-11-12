(* tba_opt: run the verified optimizer and exporter on a timed Buchi automaton
   read from a text file, instead of one produced by the MTL front end.
   Only the reader below is hand-written; the passes are the extracted ones
   (Optim.optimize, Optim.export, Optim.init_free), as in mtl2tba.

   Input format (lines; '#' starts a comment):
     events p q r            event names; the event with name i-th is atom i
     clocks 3                number of clocks
     init 0
     states 12
     acc 3 5 7               accepting locations
     t SRC DST | 0+ 1- | 0<=5 1>2 | 0 1
       label literals "<event><+|->", guard atoms "<clock><op><bound>",
       clocks reset; the three fields may be empty.
   Clocks are given distinct formulas (the passes use them as names). *)
open Optim

let out = ref "out"
let rounds = ref 50
let all_copy = ref false
let stats = ref false
let prune = ref false
let prune_split = ref false
let file = ref ""
let speclist = [
  ("-o", Arg.Set_string out, "<base> output files <base>.xml and <base>.dot");
  ("-n", Arg.Set_int rounds, "<n> maximal number of optimization rounds (0: none)");
  ("-all-copy", Arg.Set all_copy, " all-copy invariant split");
  ("-prune-eq", Arg.Set Prune.eq_only, " with -prune: ablation, the certifier demands equality of every clock read by a guard (no ordered clocks)");
  ("-prune-split", Arg.Unit (fun () -> prune := true; prune_split := true), " like -prune, after splitting every transition by cells of letters (verified, split_cells_accepts)");
  ("-prune", Arg.Set prune, " drop dominated transitions (verified checker Optim.prune_ok)");
  ("-stats", Arg.Set stats, " one tab-separated line of measures");
]

let fail fmt = Printf.ksprintf (fun s -> prerr_endline ("tba_opt: " ^ s); exit 2) fmt
let split_on c s = List.filter (fun x -> x <> "") (String.split_on_char c s)
let words s = List.filter (fun x -> x <> "") (String.split_on_char ' ' (String.trim s))

let () =
  Arg.parse speclist (fun s -> file := s) "tba_opt [options] file.tba";
  if !file = "" then fail "no input file";
  let lines = In_channel.with_open_bin !file In_channel.input_all |> String.split_on_char '\n' in
  let evs = ref [] and ncl = ref 0 and init = ref 0 and nst = ref 0 and acc = ref [] and trs = ref [] in
  List.iter (fun l ->
      let l = match String.index_opt l '#' with Some i -> String.sub l 0 i | None -> l in
      let l = String.trim l in
      if l <> "" then
        match words l with
        | "events" :: r -> evs := r
        | ["clocks"; n] -> ncl := int_of_string n
        | ["init"; n] -> init := int_of_string n
        | ["states"; n] -> nst := int_of_string n
        | "acc" :: r -> acc := List.map int_of_string r
        | "t" :: _ ->
          let body = String.sub l 1 (String.length l - 1) in
          (match String.split_on_char '|' body with
           | [a; b; c; d] -> trs := (words a, words b, words c, words d) :: !trs
           | _ -> fail "bad transition line: %s" l)
        | _ -> fail "bad line: %s" l) lines;
  (* clocks as distinct formulas *)
  let clocks = List.init !ncl (fun i -> MUhatLe (float_of_int (i + 1), MAtom 0, MAtom 1)) in
  let root = match clocks with
    | [] -> MAtom 0
    | c :: r -> List.fold_left (fun a b -> MAnd (a, b)) c r in
  let clk i = List.nth clocks i in
  let cmp = function
    | "<=" -> CLe | "<" -> CLt | ">=" -> CGe | ">" -> CGt | "==" | "=" -> CEq
    | s -> fail "operator %s" s in
  let parse_guard s =
    (* <clock><op><bound>, op among <= < >= > == *)
    let n = String.length s in
    let i = ref 0 in
    while !i < n && (s.[!i] <> '<' && s.[!i] <> '>' && s.[!i] <> '=') do incr i done;
    let j = ref !i in
    while !j < n && (s.[!j] = '<' || s.[!j] = '>' || s.[!j] = '=') do incr j done;
    Some { guard_clock = clk (int_of_string (String.sub s 0 !i));
           guard_comparison = cmp (String.sub s !i (!j - !i));
           guard_bound = float_of_string (String.sub s !j (n - !j)) } in
  let parse_lit s =
    let n = String.length s in
    (int_of_string (String.sub s 0 (n - 1)), s.[n - 1] = '+') in
  let tba = {
    tba_nstates = !nst; tba_init = !init; tba_accepting = !acc;
    tba_transitions = List.rev_map (fun (src_dst, lab, gd, rs) ->
        match src_dst with
        | [s; d] ->
          { bt_source = int_of_string s; bt_target = int_of_string d;
            bt_label = List.map parse_lit lab;
            bt_guard = List.map parse_guard gd;
            bt_resets = List.map (fun r -> clk (int_of_string r)) rs }
        | _ -> fail "source and target expected") !trs } in
  let size_tba (a : tBA) =
    let locs = Output.reachable a.tba_init (fun s ->
        List.filter_map (fun t -> if t.bt_source = s then Some t.bt_target else None) a.tba_transitions) in
    let trs = List.filter (fun t -> List.mem t.bt_source locs) a.tba_transitions in
    let clks = List.sort_uniq compare
        (List.concat_map (fun t ->
             t.bt_resets @ List.filter_map (Option.map (fun k -> k.guard_clock)) t.bt_guard) trs) in
    (List.length locs, List.length trs, List.length clks) in
  let t0 = Unix.gettimeofday () in
  let (s0, t0n, c0) = size_tba tba in
  let rec fix k a =
    if k >= !rounds then (k, a)
    else let a' = optimize root 1 a in if a' = a then (k, a) else fix (k + 1) a' in
  let (k, opt) = fix 0 tba in
  let opt =
    if not !prune then opt
    else begin
      let tm = Unix.gettimeofday () in
      let opt = if !prune_split then split_cells root opt else opt in
      let (s, l, l2, kp) = Prune.certify root opt in
      Printf.eprintf "prune: certificate computed in %.2fs
%!" (Unix.gettimeofday () -. tm);
      let tm = Unix.gettimeofday () in
      let okc = prune_ok root s l l2 kp opt in
      Printf.eprintf "prune: certificate accepted by the checker: %b (%.2fs)
%!" okc (Unix.gettimeofday () -. tm);
      let r = prune_pass root (fun _ -> (((s, l), l2), kp)) opt in
      Printf.eprintf "prune: pass done (%.2fs)
%!" (Unix.gettimeofday () -. tm);
      r
    end in
  let (s1, t1, c1) = size_tba opt in
  let t_opt = Unix.gettimeofday () -. t0 in
  let d = if !all_copy then export_all root opt else export root opt in
  let free = init_free root d in
  let names = {
    Output.clock_name = (fun x ->
        let rec idx i = function [] -> "x?" | y :: l -> if y = x then "x" ^ string_of_int i else idx (i + 1) l in
        idx 0 clocks);
    event_name = (fun a -> List.nth !evs a);
    events = List.init (List.length !evs) (fun i -> i);
  } in
  let write f pr = Out_channel.with_open_bin f (fun oc -> pr oc) in
  write (!out ^ ".xml") (fun oc -> Output.uppaal_dta oc names d);
  let sd = symbolic root d in
  write (!out ^ ".dot") (fun oc -> Output.dot_sdta oc names sd);
  let locs = Output.dta_locations d in
  let dtrs = List.filter (fun t -> List.mem t.dt_src locs) d.dta_trans in
  let ndiff = List.fold_left (fun n t ->
      n + List.length (List.filter (function DDiff _ -> true | _ -> false) (List.concat t.dt_guard))) 0 dtrs in
  let sym = List.length (Output.sdta_reachable_trans sd) in
  if !stats then
    print_endline (String.concat "\t" (List.map string_of_int
      [ s0; t0n; c0; k; s1; t1; c1; List.length locs; List.length dtrs; ndiff; sym; (if free then 1 else 0) ]))
  else
    Printf.printf "tba %d/%d/%d -> opt %d/%d/%d (%d rounds) -> %d locations, %d transitions (%d symbolic), %d diagonal, init_free %b\n"
      s0 t0n c0 s1 t1 c1 k (List.length locs) (List.length dtrs) sym ndiff free

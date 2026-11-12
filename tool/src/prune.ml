(* Certificate producer for the verified dominated-transition pass (Coq:
   MTL_to_TBA_DomPrune.v, prune_pass / prune_pass_accepts).

   This code is NOT verified and does not need to be: Optim.prune_pass runs the
   proved boolean checker Optim.prune_ok on the result and returns the
   automaton unchanged when the check fails.  What it computes:

     live, lle the clocks read before being reset, by lower bounds and
               equalities (live) and by any guard (lle);
     sim       the greatest relation S on locations such that (q1,q2) is in S
               when q2 accepting implies q1 accepting and every transition t2
               out of q2 has a transition t1 out of q1 that Optim.dom_step
               accepts, with (target t1, target t2) in S;
     keep      transitions are scanned in order and a transition is dropped
               when another kept transition from the same location dominates it
               under S; S is then recomputed with the kept transitions only.
   If the recomputed relation no longer contains (init, init), nothing is
   dropped. *)
open Optim

(* clocks read before being reset: with [eq_only] only by lower bounds and equalities *)
let liveness (root : mtl) (a : tBA) (eq_only : bool) : int -> clock list =
  let trs = a.tba_transitions in
  let nst = List.fold_left (fun n t -> max n (max t.bt_source t.bt_target + 1))
      (max a.tba_nstates (a.tba_init + 1)) trs in
  let cl = ref [] in
  let id x =
    let rec find i = function
      | [] -> cl := !cl @ [ x ]; i
      | y :: r -> if clock_eq_dec root x y then i else find (i + 1) r in
    find 0 !cl in
  let reads t =
    List.filter_map (function
        | Some k when (not eq_only) || not (upper_cmp k.guard_comparison) -> Some (id k.guard_clock)
        | _ -> None) t.bt_guard in
  let tr = List.map (fun t -> (t.bt_source, t.bt_target, reads t, List.map id t.bt_resets)) trs in
  let n = List.length !cl in
  let clocks = Array.of_list !cl in
  let live = Array.init nst (fun _ -> Array.make (max n 1) false) in
  let changed = ref true in
  while !changed do
    changed := false;
    List.iter (fun (s, d, g, r) ->
        List.iter (fun c -> if not live.(s).(c) then (live.(s).(c) <- true; changed := true)) g;
        for c = 0 to n - 1 do
          if live.(d).(c) && not (List.mem c r) && not live.(s).(c) then
            (live.(s).(c) <- true; changed := true)
        done) tr
  done;
  let memo = Array.init nst (fun s ->
      List.filter_map (fun c -> if live.(s).(c) then Some clocks.(c) else None) (List.init n (fun c -> c))) in
  fun s -> if s < 0 || s >= nst then [] else memo.(s)

(* ablation: demand equality of every clock read by any guard (no ordered clocks) *)
let eq_only : bool ref = ref false

let certify (root : mtl) (a : tBA)
  : (int -> int -> bool) * (int -> clock list) * (int -> clock list) * (tba_transition -> bool) =
  let n = max a.tba_nstates (a.tba_init + 1) in
  let lle = liveness root a false in
  let livef = if !eq_only then lle else liveness root a true in
  let trs = a.tba_transitions in
  let by_src = Array.make n [] in
  List.iter (fun t -> if t.bt_source < n then by_src.(t.bt_source) <- t :: by_src.(t.bt_source)) (List.rev trs);
  let acc = Array.make n false in
  List.iter (fun q -> if q < n then acc.(q) <- true) a.tba_accepting;
  let cs = cells root a in
  let gfp (keep : tba_transition -> bool) : bool array array =
    let s = Array.init n (fun q1 -> Array.init n (fun q2 -> (not acc.(q2)) || acc.(q1))) in
    let simf q1 q2 = q1 >= 0 && q1 < n && q2 >= 0 && q2 < n && s.(q1).(q2) in
    let changed = ref true in
    while !changed do
      changed := false;
      for q1 = 0 to n - 1 do
        for q2 = 0 to n - 1 do
          if s.(q1).(q2) then begin
            let ok = List.for_all (fun c ->
                List.for_all (fun t2 ->
                    (not (label_at c t2.bt_label)) ||
                    List.exists (fun t1 -> dom_step root simf livef lle keep a q1 c t2 t1) by_src.(q1))
                  by_src.(q2)) cs in
            if not ok then (s.(q1).(q2) <- false; changed := true)
          end
        done
      done
    done;
    s in
  let tm0 = Unix.gettimeofday () in
  let dbg = Sys.getenv_opt "PRUNE_TIME" <> None in
  if dbg then Printf.eprintf "certify: n=%d trans=%d cells=%d
%!" n (List.length trs) (List.length cs);
  let all_keep _ = true in
  let s_all = gfp all_keep in
  if dbg then Printf.eprintf "certify: gfp all %.1fs
%!" (Unix.gettimeofday () -. tm0);
  let simf_all q1 q2 = q1 >= 0 && q1 < n && q2 >= 0 && q2 < n && s_all.(q1).(q2) in
  (* greedy choice of the transitions to drop *)
  let removed : (tba_transition, unit) Hashtbl.t = Hashtbl.create 1024 in
  let keep_now t = not (Hashtbl.mem removed t) in
  List.iter (fun t2 ->
      let q = t2.bt_source in
      if q >= 0 && q < n && keep_now t2 then begin
        let dominated =
          List.for_all (fun c ->
              (not (label_at c t2.bt_label)) ||
              List.exists (fun t1 ->
                  t1 <> t2 && keep_now t1 &&
                  dom_step root simf_all livef lle keep_now a q c t2 t1) by_src.(q)) cs in
        if dominated then Hashtbl.replace removed t2 ()
      end) trs;
  if dbg then Printf.eprintf "certify: greedy %.1fs removed %d
%!" (Unix.gettimeofday () -. tm0) (Hashtbl.length removed);
  let keep t = not (Hashtbl.mem removed t) in
  let s_kept = gfp keep in
  if Sys.getenv_opt "PRUNE_DEBUG" <> None then begin
    let pl t = Printf.sprintf "%d->%d [%s] g%d r%d" t.bt_source t.bt_target
        (String.concat "," (List.map (fun (a, b) -> Printf.sprintf "%d%s" a (if b then "+" else "-")) t.bt_label))
        (List.length t.bt_guard) (List.length t.bt_resets) in
    for q = 0 to n - 1 do
      Printf.eprintf "loc %d: live=%d lle=%d\n" q (List.length (livef q)) (List.length (lle q))
    done;
    Printf.eprintf "sim pairs kept: %d
" (Array.fold_left (fun k r -> Array.fold_left (fun k b -> if b then k + 1 else k) k r) 0 s_kept);
    List.iter (fun c ->
        for q = 0 to n - 1 do
          let es = List.filter (fun t -> keep t && label_at c t.bt_label) by_src.(q) in
          if List.length es >= 2 then begin
            Printf.eprintf "cell %s loc %d:
" (match c with None -> "other" | Some a -> string_of_int a) q;
            List.iter (fun t -> Printf.eprintf "   %s  sim(t,.)=%s
" (pl t)
              (String.concat "" (List.map (fun t2 -> if t2 == t then "." else if s_kept.(t.bt_target).(t2.bt_target) then "1" else "0") es))) es
          end
        done) cs
  end;
  if s_kept.(a.tba_init).(a.tba_init) then
    ((fun q1 q2 -> q1 >= 0 && q1 < n && q2 >= 0 && q2 < n && s_kept.(q1).(q2)), livef, lle, keep)
  else
    (simf_all, livef, lle, all_keep)

(* Certificate producer for the verified clock-allocation pass (Coq:
   MTL_to_TBA_ClockAlloc.v, alloc_pass / alloc_pass_accepts).

   This code is NOT verified and does not need to be: Optim.alloc_pass runs
   the proved boolean checker Optim.alloc_ok on the result and returns the
   automaton unchanged when the check fails, so the language is preserved
   whatever this function returns.  What it computes:

     live(q)   clocks that may be read before being reset on a path from q:
               the least sets with  guard_clocks(t) <= live(source t)  and
               live(target t) \ resets(t) <= live(source t);
     graph     r -- y  when t resets r and y is in live(target t), and for
               every pair of clocks in live(init);
     colours   greedy DSATUR colouring of the graph;
     alloc     each clock goes to the first clock of its colour.

   A clock that is never read keeps an empty live set and its resets are
   merged with those of its class, which is harmless. *)
open Optim

let certify_gen (fuzz : int) (root : mtl) (a : tBA) : (clock -> clock) * (int -> clock list) =
  let trs = a.tba_transitions in
  let nst =
    List.fold_left (fun n t -> max n (max t.bt_source t.bt_target + 1))
      (max a.tba_nstates (a.tba_init + 1)) trs in
  (* clocks occurring in the automaton, numbered *)
  let cl = ref [] in
  let id x =
    let rec find i = function
      | [] -> cl := !cl @ [ x ]; i
      | y :: r -> if clock_eq_dec root x y then i else find (i + 1) r in
    find 0 !cl in
  let gcl t = List.filter_map (Option.map (fun k -> id k.guard_clock)) t.bt_guard in
  let rst t = List.map id t.bt_resets in
  let tr = List.map (fun t -> (t.bt_source, t.bt_target, gcl t, rst t)) trs in
  let n = List.length !cl in
  let clocks = Array.of_list !cl in
  if n = 0 then ((fun x -> x), (fun _ -> []))
  else begin
    let live = Array.init nst (fun _ -> Array.make n false) in
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
    let adj = Array.make_matrix n n false in
    let link x y = if x <> y then (adj.(x).(y) <- true; adj.(y).(x) <- true) in
    List.iter (fun (_, d, _, r) ->
        List.iter (fun x -> for y = 0 to n - 1 do if live.(d).(y) then link x y done) r) tr;
    for x = 0 to n - 1 do
      for y = 0 to n - 1 do
        if live.(a.tba_init).(x) && live.(a.tba_init).(y) then link x y
      done
    done;
    (* DSATUR *)
    let col = Array.make n (-1) in
    for _ = 1 to n do
      let sat c =
        let s = ref [] in
        for y = 0 to n - 1 do
          if adj.(c).(y) && col.(y) >= 0 && not (List.mem col.(y) !s) then s := col.(y) :: !s
        done; !s in
      let deg c = Array.fold_left (fun k b -> if b then k + 1 else k) 0 adj.(c) in
      let best = ref (-1) and key = ref (-1, -1) in
      for c = 0 to n - 1 do
        if col.(c) < 0 then begin
          let k = (List.length (sat c), deg c) in
          if !best < 0 || k > !key then (best := c; key := k)
        end
      done;
      let used = sat !best in
      let k = ref 0 in
      while List.mem !k used do incr k done;
      col.(!best) <- !k
    done;
    let rep = Array.make n 0 in
    for c = 0 to n - 1 do
      let r = ref c in
      (try for y = 0 to c - 1 do if col.(y) = col.(c) then (r := y; raise Exit) done
       with Exit -> ());
      rep.(c) <- !r
    done;
    (* FUZZ (testing of the checker only): replace the allocation by a random one over the same clocks *)
    if fuzz <> 0 then begin
      let st = Random.State.make [| fuzz |] in
      for c = 0 to n - 1 do rep.(c) <- Random.State.int st n done
    end;
    let alloc x =
      let rec find i =
        if i >= n then x else if clock_eq_dec root x clocks.(i) then clocks.(rep.(i)) else find (i + 1) in
      find 0 in
    let livef s =
      if s < 0 || s >= nst then []
      else List.filter_map (fun c -> if live.(s).(c) then Some clocks.(c) else None)
          (List.init n (fun c -> c)) in
    (alloc, livef)
  end

let certify root a = certify_gen 0 root a

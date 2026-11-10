let timed name f x =
  let t0 = Unix.gettimeofday () in
  let r = f x in
  Printf.eprintf "PASS %-22s %8.3f s\n%!" name (Unix.gettimeofday () -. t0);
  r

let optimize_step root a =
  let a = timed "propagate_fast" (propagate_fast root) a in
  let a = timed "forward_fast" (forward_fast root) a in
  let a = timed "remove_contradictory" (remove_contradictory root) a in
  let a = timed "remove_unsat" (remove_unsat root) a in
  let a = timed "remove_unreachable" (remove_unreachable root) a in
  let a = timed "normalize(1)" (normalize root) a in
  let a = timed "remove_dead_resets" (remove_dead_resets root) a in
  let a = timed "merge_all" (merge_all root) a in
  let a = timed "normalize(2)" (normalize root) a in
  let a = timed "merge_trans" (merge_trans root) a in
  timed "merge_states_all" (merge_states_all root) a

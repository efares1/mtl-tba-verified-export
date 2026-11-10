let timed_e name f x =
  let t0 = Unix.gettimeofday () in
  let r = f x in
  Printf.eprintf "EXPORT %-18s %8.3f s\n%!" name (Unix.gettimeofday () -. t0);
  r

let export root a =
  let d = timed_e "of_tba" (of_tba root) a in
  let d = timed_e "merge_transitions" (merge_transitions root) d in
  let d = timed_e "normalize_d(1)" (normalize_d root) d in
  let d = timed_e "split" (split root) d in
  let d = timed_e "normalize_d(2)" (normalize_d root) d in
  let d = timed_e "explode_all" (explode_all root) d in
  let d = timed_e "dprune_all" (dprune_all root) d in
  timed_e "dmerge_states_all" (dmerge_states_all root) d

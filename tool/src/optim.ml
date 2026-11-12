(** val implb : bool -> bool -> bool **)

let implb b1 b2 =
  if b1 then b2 else true

(** val xorb : bool -> bool -> bool **)

let xorb b1 b2 =
  if b1 then if b2 then false else true else b2

(** val remove : ('a1 -> 'a1 -> bool) -> 'a1 -> 'a1 list -> 'a1 list **)

let rec remove eq_dec x = function
| [] -> []
| y :: tl ->
  if eq_dec x y then remove eq_dec x tl else y :: (remove eq_dec x tl)

(** val fold_left : ('a1 -> 'a2 -> 'a1) -> 'a2 list -> 'a1 -> 'a1 **)

let rec fold_left f l a0 =
  match l with
  | [] -> a0
  | b :: t0 -> fold_left f t0 (f a0 b)

(** val find : ('a1 -> bool) -> 'a1 list -> 'a1 option **)

let rec find f = function
| [] -> None
| x :: tl -> if f x then Some x else find f tl

(** val nodup : ('a1 -> 'a1 -> bool) -> 'a1 list -> 'a1 list **)

let rec nodup decA = function
| [] -> []
| x :: xs ->
  if (fun eq a l -> List.exists (eq a) l) decA x xs
  then nodup decA xs
  else x :: (nodup decA xs)

type action = int

(** val left_path : path -> path **)

let left_path p =
  List.append p (false :: [])

(** val right_path : path -> path **)

let right_path p =
  List.append p (true :: [])

type mtl =
| MTrue
| MFalse
| MAtom of action
| MNotAtom of action
| MAnd of mtl * mtl
| MOr of mtl * mtl
| MNext of mtl
| MU of mtl * mtl
| MR of mtl * mtl
| MUhatLe of float * mtl * mtl
| MUhatGe of float * mtl * mtl
| MRhatLe of float * mtl * mtl
| MRhatGe of float * mtl * mtl
| MUhatLt of float * mtl * mtl
| MUhatGt of float * mtl * mtl
| MRhatLt of float * mtl * mtl
| MRhatGt of float * mtl * mtl

(** val mUle : float -> mtl -> mtl -> mtl **)

let mUle d p q0 =
  MOr (q0, (MAnd (p, (MUhatLe (d, p, q0)))))

(** val mUge : float -> mtl -> mtl -> mtl **)

let mUge d p q0 =
  MAnd (p, (MUhatGe (d, p, q0)))

(** val mRle : float -> mtl -> mtl -> mtl **)

let mRle d p q0 =
  MAnd (q0, (MOr (p, (MRhatLe (d, p, q0)))))

(** val mRge : float -> mtl -> mtl -> mtl **)

let mRge d p q0 =
  MOr (p, (MRhatGe (d, p, q0)))

(** val mUlt : float -> mtl -> mtl -> mtl **)

let mUlt d p q0 =
  MOr (q0, (MAnd (p, (MUhatLt (d, p, q0)))))

(** val mUgt : float -> mtl -> mtl -> mtl **)

let mUgt d p q0 =
  MAnd (p, (MUhatGt (d, p, q0)))

(** val mRlt : float -> mtl -> mtl -> mtl **)

let mRlt d p q0 =
  MAnd (q0, (MOr (p, (MRhatLt (d, p, q0)))))

(** val mRgt : float -> mtl -> mtl -> mtl **)

let mRgt d p q0 =
  MOr (p, (MRhatGt (d, p, q0)))

(** val timed_subformulas : mtl -> mtl list **)

let rec timed_subformulas f = match f with
| MAnd (p, q0) -> List.append (timed_subformulas p) (timed_subformulas q0)
| MOr (p, q0) -> List.append (timed_subformulas p) (timed_subformulas q0)
| MNext p -> timed_subformulas p
| MU (p, q0) -> List.append (timed_subformulas p) (timed_subformulas q0)
| MR (p, q0) -> List.append (timed_subformulas p) (timed_subformulas q0)
| MUhatLe (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| MUhatGe (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| MRhatLe (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| MRhatGe (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| MUhatLt (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| MUhatGt (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| MRhatLt (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| MRhatGt (_, p, q0) ->
  f :: (List.append (timed_subformulas p) (timed_subformulas q0))
| _ -> []

(** val mtl_eq_dec : mtl -> mtl -> bool **)

let rec mtl_eq_dec m x =
  match m with
  | MTrue -> (match x with
              | MTrue -> true
              | _ -> false)
  | MFalse -> (match x with
               | MFalse -> true
               | _ -> false)
  | MAtom a -> (match x with
                | MAtom a0 -> (=) a a0
                | _ -> false)
  | MNotAtom a -> (match x with
                   | MNotAtom a0 -> (=) a a0
                   | _ -> false)
  | MAnd (m0, m1) ->
    (match x with
     | MAnd (m2, m3) -> if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
     | _ -> false)
  | MOr (m0, m1) ->
    (match x with
     | MOr (m2, m3) -> if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
     | _ -> false)
  | MNext m0 -> (match x with
                 | MNext m1 -> mtl_eq_dec m0 m1
                 | _ -> false)
  | MU (m0, m1) ->
    (match x with
     | MU (m2, m3) -> if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
     | _ -> false)
  | MR (m0, m1) ->
    (match x with
     | MR (m2, m3) -> if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
     | _ -> false)
  | MUhatLe (r, m0, m1) ->
    (match x with
     | MUhatLe (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)
  | MUhatGe (r, m0, m1) ->
    (match x with
     | MUhatGe (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)
  | MRhatLe (r, m0, m1) ->
    (match x with
     | MRhatLe (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)
  | MRhatGe (r, m0, m1) ->
    (match x with
     | MRhatGe (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)
  | MUhatLt (r, m0, m1) ->
    (match x with
     | MUhatLt (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)
  | MUhatGt (r, m0, m1) ->
    (match x with
     | MUhatGt (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)
  | MRhatLt (r, m0, m1) ->
    (match x with
     | MRhatLt (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)
  | MRhatGt (r, m0, m1) ->
    (match x with
     | MRhatGt (r0, m2, m3) ->
       if (=) r r0
       then if mtl_eq_dec m0 m2 then mtl_eq_dec m1 m3 else false
       else false
     | _ -> false)

type clock = mtl

(** val mk_clock : mtl -> mtl -> clock **)

let mk_clock _ f =
  f

(** val clock_eq_dec : mtl -> clock -> clock -> bool **)

let clock_eq_dec _ x y =
  mtl_eq_dec (let a = x in a) (let a = y in a)

(** val clock_of : mtl -> mtl -> clock option **)

let clock_of root f =
  if (fun eq a l -> List.exists (eq a) l) mtl_eq_dec f
       (timed_subformulas root)
  then Some (mk_clock root f)
  else None

type latom =
| LAct of action
| LNAct of action
| LCLe of clock * float
| LCLt of clock * float
| LCGe of clock * float
| LCGt of clock * float
| LRst of clock
| LUnch of clock

type ltl =
| LTrue
| LFalse
| LAtom of latom
| LAnd of ltl * ltl
| LOr of ltl * ltl
| LNext of ltl
| LUntil of ltl * ltl
| LRelease of ltl * ltl

(** val lF : mtl -> ltl -> ltl **)

let lF _ p =
  LUntil (LTrue, p)

(** val lG : mtl -> ltl -> ltl **)

let lG _ p =
  LRelease (LFalse, p)

(** val lW : mtl -> ltl -> ltl -> ltl **)

let lW root p q0 =
  LOr ((LUntil (p, q0)), (lG root p))

(** val lGF : mtl -> ltl -> ltl **)

let lGF root p =
  lG root (lF root p)

(** val t_at : mtl -> path -> mtl -> ltl **)

let rec t_at root path0 = function
| MTrue -> LTrue
| MFalse -> LFalse
| MAtom a -> LAtom (LAct a)
| MNotAtom a -> LAtom (LNAct a)
| MAnd (p, q0) ->
  LAnd ((t_at root (left_path path0) p), (t_at root (right_path path0) q0))
| MOr (p, q0) ->
  LOr ((t_at root (left_path path0) p), (t_at root (right_path path0) q0))
| MNext p -> LNext (t_at root (left_path path0) p)
| MU (p, q0) ->
  LUntil ((t_at root (left_path path0) p), (t_at root (right_path path0) q0))
| MR (p, q0) ->
  LRelease ((t_at root (left_path path0) p),
    (t_at root (right_path path0) q0))
| MUhatLe (d, p, q0) ->
  (match clock_of root (MUhatLe (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let c = LAtom (LCLe (x, d)) in
     let h = LAtom (LUnch x) in
     LNext (LUntil ((LAnd (c, (LAnd (h, a)))), (LAnd (c, b))))
   | None -> LFalse)
| MUhatGe (d, p, q0) ->
  (match clock_of root (MUhatGe (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let q1 = LAnd ((LAtom (LCGe (x, d))), (LUntil (a, b))) in
     let gamma = LOr ((LUntil (a, q1)), (LAnd ((lG root a), (lGF root b)))) in
     LAnd ((LAtom (LRst x)), (LNext gamma))
   | None -> LFalse)
| MRhatLe (d, p, q0) ->
  (match clock_of root (MRhatLe (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let d0 = LOr ((LAtom (LCGt (x, d))), (LAnd (a, b))) in
     LAnd ((LAtom (LRst x)), (LNext (lW root b d0)))
   | None -> LFalse)
| MRhatGe (d, p, q0) ->
  (match clock_of root (MRhatGe (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let e = LOr ((LRelease (a, b)), (LAnd ((LAtom (LCLt (x, d))), a))) in
     let k = LAnd ((LAtom (LCLt (x, d))), (LAtom (LUnch x))) in
     LNext (lW root k e)
   | None -> LFalse)
| MUhatLt (d, p, q0) ->
  (match clock_of root (MUhatLt (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let c = LAtom (LCLt (x, d)) in
     let h = LAtom (LUnch x) in
     LNext (LUntil ((LAnd (c, (LAnd (h, a)))), (LAnd (c, b))))
   | None -> LFalse)
| MUhatGt (d, p, q0) ->
  (match clock_of root (MUhatGt (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let q1 = LAnd ((LAtom (LCGt (x, d))), (LUntil (a, b))) in
     let gamma = LOr ((LUntil (a, q1)), (LAnd ((lG root a), (lGF root b)))) in
     LAnd ((LAtom (LRst x)), (LNext gamma))
   | None -> LFalse)
| MRhatLt (d, p, q0) ->
  (match clock_of root (MRhatLt (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let d0 = LOr ((LAtom (LCGe (x, d))), (LAnd (a, b))) in
     LAnd ((LAtom (LRst x)), (LNext (lW root b d0)))
   | None -> LFalse)
| MRhatGt (d, p, q0) ->
  (match clock_of root (MRhatGt (d, p, q0)) with
   | Some x ->
     let a = t_at root (left_path path0) p in
     let b = t_at root (right_path path0) q0 in
     let e = LOr ((LRelease (a, b)), (LAnd ((LAtom (LCLe (x, d))), a))) in
     let k = LAnd ((LAtom (LCLe (x, d))), (LAtom (LUnch x))) in
     LNext (lW root k e)
   | None -> LFalse)

type alit = action * bool

(** val ltl_atoms : mtl -> ltl -> latom list **)

let rec ltl_atoms root = function
| LAtom a -> a :: []
| LAnd (p, q0) -> List.append (ltl_atoms root p) (ltl_atoms root q0)
| LOr (p, q0) -> List.append (ltl_atoms root p) (ltl_atoms root q0)
| LNext p -> ltl_atoms root p
| LUntil (p, q0) -> List.append (ltl_atoms root p) (ltl_atoms root q0)
| LRelease (p, q0) -> List.append (ltl_atoms root p) (ltl_atoms root q0)
| _ -> []

type plit = latom * bool

type ptransition = { pt_src : int; pt_label : plit list; pt_tgt : int }

type pBuchi = { pb_nstates : int; pb_init : int; pb_trans : ptransition list;
                pb_accepting : int list }

type clock_comparison =
| CLe
| CLt
| CGe
| CGt
| CEq

type clock_constraint = { guard_clock : clock;
                          guard_comparison : clock_comparison;
                          guard_bound : float }

type guard = clock_constraint option list

(** val atom_to_guard : mtl -> latom -> clock_constraint option **)

let atom_to_guard _ = function
| LCLe (x, d) ->
  Some { guard_clock = x; guard_comparison = CLe; guard_bound = d }
| LCLt (x, d) ->
  Some { guard_clock = x; guard_comparison = CLt; guard_bound = d }
| LCGe (x, d) ->
  Some { guard_clock = x; guard_comparison = CGe; guard_bound = d }
| LCGt (x, d) ->
  Some { guard_clock = x; guard_comparison = CGt; guard_bound = d }
| _ -> None

type tba_transition = { bt_source : int; bt_label : alit list;
                        bt_guard : guard; bt_resets : clock list;
                        bt_target : int }

type tBA = { tba_nstates : int; tba_init : int;
             tba_transitions : tba_transition list; tba_accepting : int list }

(** val t : mtl -> ltl **)

let t f =
  t_at f [] f

(** val latom_eq_dec : mtl -> latom -> latom -> bool **)

let latom_eq_dec root a b =
  match a with
  | LAct a0 -> (match b with
                | LAct a1 -> (=) a0 a1
                | _ -> false)
  | LNAct a0 -> (match b with
                 | LNAct a1 -> (=) a0 a1
                 | _ -> false)
  | LCLe (c, r) ->
    (match b with
     | LCLe (c0, r0) -> if clock_eq_dec root c c0 then (=) r r0 else false
     | _ -> false)
  | LCLt (c, r) ->
    (match b with
     | LCLt (c0, r0) -> if clock_eq_dec root c c0 then (=) r r0 else false
     | _ -> false)
  | LCGe (c, r) ->
    (match b with
     | LCGe (c0, r0) -> if clock_eq_dec root c c0 then (=) r r0 else false
     | _ -> false)
  | LCGt (c, r) ->
    (match b with
     | LCGt (c0, r0) -> if clock_eq_dec root c c0 then (=) r r0 else false
     | _ -> false)
  | LRst c -> (match b with
               | LRst c0 -> clock_eq_dec root c c0
               | _ -> false)
  | LUnch c -> (match b with
                | LUnch c0 -> clock_eq_dec root c c0
                | _ -> false)

(** val latom_eqb : mtl -> latom -> latom -> bool **)

let latom_eqb root a b =
  if latom_eq_dec root a b then true else false

(** val in_atoms : mtl -> latom -> latom list -> bool **)

let in_atoms root a l =
  List.exists (latom_eqb root a) l

(** val is_ext : mtl -> latom -> bool **)

let is_ext _ = function
| LAct _ -> false
| LNAct _ -> false
| _ -> true

(** val lit_conflict : mtl -> plit -> plit -> bool **)

let lit_conflict root p q0 =
  (&&) (latom_eqb root (fst p) (fst q0)) (xorb (snd p) (snd q0))

(** val consistent : mtl -> plit list -> bool **)

let consistent root l =
  List.for_all (fun p -> not (List.exists (lit_conflict root p) l)) l

(** val keep_lit : mtl -> latom list -> plit -> bool **)

let keep_lit root f p =
  (||) (not (is_ext root (fst p))) ((&&) (snd p) (in_atoms root (fst p) f))

(** val relax_trans : mtl -> latom list -> ptransition -> ptransition **)

let relax_trans root f t0 =
  { pt_src = t0.pt_src; pt_label =
    (List.filter (keep_lit root f) t0.pt_label); pt_tgt = t0.pt_tgt }

(** val relax : mtl -> latom list -> pBuchi -> pBuchi **)

let relax root f a =
  { pb_nstates = a.pb_nstates; pb_init = a.pb_init; pb_trans =
    (List.map (relax_trans root f)
      (List.filter (fun t0 -> consistent root t0.pt_label) a.pb_trans));
    pb_accepting = a.pb_accepting }

(** val is_restart : mtl -> clock -> bool **)

let is_restart _ x =
  match let a = x in a with
  | MUhatGe (_, _, _) -> true
  | MRhatLe (_, _, _) -> true
  | MUhatGt (_, _, _) -> true
  | MRhatLt (_, _, _) -> true
  | _ -> false

(** val all_clocks : mtl -> clock list **)

let all_clocks root =
  List.concat_map (fun f ->
    match clock_of root f with
    | Some x -> x :: []
    | None -> []) (timed_subformulas root)

(** val has_pos : mtl -> latom -> plit list -> bool **)

let has_pos root a l =
  List.exists (fun p -> (&&) (latom_eqb root (fst p) a) (snd p)) l

(** val comp_resets : mtl -> plit list -> clock list **)

let comp_resets root l =
  List.filter (fun x ->
    if is_restart root x
    then has_pos root (LRst x) l
    else not (has_pos root (LUnch x) l)) (all_clocks root)

(** val act_lit : mtl -> plit -> alit list **)

let act_lit _ p =
  match fst p with
  | LAct q0 -> (q0, (snd p)) :: []
  | LNAct q0 -> (q0, (not (snd p))) :: []
  | _ -> []

(** val pos_atoms : mtl -> plit list -> latom list **)

let pos_atoms _ l =
  List.map fst (List.filter snd l)

(** val complete_trans : mtl -> ptransition -> tba_transition **)

let complete_trans root t0 =
  { bt_source = t0.pt_src; bt_label =
    (List.concat_map (act_lit root) t0.pt_label); bt_guard =
    (List.map (atom_to_guard root) (pos_atoms root t0.pt_label)); bt_resets =
    (comp_resets root t0.pt_label); bt_target = t0.pt_tgt }

(** val complete : mtl -> pBuchi -> tBA **)

let complete root a =
  { tba_nstates = a.pb_nstates; tba_init = a.pb_init; tba_transitions =
    (List.map (complete_trans root) a.pb_trans); tba_accepting =
    a.pb_accepting }

(** val compile_with : mtl -> pBuchi -> tBA **)

let compile_with f a =
  complete f (relax f (ltl_atoms f (t f)) a)

(** val is_upper : clock_comparison -> bool **)

let is_upper = function
| CGe -> false
| CGt -> false
| _ -> true

(** val clock_eqb : mtl -> clock -> clock -> bool **)

let clock_eqb root x y =
  if clock_eq_dec root x y then true else false

(** val opt_min : float option -> float option -> float option **)

let opt_min a b =
  match a with
  | Some u -> (match b with
               | Some v -> Some (Float.min u v)
               | None -> a)
  | None -> b

(** val ub_item : mtl -> clock -> clock_constraint option -> float option **)

let ub_item root x = function
| Some k ->
  if (&&) (is_upper k.guard_comparison) (clock_eqb root k.guard_clock x)
  then Some k.guard_bound
  else None
| None -> None

(** val ub_guard : mtl -> guard -> clock -> float option **)

let rec ub_guard root g x =
  match g with
  | [] -> None
  | o :: g' -> opt_min (ub_item root x o) (ub_guard root g' x)

(** val max_all : float option list -> float option **)

let rec max_all = function
| [] -> None
| a :: l' ->
  (match l' with
   | [] -> a
   | _ :: _ ->
     (match a with
      | Some u ->
        (match max_all l' with
         | Some v -> Some (Float.max u v)
         | None -> None)
      | None -> None))

(** val outgoing : mtl -> tBA -> int -> tba_transition list **)

let outgoing _ a l =
  List.filter (fun t0 -> (=) t0.bt_source l) a.tba_transitions

(** val synth_inv : mtl -> tBA -> int -> clock -> float option **)

let synth_inv root a l x =
  max_all
    (List.map (fun t0 -> ub_guard root t0.bt_guard x) (outgoing root a l))

type invariant = clock -> float option

(** val upper_clocks : mtl -> clock_constraint option -> clock list **)

let upper_clocks _ = function
| Some k -> if is_upper k.guard_comparison then k.guard_clock :: [] else []
| None -> []

(** val implies_c : mtl -> clock_constraint -> clock_constraint -> bool **)

let implies_c root a b =
  let u = a.guard_bound in
  let w = b.guard_bound in
  (&&) (clock_eqb root a.guard_clock b.guard_clock)
    (match b.guard_comparison with
     | CLe ->
       (match a.guard_comparison with
        | CGe -> false
        | CGt -> false
        | _ ->  ((<=) u w))
     | CLt ->
       (match a.guard_comparison with
        | CLe ->  ((<) u w)
        | CLt ->  ((<=) u w)
        | CEq ->  ((<) u w)
        | _ -> false)
     | CGe ->
       (match a.guard_comparison with
        | CLe -> false
        | CLt -> false
        | _ ->  ((<=) w u))
     | CGt ->
       (match a.guard_comparison with
        | CLe -> false
        | CLt -> false
        | CGt ->  ((<=) w u)
        | _ ->  ((<) w u))
     | CEq -> (match a.guard_comparison with
               | CEq ->  ((=) u w)
               | _ -> false))

(** val insert_t :
    mtl -> clock_constraint -> clock_constraint list -> clock_constraint list **)

let insert_t root c acc =
  if List.exists (fun a -> implies_c root a c) acc
  then acc
  else c :: (List.filter (fun a -> not (implies_c root c a)) acc)

(** val present : mtl -> guard -> clock_constraint list **)

let rec present root = function
| [] -> []
| o :: g' ->
  (match o with
   | Some k -> k :: (present root g')
   | None -> present root g')

(** val tighten : mtl -> guard -> guard **)

let tighten root g =
  List.map (fun x -> Some x)
    ((fun f a l -> List.fold_right f l a) (insert_t root) [] (present root g))

(** val conj_guard : mtl -> guard -> guard -> guard **)

let conj_guard root g h =
  tighten root (List.append g h)

(** val with_transitions : mtl -> tBA -> tba_transition list -> tBA **)

let with_transitions _ a ts =
  { tba_nstates = a.tba_nstates; tba_init = a.tba_init; tba_transitions = ts;
    tba_accepting = a.tba_accepting }

(** val is_lower : clock_comparison -> bool **)

let is_lower = function
| CLe -> false
| CLt -> false
| _ -> true

(** val opt_max : float option -> float option -> float option **)

let opt_max a b =
  match a with
  | Some u -> (match b with
               | Some v -> Some (Float.max u v)
               | None -> a)
  | None -> b

(** val lb_item : mtl -> clock -> clock_constraint option -> float option **)

let lb_item root x = function
| Some k ->
  if (&&) (is_lower k.guard_comparison) (clock_eqb root k.guard_clock x)
  then Some k.guard_bound
  else None
| None -> None

(** val lb_guard : mtl -> guard -> clock -> float option **)

let rec lb_guard root g x =
  match g with
  | [] -> None
  | o :: g' -> opt_max (lb_item root x o) (lb_guard root g' x)

(** val min_all : float option list -> float option **)

let rec min_all = function
| [] -> None
| a :: l' ->
  (match l' with
   | [] -> a
   | _ :: _ ->
     (match a with
      | Some u ->
        (match min_all l' with
         | Some v -> Some (Float.min u v)
         | None -> None)
      | None -> None))

(** val incoming : mtl -> tBA -> int -> tba_transition list **)

let incoming _ a l =
  List.filter (fun t0 -> (=) t0.bt_target l) a.tba_transitions

(** val entry_bound : mtl -> tba_transition -> clock -> float option **)

let entry_bound root t0 x =
  if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) x t0.bt_resets
  then Some (float_of_int 0)
  else lb_guard root t0.bt_guard x

(** val entry_lb : mtl -> tBA -> int -> clock -> float option **)

let entry_lb root a l x =
  min_all
    (List.append
      (if (=) l a.tba_init then (Some (float_of_int 0)) :: [] else [])
      (List.map (fun t0 -> entry_bound root t0 x) (incoming root a l)))

(** val lower_clocks : mtl -> clock_constraint option -> clock list **)

let lower_clocks _ = function
| Some k -> if is_lower k.guard_comparison then k.guard_clock :: [] else []
| None -> []

(** val entry_clocks : mtl -> tBA -> int -> clock list **)

let entry_clocks root a l =
  nodup (clock_eq_dec root)
    (List.concat_map (fun t0 ->
      List.append t0.bt_resets
        (List.concat_map (lower_clocks root) t0.bt_guard))
      (incoming root a l))

type tBAIL = { tbail_base : tBA; tbail_up : (int -> invariant);
               tbail_low : (int -> invariant) }

(** val add_two_sided_invariants : mtl -> tBA -> tBAIL **)

let add_two_sided_invariants root a =
  { tbail_base = a; tbail_up = (synth_inv root a); tbail_low =
    (entry_lb root a) }

(** val lower_info :
    mtl -> clock_constraint option -> ((clock * float) * bool) option **)

let lower_info _ = function
| Some k ->
  (match k.guard_comparison with
   | CLe -> None
   | CLt -> None
   | CGt -> Some ((k.guard_clock, k.guard_bound), true)
   | _ -> Some ((k.guard_clock, k.guard_bound), false))
| None -> None

(** val upper_info :
    mtl -> clock_constraint option -> ((clock * float) * bool) option **)

let upper_info _ = function
| Some k ->
  (match k.guard_comparison with
   | CLe -> Some ((k.guard_clock, k.guard_bound), false)
   | CLt -> Some ((k.guard_clock, k.guard_bound), true)
   | CEq -> Some ((k.guard_clock, k.guard_bound), false)
   | _ -> None)
| None -> None

(** val contradictory_bounds : float -> bool -> float -> bool -> bool **)

let contradictory_bounds l sl u su =
  if (<) u l then true else if (=) u l then (||) sl su else false

(** val contra_pair :
    mtl -> clock_constraint option -> clock_constraint option -> bool **)

let contra_pair root a b =
  match lower_info root a with
  | Some p ->
    let (p0, sl) = p in
    let (x, l) = p0 in
    (match upper_info root b with
     | Some p1 ->
       let (p2, su) = p1 in
       let (y, u) = p2 in
       (&&) (clock_eqb root x y) (contradictory_bounds l sl u su)
     | None -> false)
  | None -> false

(** val negative_upper : mtl -> clock_constraint option -> bool **)

let negative_upper root o =
  match upper_info root o with
  | Some p ->
    let (p0, su) = p in
    let (_, u) = p0 in contradictory_bounds (float_of_int 0) false u su
  | None -> false

(** val guard_contradictory : mtl -> guard -> bool **)

let guard_contradictory root g =
  (||) (List.exists (negative_upper root) g)
    (List.exists (fun a -> List.exists (contra_pair root a) g) g)

(** val remove_contradictory : mtl -> tBA -> tBA **)

let remove_contradictory root a =
  with_transitions root a
    (List.filter (fun t0 -> not (guard_contradictory root t0.bt_guard))
      a.tba_transitions)

(** val has_incoming : mtl -> tBA -> int -> bool **)

let has_incoming _ a l =
  List.exists (fun t0 -> (=) t0.bt_target l) a.tba_transitions

(** val remove_unreachable : mtl -> tBA -> tBA **)

let remove_unreachable root a =
  with_transitions root a
    (List.filter (fun t0 ->
      (||) ((=) t0.bt_source a.tba_init) (has_incoming root a t0.bt_source))
      a.tba_transitions)

(** val label_sat : alit list -> bool **)

let label_sat l =
  match find snd l with
  | Some a0 ->
    let (a, _) = a0 in
    List.for_all (fun p ->
      if snd p then (=) (fst p) a else not ((=) (fst p) a)) l
  | None -> true

(** val remove_unsat : mtl -> tBA -> tBA **)

let remove_unsat root a =
  with_transitions root a
    (List.filter (fun t0 -> label_sat t0.bt_label) a.tba_transitions)

(** val rename_item :
    mtl -> clock -> clock -> clock_constraint option -> clock_constraint
    option **)

let rename_item root x y o = match o with
| Some k ->
  if clock_eqb root k.guard_clock x
  then Some { guard_clock = y; guard_comparison = k.guard_comparison;
         guard_bound = k.guard_bound }
  else o
| None -> None

(** val merge_transition :
    mtl -> clock -> clock -> tba_transition -> tba_transition **)

let merge_transition root x y t0 =
  { bt_source = t0.bt_source; bt_label = t0.bt_label; bt_guard =
    (List.map (rename_item root x y) t0.bt_guard); bt_resets = t0.bt_resets;
    bt_target = t0.bt_target }

(** val merge_clock : mtl -> clock -> clock -> tBA -> tBA **)

let merge_clock root x y a =
  with_transitions root a
    (List.map (merge_transition root x y) a.tba_transitions)

(** val mentions : mtl -> clock -> clock_constraint option -> bool **)

let mentions root x = function
| Some k -> clock_eqb root k.guard_clock x
| None -> false

(** val clock_in : mtl -> clock -> clock list -> bool **)

let clock_in root x l =
  if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) x l
  then true
  else false

(** val mergeable_b : mtl -> tBA -> clock -> clock -> bool **)

let mergeable_b root a x y =
  (&&)
    ((&&)
      ((&&) (if clock_eq_dec root x y then false else true)
        (List.for_all (fun t0 ->
          (=) (clock_in root x t0.bt_resets) (clock_in root y t0.bt_resets))
          a.tba_transitions))
      (List.for_all (fun t0 -> not ((=) t0.bt_target a.tba_init))
        a.tba_transitions))
    (List.for_all (fun t0 ->
      (||) (not ((=) t0.bt_source a.tba_init))
        ((&&) (clock_in root x t0.bt_resets)
          (not (List.exists (mentions root x) t0.bt_guard))))
      a.tba_transitions)

(** val try_merge : mtl -> clock -> clock -> tBA -> tBA **)

let try_merge root x y a =
  if mergeable_b root a x y then merge_clock root x y a else a

(** val merge_pairs : mtl -> (clock * clock) list -> tBA -> tBA **)

let rec merge_pairs root ps a =
  match ps with
  | [] -> a
  | p :: ps' -> let (x, y) = p in merge_pairs root ps' (try_merge root x y a)

(** val reset_clocks : mtl -> tBA -> clock list **)

let reset_clocks root a =
  nodup (clock_eq_dec root)
    (List.concat_map (fun t0 -> t0.bt_resets) a.tba_transitions)

(** val merge_all : mtl -> tBA -> tBA **)

let merge_all root a =
  merge_pairs root
    ((fun l1 l2 -> List.concat_map (fun x -> List.map (fun y -> (x, y)) l2) l1)
      (reset_clocks root a) (reset_clocks root a)) a

(** val tests : mtl -> clock -> tba_transition -> bool **)

let tests root x t0 =
  List.exists (mentions root x) t0.bt_guard

(** val live_step : mtl -> tBA -> clock -> int list -> int list **)

let live_step root a x l =
  nodup (=)
    (List.append l
      (List.map (fun t0 -> t0.bt_source)
        (List.filter (fun t0 ->
          (||) (tests root x t0) (List.exists ((=) t0.bt_target) l))
          a.tba_transitions)))

(** val live_iter : mtl -> int -> tBA -> clock -> int list -> int list **)

let rec live_iter root n a x l =
  (fun fO fS n -> if n = 0 then fO () else fS (n - 1))
    (fun _ -> l)
    (fun n' ->
    let l' = live_step root a x l in
    if (=) (List.length l') (List.length l)
    then l'
    else live_iter root n' a x l')
    n

(** val live : mtl -> tBA -> clock -> int list **)

let live root a x =
  live_iter root ((fun n -> n + 1) (List.length a.tba_transitions)) a x []

(** val drop_reset : mtl -> clock -> tba_transition -> tba_transition **)

let drop_reset root x t0 =
  { bt_source = t0.bt_source; bt_label = t0.bt_label; bt_guard = t0.bt_guard;
    bt_resets =
    (List.filter (fun c -> not (clock_eqb root c x)) t0.bt_resets);
    bt_target = t0.bt_target }

(** val remove_dead_resets_clock_fast : mtl -> clock -> tBA -> tBA **)

let remove_dead_resets_clock_fast root x a =
  let l = live root a x in
  let dead_in = fun l0 -> not (List.exists ((=) l0) l) in
  if List.for_all (fun t0 ->
       (||) (not (dead_in t0.bt_source))
         ((&&) (dead_in t0.bt_target) (not (tests root x t0))))
       a.tba_transitions
  then with_transitions root a
         (List.map (fun t0 ->
           if dead_in t0.bt_target then drop_reset root x t0 else t0)
           a.tba_transitions)
  else a

(** val remove_dead_resets_list : mtl -> clock list -> tBA -> tBA **)

let rec remove_dead_resets_list root xs a =
  match xs with
  | [] -> a
  | x :: xs' ->
    remove_dead_resets_list root xs' (remove_dead_resets_clock_fast root x a)

(** val remove_dead_resets : mtl -> tBA -> tBA **)

let remove_dead_resets root a =
  remove_dead_resets_list root (reset_clocks root a) a

(** val trivial_c : mtl -> clock_constraint -> bool **)

let trivial_c _ k =
  match k.guard_comparison with
  | CGe ->  ((<=) k.guard_bound (float_of_int 0))
  | CGt ->  ((<) k.guard_bound (float_of_int 0))
  | _ -> false

(** val insert_c :
    mtl -> clock_constraint -> clock_constraint list -> clock_constraint list **)

let insert_c root c acc =
  if trivial_c root c then acc else insert_t root c acc

(** val norm_guard : mtl -> guard -> guard **)

let norm_guard root g =
  List.map (fun x -> Some x)
    ((fun f a l -> List.fold_right f l a) (insert_c root) [] (present root g))

(** val normalize_transition : mtl -> tba_transition -> tba_transition **)

let normalize_transition root t0 =
  { bt_source = t0.bt_source; bt_label = t0.bt_label; bt_guard =
    (norm_guard root t0.bt_guard); bt_resets = t0.bt_resets; bt_target =
    t0.bt_target }

(** val normalize : mtl -> tBA -> tBA **)

let normalize root a =
  with_transitions root a
    (List.map (normalize_transition root) a.tba_transitions)

(** val alit_dec : alit -> alit -> bool **)

let alit_dec a b =
  let (a0, b0) = a in
  let (a1, b1) = b in if (=) a0 a1 then (=) b0 b1 else false

(** val cmp_dec : clock_comparison -> clock_comparison -> bool **)

let cmp_dec a b =
  match a with
  | CLe -> (match b with
            | CLe -> true
            | _ -> false)
  | CLt -> (match b with
            | CLt -> true
            | _ -> false)
  | CGe -> (match b with
            | CGe -> true
            | _ -> false)
  | CGt -> (match b with
            | CGt -> true
            | _ -> false)
  | CEq -> (match b with
            | CEq -> true
            | _ -> false)

(** val cc_dec : mtl -> clock_constraint -> clock_constraint -> bool **)

let cc_dec root a b =
  let { guard_clock = guard_clock0; guard_comparison = guard_comparison0;
    guard_bound = guard_bound0 } = a
  in
  let { guard_clock = guard_clock1; guard_comparison = guard_comparison1;
    guard_bound = guard_bound1 } = b
  in
  if clock_eq_dec root guard_clock0 guard_clock1
  then if cmp_dec guard_comparison0 guard_comparison1
       then (=) guard_bound0 guard_bound1
       else false
  else false

(** val item_dec :
    mtl -> clock_constraint option -> clock_constraint option -> bool **)

let item_dec root a b =
  match a with
  | Some a0 -> (match b with
                | Some c -> cc_dec root a0 c
                | None -> false)
  | None -> (match b with
             | Some _ -> false
             | None -> true)

(** val tr_dec : mtl -> tba_transition -> tba_transition -> bool **)

let tr_dec root a b =
  let { bt_source = bt_source0; bt_label = bt_label0; bt_guard = bt_guard0;
    bt_resets = bt_resets0; bt_target = bt_target0 } = a
  in
  let { bt_source = bt_source1; bt_label = bt_label1; bt_guard = bt_guard1;
    bt_resets = bt_resets1; bt_target = bt_target1 } = b
  in
  if (=) bt_source0 bt_source1
  then if List.equal alit_dec bt_label0 bt_label1
       then if List.equal (item_dec root) bt_guard0 bt_guard1
            then if List.equal (clock_eq_dec root) bt_resets0 bt_resets1
                 then (=) bt_target0 bt_target1
                 else false
            else false
       else false
  else false

(** val beq : ('a1 -> 'a1 -> bool) -> 'a1 -> 'a1 -> bool **)

let beq d a b =
  if d a b then true else false

(** val set_incl : ('a1 -> 'a1 -> bool) -> 'a1 list -> 'a1 list -> bool **)

let set_incl d l1 l2 =
  List.for_all (fun a -> List.exists (beq d a) l2) l1

(** val set_eqb : ('a1 -> 'a1 -> bool) -> 'a1 list -> 'a1 list -> bool **)

let set_eqb d l1 l2 =
  (&&) (set_incl d l1 l2) (set_incl d l2 l1)

(** val free_loop : mtl -> int -> clock -> tba_transition -> bool **)

let free_loop root l x t0 =
  if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) x t0.bt_resets
  then false
  else (=) t0.bt_source l

(** val entry_lb_loop : mtl -> tBA -> int -> clock -> float option **)

let entry_lb_loop root a l x =
  min_all
    (List.append
      (if (=) l a.tba_init then (Some (float_of_int 0)) :: [] else [])
      (List.map (fun t0 -> entry_bound root t0 x)
        (List.filter (fun t0 -> not (free_loop root l x t0))
          (incoming root a l))))

(** val entry_guard_loop : mtl -> tBA -> int -> guard **)

let entry_guard_loop root a l =
  List.map (fun x ->
    match entry_lb_loop root a l x with
    | Some m ->
      Some { guard_clock = x; guard_comparison = CGe; guard_bound = m }
    | None -> None) (entry_clocks root a l)

(** val red : int -> int -> int -> int **)

let red p q0 s =
  if (=) s q0 then p else s

(** val redirect : mtl -> int -> int -> tba_transition -> tba_transition **)

let redirect _ p q0 t0 =
  { bt_source = t0.bt_source; bt_label = t0.bt_label; bt_guard = t0.bt_guard;
    bt_resets = t0.bt_resets; bt_target = (red p q0 t0.bt_target) }

(** val guard_implied : mtl -> guard -> guard -> bool **)

let guard_implied root g g' =
  List.for_all (fun o ->
    match o with
    | Some k' ->
      List.exists (fun o2 ->
        match o2 with
        | Some k -> implies_c root k k'
        | None -> false) g
    | None -> true) g'

(** val sim :
    mtl -> int -> int -> guard -> tba_transition -> tba_transition -> bool **)

let sim root p q0 g t0 t' =
  (&&)
    ((&&)
      ((&&) (set_incl alit_dec t'.bt_label t0.bt_label)
        (guard_implied root (List.append t0.bt_guard g) t'.bt_guard))
      (set_eqb (clock_eq_dec root) t0.bt_resets t'.bt_resets))
    ((=) (red p q0 t0.bt_target) (red p q0 t'.bt_target))

(** val in_nat : int -> int list -> bool **)

let in_nat n l =
  List.exists ((=) n) l

(** val covers_fast :
    mtl -> tBA -> int -> int -> guard -> int -> int -> bool **)

let covers_fast root a p q0 g s s' =
  List.for_all (fun t0 ->
    List.exists (sim root p q0 g t0) (outgoing root a s')) (outgoing root a s)

(** val states_mergeable_fast : mtl -> tBA -> int -> int -> bool **)

let states_mergeable_fast root a p q0 =
  (&&)
    ((&&)
      ((&&)
        ((&&) ((&&) (not ((=) p q0)) ((<) p a.tba_nstates))
          ((<) q0 a.tba_nstates))
        ((=) (in_nat p a.tba_accepting) (in_nat q0 a.tba_accepting)))
      (covers_fast root a p q0 [] p q0))
    (covers_fast root a p q0 (entry_guard_loop root a q0) q0 p)

(** val merge_states : mtl -> int -> int -> tBA -> tBA **)

let merge_states root p q0 a =
  { tba_nstates = a.tba_nstates; tba_init = (red p q0 a.tba_init);
    tba_transitions =
    (List.map (redirect root p q0)
      (List.filter (fun t0 -> not ((=) t0.bt_source q0)) a.tba_transitions));
    tba_accepting = a.tba_accepting }

(** val try_merge_states : mtl -> int -> int -> tBA -> tBA **)

let try_merge_states root p q0 a =
  if states_mergeable_fast root a p q0 then merge_states root p q0 a else a

(** val state_pairs : int -> (int * int) list **)

let state_pairs n =
  List.filter (fun pq -> not ((=) (fst pq) (snd pq)))
    ((fun l1 l2 -> List.concat_map (fun x -> List.map (fun y -> (x, y)) l2) l1)
      ((fun s n -> List.init n (fun i -> s + i)) 0 n)
      ((fun s n -> List.init n (fun i -> s + i)) 0 n))

(** val merge_states_all : mtl -> tBA -> tBA **)

let merge_states_all root a =
  fold_left (fun b pq -> try_merge_states root (fst pq) (snd pq) b)
    (state_pairs a.tba_nstates) a

(** val same_ends : mtl -> tba_transition -> tba_transition -> bool **)

let same_ends root t0 u =
  (&&) ((&&) ((=) t0.bt_source u.bt_source) ((=) t0.bt_target u.bt_target))
    (beq (List.equal (clock_eq_dec root)) t0.bt_resets u.bt_resets)

(** val subsumes : mtl -> tba_transition -> tba_transition -> bool **)

let subsumes root u t0 =
  (&&)
    ((&&) (same_ends root u t0) (set_incl alit_dec u.bt_label t0.bt_label))
    (guard_implied root t0.bt_guard u.bt_guard)

(** val insert_sub :
    mtl -> tba_transition -> tba_transition list -> tba_transition list **)

let insert_sub root t0 acc =
  if List.exists (fun a -> subsumes root a t0) acc
  then acc
  else t0 :: (List.filter (fun a -> not (subsumes root t0 a)) acc)

(** val remove_item : ('a1 -> 'a1 -> bool) -> 'a1 -> 'a1 list -> 'a1 list **)

let remove_item d x l =
  List.filter (fun y -> not (beq d x y)) l

(** val neg_alit : alit -> alit **)

let neg_alit l =
  ((fst l), (not (snd l)))

(** val resolve_lab : alit list -> alit list -> alit list option **)

let resolve_lab l1 l2 =
  match find (fun x ->
          (&&) (List.exists (beq alit_dec (neg_alit x)) l2)
            (set_eqb alit_dec (remove_item alit_dec x l1)
              (remove_item alit_dec (neg_alit x) l2))) l1 with
  | Some x -> Some (remove_item alit_dec x l1)
  | None -> None

(** val compl : mtl -> clock_constraint -> clock_constraint option **)

let compl _ k =
  let mk = fun c -> Some { guard_clock = k.guard_clock; guard_comparison = c;
    guard_bound = k.guard_bound }
  in
  (match k.guard_comparison with
   | CLe -> mk CGt
   | CLt -> mk CGe
   | CGe -> mk CLt
   | CGt -> mk CLe
   | CEq -> None)

(** val resolve_grd : mtl -> guard -> guard -> guard option **)

let resolve_grd root g1 g2 =
  match find (fun o ->
          match o with
          | Some k ->
            (match compl root k with
             | Some k' ->
               (&&) (List.exists (beq (item_dec root) (Some k')) g2)
                 (set_eqb (item_dec root) (remove_item (item_dec root) o g1)
                   (remove_item (item_dec root) (Some k') g2))
             | None -> false)
          | None -> false) g1 with
  | Some o -> Some (remove_item (item_dec root) o g1)
  | None -> None

(** val with_label : mtl -> tba_transition -> alit list -> tba_transition **)

let with_label _ t0 l =
  { bt_source = t0.bt_source; bt_label = l; bt_guard = t0.bt_guard;
    bt_resets = t0.bt_resets; bt_target = t0.bt_target }

(** val with_guard : mtl -> tba_transition -> guard -> tba_transition **)

let with_guard _ t0 g =
  { bt_source = t0.bt_source; bt_label = t0.bt_label; bt_guard = g;
    bt_resets = t0.bt_resets; bt_target = t0.bt_target }

(** val resolve :
    mtl -> tba_transition -> tba_transition -> tba_transition option **)

let resolve root u t0 =
  if same_ends root u t0
  then if set_eqb (item_dec root) u.bt_guard t0.bt_guard
       then (match resolve_lab u.bt_label t0.bt_label with
             | Some m -> Some (with_label root u m)
             | None -> None)
       else if set_eqb alit_dec u.bt_label t0.bt_label
            then (match resolve_grd root u.bt_guard t0.bt_guard with
                  | Some g -> Some (with_guard root u g)
                  | None -> None)
            else None
  else None

(** val insert_res :
    mtl -> tba_transition -> tba_transition list -> tba_transition list **)

let insert_res root t0 acc =
  match find (fun a ->
          match resolve root a t0 with
          | Some _ -> true
          | None -> false) acc with
  | Some a ->
    (match resolve root a t0 with
     | Some m -> m :: (remove_item (tr_dec root) a acc)
     | None -> t0 :: acc)
  | None -> t0 :: acc

(** val merge_trans : mtl -> tBA -> tBA **)

let merge_trans root a =
  with_transitions root a
    ((fun f a l -> List.fold_right f l a) (insert_res root) []
      ((fun f a l -> List.fold_right f l a) (insert_sub root) []
        a.tba_transitions))

(** val table_of : mtl -> (int -> 'a1) -> tBA -> 'a1 list **)

let table_of _ f a =
  List.map f ((fun s n -> List.init n (fun i -> s + i)) 0 a.tba_nstates)

(** val lookup :
    mtl -> 'a1 -> (int -> 'a1) -> 'a1 list -> tBA -> int -> 'a1 **)

let lookup _ d f tbl a l =
  if (<) l a.tba_nstates
  then (fun n l d -> match List.nth_opt l n with Some x -> x | None -> d) l
         tbl d
  else f l

(** val entry_clocks_w :
    mtl -> (int -> tba_transition list) -> int -> clock list **)

let entry_clocks_w root inc l =
  nodup (clock_eq_dec root)
    (List.concat_map (fun t0 ->
      List.append t0.bt_resets
        (List.concat_map (lower_clocks root) t0.bt_guard)) (inc l))

(** val entry_lb_w :
    mtl -> tBA -> (int -> tba_transition list) -> int -> clock -> float option **)

let entry_lb_w root a inc l x =
  min_all
    (List.append
      (if (=) l a.tba_init then (Some (float_of_int 0)) :: [] else [])
      (List.map (fun t0 -> entry_bound root t0 x) (inc l)))

(** val entry_guard_w :
    mtl -> tBA -> (int -> tba_transition list) -> int -> guard **)

let entry_guard_w root a inc l =
  List.map (fun x ->
    match entry_lb_w root a inc l x with
    | Some m ->
      Some { guard_clock = x; guard_comparison = CGe; guard_bound = m }
    | None -> None) (entry_clocks_w root inc l)

(** val forward_fast : mtl -> tBA -> tBA **)

let forward_fast root a =
  let inc =
    lookup root [] (incoming root a) (table_of root (incoming root a) a) a
  in
  let eg =
    lookup root [] (entry_guard_w root a inc)
      (table_of root (entry_guard_w root a inc) a) a
  in
  with_transitions root a
    (List.map (fun t0 -> { bt_source = t0.bt_source; bt_label = t0.bt_label;
      bt_guard = (conj_guard root t0.bt_guard (eg t0.bt_source)); bt_resets =
      t0.bt_resets; bt_target = t0.bt_target }) a.tba_transitions)

(** val synth_inv_w :
    mtl -> (int -> tba_transition list) -> int -> clock -> float option **)

let synth_inv_w root out l x =
  max_all (List.map (fun t0 -> ub_guard root t0.bt_guard x) (out l))

(** val inv_clocks_w :
    mtl -> (int -> tba_transition list) -> int -> clock list **)

let inv_clocks_w root out l =
  nodup (clock_eq_dec root)
    (List.concat_map (fun t0 ->
      List.concat_map (upper_clocks root) t0.bt_guard) (out l))

(** val inv_item_of :
    mtl -> clock list -> clock -> float option -> clock_constraint option **)

let inv_item_of root z0 x = function
| Some m ->
  if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) x z0
  then if (<=) (float_of_int 0) m
       then None
       else Some { guard_clock = x; guard_comparison = CLt; guard_bound =
              (float_of_int 0) }
  else Some { guard_clock = x; guard_comparison = CLe; guard_bound = m }
| None -> None

(** val inv_info_w :
    mtl -> (int -> tba_transition list) -> int -> (clock * float option) list **)

let inv_info_w root out l =
  List.map (fun x -> (x, (synth_inv_w root out l x)))
    (inv_clocks_w root out l)

(** val inv_guard_of_info :
    mtl -> clock list -> (clock * float option) list -> guard **)

let inv_guard_of_info root z0 info =
  List.map (fun p -> inv_item_of root z0 (fst p) (snd p)) info

(** val propagate_fast : mtl -> tBA -> tBA **)

let propagate_fast root a =
  let out =
    lookup root [] (outgoing root a) (table_of root (outgoing root a) a) a
  in
  let info =
    lookup root [] (inv_info_w root out)
      (table_of root (inv_info_w root out) a) a
  in
  with_transitions root a
    (List.map (fun t0 -> { bt_source = t0.bt_source; bt_label = t0.bt_label;
      bt_guard =
      (conj_guard root t0.bt_guard
        (inv_guard_of_info root t0.bt_resets (info t0.bt_target)));
      bt_resets = t0.bt_resets; bt_target = t0.bt_target }) a.tba_transitions)

(** val optimize_step : mtl -> tBA -> tBA **)

let optimize_step root a =
  merge_states_all root
    (merge_trans root
      (normalize root
        (merge_all root
          (remove_dead_resets root
            (normalize root
              (remove_unreachable root
                (remove_unsat root
                  (remove_contradictory root
                    (forward_fast root (propagate_fast root a))))))))))

(** val optimize : mtl -> int -> tBA -> tBA **)

let rec optimize root n a =
  (fun fO fS n -> if n = 0 then fO () else fS (n - 1))
    (fun _ -> a)
    (fun n' -> optimize root n' (optimize_step root a))
    n

(** val optimized : mtl -> int -> tBA -> tBAIL **)

let optimized root n a =
  add_two_sided_invariants root (optimize root n a)

(** val complete_fast : mtl -> pBuchi -> tBA **)

let complete_fast root a =
  let cl = all_clocks root in
  { tba_nstates = a.pb_nstates; tba_init = a.pb_init; tba_transitions =
  (List.map (fun t0 -> { bt_source = t0.pt_src; bt_label =
    (List.concat_map (act_lit root) t0.pt_label); bt_guard =
    (List.map (atom_to_guard root) (pos_atoms root t0.pt_label)); bt_resets =
    (List.filter (fun x ->
      if is_restart root x
      then has_pos root (LRst x) t0.pt_label
      else not (has_pos root (LUnch x) t0.pt_label)) cl); bt_target =
    t0.pt_tgt }) a.pb_trans); tba_accepting = a.pb_accepting }

(** val compile_with_fast : mtl -> pBuchi -> tBA **)

let compile_with_fast root a =
  complete_fast root (relax root (ltl_atoms root (t root)) a)

type dconstraint =
| DSingle of clock_constraint
| DDiff of clock * clock * float

type dconj = dconstraint list

type dguard = dconj list

type uinv = (clock * float) list

type dtrans = { dt_src : int; dt_label : alit list; dt_guard : dguard;
                dt_resets : clock list; dt_tgt : int }

type dTA = { dta_nstates : int; dta_init : int; dta_trans : dtrans list;
             dta_accepting : int list; dta_inv : (int -> uinv list option) }

(** val singles : mtl -> guard -> dconj **)

let rec singles root = function
| [] -> []
| o :: g' ->
  (match o with
   | Some k -> (DSingle k) :: (singles root g')
   | None -> singles root g')

(** val of_tba_trans : mtl -> tba_transition -> dtrans **)

let of_tba_trans root t0 =
  { dt_src = t0.bt_source; dt_label = t0.bt_label; dt_guard =
    ((singles root t0.bt_guard) :: []); dt_resets = t0.bt_resets; dt_tgt =
    t0.bt_target }

(** val of_tba : mtl -> tBA -> dTA **)

let of_tba root a =
  { dta_nstates = a.tba_nstates; dta_init = a.tba_init; dta_trans =
    (List.map (of_tba_trans root) a.tba_transitions); dta_accepting =
    a.tba_accepting; dta_inv = (fun _ -> None) }

(** val alit_eq_dec : alit -> alit -> bool **)

let alit_eq_dec a b =
  let (a0, b0) = a in
  let (a1, b1) = b in if (=) a0 a1 then (=) b0 b1 else false

(** val same_key_dec : mtl -> dtrans -> dtrans -> bool **)

let same_key_dec root t0 u =
  let s = (=) t0.dt_src u.dt_src in
  if s
  then let s0 = (=) t0.dt_tgt u.dt_tgt in
       if s0
       then let s1 = List.equal alit_eq_dec t0.dt_label u.dt_label in
            if s1
            then List.equal (clock_eq_dec root) t0.dt_resets u.dt_resets
            else false
       else false
  else false

(** val add_guard : mtl -> dtrans -> dguard -> dtrans **)

let add_guard _ t0 g =
  { dt_src = t0.dt_src; dt_label = t0.dt_label; dt_guard =
    (List.append t0.dt_guard g); dt_resets = t0.dt_resets; dt_tgt =
    t0.dt_tgt }

(** val insert_trans : mtl -> dtrans -> dtrans list -> dtrans list **)

let rec insert_trans root t0 = function
| [] -> t0 :: []
| u :: acc' ->
  if same_key_dec root u t0
  then (add_guard root u t0.dt_guard) :: acc'
  else u :: (insert_trans root t0 acc')

(** val group : mtl -> dtrans list -> dtrans list **)

let group root ts =
  (fun f a l -> List.fold_right f l a) (insert_trans root) [] ts

(** val merge_transitions : mtl -> dTA -> dTA **)

let merge_transitions root d =
  { dta_nstates = d.dta_nstates; dta_init = d.dta_init; dta_trans =
    (group root d.dta_trans); dta_accepting = d.dta_accepting; dta_inv =
    d.dta_inv }

(** val ub_conj : mtl -> dconj -> uinv **)

let rec ub_conj root = function
| [] -> []
| d :: c' ->
  (match d with
   | DSingle k ->
     List.append
       (if is_upper k.guard_comparison
        then (k.guard_clock, k.guard_bound) :: []
        else []) (ub_conj root c')
   | DDiff (_, _, _) -> ub_conj root c')

(** val outgoing_d : mtl -> dTA -> int -> dtrans list **)

let outgoing_d _ d l =
  List.filter (fun t0 -> (=) t0.dt_src l) d.dta_trans

(** val uimplies : mtl -> uinv -> uinv -> bool **)

let uimplies root u u' =
  List.for_all (fun p ->
    List.exists (fun q0 ->
      (&&) (clock_eqb root (fst q0) (fst p)) ( ((<=) (snd q0) (snd p)))) u) u'

(** val insert_u : mtl -> uinv -> uinv list -> uinv list **)

let insert_u root u acc =
  if List.exists (fun a -> uimplies root u a) acc
  then acc
  else u :: (List.filter (fun a -> not (uimplies root a u)) acc)

(** val dedupe_u : mtl -> uinv list -> uinv list **)

let dedupe_u root l =
  (fun f a l -> List.fold_right f l a) (insert_u root) [] l

(** val disj_inv : mtl -> dTA -> int -> uinv list **)

let disj_inv root d l =
  dedupe_u root
    (List.concat_map (fun t0 -> List.map (ub_conj root) t0.dt_guard)
      (outgoing_d root d l))

(** val upper_singles : mtl -> uinv -> dconj **)

let upper_singles _ u =
  List.map (fun p -> DSingle { guard_clock = (fst p); guard_comparison = CLe;
    guard_bound = (snd p) }) u

(** val notlonger : mtl -> uinv -> uinv -> dguard **)

let notlonger _ ul uk = match uk with
| [] -> [] :: []
| _ :: _ ->
  List.map (fun q0 ->
    List.map (fun p -> DDiff ((fst p), (fst q0), ((-.) (snd p) (snd q0)))) uk)
    ul

(** val dnf_and : mtl -> dguard -> dguard -> dguard **)

let dnf_and _ g1 g2 =
  List.concat_map (fun c1 -> List.map (fun c2 -> List.append c1 c2) g2) g1

(** val notlonger_all : mtl -> uinv list -> uinv -> dguard **)

let rec notlonger_all root us uk =
  match us with
  | [] -> [] :: []
  | ul :: us' ->
    dnf_and root (notlonger root ul uk) (notlonger_all root us' uk)

(** val entry_cond : mtl -> uinv list -> int -> dguard **)

let entry_cond root us k =
  dnf_and root
    ((upper_singles root
       ((fun n l d -> match List.nth_opt l n with Some x -> x | None -> d) k
         us [])) :: [])
    (notlonger_all root us
      ((fun n l d -> match List.nth_opt l n with Some x -> x | None -> d) k
        us []))

(** val const_true : mtl -> clock_constraint -> bool **)

let const_true _ k =
  match k.guard_comparison with
  | CLe -> if (<=) (float_of_int 0) k.guard_bound then true else false
  | CLt -> if (<) (float_of_int 0) k.guard_bound then true else false
  | CGe -> if (<=) k.guard_bound (float_of_int 0) then true else false
  | CGt -> if (<) k.guard_bound (float_of_int 0) then true else false
  | CEq -> if (=) (float_of_int 0) k.guard_bound then true else false

(** val subst_c : mtl -> clock list -> dconstraint -> dconj option **)

let subst_c root z0 c = match c with
| DSingle k ->
  if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) k.guard_clock z0
  then if const_true root k then Some [] else None
  else Some (c :: [])
| DDiff (x, y, b) ->
  if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) x z0
  then if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) y z0
       then if (<=) (float_of_int 0) b then Some [] else None
       else Some ((DSingle { guard_clock = y; guard_comparison = CGe;
              guard_bound = ((~-.) b) }) :: [])
  else if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) y z0
       then Some ((DSingle { guard_clock = x; guard_comparison = CLe;
              guard_bound = b }) :: [])
       else Some (c :: [])

(** val subst_conj : mtl -> clock list -> dconj -> dconj option **)

let rec subst_conj root z0 = function
| [] -> Some []
| a :: c' ->
  (match subst_c root z0 a with
   | Some p ->
     (match subst_conj root z0 c' with
      | Some q0 -> Some (List.append p q0)
      | None -> None)
   | None -> None)

(** val subst_guard : mtl -> clock list -> dguard -> dguard **)

let subst_guard root z0 g =
  List.concat_map (fun c ->
    match subst_conj root z0 c with
    | Some c' -> c' :: []
    | None -> []) g

(** val kmax : mtl -> dTA -> int **)

let kmax root d =
  (List.fold_left max 0)
    (List.map (fun l -> List.length (disj_inv root d l))
      (List.append
        ((fun s n -> List.init n (fun i -> s + i)) 0 d.dta_nstates)
        (List.map (fun t0 -> t0.dt_tgt) d.dta_trans)))

(** val kp : mtl -> dTA -> int **)

let kp root d =
  (fun n -> n + 1) (kmax root d)

(** val enc : mtl -> dTA -> int -> int -> int **)

let enc root d l k =
  (+) (( * ) l (kp root d)) k

(** val split_inv : mtl -> dTA -> int -> uinv list option **)

let split_inv root d s =
  let k = (fun n m -> if m = 0 then n else n mod m) s (kp root d) in
  if (=) k (kmax root d)
  then None
  else (match List.nth_opt
                (disj_inv root d
                  ((fun n m -> if m = 0 then 0 else n / m) s (kp root d))) k with
        | Some u -> Some (u :: [])
        | None -> None)

(** val split_all_trans : mtl -> dTA -> dtrans -> dtrans list **)

let split_all_trans root d t0 =
  List.concat_map (fun j ->
    List.map (fun k -> { dt_src = (enc root d t0.dt_src j); dt_label =
      t0.dt_label; dt_guard = t0.dt_guard; dt_resets = t0.dt_resets; dt_tgt =
      (enc root d t0.dt_tgt k) })
      ((fun s n -> List.init n (fun i -> s + i)) 0
        (List.length (disj_inv root d t0.dt_tgt))))
    ((fun s n -> List.init n (fun i -> s + i)) 0 (kp root d))

(** val split_all : mtl -> dTA -> dTA **)

let split_all root d =
  { dta_nstates = (( * ) d.dta_nstates (kp root d)); dta_init =
    (enc root d d.dta_init (kmax root d)); dta_trans =
    (List.concat_map (split_all_trans root d) d.dta_trans); dta_accepting =
    (List.concat_map (fun l ->
      List.map (enc root d l)
        ((fun s n -> List.init n (fun i -> s + i)) 0 (kp root d)))
      d.dta_accepting); dta_inv = (split_inv root d) }

(** val explode : mtl -> dtrans -> dtrans list **)

let explode _ t0 =
  List.map (fun c -> { dt_src = t0.dt_src; dt_label = t0.dt_label; dt_guard =
    (c :: []); dt_resets = t0.dt_resets; dt_tgt = t0.dt_tgt }) t0.dt_guard

(** val explode_all : mtl -> dTA -> dTA **)

let explode_all root d =
  { dta_nstates = d.dta_nstates; dta_init = d.dta_init; dta_trans =
    (List.concat_map (explode root) d.dta_trans); dta_accepting =
    d.dta_accepting; dta_inv = d.dta_inv }

(** val implies_d : mtl -> dconstraint -> dconstraint -> bool **)

let implies_d root a b =
  match a with
  | DSingle k1 ->
    (match b with
     | DSingle k2 -> implies_c root k1 k2
     | DDiff (_, _, _) -> false)
  | DDiff (x, y, u) ->
    (match b with
     | DSingle _ -> false
     | DDiff (x', y', u') ->
       (&&) ((&&) (clock_eqb root x x') (clock_eqb root y y')) ( ((<=) u u')))

(** val trivial_d : mtl -> dconstraint -> bool **)

let trivial_d root = function
| DSingle _ -> false
| DDiff (x, y, b) -> (&&) (clock_eqb root x y) ( ((<=) (float_of_int 0) b))

(** val self_contra : mtl -> dconstraint -> bool **)

let self_contra root = function
| DSingle _ -> false
| DDiff (x, y, b) -> (&&) (clock_eqb root x y) ( ((<) b (float_of_int 0)))

(** val insert_d : mtl -> dconstraint -> dconj -> dconj **)

let insert_d root c acc =
  if trivial_d root c
  then acc
  else if List.exists (fun a -> implies_d root a c) acc
       then acc
       else c :: (List.filter (fun a -> not (implies_d root c a)) acc)

(** val dnorm_conj : mtl -> dconj -> dconj **)

let dnorm_conj root c =
  (fun f a l -> List.fold_right f l a) (insert_d root) [] c

(** val conj_implies : mtl -> dconj -> dconj -> bool **)

let conj_implies root c a =
  List.for_all (fun b -> List.exists (fun x -> implies_d root x b) c) a

(** val insert_g : mtl -> dconj -> dguard -> dguard **)

let insert_g root c acc =
  if List.exists (self_contra root) c
  then acc
  else if List.exists (fun a -> conj_implies root c a) acc
       then acc
       else c :: (List.filter (fun a -> not (conj_implies root a c)) acc)

(** val dnorm_guard : mtl -> dguard -> dguard **)

let dnorm_guard root g =
  (fun f a l -> List.fold_right f l a) (insert_g root) []
    (List.map (dnorm_conj root) g)

(** val normalize_dtrans : mtl -> dtrans -> dtrans **)

let normalize_dtrans root t0 =
  { dt_src = t0.dt_src; dt_label = t0.dt_label; dt_guard =
    (dnorm_guard root t0.dt_guard); dt_resets = t0.dt_resets; dt_tgt =
    t0.dt_tgt }

(** val normalize_d : mtl -> dTA -> dTA **)

let normalize_d root d =
  { dta_nstates = d.dta_nstates; dta_init = d.dta_init; dta_trans =
    (List.map (normalize_dtrans root) d.dta_trans); dta_accepting =
    d.dta_accepting; dta_inv = d.dta_inv }

(** val dhas_incoming : mtl -> dTA -> int -> bool **)

let dhas_incoming _ d l =
  List.exists (fun t0 -> (=) t0.dt_tgt l) d.dta_trans

(** val dprune : mtl -> dTA -> dTA **)

let dprune root d =
  { dta_nstates = d.dta_nstates; dta_init = d.dta_init; dta_trans =
    (List.filter (fun t0 ->
      (||) ((=) t0.dt_src d.dta_init) (dhas_incoming root d t0.dt_src))
      d.dta_trans); dta_accepting = d.dta_accepting; dta_inv = d.dta_inv }

(** val dprune_n : mtl -> int -> dTA -> dTA **)

let rec dprune_n root n d =
  (fun fO fS n -> if n = 0 then fO () else fS (n - 1))
    (fun _ -> d)
    (fun n' ->
    if (=) (List.length (dprune root d).dta_trans) (List.length d.dta_trans)
    then d
    else dprune_n root n' (dprune root d))
    n

(** val dprune_all : mtl -> dTA -> dTA **)

let dprune_all root d =
  dprune_n root (List.length d.dta_trans) d

(** val dc_dec : mtl -> dconstraint -> dconstraint -> bool **)

let dc_dec root a b =
  match a with
  | DSingle c ->
    (match b with
     | DSingle c0 -> cc_dec root c c0
     | DDiff (_, _, _) -> false)
  | DDiff (c, c0, r) ->
    (match b with
     | DSingle _ -> false
     | DDiff (c1, c2, r0) ->
       if clock_eq_dec root c c1
       then if clock_eq_dec root c0 c2 then (=) r r0 else false
       else false)

(** val dconj_dec : mtl -> dconj -> dconj -> bool **)

let dconj_dec root =
  List.equal (dc_dec root)

(** val cr_dec : mtl -> (clock * float) -> (clock * float) -> bool **)

let cr_dec root a b =
  let (a0, b0) = a in
  let (c, r) = b in if clock_eq_dec root a0 c then (=) b0 r else false

(** val oinv_dec : mtl -> uinv list option -> uinv list option -> bool **)

let oinv_dec root a b =
  match a with
  | Some a0 ->
    (match b with
     | Some l -> List.equal (List.equal (cr_dec root)) a0 l
     | None -> false)
  | None -> (match b with
             | Some _ -> false
             | None -> true)

(** val inv_norm : mtl -> uinv list option -> uinv list option **)

let inv_norm _ = function
| Some us ->
  if List.exists (fun u -> match u with
                           | [] -> true
                           | _ :: _ -> false) us
  then None
  else Some us
| None -> None

(** val dred_trans : mtl -> int -> int -> dtrans -> dtrans **)

let dred_trans _ p q0 t0 =
  { dt_src = t0.dt_src; dt_label = t0.dt_label; dt_guard = t0.dt_guard;
    dt_resets = t0.dt_resets; dt_tgt = (red p q0 t0.dt_tgt) }

(** val dsim : mtl -> int -> int -> dtrans -> dtrans -> bool **)

let dsim root p q0 t0 t' =
  (&&)
    ((&&)
      ((&&) (set_eqb alit_eq_dec t0.dt_label t'.dt_label)
        (set_eqb (dconj_dec root) t0.dt_guard t'.dt_guard))
      (set_eqb (clock_eq_dec root) t0.dt_resets t'.dt_resets))
    ((=) (red p q0 t0.dt_tgt) (red p q0 t'.dt_tgt))

(** val dout : mtl -> dTA -> int -> dtrans list **)

let dout _ d s =
  List.filter (fun t0 -> (=) t0.dt_src s) d.dta_trans

(** val dcovers : mtl -> dTA -> int -> int -> int -> int -> bool **)

let dcovers root d p q0 s s' =
  List.for_all (fun t0 ->
    List.exists (fun t' -> dsim root p q0 t0 t') (dout root d s'))
    (dout root d s)

(** val dstates_mergeable : mtl -> dTA -> int -> int -> bool **)

let dstates_mergeable root d p q0 =
  (&&)
    ((&&)
      ((&&)
        ((&&)
          ((&&) ((&&) (not ((=) p q0)) ((<) p d.dta_nstates))
            ((<) q0 d.dta_nstates))
          ((=) (in_nat p d.dta_accepting) (in_nat q0 d.dta_accepting)))
        (if oinv_dec root (inv_norm root (d.dta_inv p))
              (inv_norm root (d.dta_inv q0))
         then true
         else false)) (dcovers root d p q0 q0 p)) (dcovers root d p q0 p q0)

(** val dmerge_states : mtl -> int -> int -> dTA -> dTA **)

let dmerge_states root p q0 d =
  { dta_nstates = d.dta_nstates; dta_init = (red p q0 d.dta_init);
    dta_trans =
    (List.map (dred_trans root p q0)
      (List.filter (fun t0 -> not ((=) t0.dt_src q0)) d.dta_trans));
    dta_accepting = d.dta_accepting; dta_inv = d.dta_inv }

(** val dtry_merge_states : mtl -> int -> int -> dTA -> dTA **)

let dtry_merge_states root p q0 d =
  if dstates_mergeable root d p q0 then dmerge_states root p q0 d else d

(** val dmerge_states_all : mtl -> dTA -> dTA **)

let dmerge_states_all root d =
  fold_left (fun b s -> dtry_merge_states root s b.dta_init b)
    ((fun s n -> List.init n (fun i -> s + i)) 0 d.dta_nstates) d

(** val table_n : int -> (int -> 'a1) -> 'a1 list **)

let table_n n f =
  List.map f ((fun s n -> List.init n (fun i -> s + i)) 0 n)

(** val lookup_n : int -> 'a1 -> (int -> 'a1) -> 'a1 list -> int -> 'a1 **)

let lookup_n n d f tbl l =
  if (<) l n
  then (fun n l d -> match List.nth_opt l n with Some x -> x | None -> d) l
         tbl d
  else f l

(** val enc_w : int -> int -> int -> int **)

let enc_w k l k0 =
  (+) (( * ) l k) k0

(** val split_trans_w :
    mtl -> int -> (int -> uinv list) -> dtrans -> dtrans list **)

let split_trans_w root k di t0 =
  List.concat_map (fun j ->
    List.map (fun k0 -> { dt_src = (enc_w k t0.dt_src j); dt_label =
      t0.dt_label; dt_guard =
      (dnf_and root t0.dt_guard
        (subst_guard root t0.dt_resets (entry_cond root (di t0.dt_tgt) k0)));
      dt_resets = t0.dt_resets; dt_tgt = (enc_w k t0.dt_tgt k0) })
      ((fun s n -> List.init n (fun i -> s + i)) 0
        (List.length (di t0.dt_tgt))))
    ((fun s n -> List.init n (fun i -> s + i)) 0 k)

(** val split_inv_w :
    mtl -> int -> int -> (int -> uinv list) -> int -> uinv list option **)

let split_inv_w _ k kmx di s =
  let k0 = (fun n m -> if m = 0 then n else n mod m) s k in
  if (=) k0 kmx
  then None
  else (match List.nth_opt (di ((fun n m -> if m = 0 then 0 else n / m) s k))
                k0 with
        | Some u -> Some (u :: [])
        | None -> None)

(** val split_w : mtl -> int -> int -> (int -> uinv list) -> dTA -> dTA **)

let split_w root k kmx di d =
  { dta_nstates = (( * ) d.dta_nstates k); dta_init =
    (enc_w k d.dta_init kmx); dta_trans =
    (List.concat_map (split_trans_w root k di) d.dta_trans); dta_accepting =
    (List.concat_map (fun l ->
      List.map (enc_w k l) ((fun s n -> List.init n (fun i -> s + i)) 0 k))
      d.dta_accepting); dta_inv = (split_inv_w root k kmx di) }

(** val kmax_w : mtl -> (int -> uinv list) -> dTA -> int **)

let kmax_w _ di d =
  (List.fold_left max 0)
    (List.map (fun l -> List.length (di l))
      (List.append
        ((fun s n -> List.init n (fun i -> s + i)) 0 d.dta_nstates)
        (List.map (fun t0 -> t0.dt_tgt) d.dta_trans)))

(** val split_fast : mtl -> dTA -> dTA **)

let split_fast root d =
  let n = d.dta_nstates in
  let di = lookup_n n [] (disj_inv root d) (table_n n (disj_inv root d)) in
  let km = kmax_w root di d in split_w root ((fun n -> n + 1) km) km di d

(** val export : mtl -> tBA -> dTA **)

let export root a =
  dmerge_states_all root
    (dprune_all root
      (explode_all root
        (normalize_d root
          (split_fast root
            (normalize_d root (merge_transitions root (of_tba root a)))))))

(** val export_all : mtl -> tBA -> dTA **)

let export_all root a =
  dmerge_states_all root
    (dprune_all root
      (explode_all root
        (normalize_d root
          (split_all root
            (normalize_d root (merge_transitions root (of_tba root a)))))))

(** val dc_clocks : mtl -> dconstraint -> clock list **)

let dc_clocks _ = function
| DSingle k -> k.guard_clock :: []
| DDiff (x, y, _) -> x :: (y :: [])

(** val trans_reads : mtl -> dtrans -> clock list **)

let trans_reads root t0 =
  List.concat_map (List.concat_map (dc_clocks root)) t0.dt_guard

(** val inv_reads : mtl -> uinv list option -> clock list **)

let inv_reads _ = function
| Some us -> List.concat_map (List.map fst) us
| None -> []

(** val mem_clock : mtl -> clock -> clock list -> bool **)

let mem_clock root x l =
  if (fun eq a l -> List.exists (eq a) l) (clock_eq_dec root) x l
  then true
  else false

(** val inv_table : mtl -> dTA -> clock list list **)

let inv_table root d =
  List.map (fun s -> inv_reads root (d.dta_inv s))
    ((fun s n -> List.init n (fun i -> s + i)) 0 d.dta_nstates)

(** val live0 : mtl -> dTA -> clock list list -> clock -> int list **)

let live0 root d tbl x =
  List.append
    (List.filter (fun s ->
      mem_clock root x
        ((fun n l d -> match List.nth_opt l n with Some x -> x | None -> d) s
          tbl []))
      ((fun s n -> List.init n (fun i -> s + i)) 0 d.dta_nstates))
    (List.map (fun t0 -> t0.dt_src)
      (List.filter (fun t0 -> mem_clock root x (trans_reads root t0))
        d.dta_trans))

(** val live_step0 :
    mtl -> dTA -> clock -> int list -> int list -> int list **)

let live_step0 root d x s frontier =
  nodup (=)
    (List.filter (fun s0 -> not (in_nat s0 s))
      (List.map (fun t0 -> t0.dt_src)
        (List.filter (fun t0 ->
          (&&) (in_nat t0.dt_tgt frontier)
            (not (mem_clock root x t0.dt_resets))) d.dta_trans)))

(** val live_search :
    mtl -> dTA -> clock -> int -> int list -> int list -> int list **)

let rec live_search root d x n s frontier =
  (fun fO fS n -> if n = 0 then fO () else fS (n - 1))
    (fun _ -> s)
    (fun m ->
    match frontier with
    | [] -> s
    | _ :: _ ->
      let new0 = live_step0 root d x s frontier in
      live_search root d x m (List.append s new0) new0)
    n

(** val live_set : mtl -> dTA -> clock list list -> clock -> int list **)

let live_set root d tbl x =
  let s0 = nodup (=) (live0 root d tbl x) in
  live_search root d x ((fun n -> n + 1) d.dta_nstates) s0 s0

(** val live_ok :
    mtl -> dTA -> clock list list -> clock -> int list -> bool **)

let live_ok root d tbl x s =
  (&&)
    ((&&) (not (in_nat d.dta_init s))
      (List.for_all (fun s0 ->
        (||)
          (not
            (mem_clock root x
              ((fun n l d -> match List.nth_opt l n with Some x -> x | None -> d)
                s0 tbl []))) (in_nat s0 s))
        ((fun s n -> List.init n (fun i -> s + i)) 0 d.dta_nstates)))
    (List.for_all (fun t0 ->
      (&&)
        ((||) (not (mem_clock root x (trans_reads root t0)))
          (in_nat t0.dt_src s))
        ((||)
          ((||) (mem_clock root x t0.dt_resets) (not (in_nat t0.dt_tgt s)))
          (in_nat t0.dt_src s))) d.dta_trans)

(** val init_free : mtl -> dTA -> bool **)

let init_free root d =
  let tbl = inv_table root d in
  List.for_all (fun x -> live_ok root d tbl x (live_set root d tbl x))
    (all_clocks root)

(** val s_and : mtl -> ltl -> ltl -> ltl **)

let s_and _ p q0 =
  match p with
  | LTrue -> q0
  | LFalse -> (match q0 with
               | LTrue -> p
               | _ -> LFalse)
  | _ -> (match q0 with
          | LTrue -> p
          | LFalse -> LFalse
          | _ -> LAnd (p, q0))

(** val s_or : mtl -> ltl -> ltl -> ltl **)

let s_or _ p q0 =
  match p with
  | LTrue -> (match q0 with
              | LFalse -> p
              | _ -> LTrue)
  | LFalse -> q0
  | _ -> (match q0 with
          | LTrue -> LTrue
          | LFalse -> p
          | _ -> LOr (p, q0))

(** val s_next : mtl -> ltl -> ltl **)

let s_next _ p = match p with
| LTrue -> LTrue
| LFalse -> LFalse
| _ -> LNext p

(** val s_until : mtl -> ltl -> ltl -> ltl **)

let s_until _ p q0 = match q0 with
| LTrue -> LTrue
| LFalse -> LFalse
| _ -> (match p with
        | LFalse -> q0
        | _ -> LUntil (p, q0))

(** val s_release : mtl -> ltl -> ltl -> ltl **)

let s_release _ p q0 = match q0 with
| LTrue -> LTrue
| LFalse -> LFalse
| _ -> (match p with
        | LTrue -> q0
        | _ -> LRelease (p, q0))

(** val ltl_simp : mtl -> ltl -> ltl **)

let rec ltl_simp root f = match f with
| LAnd (p, q0) -> s_and root (ltl_simp root p) (ltl_simp root q0)
| LOr (p, q0) -> s_or root (ltl_simp root p) (ltl_simp root q0)
| LNext p -> s_next root (ltl_simp root p)
| LUntil (p, q0) -> s_until root (ltl_simp root p) (ltl_simp root q0)
| LRelease (p, q0) -> s_release root (ltl_simp root p) (ltl_simp root q0)
| _ -> f

type evset =
| EvIn of action list
| EvOut of action list

(** val memb : action -> action list -> bool **)

let memb a l =
  if (fun eq a l -> List.exists (eq a) l) (=) a l then true else false

(** val meet : evset -> alit -> evset **)

let meet e = function
| (a, pos) ->
  if pos
  then (match e with
        | EvIn l -> if memb a l then EvIn (a :: []) else EvIn []
        | EvOut l -> if memb a l then EvIn [] else EvIn (a :: []))
  else (match e with
        | EvIn l -> EvIn (remove (=) a l)
        | EvOut l -> EvOut (a :: l))

(** val evset_of_label : alit list -> evset **)

let evset_of_label l =
  fold_left meet l (EvOut [])

(** val ev_union : evset -> evset -> evset **)

let ev_union e f =
  match e with
  | EvIn a ->
    (match f with
     | EvIn b -> EvIn (List.append a b)
     | EvOut b -> EvOut (List.filter (fun y -> not (memb y a)) b))
  | EvOut a ->
    (match f with
     | EvIn b -> EvOut (List.filter (fun y -> not (memb y b)) a)
     | EvOut b -> EvOut (List.filter (fun y -> memb y b) a))

type scase = evset * dconj

type strans = { st_src : int; st_resets : clock list; st_tgt : int;
                st_cases : scase list }

type sDTA = { sdta_nstates : int; sdta_init : int; sdta_trans : strans list;
              sdta_accepting : int list; sdta_inv : (int -> uinv list option) }

(** val add_case : mtl -> scase -> scase list -> scase list **)

let rec add_case root x = function
| [] -> x :: []
| y :: r ->
  if dconj_dec root (snd x) (snd y)
  then ((ev_union (fst y) (fst x)), (snd y)) :: r
  else y :: (add_case root x r)

(** val add_cases : mtl -> scase list -> scase list -> scase list **)

let add_cases root xs cs =
  (fun f a l -> List.fold_right f l a) (add_case root) cs xs

(** val cases_of : mtl -> dtrans -> scase list **)

let cases_of _ t0 =
  List.map (fun c -> ((evset_of_label t0.dt_label), c)) t0.dt_guard

(** val same_skey : mtl -> strans -> dtrans -> bool **)

let same_skey root g t0 =
  (&&) ((&&) ((=) g.st_src t0.dt_src) ((=) g.st_tgt t0.dt_tgt))
    (if List.equal (clock_eq_dec root) g.st_resets t0.dt_resets
     then true
     else false)

(** val ins : mtl -> dtrans -> strans list -> strans list **)

let rec ins root t0 = function
| [] ->
  { st_src = t0.dt_src; st_resets = t0.dt_resets; st_tgt = t0.dt_tgt;
    st_cases = (add_cases root (cases_of root t0) []) } :: []
| g :: r ->
  if same_skey root g t0
  then { st_src = g.st_src; st_resets = g.st_resets; st_tgt = g.st_tgt;
         st_cases = (add_cases root (cases_of root t0) g.st_cases) } :: r
  else g :: (ins root t0 r)

(** val group0 : mtl -> dtrans list -> strans list **)

let group0 root ts =
  (fun f a l -> List.fold_right f l a) (ins root) [] ts

(** val symbolic : mtl -> dTA -> sDTA **)

let symbolic root d =
  { sdta_nstates = d.dta_nstates; sdta_init = d.dta_init; sdta_trans =
    (group0 root d.dta_trans); sdta_accepting = d.dta_accepting; sdta_inv =
    d.dta_inv }

(** val neg : mtl -> mtl **)

let rec neg = function
| MTrue -> MFalse
| MFalse -> MTrue
| MAtom a -> MNotAtom a
| MNotAtom a -> MAtom a
| MAnd (p, q0) -> MOr ((neg p), (neg q0))
| MOr (p, q0) -> MAnd ((neg p), (neg q0))
| MNext p -> MNext (neg p)
| MU (p, q0) -> MR ((neg p), (neg q0))
| MR (p, q0) -> MU ((neg p), (neg q0))
| MUhatLe (d, p, q0) -> MRhatLe (d, (neg p), (neg q0))
| MUhatGe (d, p, q0) -> MRhatGe (d, (neg p), (neg q0))
| MRhatLe (d, p, q0) -> MUhatLe (d, (neg p), (neg q0))
| MRhatGe (d, p, q0) -> MUhatGe (d, (neg p), (neg q0))
| MUhatLt (d, p, q0) -> MRhatLt (d, (neg p), (neg q0))
| MUhatGt (d, p, q0) -> MRhatGt (d, (neg p), (neg q0))
| MRhatLt (d, p, q0) -> MUhatLt (d, (neg p), (neg q0))
| MRhatGt (d, p, q0) -> MUhatGt (d, (neg p), (neg q0))

(** val upper_wait : mtl -> ltl -> bool **)

let upper_wait root = function
| LAnd (l, l0) ->
  (match l with
   | LAtom l1 ->
     (match l1 with
      | LCLe (x, _) ->
        (match l0 with
         | LAnd (l2, _) ->
           (match l2 with
            | LAtom l4 ->
              (match l4 with
               | LUnch y -> if clock_eq_dec root x y then true else false
               | _ -> false)
            | _ -> false)
         | _ -> false)
      | LCLt (x, _) ->
        (match l0 with
         | LAnd (l2, _) ->
           (match l2 with
            | LAtom l4 ->
              (match l4 with
               | LUnch y -> if clock_eq_dec root x y then true else false
               | _ -> false)
            | _ -> false)
         | _ -> false)
      | _ -> false)
   | _ -> false)
| _ -> false

(** val weak : mtl -> ltl -> ltl **)

let rec weak root f = match f with
| LAnd (p, q0) -> LAnd ((weak root p), (weak root q0))
| LOr (p, q0) -> LOr ((weak root p), (weak root q0))
| LNext p -> LNext (weak root p)
| LUntil (p, q0) ->
  if upper_wait root p
  then lW root (weak root p) (weak root q0)
  else LUntil ((weak root p), (weak root q0))
| LRelease (p, q0) -> LRelease ((weak root p), (weak root q0))
| _ -> f

(** val is_true : mtl -> bool **)

let is_true = function
| MTrue -> true
| _ -> false

(** val is_false : mtl -> bool **)

let is_false = function
| MFalse -> true
| _ -> false

(** val rw1 : mtl -> mtl **)

let rw1 g = match g with
| MU (a, b) ->
  if is_true a
  then (match b with
        | MOr (c, e) ->
          if is_false c
          then (match e with
                | MRhatGe (_, x, p) ->
                  if is_false x then MU (MTrue, (MR (MFalse, p))) else g
                | MRhatGt (_, x, p) ->
                  if is_false x then MU (MTrue, (MR (MFalse, p))) else g
                | _ -> g)
          else g
        | _ -> g)
  else g
| MR (a, b) ->
  if is_false a
  then (match b with
        | MAnd (c, e) ->
          if is_true c
          then (match e with
                | MUhatGe (_, x, p) ->
                  if is_true x then MR (MFalse, (MU (MTrue, p))) else g
                | MUhatGt (_, x, p) ->
                  if is_true x then MR (MFalse, (MU (MTrue, p))) else g
                | _ -> g)
          else g
        | _ -> g)
  else g
| _ -> g

(** val recur : mtl -> mtl **)

let rec recur = function
| MAnd (p, q0) -> rw1 (MAnd ((recur p), (recur q0)))
| MOr (p, q0) -> rw1 (MOr ((recur p), (recur q0)))
| MNext p -> rw1 (MNext (recur p))
| MU (p, q0) -> rw1 (MU ((recur p), (recur q0)))
| MR (p, q0) -> rw1 (MR ((recur p), (recur q0)))
| MUhatLe (d, p, q0) -> rw1 (MUhatLe (d, (recur p), (recur q0)))
| MUhatGe (d, p, q0) -> rw1 (MUhatGe (d, (recur p), (recur q0)))
| MRhatLe (d, p, q0) -> rw1 (MRhatLe (d, (recur p), (recur q0)))
| MRhatGe (d, p, q0) -> rw1 (MRhatGe (d, (recur p), (recur q0)))
| MUhatLt (d, p, q0) -> rw1 (MUhatLt (d, (recur p), (recur q0)))
| MUhatGt (d, p, q0) -> rw1 (MUhatGt (d, (recur p), (recur q0)))
| MRhatLt (d, p, q0) -> rw1 (MRhatLt (d, (recur p), (recur q0)))
| MRhatGt (d, p, q0) -> rw1 (MRhatGt (d, (recur p), (recur q0)))
| x -> x

(** val alloc_item :
    mtl -> (clock -> clock) -> clock_constraint option -> clock_constraint
    option **)

let alloc_item _ alloc = function
| Some k ->
  Some { guard_clock = (alloc k.guard_clock); guard_comparison =
    k.guard_comparison; guard_bound = k.guard_bound }
| None -> None

(** val alloc_resets : mtl -> (clock -> clock) -> clock list -> clock list **)

let alloc_resets root alloc rs =
  nodup (clock_eq_dec root) (List.map alloc rs)

(** val alloc_transition :
    mtl -> (clock -> clock) -> tba_transition -> tba_transition **)

let alloc_transition root alloc t0 =
  { bt_source = t0.bt_source; bt_label = t0.bt_label; bt_guard =
    (List.map (alloc_item root alloc) t0.bt_guard); bt_resets =
    (alloc_resets root alloc t0.bt_resets); bt_target = t0.bt_target }

(** val allocate_clocks : mtl -> (clock -> clock) -> tBA -> tBA **)

let allocate_clocks root alloc a =
  with_transitions root a
    (List.map (alloc_transition root alloc) a.tba_transitions)

(** val guard_clocks : mtl -> guard -> clock list **)

let guard_clocks _ g =
  List.concat_map (fun o ->
    match o with
    | Some k -> k.guard_clock :: []
    | None -> []) g

(** val same_class_eq : mtl -> (clock -> clock) -> clock -> clock -> bool **)

let same_class_eq root alloc r y =
  if clock_eq_dec root (alloc r) (alloc y) then clock_eqb root r y else true

(** val alloc_ok :
    mtl -> (clock -> clock) -> (int -> clock list) -> tBA -> bool **)

let alloc_ok root alloc live1 a =
  (&&)
    (List.for_all (fun t0 ->
      (&&)
        ((&&)
          (List.for_all (fun x -> clock_in root x (live1 t0.bt_source))
            (guard_clocks root t0.bt_guard))
          (List.for_all (fun x ->
            (||) (clock_in root x t0.bt_resets)
              (clock_in root x (live1 t0.bt_source))) (live1 t0.bt_target)))
        (List.for_all (fun r ->
          List.for_all (fun y -> same_class_eq root alloc r y)
            (live1 t0.bt_target)) t0.bt_resets)) a.tba_transitions)
    (List.for_all (fun x ->
      List.for_all (fun y -> same_class_eq root alloc x y) (live1 a.tba_init))
      (live1 a.tba_init))

(** val try_allocate :
    mtl -> (clock -> clock) -> (int -> clock list) -> tBA -> tBA **)

let try_allocate root alloc live1 a =
  if alloc_ok root alloc live1 a then allocate_clocks root alloc a else a

(** val alloc_pass : mtl -> certifier -> tBA -> tBA **)

let alloc_pass root cert a =
  try_allocate root (fst (cert a)) (snd (cert a)) a

(** val prune_trans : mtl -> (tba_transition -> bool) -> tBA -> tBA **)

let prune_trans root keep a =
  with_transitions root a (List.filter keep a.tba_transitions)

(** val upper_cmp : clock_comparison -> bool **)

let upper_cmp = function
| CLe -> true
| CLt -> true
| _ -> false

(** val guard_item_ok :
    mtl -> (int -> clock list) -> (int -> clock list) -> int ->
    clock_constraint option -> bool **)

let guard_item_ok root live1 lle q1 = function
| Some k ->
  (||) (clock_in root k.guard_clock (live1 q1))
    ((&&) (upper_cmp k.guard_comparison)
      (clock_in root k.guard_clock (lle q1)))
| None -> true

(** val flow_ok :
    mtl -> (int -> clock list) -> (int -> clock list) -> int ->
    tba_transition -> tba_transition -> bool **)

let flow_ok root live1 lle q1 t1 t2 =
  (&&)
    (List.for_all (fun x ->
      (||)
        ((&&) (clock_in root x t1.bt_resets) (clock_in root x t2.bt_resets))
        ((&&)
          ((&&) (not (clock_in root x t1.bt_resets))
            (not (clock_in root x t2.bt_resets)))
          (clock_in root x (live1 q1)))) (live1 t1.bt_target))
    (List.for_all (fun x ->
      (||) (clock_in root x t1.bt_resets)
        ((&&) (not (clock_in root x t2.bt_resets))
          ((||) (clock_in root x (lle q1)) (clock_in root x (live1 q1)))))
      (lle t1.bt_target))

(** val lit_at : int option -> alit -> bool **)

let lit_at c l =
  match c with
  | Some a -> if (=) a (fst l) then snd l else not (snd l)
  | None -> not (snd l)

(** val label_at : int option -> alit list -> bool **)

let label_at c ls =
  List.for_all (lit_at c) ls

(** val mentioned : mtl -> tBA -> int list **)

let mentioned _ a =
  nodup (=)
    (List.concat_map (fun t0 -> List.map fst t0.bt_label) a.tba_transitions)

(** val cells : mtl -> tBA -> int option list **)

let cells root a =
  None :: (List.map (fun a0 -> Some a0) (mentioned root a))

(** val land0 : bool -> (unit -> bool) -> bool **)

let land0 a b =
  if a then b () else false

(** val dom_step :
    mtl -> (int -> int -> bool) -> (int -> clock list) -> (int -> clock list)
    -> (tba_transition -> bool) -> tBA -> int -> int option -> tba_transition
    -> tba_transition -> bool **)

let dom_step root sim0 live1 lle keep a q1 c t2 t1 =
  land0 ((=) t1.bt_source q1) (fun _ ->
    land0 (keep t1) (fun _ ->
      land0 (label_at c t1.bt_label) (fun _ ->
        land0 (guard_implied root t2.bt_guard t1.bt_guard) (fun _ ->
          land0 (List.for_all (guard_item_ok root live1 lle q1) t1.bt_guard)
            (fun _ ->
            land0 (flow_ok root live1 lle q1 t1 t2) (fun _ ->
              land0 (sim0 t1.bt_target t2.bt_target) (fun _ ->
                (<) t1.bt_target a.tba_nstates)))))))

(** val mem_nat : int -> int list -> bool **)

let mem_nat q0 l =
  List.exists ((=) q0) l

(** val prune_ok :
    mtl -> (int -> int -> bool) -> (int -> clock list) -> (int -> clock list)
    -> (tba_transition -> bool) -> tBA -> bool **)

let prune_ok root sim0 live1 lle keep a =
  land0 (sim0 a.tba_init a.tba_init) (fun _ ->
    List.for_all (fun q1 ->
      List.for_all (fun q2 ->
        if sim0 q1 q2
        then (&&)
               (implb (mem_nat q2 a.tba_accepting)
                 (mem_nat q1 a.tba_accepting))
               (List.for_all (fun c ->
                 List.for_all (fun t2 ->
                   if (&&) ((=) t2.bt_source q2) (label_at c t2.bt_label)
                   then List.exists (fun t1 ->
                          dom_step root sim0 live1 lle keep a q1 c t2 t1)
                          a.tba_transitions
                   else true) a.tba_transitions) (cells root a))
        else true) ((fun s n -> List.init n (fun i -> s + i)) 0 a.tba_nstates))
      ((fun s n -> List.init n (fun i -> s + i)) 0 a.tba_nstates))

(** val try_prune :
    mtl -> (int -> int -> bool) -> (int -> clock list) -> (int -> clock list)
    -> (tba_transition -> bool) -> tBA -> tBA **)

let try_prune root sim0 live1 lle keep a =
  if prune_ok root sim0 live1 lle keep a then prune_trans root keep a else a

(** val prune_pass : mtl -> prune_certifier -> tBA -> tBA **)

let prune_pass root cert a =
  try_prune root (fst (fst (fst (cert a)))) (snd (fst (fst (cert a))))
    (snd (fst (cert a))) (snd (cert a)) a

(** val cell_label : mtl -> tBA -> int option -> alit list **)

let cell_label root a = function
| Some a0 -> (a0, true) :: []
| None -> List.map (fun m -> (m, false)) (mentioned root a)

(** val relabel : mtl -> tba_transition -> alit list -> tba_transition **)

let relabel _ t0 l =
  { bt_source = t0.bt_source; bt_label = l; bt_guard = t0.bt_guard;
    bt_resets = t0.bt_resets; bt_target = t0.bt_target }

(** val split_cells : mtl -> tBA -> tBA **)

let split_cells root a =
  with_transitions root a
    (List.concat_map (fun t0 ->
      List.map (fun c -> relabel root t0 (cell_label root a c))
        (List.filter (fun c -> label_at c t0.bt_label) (cells root a)))
      a.tba_transitions)

(** val optimize_export : mtl -> int -> tBA -> dTA **)

let optimize_export root n a =
  export root (optimize root n a)

(** val optimize_export_all : mtl -> int -> tBA -> dTA **)

let optimize_export_all root n a =
  export_all root (optimize root n a)

(*
  MTL_to_TBA_DomPrune.v

  Removal of dominated transitions, checked by a simulation certificate.

  Two transitions out of the same location may overlap: whenever the
  second is enabled, so is the first, and the first leads to a location
  that can do everything the second one's target can do.  The second is
  then redundant for the language, although it is not redundant for a
  model checker, which explores both.  Generated automata contain many such
  pairs (the translation guesses which obligations are pending).

  The set of transitions to keep is given by an unverified procedure,
  together with a relation [sim] between locations ("q1 simulates q2") and
  sets [live q] and [lle q] of clocks.  What is proved is a boolean checker of local
  conditions on this certificate, and the theorem that the automaton
  restricted to the kept transitions accepts the same timed words whenever
  the check succeeds.  [try_prune] returns the automaton unchanged when the
  check fails, so the pass preserves the language for every certificate.

  Conditions (q1 simulates q2 when [sim q1 q2]):

    (init)   the initial location simulates itself;
    (accept) if q2 is accepting then so is q1;
    (step)   for every transition t2 out of q2 there is a KEPT transition
             t1 out of q1 with
               - label(t1) included in label(t2),
               - guard(t2) implies guard(t1), and the clocks of guard(t1)
                 are in live(q1), or are upper bounds on clocks of lle(q1),
               - every clock of live(target t1) is reset by both t1 and t2,
                 or by neither and is in live(q1); every clock of
                 lle(target t1) is reset by t1, or by neither and is in
                 lle(q1) or live(q1),
               - the target of t1 simulates the target of t2.

  The clocks in [live q1] are those on which the valuations of the two runs
  are kept equal; the clocks in [lle q1] are those on which the run of q1 has
  a value at most that of the run of q2, which suffices for upper bounds;
  the resets of t1 and t2 may differ elsewhere.  No axiom
  is added to those of the chain.
*)

Require Import Arith Lia List Bool Reals Lra.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import MTL_to_TBA_Invariants.
Require Import MTL_to_TBA_Optimizations.
Import ListNotations.
Open Scope R_scope.

Section DomPrune.

Variable root : mtl.
Variable sim : nat -> nat -> bool.
Variable live : nat -> list (Clock root).
Variable lle : nat -> list (Clock root).
Variable keep : tba_transition root -> bool.

(* ====================================================================== *)
(* 1. The pruned automaton and the checker                                *)
(* ====================================================================== *)

Definition prune_trans (A : TBA root) : TBA root :=
  with_transitions A (filter keep (tba_transitions A)).

Definition dp_guard_clocks (g : guard root) : list (Clock root) :=
  flat_map (fun o => match o with
                     | Some k => [guard_clock k]
                     | None => []
                     end) g.

Definition upper_cmp (c : clock_comparison) : bool :=
  match c with CLe | CLt => true | _ => false end.

(* A guard item of t1 is safe at q1 when its clock is kept equal in the two
   runs, or kept smaller or equal in the run of t1 and the item is an upper
   bound. *)
Definition guard_item_ok (q1 : nat) (o : option (clock_constraint root)) : bool :=
  match o with
  | None => true
  | Some k => clock_in (guard_clock k) (live q1) ||
              (upper_cmp (guard_comparison k) && clock_in (guard_clock k) (lle q1))
  end.

Definition flow_ok (q1 : nat) (t1 t2 : tba_transition root) : bool :=
  forallb (fun x =>
    (clock_in x (bt_resets t1) && clock_in x (bt_resets t2)) ||
    (negb (clock_in x (bt_resets t1)) && negb (clock_in x (bt_resets t2)) &&
     clock_in x (live q1)))
    (live (bt_target t1)) &&
  forallb (fun x =>
    clock_in x (bt_resets t1) ||
    (negb (clock_in x (bt_resets t2)) &&
     (clock_in x (lle q1) || clock_in x (live q1))))
    (lle (bt_target t1)).

(* Letters are grouped in cells: one cell for each action mentioned in a label
   of the automaton, and one cell [None] for all the other actions.  A label
   holds on a letter iff it holds on the cell of the letter. *)
Definition lit_at (c : option nat) (l : alit) : bool :=
  match c with
  | None => negb (snd l)
  | Some a => if Nat.eqb a (fst l) then snd l else negb (snd l)
  end.

Definition label_at (c : option nat) (ls : list alit) : bool :=
  forallb (lit_at c) ls.

(* Each mentioned action once: the cells, and the transitions produced by the
   splitting, are then not repeated. *)
Definition mentioned (A : TBA root) : list nat :=
  nodup Nat.eq_dec (flat_map (fun t => map fst (bt_label t)) (tba_transitions A)).

Definition cell_of (A : TBA root) (p : nat) : option nat :=
  if existsb (Nat.eqb p) (mentioned A) then Some p else None.

Definition cells (A : TBA root) : list (option nat) :=
  None :: map (fun a => Some a) (mentioned A).

Lemma cell_of_in : forall A p, In (cell_of A p) (cells A).
Proof.
  intros A p. unfold cell_of, cells.
  destruct (existsb (Nat.eqb p) (mentioned A)) eqn:E.
  - right. apply in_map_iff. exists p. split; [reflexivity|].
    apply existsb_exists in E. destruct E as [x [Hx Ex]].
    apply Nat.eqb_eq in Ex. subst. exact Hx.
  - left. reflexivity.
Qed.

Lemma label_at_iff :
  forall A (t : tba_transition root) p,
    In t (tba_transitions A) ->
    (label_at (cell_of A p) (bt_label t) = true <->
     Forall (alit_holds p) (bt_label t)).
Proof.
  intros A t p Ht. unfold label_at. rewrite forallb_forall, Forall_forall.
  assert (Hm : forall l, In l (bt_label t) -> In (fst l) (mentioned A)).
  { intros l Hl. unfold mentioned. apply nodup_In. apply in_flat_map. exists t.
    split; [exact Ht|]. apply in_map. exact Hl. }
  split; intros H l Hl; specialize (H l Hl).
  - unfold alit_holds. unfold cell_of in H.
    destruct (existsb (Nat.eqb p) (mentioned A)) eqn:E; unfold lit_at in H.
    + destruct (Nat.eqb p (fst l)) eqn:Ep.
      * apply Nat.eqb_eq in Ep. subst. destruct (snd l); [reflexivity | discriminate].
      * apply Nat.eqb_neq in Ep. destruct (snd l); [discriminate|exact Ep].
    + destruct (snd l); [discriminate|].
      intro Hc. pose proof (Hm l Hl) as Hin. rewrite <- Hc in Hin.
      assert (existsb (Nat.eqb p) (mentioned A) = true).
      { apply existsb_exists. exists p. split; [exact Hin|]. apply Nat.eqb_refl. }
      congruence.
  - unfold alit_holds in H. unfold cell_of.
    destruct (existsb (Nat.eqb p) (mentioned A)) eqn:E; unfold lit_at.
    + destruct (Nat.eqb p (fst l)) eqn:Ep.
      * destruct (snd l); [reflexivity|]. apply Nat.eqb_eq in Ep. exfalso.
        apply H. exact Ep.
      * destruct (snd l); simpl.
        -- exfalso. apply Nat.eqb_neq in Ep. apply Ep. exact H.
        -- reflexivity.
    + destruct (snd l); simpl.
      * exfalso. pose proof (Hm l Hl) as Hin. 
        assert (Ep : p = fst l) by exact H. rewrite <- Ep in Hin.
        assert (existsb (Nat.eqb p) (mentioned A) = true).
        { apply existsb_exists. exists p. split; [exact Hin|]. apply Nat.eqb_refl. }
        congruence.
      * reflexivity.
Qed.

(* Lazy conjunction.  The extracted code of [andb] evaluates both of its
   arguments; the checker runs on thousands of transitions, so the expensive
   tests must only be evaluated when the cheap ones succeed. *)
Definition land (a : bool) (b : unit -> bool) : bool :=
  if a then b tt else false.

Lemma land_true : forall a b, land a b = true <-> a = true /\ b tt = true.
Proof.
  intros a b. unfold land. destruct a; split; intro H;
    try (split; [reflexivity | exact H]); try discriminate; try (destruct H; assumption).
Qed.

Definition dom_step (A : TBA root) (q1 : nat) (c : option nat)
    (t2 t1 : tba_transition root) : bool :=
  land (Nat.eqb (bt_source t1) q1) (fun _ =>
  land (keep t1) (fun _ =>
  land (label_at c (bt_label t1)) (fun _ =>
  land (guard_implied (bt_guard t2) (bt_guard t1)) (fun _ =>
  land (forallb (guard_item_ok q1) (bt_guard t1)) (fun _ =>
  land (flow_ok q1 t1 t2) (fun _ =>
  land (sim (bt_target t1) (bt_target t2)) (fun _ =>
  Nat.ltb (bt_target t1) (tba_nstates A)))))))).

Definition mem_nat (q : nat) (l : list nat) : bool := existsb (Nat.eqb q) l.

Lemma mem_nat_iff : forall q l, mem_nat q l = true <-> In q l.
Proof.
  intros q l. unfold mem_nat. rewrite existsb_exists. split.
  - intros [x [Hx E]]. apply Nat.eqb_eq in E. subst. exact Hx.
  - intro H. exists q. split; [exact H|]. apply Nat.eqb_refl.
Qed.

Definition prune_ok (A : TBA root) : bool :=
  land (sim (tba_init A) (tba_init A)) (fun _ =>
  forallb (fun q1 =>
    forallb (fun q2 =>
      if sim q1 q2 then
        (implb (mem_nat q2 (tba_accepting A)) (mem_nat q1 (tba_accepting A)) &&
         forallb (fun c =>
           forallb (fun t2 =>
             if Nat.eqb (bt_source t2) q2 && label_at c (bt_label t2)
             then existsb (fun t1 => dom_step A q1 c t2 t1) (tba_transitions A)
             else true)
             (tba_transitions A))
           (cells A))
      else true)
      (seq 0 (tba_nstates A)))
    (seq 0 (tba_nstates A))).

Definition try_prune (A : TBA root) : TBA root :=
  if prune_ok A then prune_trans A else A.

(* ====================================================================== *)
(* 2. What the checker establishes                                        *)
(* ====================================================================== *)

Lemma dom_step_spec :
  forall A q1 c t2 t1, dom_step A q1 c t2 t1 = true ->
    bt_source t1 = q1 /\ keep t1 = true /\
    label_at c (bt_label t1) = true /\
    guard_implied (bt_guard t2) (bt_guard t1) = true /\
    (forall o, In o (bt_guard t1) ->
       match o with
       | None => True
       | Some k => In (guard_clock k) (live q1) \/
                   (upper_cmp (guard_comparison k) = true /\ In (guard_clock k) (lle q1))
       end) /\
    (forall x, In x (live (bt_target t1)) ->
       (In x (bt_resets t1) /\ In x (bt_resets t2)) \/
       (~ In x (bt_resets t1) /\ ~ In x (bt_resets t2) /\ In x (live q1))) /\
    (forall x, In x (lle (bt_target t1)) ->
       In x (bt_resets t1) \/
       (~ In x (bt_resets t1) /\ ~ In x (bt_resets t2) /\
        (In x (lle q1) \/ In x (live q1)))) /\
    sim (bt_target t1) (bt_target t2) = true /\
    (bt_target t1 < tba_nstates A)%nat.
Proof.
  intros A q1 c t2 t1 H. unfold dom_step in H.
  repeat (rewrite land_true in H; cbv beta in H).
  destruct H as [H1 [H2 [H3 [H4 [H5 [H6 [H7 H8]]]]]]].
  pose proof H6 as H6'.
  apply Nat.eqb_eq in H1. apply Nat.ltb_lt in H8.
  repeat split.
  - exact H1.
  - exact H2.
  - exact H3.
  - exact H4.
  - intros o Ho. rewrite forallb_forall in H5. specialize (H5 o Ho).
    destruct o as [k|]; [|exact I]. unfold guard_item_ok in H5.
    apply orb_true_iff in H5. destruct H5 as [H5|H5].
    + left. apply clock_in_iff. exact H5.
    + apply andb_true_iff in H5. destruct H5 as [Ha Hb].
      right. split; [exact Ha | apply clock_in_iff; exact Hb].
  - intros x Hx. unfold flow_ok in H6. apply andb_true_iff in H6.
    destruct H6 as [H6 _]. rewrite forallb_forall in H6.
    specialize (H6 x Hx). apply orb_true_iff in H6.
    destruct H6 as [H6|H6].
    + apply andb_true_iff in H6. destruct H6 as [Ha Hb].
      left. split; apply clock_in_iff; assumption.
    + repeat rewrite andb_true_iff in H6. destruct H6 as [[Ha Hb] Hc].
      apply negb_true_iff in Ha. apply negb_true_iff in Hb.
      right. split; [|split].
      * intro C. apply clock_in_iff in C. congruence.
      * intro C. apply clock_in_iff in C. congruence.
      * apply clock_in_iff. exact Hc.
  - intros x Hx. unfold flow_ok in H6. apply andb_true_iff in H6.
    destruct H6 as [_ H6]. rewrite forallb_forall in H6.
    specialize (H6 x Hx). apply orb_true_iff in H6.
    destruct (In_dec (@clock_eq_dec root) x (bt_resets t1)) as [E1|E1].
    + left. exact E1.
    + right. destruct H6 as [H6|H6].
      * exfalso. apply E1. apply clock_in_iff. exact H6.
      * apply andb_true_iff in H6. destruct H6 as [Ha Hb].
        apply negb_true_iff in Ha. split; [exact E1|split].
        -- intro C. apply clock_in_iff in C. congruence.
        -- apply orb_true_iff in Hb. destruct Hb as [Hb|Hb];
             [left | right]; apply clock_in_iff; exact Hb.
  - exact H7.
  - exact H8.
Qed.

Lemma prune_ok_spec :
  forall A, prune_ok A = true ->
    sim (tba_init A) (tba_init A) = true /\
    forall q1 q2, (q1 < tba_nstates A)%nat -> (q2 < tba_nstates A)%nat ->
      sim q1 q2 = true ->
      (In q2 (tba_accepting A) -> In q1 (tba_accepting A)) /\
      forall c, In c (cells A) ->
      forall t2, In t2 (tba_transitions A) -> bt_source t2 = q2 ->
        label_at c (bt_label t2) = true ->
        exists t1, In t1 (tba_transitions A) /\ dom_step A q1 c t2 t1 = true.
Proof.
  intros A H. unfold prune_ok in H. rewrite land_true in H. cbv beta in H.
  destruct H as [Hi H]. split; [exact Hi|].
  intros q1 q2 H1 H2 Hs.
  assert (Hq1 : In q1 (seq 0 (tba_nstates A))) by (apply in_seq; lia).
  assert (Hq2 : In q2 (seq 0 (tba_nstates A))) by (apply in_seq; lia).
  rewrite forallb_forall in H. specialize (H q1 Hq1).
  rewrite forallb_forall in H. specialize (H q2 Hq2).
  rewrite Hs in H. cbv iota in H.
  apply andb_true_iff in H. destruct H as [Ha Hb].
  split.
  - intro Hq. apply mem_nat_iff. apply mem_nat_iff in Hq.
    rewrite Hq in Ha. simpl in Ha. exact Ha.
  - intros c Hc t2 Hin Hsrc Hl. rewrite forallb_forall in Hb. specialize (Hb c Hc).
    rewrite forallb_forall in Hb. specialize (Hb t2 Hin).
    apply Nat.eqb_eq in Hsrc. rewrite Hsrc, Hl in Hb. cbv iota in Hb.
    apply existsb_exists in Hb. exact Hb.
Qed.

(* ====================================================================== *)
(* 3. From a word of A to a word of the pruned automaton                  *)
(* ====================================================================== *)

Fixpoint pick {P : tba_transition root -> Prop} (P_dec : forall t, {P t} + {~ P t})
    (l : list (tba_transition root))
    (d : tba_transition root) : tba_transition root :=
  match l with
  | [] => d
  | t :: l' => if P_dec t then t else pick P_dec l' d
  end.

Lemma pick_spec :
  forall P (P_dec : forall t, {P t} + {~ P t}) l d,
    (exists t, In t l /\ P t) -> In (pick P_dec l d) l /\ P (pick P_dec l d).
Proof.
  intros P P_dec l d. induction l as [|t l IH]; intros [t0 [Hin HP]]; [contradiction|].
  simpl. destruct (P_dec t) as [H|N].
  - split; [left; reflexivity | exact H].
  - destruct Hin as [->|Hin]; [contradiction|].
    destruct (IH (ex_intro _ t0 (conj Hin HP))) as [H1 H2].
    split; [right; exact H1 | exact H2].
Qed.

Section Construct.

Variable A : TBA root.
Variable rho : ext_word root.
Variable run : nat -> nat.
Variable t0 : tba_transition root.

(* the transition of A behind each step of the original run *)
Definition T2_dec (i : nat) (t : tba_transition root) :
  {bt_source t = run i /\ bt_target t = run (S i) /\ tba_transition_enabled rho i t} +
  {~ (bt_source t = run i /\ bt_target t = run (S i) /\ tba_transition_enabled rho i t)}.
Proof.
  destruct (Nat.eq_dec (bt_source t) (run i)); [|right; tauto].
  destruct (Nat.eq_dec (bt_target t) (run (S i))); [|right; tauto].
  destruct (tba_transition_enabled_dec rho i t); [left | right]; tauto.
Defined.

Definition T2 (i : nat) : tba_transition root :=
  pick (T2_dec i) (tba_transitions A) t0.

(* the kept transition that answers it from the location q *)
Definition T1 (i q : nat) : tba_transition root :=
  pick (fun t1 => bool_dec (dom_step A q (cell_of A (tw_action (ew_base rho) i)) (T2 i) t1) true)
       (tba_transitions A) t0.

Fixpoint qs (i : nat) : nat :=
  match i with
  | 0%nat => tba_init A
  | S j => bt_target (T1 j (qs j))
  end.

Definition rs (i : nat) : list (Clock root) := bt_resets (T1 i (qs i)).

Fixpoint dpval (i : nat) (x : Clock root) : R :=
  match i with
  | 0%nat => ew_val rho 0 x
  | S j => if clock_in x (rs j)
           then delta (ew_base rho) j
           else dpval j x + delta (ew_base rho) j
  end.

Definition dp_word : ext_word root :=
  {| ew_base := ew_base rho;
     ew_val := dpval;
     ew_reset := fun i x => clock_in x (rs i) |}.

Lemma dp_consistent : clock_consistent rho -> clock_consistent dp_word.
Proof.
  intros [Hnn Hstep]. split.
  - intros i x. simpl. induction i as [|j IH]; simpl.
    + apply Hnn.
    + destruct (clock_in x (rs j)); pose proof (delta_nonneg (ew_base rho) j);
        [assumption | lra].
  - intros i x. simpl. reflexivity.
Qed.

Lemma constraint_transfer :
  forall (rho1 rho2 : ext_word root) i k,
    ew_val rho2 i (guard_clock k) = ew_val rho1 i (guard_clock k) ->
    clock_constraint_holds rho1 i k -> clock_constraint_holds rho2 i k.
Proof.
  intros rho1 rho2 i k H Hh. unfold clock_constraint_holds in *.
  destruct (guard_comparison k); rewrite H; exact Hh.
Qed.

Lemma constraint_transfer_le :
  forall (rho1 rho2 : ext_word root) i k,
    upper_cmp (guard_comparison k) = true ->
    ew_val rho2 i (guard_clock k) <= ew_val rho1 i (guard_clock k) ->
    clock_constraint_holds rho1 i k -> clock_constraint_holds rho2 i k.
Proof.
  intros rho1 rho2 i k Hu H Hh. unfold clock_constraint_holds in *.
  destruct (guard_comparison k); simpl in Hu; try discriminate; lra.
Qed.

Lemma guard_clocks_in :
  forall g o, In o g ->
    match o with
    | Some k => In (guard_clock k) (dp_guard_clocks g)
    | None => True
    end.
Proof.
  intros g [k|] Ho; [|exact I].
  unfold dp_guard_clocks. apply in_flat_map. exists (Some k). split; [exact Ho|].
  simpl. left. reflexivity.
Qed.

Hypothesis Hok : prune_ok A = true.
Hypothesis Hcc : clock_consistent rho.
Hypothesis Hinit : run 0%nat = tba_init A.
Hypothesis Hsteps : forall i,
  (run i < tba_nstates A)%nat /\
  exists t, In t (tba_transitions A) /\
    bt_source t = run i /\ bt_target t = run (S i) /\
    tba_transition_enabled rho i t.

Lemma T2_spec : forall i,
  In (T2 i) (tba_transitions A) /\
  bt_source (T2 i) = run i /\ bt_target (T2 i) = run (S i) /\
  tba_transition_enabled rho i (T2 i).
Proof.
  intro i. destruct (Hsteps i) as [_ [t [Hin [Hs [Hd He]]]]].
  destruct (@pick_spec _ (T2_dec i) (tba_transitions A) t0
            (ex_intro _ t (conj Hin (conj Hs (conj Hd He))))) as [H1 [H2 [H3 H4]]].
  exact (conj H1 (conj H2 (conj H3 H4))).
Qed.

Record dp_inv (i : nat) : Prop := {
  di_sim : sim (qs i) (run i) = true;
  di_lt : (qs i < tba_nstates A)%nat;
  di_val : forall x, In x (live (qs i)) -> dpval i x = ew_val rho i x;
  di_le : forall x, In x (lle (qs i)) -> dpval i x <= ew_val rho i x
}.

Lemma T1_spec : forall i, dp_inv i ->
  In (T1 i (qs i)) (tba_transitions A) /\
  dom_step A (qs i) (cell_of A (tw_action (ew_base rho) i)) (T2 i) (T1 i (qs i)) = true.
Proof.
  intros i Hi.
  destruct (prune_ok_spec A Hok) as [_ Hsp].
  destruct (Hsteps i) as [Hlt _].
  destruct (T2_spec i) as [Hin2 [Hs2 _]].
  destruct (Hsp (qs i) (run i) (di_lt i Hi) Hlt (di_sim i Hi)) as [_ Hex].
  destruct (T2_spec i) as [_ [_ [_ Hen2']]].
  destruct Hen2' as [Hlab2 _].
  assert (Hl2 : label_at (cell_of A (tw_action (ew_base rho) i)) (bt_label (T2 i)) = true).
  { apply (proj2 (label_at_iff A (T2 i) _ Hin2)). exact Hlab2. }
  destruct (Hex _ (cell_of_in A _) (T2 i) Hin2 Hs2 Hl2) as [t1 [Hin1 Hd1]].
  destruct (@pick_spec _
              (fun t1 => bool_dec (dom_step A (qs i) (cell_of A (tw_action (ew_base rho) i)) (T2 i) t1) true)
              (tba_transitions A) t0 (ex_intro _ t1 (conj Hin1 Hd1))) as [H1 H2].
  split; assumption.
Qed.

Lemma dp_invariant : forall i, dp_inv i.
Proof.
  induction i as [|i IH].
  - split.
    + simpl. rewrite Hinit. exact (proj1 (prune_ok_spec A Hok)).
    + simpl. rewrite <- Hinit. exact (proj1 (Hsteps 0%nat)).
    + intros x _. reflexivity.
    + intros x _. simpl. lra.
  - destruct (T1_spec i IH) as [Hin1 Hd].
    destruct (dom_step_spec _ _ _ _ _ Hd)
      as [Hs1 [Hk [Hli [Hgi [Hgc [Hfl [Hfll [Hsim Hlt]]]]]]]].
    destruct (T2_spec i) as [Hin2 [Hs2 [Hd2 Hen2]]].
    destruct Hen2 as [_ [_ Hrm]].
    destruct (conj Hcc Hcc) as [[Hnn Hstep] _].
    split.
    + change (qs (S i)) with (bt_target (T1 i (qs i))).
      rewrite <- Hd2. exact Hsim.
    + exact Hlt.
    + intros x Hx. change (qs (S i)) with (bt_target (T1 i (qs i))) in Hx.
      change (dpval (S i) x) with
        (if clock_in x (rs i) then delta (ew_base rho) i
         else dpval i x + delta (ew_base rho) i).
      rewrite (Hstep i x).
      destruct (Hfl x Hx) as [[Hr1 Hr2]|[Hr1 [Hr2 Hl]]].
      * assert (E : clock_in x (rs i) = true) by (apply clock_in_iff; exact Hr1).
        rewrite E.
        assert (Hrr : ew_reset rho i x = true) by (apply (proj2 (Hrm x)); exact Hr2).
        rewrite Hrr. reflexivity.
      * assert (E : clock_in x (rs i) = false).
        { destruct (clock_in x (rs i)) eqn:Ec; [|reflexivity].
          exfalso. apply Hr1. apply clock_in_iff in Ec. exact Ec. }
        rewrite E.
        assert (Hrr : ew_reset rho i x = false).
        { destruct (ew_reset rho i x) eqn:Ec; [|reflexivity].
          exfalso. apply Hr2. apply (proj1 (Hrm x)). exact Ec. }
        rewrite Hrr. rewrite (di_val i IH x Hl). reflexivity.
    + intros x Hx. change (qs (S i)) with (bt_target (T1 i (qs i))) in Hx.
      change (dpval (S i) x) with
        (if clock_in x (rs i) then delta (ew_base rho) i
         else dpval i x + delta (ew_base rho) i).
      rewrite (Hstep i x).
      destruct (Hfll x Hx) as [Hr1|[Hr1 [Hr2 Hl]]].
      * assert (E : clock_in x (rs i) = true) by (apply clock_in_iff; exact Hr1).
        rewrite E.
        pose proof (Hnn i x) as Hpos.
        destruct (ew_reset rho i x); lra.
      * assert (E : clock_in x (rs i) = false).
        { destruct (clock_in x (rs i)) eqn:Ec; [|reflexivity].
          exfalso. apply Hr1. apply clock_in_iff in Ec. exact Ec. }
        rewrite E.
        assert (Hrr : ew_reset rho i x = false).
        { destruct (ew_reset rho i x) eqn:Ec; [|reflexivity].
          exfalso. apply Hr2. apply (proj1 (Hrm x)). exact Ec. }
        rewrite Hrr.
        assert (Hle : dpval i x <= ew_val rho i x).
        { destruct Hl as [Hl|Hl]; [exact (di_le i IH x Hl)|].
          rewrite (di_val i IH x Hl). lra. }
        lra.
Qed.

Hypothesis Hbuchi : forall n, exists j, (n <= j)%nat /\ In (run j) (tba_accepting A).

Lemma prune_forward_run :
  TBA_ext_accepts (prune_trans A) dp_word.
Proof.
  exists qs. split; [reflexivity|]. split.
  - intro i. pose proof (dp_invariant i) as Hi.
    split; [exact (di_lt i Hi)|].
    destruct (T1_spec i Hi) as [Hin1 Hd].
    destruct (dom_step_spec _ _ _ _ _ Hd)
      as [Hs1 [Hk [Hli [Hgi [Hgc [Hfl [Hfll [Hsim Hlt]]]]]]]].
    destruct (T2_spec i) as [Hin2 [Hs2 [Hd2 Hen2]]].
    destruct Hen2 as [Hlab [Hg Hrm]].
    exists (T1 i (qs i)). split.
    { unfold prune_trans. simpl. apply filter_In. split; assumption. }
    split; [exact Hs1|]. split; [reflexivity|].
    unfold tba_transition_enabled. split.
    + exact (proj1 (label_at_iff A _ _ Hin1) Hli).
    + split.
      * apply Forall_forall. intros o Ho.
        pose proof (guard_implied_holds Hgi Hg) as Hg1.
        rewrite Forall_forall in Hg1. specialize (Hg1 o Ho).
        destruct o as [k|]; [|exact I]. simpl in Hg1 |- *.
        pose proof (Hgc _ Ho) as Hgk. simpl in Hgk.
        destruct Hgk as [Hgk|[Hup Hgk]].
        -- apply constraint_transfer with (rho1 := rho); [|exact Hg1].
           exact (di_val i Hi _ Hgk).
        -- apply constraint_transfer_le with (rho1 := rho); [exact Hup| |exact Hg1].
           exact (di_le i Hi _ Hgk).
      * intro x. simpl. fold (rs i). rewrite clock_in_iff. unfold rs. split; intro H; exact H.
  - intro n. destruct (Hbuchi n) as [j [Hj Hacc]].
    exists j. split; [exact Hj|].
    pose proof (dp_invariant j) as Hi.
    destruct (prune_ok_spec A Hok) as [_ Hsp].
    destruct (Hsteps j) as [Hlt _].
    destruct (Hsp (qs j) (run j) (di_lt j Hi) Hlt (di_sim j Hi)) as [Hac _].
    exact (Hac Hacc).
Qed.

End Construct.

Lemma prune_forward_ext :
  forall (A : TBA root) (rho : ext_word root),
    prune_ok A = true -> clock_consistent rho -> TBA_ext_accepts A rho ->
    exists rho', ew_base rho' = ew_base rho /\ clock_consistent rho' /\
                 TBA_ext_accepts (prune_trans A) rho'.
Proof.
  intros A rho Hok Hcc Hacc.
  destruct Hacc as [run [Hinit [Hsteps Hbuchi]]].
  destruct (Hsteps 0%nat) as [_ [t0 _]].
  exists (dp_word A rho run t0). split; [reflexivity|]. split.
  - apply dp_consistent. exact Hcc.
  - exact (prune_forward_run A rho run t0 Hok Hcc Hinit Hsteps Hbuchi).
Qed.

Theorem prune_trans_accepts :
  forall A, prune_ok A = true ->
  forall w, TBA_accepts A w <-> TBA_accepts (prune_trans A) w.
Proof.
  intros A Hok w. unfold TBA_accepts. split.
  - intros [rho [Hb [Hcc Ha]]].
    destruct (prune_forward_ext A rho Hok Hcc Ha) as [rho' [Hb' [Hcc' Ha']]].
    exists rho'. split; [|split; assumption].
    unfold same_base in *. rewrite Hb'. exact Hb.
  - intros [rho [Hb [Hcc Ha]]].
    exists rho. split; [exact Hb|]. split; [exact Hcc|].
    destruct Ha as [run [Hinit [Hsteps Hbuchi]]].
    exists run. split; [exact Hinit|]. split; [|exact Hbuchi].
    intro i. destruct (Hsteps i) as [Hlt [t [Hin Hrest]]].
    split; [exact Hlt|]. exists t. split; [|exact Hrest].
    unfold prune_trans in Hin. simpl in Hin. apply filter_In in Hin.
    exact (proj1 Hin).
Qed.

Theorem try_prune_accepts :
  forall A w, TBA_accepts A w <-> TBA_accepts (try_prune A) w.
Proof.
  intros A w. unfold try_prune.
  destruct (prune_ok A) eqn:E; [|reflexivity].
  apply prune_trans_accepts. exact E.
Qed.

End DomPrune.

Print Assumptions try_prune_accepts.

(* ====================================================================== *)
(* 4. The pass                                                            *)
(* ====================================================================== *)

(* An unverified producer of certificates: a simulation relation between
   locations, clock sets, and the predicate of the transitions to keep. *)
Definition prune_certifier (root : mtl) : Type :=
  TBA root ->
  (nat -> nat -> bool) * (nat -> list (Clock root)) * (nat -> list (Clock root)) *
  (tba_transition root -> bool).

Definition prune_pass (root : mtl) (cert : prune_certifier root) (A : TBA root)
    : TBA root :=
  try_prune root (fst (fst (fst (cert A)))) (snd (fst (fst (cert A))))
    (snd (fst (cert A))) (snd (cert A)) A.

Theorem prune_pass_accepts :
  forall root (cert : prune_certifier root) A w,
    TBA_accepts A w <-> TBA_accepts (prune_pass root cert A) w.
Proof.
  intros root cert A w. unfold prune_pass. apply try_prune_accepts.
Qed.

Print Assumptions prune_pass_accepts.

(* ====================================================================== *)
(* 5. Splitting transitions by cells of letters                           *)
(* ====================================================================== *)

(* A transition whose label holds on several cells may be dominated on some
   of them only.  Splitting it into one transition per cell, each labelled
   with the literals that characterise the cell, makes the domination
   test exact; the language is unchanged. *)

Definition cell_label (root : mtl) (A : TBA root) (c : option nat) : list alit :=
  match c with
  | Some a => [(a, true)]
  | None => map (fun m => (m, false)) (mentioned root A)
  end.

Definition relabel (root : mtl) (t : tba_transition root) (l : list alit)
    : tba_transition root :=
  {| bt_source := bt_source t; bt_label := l; bt_guard := bt_guard t;
     bt_resets := bt_resets t; bt_target := bt_target t |}.

Definition split_cells (root : mtl) (A : TBA root) : TBA root :=
  with_transitions A
    (flat_map (fun t =>
       map (fun c => relabel root t (cell_label root A c))
           (filter (fun c => label_at c (bt_label t)) (cells root A)))
       (tba_transitions A)).

Lemma cell_label_holds :
  forall root (A : TBA root) p,
    Forall (alit_holds p) (cell_label root A (cell_of root A p)).
Proof.
  intros root A p. unfold cell_of.
  destruct (existsb (Nat.eqb p) (mentioned root A)) eqn:E.
  - simpl. constructor; [|constructor]. unfold alit_holds. simpl. reflexivity.
  - simpl. apply Forall_forall. intros l Hl. apply in_map_iff in Hl.
    destruct Hl as [m [<- Hm]]. unfold alit_holds. simpl. intro Hc.
    assert (existsb (Nat.eqb p) (mentioned root A) = true).
    { apply existsb_exists. exists m. split; [exact Hm|].
      apply Nat.eqb_eq. exact Hc. }
    congruence.
Qed.

Lemma cell_label_inv :
  forall root (A : TBA root) p c,
    In c (cells root A) ->
    Forall (alit_holds p) (cell_label root A c) ->
    c = cell_of root A p.
Proof.
  intros root A p c Hc H. destruct c as [a|].
  - simpl in H. inversion H as [|l r Ha _]; subst. unfold alit_holds in Ha.
    simpl in Ha. subst a. unfold cell_of.
    assert (Hm : In p (mentioned root A)).
    { unfold cells in Hc. destruct Hc as [Hc|Hc]; [discriminate|].
      apply in_map_iff in Hc. destruct Hc as [x [Hx Hin]].
      injection Hx as ->. exact Hin. }
    assert (existsb (Nat.eqb p) (mentioned root A) = true).
    { apply existsb_exists. exists p. split; [exact Hm|]. apply Nat.eqb_refl. }
    rewrite H0. reflexivity.
  - unfold cell_of.
    destruct (existsb (Nat.eqb p) (mentioned root A)) eqn:E; [|reflexivity].
    exfalso. apply existsb_exists in E. destruct E as [m [Hm Eq]].
    apply Nat.eqb_eq in Eq. subst m.
    simpl in H. rewrite Forall_forall in H.
    pose proof (H (p, false) (in_map (fun m => (m, false)) _ _ Hm)) as Hx.
    unfold alit_holds in Hx. simpl in Hx. apply Hx. reflexivity.
Qed.

Theorem split_cells_accepts :
  forall root (A : TBA root) w,
    TBA_accepts A w <-> TBA_accepts (split_cells root A) w.
Proof.
  intros root A w. unfold TBA_accepts. split.
  - intros [rho [Hb [Hcc [run [Hinit [Hsteps Hbu]]]]]].
    exists rho. split; [exact Hb|]. split; [exact Hcc|].
    exists run. split; [exact Hinit|]. split; [|exact Hbu].
    intro i. destruct (Hsteps i) as [Hlt [t [Hin [Hs [Hd Hen]]]]].
    split; [exact Hlt|].
    destruct Hen as [Hlab [Hg Hrm]].
    set (p := tw_action (ew_base rho) i).
    exists (relabel root t (cell_label root A (cell_of root A p))).
    split.
    { unfold split_cells, with_transitions. cbn [tba_transitions]. apply in_flat_map. exists t.
      split; [exact Hin|]. apply in_map_iff.
      exists (cell_of root A p). split; [reflexivity|].
      rewrite filter_In. split; [apply (cell_of_in root)|].
      apply (proj2 (label_at_iff root A t p Hin)). exact Hlab. }
    split; [exact Hs|]. split; [exact Hd|].
    split; [|split; assumption].
    exact (cell_label_holds root A p).
  - intros [rho [Hb [Hcc [run [Hinit [Hsteps Hbu]]]]]].
    exists rho. split; [exact Hb|]. split; [exact Hcc|].
    exists run. split; [exact Hinit|]. split; [|exact Hbu].
    intro i. destruct (Hsteps i) as [Hlt [t' [Hin [Hs [Hd Hen]]]]].
    split; [exact Hlt|].
    unfold split_cells, with_transitions in Hin. cbn [tba_transitions] in Hin.
    apply in_flat_map in Hin.
    destruct Hin as [t [Hint Hin]]. apply in_map_iff in Hin.
    destruct Hin as [c [<- Hc]]. apply filter_In in Hc. destruct Hc as [Hc Hl].
    exists t. split; [exact Hint|]. split; [exact Hs|]. split; [exact Hd|].
    destruct Hen as [Hlab [Hg Hrm]]. simpl in Hlab, Hg, Hrm.
    split; [|split; assumption].
    pose proof (cell_label_inv root A (tw_action (ew_base rho) i) c Hc Hlab) as Ec.
    pose proof (proj1 (label_at_iff root A t (tw_action (ew_base rho) i) Hint)) as Hf.
    rewrite <- Ec in Hf. specialize (Hf Hl). exact Hf.
Qed.

Print Assumptions split_cells_accepts.

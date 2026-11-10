(* ====================================================================== *)
(* Conventional clock initialization                                      *)
(*                                                                        *)
(* The acceptance notion of the development is existential: the clocks    *)
(* may take any nonnegative value at the first event.  UPPAAL starts the  *)
(* clocks at 0 at time 0, so that they all read t_0, the time of the      *)
(* first event, at that event.  This file defines this conventional       *)
(* acceptance and proves that it coincides with the existential one on    *)
(* every automaton in which no clock is read, by a guard or an invariant, *)
(* before it has been reset.  This condition is decided by the Boolean    *)
(* function [init_free], which the tool runs on the exported automaton.   *)
(* ====================================================================== *)

Require Import Arith Lia List Bool Reals Lra.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import MTL_to_TBA_Invariants.
Require Import MTL_to_TBA_Optimizations.
Require Import MTL_to_TBA_Export.
Import ListNotations.

Set Implicit Arguments.
Unset Strict Implicit.

Section Initialization.

Variable root : mtl.

(* Conventional acceptance: every clock reads the time of the first event
   at that event.  The invariant of the initial location is then checked at
   the first event; since invariants are upper bounds, it also holds during
   the stay [0, t_0]. *)
Definition DTA_accepts0 (D : DTA root) (w : timed_word) : Prop :=
  exists rho : ext_word root,
    same_base rho w /\
    clock_consistent rho /\
    (forall x, ew_val rho 0 x = tw_time w 0) /\
    DTA_ext_accepts D rho.

Lemma DTA_accepts0_accepts :
  forall D w, DTA_accepts0 D w -> DTA_accepts D w.
Proof.
  intros D w [rho [Hb [Hc [_ Ha]]]]. exists rho. tauto.
Qed.

(* ---------------------------------------------------------------------- *)
(* Clocks read by guards and invariants                                   *)

Definition dc_clocks (c : dconstraint root) : list (Clock root) :=
  match c with
  | DSingle k => [guard_clock k]
  | DDiff x y _ => [x; y]
  end.

Definition trans_reads (t : dtrans root) : list (Clock root) :=
  flat_map (flat_map dc_clocks) (dt_guard t).

Definition inv_reads (I : option (list (uinv root))) : list (Clock root) :=
  match I with
  | None => []
  | Some Us => flat_map (map fst) Us
  end.

Lemma dc_holds_ext :
  forall (v v' : valuation root) c,
    (forall x, In x (dc_clocks c) -> v x = v' x) ->
    dc_holds v c -> dc_holds v' c.
Proof.
  intros v v' [k|x y b] E H; simpl in *.
  - unfold single_holds in *. rewrite <- (E (guard_clock k)); [exact H | left; reflexivity].
  - rewrite <- (E x), <- (E y); [exact H | right; left; reflexivity | left; reflexivity].
Qed.

Lemma dguard_holds_ext :
  forall (v v' : valuation root) g,
    (forall x, In x (flat_map (flat_map dc_clocks) g) -> v x = v' x) ->
    dguard_holds v g -> dguard_holds v' g.
Proof.
  intros v v' g E [c [Hc Hh]]. exists c. split; [exact Hc|].
  unfold conj_holds in *. rewrite Forall_forall in *. intros k Hk.
  apply (dc_holds_ext (v := v)); [|apply Hh; exact Hk].
  intros x Hx. apply E. apply in_flat_map. exists c. split; [exact Hc|].
  apply in_flat_map. exists k. tauto.
Qed.

Lemma dinv_holds_ext :
  forall (v v' : valuation root) I,
    (forall x, In x (inv_reads I) -> v x = v' x) ->
    dinv_holds I v -> dinv_holds I v'.
Proof.
  intros v v' [Us|] E H; simpl in *; [|exact I].
  destruct H as [U [HU Hh]]. exists U. split; [exact HU|].
  unfold uinv_holds in *. rewrite Forall_forall in *. intros [x b] Hx.
  simpl. rewrite <- (E x); [exact (Hh _ Hx)|].
  apply in_flat_map. exists U. split; [exact HU|].
  apply (in_map fst) in Hx. exact Hx.
Qed.

(* ---------------------------------------------------------------------- *)
(* The set of locations from which a clock may be read before a reset     *)

Definition mem_clock (x : Clock root) (l : list (Clock root)) : bool :=
  if in_dec (@clock_eq_dec root) x l then true else false.

Lemma mem_clock_iff : forall x l, mem_clock x l = true <-> In x l.
Proof.
  intros x l. unfold mem_clock. destruct (in_dec (@clock_eq_dec root) x l); split;
    intro H; auto; discriminate.
Qed.

(* The clocks read by the invariant of each location, computed once: the
   invariants of the exported automaton are computed on demand. *)
Definition inv_table (D : DTA root) : list (list (Clock root)) :=
  map (fun s => inv_reads (dta_inv D s)) (seq 0 (dta_nstates D)).

Lemma inv_table_nth :
  forall D s, (s < dta_nstates D)%nat ->
    nth s (inv_table D) [] = inv_reads (dta_inv D s).
Proof.
  intros D s Hs. unfold inv_table.
  rewrite (nth_indep _ [] ((fun s0 => inv_reads (dta_inv D s0)) 0%nat))
    by (rewrite length_map, length_seq; lia).
  rewrite (map_nth (fun s0 => inv_reads (dta_inv D s0))).
  rewrite seq_nth by lia. reflexivity.
Qed.

(* Locations reading [x] directly. *)
Definition live0 (D : DTA root) (tbl : list (list (Clock root))) (x : Clock root)
    : list nat :=
  filter (fun s => mem_clock x (nth s tbl [])) (seq 0 (dta_nstates D)) ++
  map (fun t => dt_src t) (filter (fun t => mem_clock x (trans_reads t)) (dta_trans D)).

(* The sources, not yet in [S], of the transitions that do not reset [x]
   and enter [S]. *)
Definition live_new (D : DTA root) (x : Clock root) (S : list nat) : list nat :=
  map (fun t => dt_src t)
      (filter (fun t => negb (mem_clock x (dt_resets t)) && in_nat (dt_tgt t) S &&
                        negb (in_nat (dt_src t) S))
              (dta_trans D)).

(* Iterated until nothing is added, at most [n] times. *)
Fixpoint live_iter (D : DTA root) (x : Clock root) (n : nat) (S : list nat) : list nat :=
  match n with
  | O => S
  | S m => match live_new D x S with
           | [] => S
           | l => live_iter D x m (S ++ l)
           end
  end.

(* The set is computed by a backward search from the locations reading [x]
   that follows the transitions that do not reset [x]; the set has no
   duplicates, and each round only follows the locations added by the
   previous round.  (The earlier [live_iter] keeps duplicates and tests every
   transition against the whole set in every round.)  The correctness proof
   does not depend on this computation: the result is checked by [live_ok],
   and [init_free] is false if the set were wrong. *)
Definition live_step (D : DTA root) (x : Clock root) (S frontier : list nat)
    : list nat :=
  nodup Nat.eq_dec
    (filter (fun s => negb (in_nat s S))
            (map (fun t => dt_src t)
                 (filter (fun t => in_nat (dt_tgt t) frontier &&
                                   negb (mem_clock x (dt_resets t)))
                         (dta_trans D)))).

Fixpoint live_search (D : DTA root) (x : Clock root) (n : nat)
    (S frontier : list nat) : list nat :=
  match n with
  | O => S
  | Datatypes.S m =>
      match frontier with
      | [] => S
      | _ => let new := live_step D x S frontier in
             live_search D x m (S ++ new) new
      end
  end.

Definition live_set (D : DTA root) (tbl : list (list (Clock root))) (x : Clock root)
    : list nat :=
  let S0 := nodup Nat.eq_dec (live0 D tbl x) in
  live_search D x (S (dta_nstates D)) S0 S0.

(* [S] contains the locations reading [x], is closed backward through the
   transitions that do not reset [x], and does not contain the initial
   location.  The check does not depend on how [S] was computed. *)
Definition live_ok (D : DTA root) (tbl : list (list (Clock root))) (x : Clock root)
    (S : list nat) : bool :=
  negb (in_nat (dta_init D) S) &&
  forallb (fun s => negb (mem_clock x (nth s tbl [])) || in_nat s S)
          (seq 0 (dta_nstates D)) &&
  forallb (fun t => (negb (mem_clock x (trans_reads t)) || in_nat (dt_src t) S) &&
                    (mem_clock x (dt_resets t) || negb (in_nat (dt_tgt t) S) ||
                     in_nat (dt_src t) S))
          (dta_trans D).

(* The check is made for every clock of the formula ([all_clocks], the
   primitive timed subformulas of [root]). *)
Definition init_free (D : DTA root) : bool :=
  let tbl := inv_table D in
  forallb (fun x => live_ok D tbl x (live_set D tbl x)) (all_clocks root).

(* ---------------------------------------------------------------------- *)
(* The extension that starts every clock at t_0                           *)

Section Shift.

Variable rho : ext_word root.

Fixpoint val0 (i : nat) (x : Clock root) : R :=
  match i with
  | O => tw_time (ew_base rho) 0
  | S j => if ew_reset rho j x then delta (ew_base rho) j
           else val0 j x + delta (ew_base rho) j
  end.

Definition rho0 : ext_word root :=
  {| ew_base := ew_base rho; ew_val := val0; ew_reset := ew_reset rho |}.

Lemma rho0_consistent : clock_consistent rho0.
Proof.
  split.
  - intros i x. simpl. induction i as [|i IH]; simpl.
    + apply tw_time_nonnegative.
    + pose proof (delta_nonneg (ew_base rho) i).
      destruct (ew_reset rho i x); lra.
  - intros i x. reflexivity.
Qed.

(* After a reset, the two extensions agree. *)
Lemma rho0_after_reset :
  clock_consistent rho ->
  forall i x, (exists j, (j < i)%nat /\ ew_reset rho j x = true) ->
    val0 i x = ew_val rho i x.
Proof.
  intros [_ Hc] i x. induction i as [|i IH]; intros [j [Hj Hr]]; [lia|].
  simpl. rewrite (Hc i x).
  destruct (ew_reset rho i x) eqn:E; [reflexivity|].
  rewrite IH; [reflexivity|]. exists j. split; [|exact Hr].
  destruct (Nat.eq_dec j i) as [->|]; [congruence | lia].
Qed.

End Shift.

(* ---------------------------------------------------------------------- *)
(* Main theorem                                                           *)

Lemma live_ok_spec :
  forall D x S, live_ok D (inv_table D) x S = true ->
    ~ In (dta_init D) S /\
    (forall s, (s < dta_nstates D)%nat -> In x (inv_reads (dta_inv D s)) -> In s S) /\
    (forall t, In t (dta_trans D) -> In x (trans_reads t) -> In (dt_src t) S) /\
    (forall t, In t (dta_trans D) -> ~ In x (dt_resets t) -> In (dt_tgt t) S ->
               In (dt_src t) S).
Proof.
  intros D x S H. unfold live_ok in H. repeat rewrite andb_true_iff in H.
  destruct H as [[H1 H2] H3]. rewrite forallb_forall in H2, H3.
  split; [|split; [|split]].
  - intro Hi. apply negb_true_iff in H1. rewrite <- in_nat_iff in Hi. congruence.
  - intros s Hs Hx. assert (Hin : In s (seq 0 (dta_nstates D))) by (apply in_seq; lia).
    specialize (H2 s Hin). rewrite (inv_table_nth Hs) in H2.
    apply orb_true_iff in H2. destruct H2 as [H2|H2].
    + apply negb_true_iff in H2. apply mem_clock_iff in Hx. congruence.
    + apply in_nat_iff. exact H2.
  - intros t Ht Hx. specialize (H3 t Ht). apply andb_true_iff in H3.
    destruct H3 as [H3 _]. apply orb_true_iff in H3. destruct H3 as [H3|H3].
    + apply negb_true_iff in H3. apply mem_clock_iff in Hx. congruence.
    + apply in_nat_iff. exact H3.
  - intros t Ht Hr Hs. specialize (H3 t Ht). apply andb_true_iff in H3.
    destruct H3 as [_ H3]. repeat rewrite orb_true_iff in H3.
    destruct H3 as [[H3|H3]|H3].
    + apply mem_clock_iff in H3. contradiction.
    + apply negb_true_iff in H3. apply in_nat_iff in Hs. congruence.
    + apply in_nat_iff. exact H3.
Qed.

Theorem init_free_accepts0 :
  forall D w, init_free D = true -> (DTA_accepts D w <-> DTA_accepts0 D w).
Proof.
  intros D w Hfree. split; [|apply DTA_accepts0_accepts].
  intros [rho [Hb [Hc [run [Hinit [Hsteps Hbuchi]]]]]].
  exists (rho0 rho). split; [exact Hb|]. split; [apply rho0_consistent|].
  split; [intro x; simpl; rewrite Hb; reflexivity|].
  (* a clock read along the run has been reset before *)
  assert (Hread : forall i x,
            (In x (inv_reads (dta_inv D (run i))) \/
             exists t, In t (dta_trans D) /\ dt_src t = run i /\ In x (trans_reads t)) ->
            exists j, (j < i)%nat /\ ew_reset rho j x = true).
  { intros i x Hx.
    assert (Hall : In x (all_clocks root)) by apply all_clocks_complete.
    unfold init_free in Hfree. rewrite forallb_forall in Hfree.
    destruct (live_ok_spec (Hfree x Hall)) as [Hni [Hinv [Htr Hcl]]].
    set (S := live_set D (inv_table D) x) in *.
    assert (Hin : In (run i) S).
    { destruct Hx as [Hx|[t [Ht [Hs Hx]]]].
      - apply Hinv; [exact (proj1 (Hsteps i)) | exact Hx].
      - rewrite <- Hs. apply Htr; assumption. }
    (* by induction, a location of S is reached only after a reset of x *)
    clear Hx. induction i as [|i IH].
    - rewrite Hinit in Hin. contradiction.
    - destruct (Hsteps i) as [_ [_ [t [Ht [Hs [Hd Hen]]]]]].
      destruct (ew_reset rho i x) eqn:E.
      + exists i. split; [lia | exact E].
      + assert (Hnr : ~ In x (dt_resets t)).
        { intro Hx. destruct Hen as [_ [_ Hr]]. apply Hr in Hx. congruence. }
        assert (Hsrc : In (run i) S).
        { rewrite <- Hs. apply Hcl; [exact Ht | exact Hnr | rewrite Hd; exact Hin]. }
        destruct (IH Hsrc) as [j [Hj Hr]]. exists j. split; [lia | exact Hr]. }
  exists run. split; [exact Hinit|]. split.
  - intro i. destruct (Hsteps i) as [Hb' [Hi [t [Ht [Hs [Hd Hen]]]]]].
    split; [exact Hb'|]. split.
    + intros dl Hdl. simpl in Hdl.
      assert (Hst : stay (rho0 rho) i = stay rho i) by (destruct i; reflexivity).
      rewrite Hst in Hdl. specialize (Hi dl Hdl).
      apply (dinv_holds_ext (v := fun x => ew_val rho i x - dl)); [|exact Hi].
      intros x Hx. simpl. f_equal. symmetry.
      apply (rho0_after_reset Hc). apply Hread. left. exact Hx.
    + exists t. split; [exact Ht|]. split; [exact Hs|]. split; [exact Hd|].
      destruct Hen as [Hl [Hg Hr]]. split; [exact Hl|]. split; [|exact Hr].
      apply (dguard_holds_ext (v := at_event rho i)); [|exact Hg].
      intros x Hx. unfold at_event. simpl. symmetry.
      apply (rho0_after_reset Hc). apply Hread. right.
      exists t. split; [exact Ht|]. split; [exact Hs | exact Hx].
  - exact Hbuchi.
Qed.

End Initialization.

(* ====================================================================== *)
(* End-to-end correctness under the conventional clock initialization    *)
(* ====================================================================== *)

Theorem MTL_to_exported_correct0_with :
  forall (n : nat) (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (T f))) ->
    well_formed f ->
    init_free (export (optimize n (compile_with A))) = true ->
    (msat w 0 f <-> DTA_accepts0 (export (optimize n (compile_with A))) w).
Proof.
  intros n f A w HA Hwf Hfree.
  rewrite (MTL_to_exported_correct_with n w HA Hwf).
  apply init_free_accepts0. exact Hfree.
Qed.

Print Assumptions MTL_to_exported_correct0_with.

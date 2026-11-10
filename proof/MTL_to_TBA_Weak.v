(* ====================================================================== *)
(* Weak until in the clauses of upper-bounded hatted Until                *)
(*                                                                        *)
(* In the clause of an upper-bounded hatted Until, the Until waits while  *)
(* the clock x of the subformula satisfies x <= d (or x < d) and is left  *)
(* unchanged.  On a clock-consistent extension of a timed word, whose     *)
(* time diverges, the clock then exceeds the bound: the waiting cannot    *)
(* last forever, and the Until is equivalent to the weak until            *)
(* (A U B) | G A.  Spot needs no acceptance condition for a weak until,   *)
(* so that the automaton of [weak (T f)] avoids the degeneralization of   *)
(* one acceptance condition per bounded response.                         *)
(*                                                                        *)
(* [weak] preserves the semantics on clock-consistent extensions          *)
(* ([weak_correct]) and the set of atoms ([weak_atoms]); the end-to-end   *)
(* theorems therefore hold for an automaton that is correct for           *)
(* [weak (T f)], with the same compilation [compile_with].                *)
(* ====================================================================== *)

Require Import Arith Lia List Bool Reals Lra.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import MTL_to_TBA_Invariants.
Require Import MTL_to_TBA_Optimizations.
Require Import MTL_to_TBA_Export.
Require Import MTL_to_TBA_Initialization.
Import ListNotations.

Set Implicit Arguments.
Unset Strict Implicit.

Section Weak.

Variable root : mtl.

(* The left operand of the Until of an upper-bounded clause:
   x <= d /\ (unch(x) /\ A), or x < d /\ (unch(x) /\ A), with the same clock. *)
Definition upper_wait (p : ltl root) : bool :=
  match p with
  | LAnd (LAtom (LCLe x _)) (LAnd (LAtom (LUnch y)) _)
  | LAnd (LAtom (LCLt x _)) (LAnd (LAtom (LUnch y)) _) =>
      if clock_eq_dec x y then true else false
  | _ => false
  end.

Fixpoint weak (f : ltl root) : ltl root :=
  match f with
  | LAnd p q => LAnd (weak p) (weak q)
  | LOr p q => LOr (weak p) (weak q)
  | LNext p => LNext (weak p)
  | LUntil p q =>
      if upper_wait p then LW (weak p) (weak q) else LUntil (weak p) (weak q)
  | LRelease p q => LRelease (weak p) (weak q)
  | g => g
  end.

Lemma upper_wait_shape :
  forall p, upper_wait p = true ->
    exists x d c,
      p = LAnd (LAtom (LCLe x d)) (LAnd (LAtom (LUnch x)) c) \/
      p = LAnd (LAtom (LCLt x d)) (LAnd (LAtom (LUnch x)) c).
Proof.
  intros p Hp.
  destruct p as [| | a | p1 p2 | p1 p2 | p1 | p1 p2 | p1 p2]; try discriminate.
  destruct p1 as [| | a1 | | | | |]; try discriminate.
  destruct a1 as [| |x d|x d| | | |]; try discriminate;
    destruct p2 as [| | | q1 q2 | | | |]; try discriminate;
    destruct q1 as [| | a2 | | | | |]; try discriminate;
    destruct a2 as [| | | | | | |y]; try discriminate;
    simpl in Hp; destruct (clock_eq_dec x y) as [<-|]; try discriminate;
    exists x, d, q2; [left|right]; reflexivity.
Qed.

(* The waiting cannot last forever on a clock-consistent extension. *)
Lemma upper_wait_not_forever :
  forall (rho : ext_word root) p i,
    clock_consistent rho -> upper_wait p = true ->
    ~ (forall k, (i <= k)%nat -> lsat rho k p).
Proof.
  intros rho p i Hcc Hp Hall.
  assert (Key : forall x d, (forall k, (i <= k)%nat -> unch_at rho x k /\ ew_val rho k x <= d) -> False).
  { intros x d H.
    destruct (@tw_time_divergent (ew_base rho) i (Rabs d + 1)) as [j [Hij Hj]].
    { pose proof (Rabs_pos d). lra. }
    assert (Hu : forall k, (i <= k < j)%nat -> unch_at rho x k)
      by (intros k Hk; apply (H k); lia).
    pose proof (@preserve_accumulate root rho i j x Hcc Hij Hu) as Hacc.
    pose proof (@ext_val_nonnegative root rho i x Hcc) as Hnn.
    pose proof (proj2 (H j Hij)) as Hle.
    pose proof (Rle_abs d) as Habs.
    unfold elapsed in Hacc. lra. }
  destruct (upper_wait_shape Hp) as [x [d [c [-> | ->]]]].
  - apply (Key x d). intros k Hk. destruct (Hall k Hk) as [H1 [H2 _]].
    split; [exact H2|exact H1].
  - apply (Key x d). intros k Hk. destruct (Hall k Hk) as [H1 [H2 _]].
    split; [exact H2|]. simpl in H1. unfold c_lt in H1. lra.
Qed.

Theorem weak_correct :
  forall (rho : ext_word root), clock_consistent rho ->
  forall (f : ltl root) i, lsat rho i (weak f) <-> lsat rho i f.
Proof.
  intros rho Hcc f.
  induction f as [| |a|p IHp q IHq|p IHp q IHq|p IHp|p IHp q IHq|p IHp q IHq];
    intro i; simpl; try reflexivity.
  - rewrite IHp, IHq. reflexivity.
  - rewrite IHp, IHq. reflexivity.
  - apply IHp.
  - assert (Hu : lsat rho i (LUntil (weak p) (weak q)) <-> lsat rho i (LUntil p q)).
    { simpl. split.
      - intros [j [Hij [Hq Hk]]]. exists j. split; [exact Hij|].
        split; [apply IHq; exact Hq|]. intros k Hk'. apply IHp. apply Hk. exact Hk'.
      - intros [j [Hij [Hq Hk]]]. exists j. split; [exact Hij|].
        split; [apply IHq; exact Hq|]. intros k Hk'. apply IHp. apply Hk. exact Hk'. }
    destruct (upper_wait p) eqn:Hw; [|exact Hu].
    unfold LW, LG. simpl. split.
    + intros [H | H]; [apply Hu; exact H|].
      exfalso. apply (upper_wait_not_forever (rho := rho) (p := p) (i := i) Hcc Hw).
      intros k Hk. destruct (H k Hk) as [Hf | [m [_ Hf]]]; [|contradiction].
      apply IHp. exact Hf.
    + intro H. left. apply Hu. exact H.
  - split.
    + intros H j Hij. destruct (H j Hij) as [Hq|[k [Hk Hp]]].
      * left. apply IHq. exact Hq.
      * right. exists k. split; [exact Hk|]. apply IHp. exact Hp.
    + intros H j Hij. destruct (H j Hij) as [Hq|[k [Hk Hp]]].
      * left. apply IHq. exact Hq.
      * right. exists k. split; [exact Hk|]. apply IHp. exact Hp.
Qed.

Lemma weak_atoms :
  forall (f : ltl root) a, In a (ltl_atoms (weak f)) <-> In a (ltl_atoms f).
Proof.
  induction f as [| |b|p IHp q IHq|p IHp q IHq|p IHp|p IHp q IHq|p IHp q IHq];
    intro a; simpl; try reflexivity.
  - rewrite !in_app_iff, IHp, IHq. reflexivity.
  - rewrite !in_app_iff, IHp, IHq. reflexivity.
  - apply IHp.
  - destruct (upper_wait p); simpl; rewrite ?in_app_iff, ?IHp, ?IHq; simpl; tauto.
  - rewrite !in_app_iff, IHp, IHq. reflexivity.
Qed.

(* Relaxation depends only on the set of atoms. *)
Lemma relax_atoms_ext :
  forall (F G : list (latom root)) (A : PBuchi root),
    (forall a, In a F <-> In a G) -> relax F A = relax G A.
Proof.
  intros F G A HFG. unfold relax. f_equal.
  apply map_ext. intro t. unfold relax_trans. f_equal.
  apply filter_ext. intros [a b]. unfold keep_lit. simpl.
  destruct (in_atoms a F) eqn:E1; destruct (in_atoms a G) eqn:E2; try reflexivity.
  - apply in_atoms_iff in E1. apply HFG in E1. apply in_atoms_iff in E1. congruence.
  - apply in_atoms_iff in E2. apply HFG in E2. apply in_atoms_iff in E2. congruence.
Qed.

End Weak.

(* The compiled automaton of an automaton that is correct for weak (T f). *)
Theorem MTL_to_TBA_correct_weak_with :
  forall (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (weak (T f)))) ->
    well_formed f ->
    (msat w 0 f <-> TBA_accepts (compile_with A) w).
Proof.
  intros f A w HA Hwf.
  pose proof (@EncodingCorrect_proved f w Hwf) as Henc.
  assert (Hrel : relax (ltl_atoms (T f)) A = relax (ltl_atoms (weak (T f))) A).
  { apply relax_atoms_ext. intro a. symmetry. apply weak_atoms. }
  unfold compile_with, TBA_accepts. rewrite Hrel.
  assert (Hok : labels_ok (relax (ltl_atoms (weak (T f))) A)).
  { rewrite <- Hrel. apply compile_labels_ok. }
  split.
  - intro Hm. apply (proj1 Henc) in Hm.
    destruct Hm as [rho [Hbase [Hclock Hltl]]].
    apply (proj2 (weak_correct Hclock (T f) 0)) in Hltl.
    apply lsat_psat in Hltl.
        apply (proj2 (HA (word_of rho) (word_of_action_consistent rho))) in Hltl.
    apply (relax_complete (ltl_atoms (weak (T f)))) in Hltl.
    destruct (complete_complete Hclock Hok Hltl) as [rho' [Hb' [Hc' Ha']]].
    exists rho'. split; [unfold same_base in *; rewrite Hb'; exact Hbase|].
    split; [exact Hc' | exact Ha'].
  - intros [rho [Hbase [Hclock Htba]]].
    apply (proj2 Henc).
    exists rho. split; [exact Hbase|]. split; [exact Hclock|].
    apply (proj1 (weak_correct Hclock (T f) 0)).
    apply lsat_psat.
        apply (relax_sound (A := A)).
    + apply word_of_action_consistent.
    + intros s' Hcs' Hs'. exact (proj1 (HA s' Hcs') Hs').
    + exact (complete_sound Hok Htba).
Qed.

Theorem MTL_to_exported_correct_weak_with :
  forall (n : nat) (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (weak (T f)))) ->
    well_formed f ->
    (msat w 0 f <-> DTA_accepts (export (optimize n (compile_with A))) w).
Proof.
  intros n f A w HA Hwf.
  rewrite (@MTL_to_TBA_correct_weak_with f A w HA Hwf).
  rewrite (optimize_accepts n (compile_with A) w).
  apply export_accepts.
Qed.

Theorem MTL_to_exported_correct0_weak_with :
  forall (n : nat) (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (weak (T f)))) ->
    well_formed f ->
    init_free (export (optimize n (compile_with A))) = true ->
    (msat w 0 f <-> DTA_accepts0 (export (optimize n (compile_with A))) w).
Proof.
  intros n f A w HA Hwf Hfree.
  rewrite (MTL_to_exported_correct_weak_with n w HA Hwf).
  apply init_free_accepts0. exact Hfree.
Qed.

Print Assumptions MTL_to_exported_correct0_weak_with.

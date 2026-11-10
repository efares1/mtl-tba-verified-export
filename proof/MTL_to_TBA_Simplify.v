(* ====================================================================== *)
(* Simplification of the clocked-LTL formula before the LTL-to-Buchi step *)
(*                                                                        *)
(* The translation T produces formulas with trivial operands, such as     *)
(* true & p, false R true, or p | false.  [ltl_simp] removes them         *)
(* bottom-up.  It preserves the semantics on every propositional word     *)
(* ([ltl_simp_correct]), so that an automaton that is correct for the     *)
(* simplified formula is correct for T f, and the end-to-end theorems     *)
(* apply to the automaton returned by the translator for the simplified   *)
(* formula.                                                               *)
(* ====================================================================== *)

Require Import Arith Lia List Bool Reals.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import MTL_to_TBA_Invariants.
Require Import MTL_to_TBA_Optimizations.
Require Import MTL_to_TBA_Export.
Require Import MTL_to_TBA_Initialization.
Import ListNotations.

Set Implicit Arguments.
Unset Strict Implicit.

Section Simplify.

Variable root : mtl.

Definition s_and (p q : ltl root) : ltl root :=
  match p, q with
  | LTrue, _ => q
  | _, LTrue => p
  | LFalse, _ => LFalse
  | _, LFalse => LFalse
  | _, _ => LAnd p q
  end.

Definition s_or (p q : ltl root) : ltl root :=
  match p, q with
  | LFalse, _ => q
  | _, LFalse => p
  | LTrue, _ => LTrue
  | _, LTrue => LTrue
  | _, _ => LOr p q
  end.

Definition s_next (p : ltl root) : ltl root :=
  match p with
  | LTrue => LTrue
  | LFalse => LFalse
  | _ => LNext p
  end.

(* p U true = true, p U false = false, false U q = q *)
Definition s_until (p q : ltl root) : ltl root :=
  match q with
  | LTrue => LTrue
  | LFalse => LFalse
  | _ => match p with
         | LFalse => q
         | _ => LUntil p q
         end
  end.

(* p R true = true, p R false = false, true R q = q *)
Definition s_release (p q : ltl root) : ltl root :=
  match q with
  | LTrue => LTrue
  | LFalse => LFalse
  | _ => match p with
         | LTrue => q
         | _ => LRelease p q
         end
  end.

Fixpoint ltl_simp (f : ltl root) : ltl root :=
  match f with
  | LAnd p q => s_and (ltl_simp p) (ltl_simp q)
  | LOr p q => s_or (ltl_simp p) (ltl_simp q)
  | LNext p => s_next (ltl_simp p)
  | LUntil p q => s_until (ltl_simp p) (ltl_simp q)
  | LRelease p q => s_release (ltl_simp p) (ltl_simp q)
  | _ => f
  end.

Lemma s_and_correct :
  forall (s : pword root) i (p q : ltl root), psat s i (s_and p q) <-> psat s i (LAnd p q).
Proof. intros s i p q. destruct p, q; simpl; tauto. Qed.

Lemma s_or_correct :
  forall (s : pword root) i (p q : ltl root), psat s i (s_or p q) <-> psat s i (LOr p q).
Proof. intros s i p q. destruct p, q; simpl; tauto. Qed.

Lemma s_next_correct :
  forall (s : pword root) i (p : ltl root), psat s i (s_next p) <-> psat s i (LNext p).
Proof. intros s i p. destruct p; simpl; tauto. Qed.

Lemma until_false_l :
  forall (s : pword root) i (q : ltl root), psat s i (LUntil LFalse q) <-> psat s i q.
Proof.
  intros s i q. simpl. split.
  - intros [j [Hij [Hq Hk]]].
    destruct (Nat.eq_dec i j) as [->|Hne]; [exact Hq|].
    exfalso. apply (Hk i). lia.
  - intro Hq. exists i. split; [lia|]. split; [exact Hq|]. intros k Hk. lia.
Qed.

Lemma s_until_correct :
  forall (s : pword root) i (p q : ltl root), psat s i (s_until p q) <-> psat s i (LUntil p q).
Proof.
  intros s i p q. unfold s_until.
  destruct q;
    try (destruct p; try (symmetry; apply until_false_l); reflexivity);
    simpl.
  - split; [intros _; exists i; split; [lia|]; split; [exact I|]; intros k Hk; lia
           |intros _; exact I].
  - split; [intro H; destruct H|intros [j [_ [H _]]]; exact H].
Qed.

Lemma release_true_l :
  forall (s : pword root) i (q : ltl root), psat s i (LRelease LTrue q) <-> psat s i q.
Proof.
  intros s i q. simpl. split.
  - intro H. destruct (H i (le_n i)) as [Hq|[k [Hk _]]]; [exact Hq|lia].
  - intros Hq j Hij. destruct (Nat.eq_dec i j) as [->|Hne]; [left; exact Hq|].
    right. exists i. split; [lia|exact I].
Qed.

Lemma s_release_correct :
  forall (s : pword root) i (p q : ltl root), psat s i (s_release p q) <-> psat s i (LRelease p q).
Proof.
  intros s i p q. unfold s_release.
  destruct q;
    try (destruct p; try (symmetry; apply release_true_l); reflexivity);
    simpl.
  - split; [intros _ j _; left; exact I|intros _; exact I].
  - split; [intro H; destruct H|].
    intro H. destruct (H i (le_n i)) as [Hf|[k [Hk _]]]; [exact Hf|lia].
Qed.

Theorem ltl_simp_correct :
  forall (f : ltl root) (s : pword root) i, psat s i (ltl_simp f) <-> psat s i f.
Proof.
  induction f as [| |a|p IHp q IHq|p IHp q IHq|p IHp|p IHp q IHq|p IHp q IHq];
    intros s i; simpl; try reflexivity.
  - rewrite s_and_correct. simpl. rewrite IHp, IHq. reflexivity.
  - rewrite s_or_correct. simpl. rewrite IHp, IHq. reflexivity.
  - rewrite s_next_correct. simpl. apply IHp.
  - rewrite s_until_correct. simpl. split.
    + intros [j [Hij [Hq Hk]]]. exists j. split; [exact Hij|].
      split; [apply IHq; exact Hq|]. intros k Hk'. apply IHp. apply Hk. exact Hk'.
    + intros [j [Hij [Hq Hk]]]. exists j. split; [exact Hij|].
      split; [apply IHq; exact Hq|]. intros k Hk'. apply IHp. apply Hk. exact Hk'.
  - rewrite s_release_correct. simpl. split.
    + intros H j Hij. destruct (H j Hij) as [Hq|[k [Hk Hp]]].
      * left. apply IHq. exact Hq.
      * right. exists k. split; [exact Hk|]. apply IHp. exact Hp.
    + intros H j Hij. destruct (H j Hij) as [Hq|[k [Hk Hp]]].
      * left. apply IHq. exact Hq.
      * right. exists k. split; [exact Hk|]. apply IHp. exact Hp.
Qed.

End Simplify.

(* The end-to-end theorems for the automaton returned by the translator for
   the simplified formula. *)
Theorem MTL_to_exported_correct_simp_with :
  forall (n : nat) (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (ltl_simp (T f)))) ->
    well_formed f ->
    (msat w 0 f <-> DTA_accepts (export (optimize n (compile_with A))) w).
Proof.
    intros n f A w HA Hwf. apply MTL_to_exported_correct_with; [|exact Hwf].
  intros s Hs. rewrite (HA s Hs). apply ltl_simp_correct.
Qed.

Theorem MTL_to_exported_correct0_simp_with :
  forall (n : nat) (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (ltl_simp (T f)))) ->
    well_formed f ->
    init_free (export (optimize n (compile_with A))) = true ->
    (msat w 0 f <-> DTA_accepts0 (export (optimize n (compile_with A))) w).
Proof.
    intros n f A w HA Hwf Hfree. apply MTL_to_exported_correct0_with;
    [|exact Hwf|exact Hfree].
  intros s Hs. rewrite (HA s Hs). apply ltl_simp_correct.
Qed.

Print Assumptions MTL_to_exported_correct0_simp_with.

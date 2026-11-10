(* ====================================================================== *)
(* Recurrence and persistence with a lower bound                          *)
(*                                                                        *)
(* Under time divergence, a lower bound under "always eventually" or      *)
(* "eventually always" has no effect:                                     *)
(*     [] <>_{>=d} p  ==  [] <> p        <> []_{>=d} p  ==  <> [] p       *)
(* and likewise with > d.  The function [recur] applies these laws        *)
(* bottom-up to the derived operators of the development; the tool        *)
(* applies it before the translation, which removes the clock of these    *)
(* subformulas.                                                           *)
(* ====================================================================== *)

Require Import Arith Lia List Bool Reals Lra Setoid Morphisms.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import MTL_to_TBA_Invariants.
Require Import MTL_to_TBA_Optimizations.
Require Import MTL_to_TBA_Export.
Require Import MTL_to_TBA_Initialization.
Require Import MTL_to_TBA_Weak.

Definition is_true (f : mtl) : bool :=
  match f with MTrue => true | _ => false end.

Definition is_false (f : mtl) : bool :=
  match f with MFalse => true | _ => false end.

Lemma is_true_eq : forall f, is_true f = true -> f = MTrue.
Proof. intros f H; destruct f; simpl in H; congruence. Qed.

Lemma is_false_eq : forall f, is_false f = true -> f = MFalse.
Proof. intros f H; destruct f; simpl in H; congruence. Qed.

(* One rewriting step at the root.  [] q is MR MFalse q, <> q is MU MTrue q,
   <>_{>=d} p is MUge d MTrue p = MAnd MTrue (MUhatGe d MTrue p), and
   []_{>=d} p is MRge d MFalse p = MOr MFalse (MRhatGe d MFalse p). *)
Definition rw1 (g : mtl) : mtl :=
  match g with
  | MR a b =>
      if is_false a then
        match b with
        | MAnd c e =>
            if is_true c then
              match e with
              | MUhatGe _ x p | MUhatGt _ x p =>
                  if is_true x then MR MFalse (MU MTrue p) else g
              | _ => g
              end
            else g
        | _ => g
        end
      else g
  | MU a b =>
      if is_true a then
        match b with
        | MOr c e =>
            if is_false c then
              match e with
              | MRhatGe _ x p | MRhatGt _ x p =>
                  if is_false x then MU MTrue (MR MFalse p) else g
              | _ => g
              end
            else g
        | _ => g
        end
      else g
  | _ => g
  end.

Fixpoint recur (f : mtl) : mtl :=
  match f with
  | MTrue => MTrue
  | MFalse => MFalse
  | MAtom a => MAtom a
  | MNotAtom a => MNotAtom a
  | MAnd p q => rw1 (MAnd (recur p) (recur q))
  | MOr p q => rw1 (MOr (recur p) (recur q))
  | MNext p => rw1 (MNext (recur p))
  | MU p q => rw1 (MU (recur p) (recur q))
  | MR p q => rw1 (MR (recur p) (recur q))
  | MUhatLe d p q => rw1 (MUhatLe d (recur p) (recur q))
  | MUhatGe d p q => rw1 (MUhatGe d (recur p) (recur q))
  | MRhatLe d p q => rw1 (MRhatLe d (recur p) (recur q))
  | MRhatGe d p q => rw1 (MRhatGe d (recur p) (recur q))
  | MUhatLt d p q => rw1 (MUhatLt d (recur p) (recur q))
  | MUhatGt d p q => rw1 (MUhatGt d (recur p) (recur q))
  | MRhatLt d p q => rw1 (MRhatLt d (recur p) (recur q))
  | MRhatGt d p q => rw1 (MRhatGt d (recur p) (recur q))
  end.

(* ---------------------------------------------------------------------- *)
(* The two laws                                                           *)

Lemma always_iff : forall w i q,
    msat w i (MR MFalse q) <-> (forall j, (i <= j)%nat -> msat w j q).
Proof.
  intros w i q; simpl; split.
  - intros H j Hj. destruct (H j Hj) as [Hq | [k [_ []]]]. exact Hq.
  - intros H j Hj. left. apply H. exact Hj.
Qed.

Lemma eventually_iff : forall w i q,
    msat w i (MU MTrue q) <-> (exists j, (i <= j)%nat /\ msat w j q).
Proof.
  intros w i q; simpl; split.
  - intros [j [Hj [Hq _]]]. exists j. split; assumption.
  - intros [j [Hj Hq]]. exists j. repeat split; auto.
Qed.

(* A position beyond i whose time exceeds that of i by more than d. *)
Lemma far_position : forall w i d, 0 <= d ->
    exists m, (i < m)%nat /\ d < tw_time w m - tw_time w i.
Proof.
  intros w i d Hd.
  destruct (@tw_time_divergent w i (d + 1)) as [m [Hm Ht]]; [lra|].
  exists m. split; [|lra].
  destruct (Nat.eq_dec i m) as [E|]; [subst; lra | lia].
Qed.

Lemma recurrence_lower : forall w i d p (lt : bool), 0 <= d ->
    (forall j, (i <= j)%nat ->
       exists l, (j < l)%nat /\
         (if lt then d < tw_time w l - tw_time w j
          else d <= tw_time w l - tw_time w j) /\ msat w l p) <->
    (forall j, (i <= j)%nat -> exists l, (j <= l)%nat /\ msat w l p).
Proof.
  intros w i d p lt Hd; split.
  - intros H j Hj. destruct (H j Hj) as [l [Hl [_ Hp]]].
    exists l. split; [lia | exact Hp].
  - intros H j Hj.
    destruct (far_position w j d Hd) as [m [Hm Ht]].
    destruct (H m ltac:(lia)) as [l [Hl Hp]].
    pose proof (time_monotone w Hl).
    exists l. split; [lia|]. split; [destruct lt; lra | exact Hp].
Qed.

Lemma persistence_lower : forall w i d p (lt : bool), 0 <= d ->
    (exists j, (i <= j)%nat /\
       forall l, (j < l)%nat ->
         (if lt then d < tw_time w l - tw_time w j
          else d <= tw_time w l - tw_time w j) -> msat w l p) <->
    (exists j, (i <= j)%nat /\ forall l, (j <= l)%nat -> msat w l p).
Proof.
  intros w i d p lt Hd; split.
  - intros [j [Hj H]].
    destruct (far_position w j d Hd) as [m [Hm Ht]].
    exists m. split; [lia|]. intros l Hl.
    pose proof (time_monotone w Hl).
    apply H; [lia | destruct lt; lra].
  - intros [j [Hj H]]. exists j. split; [exact Hj|].
    intros l Hl _. apply H. lia.
Qed.

Lemma rw1_correct : forall g, well_formed g ->
    forall w i, msat w i (rw1 g) <-> msat w i g.
Proof.
  intros g Hwf w i.
  destruct g; try reflexivity.
  - (* MU *)
    unfold rw1. destruct (is_true g1) eqn:E1; [|reflexivity].
    apply is_true_eq in E1; subst g1.
    destruct g2; try reflexivity.
    destruct (is_false g2_1) eqn:E2; [|reflexivity].
    apply is_false_eq in E2; subst g2_1.
    destruct g2_2; try reflexivity;
      (destruct (is_false g2_2_1) eqn:E3; [|reflexivity]);
      apply is_false_eq in E3; subst g2_2_1;
      simpl in Hwf; destruct Hwf as [_ [_ [Hd _]]];
      rewrite eventually_iff;
      setoid_rewrite always_iff.
    + (* >= *)
      rewrite <- (persistence_lower w i r g2_2_2 false ltac:(lra)).
      simpl. split.
      * intros [j [Hj H]]. exists j. repeat split; auto;
        try (right; intros l Hl Ht; left; exact (H l Hl Ht)).
      * intros [j [Hj [Hb _]]]. exists j. split; [exact Hj|].
        destruct Hb as [[] | Hb]. intros l Hl Ht.
        destruct (Hb l Hl Ht) as [Hq | [k [_ []]]]. exact Hq.
    + (* > *)
      rewrite <- (persistence_lower w i r g2_2_2 true ltac:(lra)).
      simpl. split.
      * intros [j [Hj H]]. exists j. repeat split; auto;
        try (right; intros l Hl Ht; left; exact (H l Hl Ht)).
      * intros [j [Hj [Hb _]]]. exists j. split; [exact Hj|].
        destruct Hb as [[] | Hb]. intros l Hl Ht.
        destruct (Hb l Hl Ht) as [Hq | [k [_ []]]]. exact Hq.
  - (* MR *)
    unfold rw1. destruct (is_false g1) eqn:E1; [|reflexivity].
    apply is_false_eq in E1; subst g1.
    destruct g2; try reflexivity.
    destruct (is_true g2_1) eqn:E2; [|reflexivity].
    apply is_true_eq in E2; subst g2_1.
    destruct g2_2; try reflexivity;
      (destruct (is_true g2_2_1) eqn:E3; [|reflexivity]);
      apply is_true_eq in E3; subst g2_2_1;
      simpl in Hwf; destruct Hwf as [_ [_ [Hd _]]];
      rewrite !always_iff;
      setoid_rewrite eventually_iff.
    + rewrite <- (recurrence_lower w i r g2_2_2 false ltac:(lra)).
      simpl. split.
      * intros H j Hj. destruct (H j Hj) as [l [Hl [Ht Hp]]].
        split; [exact I|]. exists l. repeat split; auto.
      * intros H j Hj. destruct (H j Hj) as [_ [l [Hl [Ht [Hp _]]]]].
        exists l. auto.
    + rewrite <- (recurrence_lower w i r g2_2_2 true ltac:(lra)).
      simpl. split.
      * intros H j Hj. destruct (H j Hj) as [l [Hl [Ht Hp]]].
        split; [exact I|]. exists l. repeat split; auto.
      * intros H j Hj. destruct (H j Hj) as [_ [l [Hl [Ht [Hp _]]]]].
        exists l. auto.
Qed.

Lemma rw1_well_formed : forall g, well_formed g -> well_formed (rw1 g).
Proof.
  intros g Hwf.
  destruct g; try exact Hwf.
  - unfold rw1. destruct (is_true g1) eqn:E1; [|exact Hwf].
    destruct g2; try exact Hwf.
    destruct (is_false g2_1) eqn:E2; [|exact Hwf].
    destruct g2_2; try exact Hwf;
      (destruct (is_false g2_2_1); [|exact Hwf]);
      simpl in *; tauto.
  - unfold rw1. destruct (is_false g1) eqn:E1; [|exact Hwf].
    destruct g2; try exact Hwf.
    destruct (is_true g2_1) eqn:E2; [|exact Hwf].
    destruct g2_2; try exact Hwf;
      (destruct (is_true g2_2_1); [|exact Hwf]);
      simpl in *; tauto.
Qed.

Theorem recur_well_formed : forall f, well_formed f -> well_formed (recur f).
Proof.
  induction f; intro Hwf; cbn [recur]; try exact I;
    apply rw1_well_formed; simpl in *; tauto.
Qed.

Theorem recur_correct : forall f, well_formed f ->
    forall w i, msat w i (recur f) <-> msat w i f.
Proof.
  induction f; intros Hwf w i; cbn [recur]; try reflexivity;
    rewrite rw1_correct
      by (simpl in Hwf |- *; intuition auto using recur_well_formed);
    simpl in Hwf; simpl;
    repeat match goal with
           | H : ?A /\ ?B |- _ => destruct H
           end;
    repeat match goal with
           | IH : well_formed ?p -> forall w i, msat w i (recur ?p) <-> _,
             H : well_formed ?p |- _ =>
               setoid_rewrite (IH H); clear IH
           end;
    reflexivity.
Qed.

(* ---------------------------------------------------------------------- *)
(* End to end: the chain of the tool, applied to recur f                   *)

Theorem MTL_to_exported_correct_recur_weak_with :
  forall (n : nat) (f : mtl) (A : PBuchi (recur f)) (w : timed_word),
    (forall s : pword (recur f), action_consistent s ->
        (PBA_accepts A s <-> psat s 0 (weak (T (recur f))))) ->
    well_formed f ->
    (msat w 0 f <-> DTA_accepts (export (optimize n (compile_with A))) w).
Proof.
  intros n f A w HA Hwf.
  rewrite <- (recur_correct f Hwf w 0).
  apply (@MTL_to_exported_correct_weak_with n (recur f) A w HA (recur_well_formed f Hwf)).
Qed.

Theorem MTL_to_exported_correct0_recur_weak_with :
  forall (n : nat) (f : mtl) (A : PBuchi (recur f)) (w : timed_word),
    (forall s : pword (recur f), action_consistent s ->
        (PBA_accepts A s <-> psat s 0 (weak (T (recur f))))) ->
    well_formed f ->
    init_free (export (optimize n (compile_with A))) = true ->
    (msat w 0 f <-> DTA_accepts0 (export (optimize n (compile_with A))) w).
Proof.
  intros n f A w HA Hwf Hfree.
  rewrite <- (recur_correct f Hwf w 0).
  apply (@MTL_to_exported_correct0_weak_with n (recur f) A w HA (recur_well_formed f Hwf) Hfree).
Qed.

Print Assumptions MTL_to_exported_correct_recur_weak_with.
Print Assumptions MTL_to_exported_correct0_recur_weak_with.

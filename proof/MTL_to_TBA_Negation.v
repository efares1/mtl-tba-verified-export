(* ====================================================================== *)
(* Negation normal form                                                   *)
(*                                                                        *)
(* The formulas of the development are in negation normal form.  The      *)
(* function [neg] computes the negation normal form of the negation of a  *)
(* formula, by duality; the tool applies it to every negation of its      *)
(* input, so that the negation normal form is no longer hand-written.     *)
(* The negations of the derived ordinary operators are the dual derived   *)
(* operators (neg_MUle, ...).                                             *)
(* ====================================================================== *)

Require Import List Reals Lra Classical.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.

Fixpoint neg (f : mtl) : mtl :=
  match f with
  | MTrue => MFalse
  | MFalse => MTrue
  | MAtom a => MNotAtom a
  | MNotAtom a => MAtom a
  | MAnd p q => MOr (neg p) (neg q)
  | MOr p q => MAnd (neg p) (neg q)
  | MNext p => MNext (neg p)
  | MU p q => MR (neg p) (neg q)
  | MR p q => MU (neg p) (neg q)
  | MUhatLe d p q => MRhatLe d (neg p) (neg q)
  | MUhatGe d p q => MRhatGe d (neg p) (neg q)
  | MRhatLe d p q => MUhatLe d (neg p) (neg q)
  | MRhatGe d p q => MUhatGe d (neg p) (neg q)
  | MUhatLt d p q => MRhatLt d (neg p) (neg q)
  | MUhatGt d p q => MRhatGt d (neg p) (neg q)
  | MRhatLt d p q => MUhatLt d (neg p) (neg q)
  | MRhatGt d p q => MUhatGt d (neg p) (neg q)
  end.

(* Duality of Until and Release, for any range of witnesses [L] and any
   range [Rg] of intermediate positions. *)
Lemma release_neg_until :
  forall (L Q : nat -> Prop) (Rg : nat -> nat -> Prop) (P : nat -> Prop),
    (forall j, L j -> ~ Q j \/ exists k, Rg j k /\ ~ P k) <->
    ~ (exists j, L j /\ Q j /\ forall k, Rg j k -> P k).
Proof.
  intros L Q Rg P; split.
  - intros H [j [Lj [Qj Hk]]].
    destruct (H j Lj) as [nQ | [k [Rk nP]]]; auto.
  - intros H j Lj.
    destruct (classic (Q j)) as [Qj | nQ]; [|left; exact nQ].
    right. apply NNPP. intro Hn. apply H. exists j. repeat split; auto.
    intros k Rk. apply NNPP. intro nPk. apply Hn. exists k. auto.
Qed.

Lemma until_neg_release :
  forall (L Q : nat -> Prop) (Rg : nat -> nat -> Prop) (P : nat -> Prop),
    (exists j, L j /\ ~ Q j /\ forall k, Rg j k -> ~ P k) <->
    ~ (forall j, L j -> Q j \/ exists k, Rg j k /\ P k).
Proof.
  intros L Q Rg P; split.
  - intros [j [Lj [nQ Hk]]] H.
    destruct (H j Lj) as [Qj | [k [Rk Pk]]]; [contradiction|].
    exact (Hk k Rk Pk).
  - intros H. apply NNPP. intro Hn. apply H. intros j Lj.
    destruct (classic (Q j)) as [Qj | nQ]; [left; exact Qj|].
    right. apply NNPP. intro Hk. apply Hn. exists j. repeat split; auto.
    intros k Rk Pk. apply Hk. exists k. auto.
Qed.

(* The same, with a witness range given by two conditions, as in the
   hatted operators (position and time). *)
Lemma release_neg_until2 :
  forall (L1 L2 Q : nat -> Prop) (Rg : nat -> nat -> Prop) (P : nat -> Prop),
    (forall j, L1 j -> L2 j -> ~ Q j \/ exists k, Rg j k /\ ~ P k) <->
    ~ (exists j, L1 j /\ L2 j /\ Q j /\ forall k, Rg j k -> P k).
Proof.
  intros L1 L2 Q Rg P.
  pose proof (release_neg_until (fun j => L1 j /\ L2 j) Q Rg P) as H.
  split.
  - intros Hr [j [L1j [L2j [Qj Hk]]]].
    apply (proj1 H); [intros j' [A B]; exact (Hr j' A B)|].
    exists j. repeat split; auto.
  - intros Hn j L1j L2j.
    apply (proj2 H); [|split; assumption].
    intros [j' [[A B] [Qj Hk]]]. apply Hn. exists j'. repeat split; auto.
Qed.

Lemma until_neg_release2 :
  forall (L1 L2 Q : nat -> Prop) (Rg : nat -> nat -> Prop) (P : nat -> Prop),
    (exists j, L1 j /\ L2 j /\ ~ Q j /\ forall k, Rg j k -> ~ P k) <->
    ~ (forall j, L1 j -> L2 j -> Q j \/ exists k, Rg j k /\ P k).
Proof.
  intros L1 L2 Q Rg P.
  pose proof (until_neg_release (fun j => L1 j /\ L2 j) Q Rg P) as H.
  split.
  - intros [j [L1j [L2j [nQ Hk]]]] Hr.
    apply (proj1 H); [exists j; repeat split; auto|].
    intros j' [A B]. exact (Hr j' A B).
  - intros Hn.
    destruct (proj2 H) as [j [[A B] [nQ Hk]]].
    + intros Hr. apply Hn. intros j' A B. exact (Hr j' (conj A B)).
    + exists j. repeat split; auto.
Qed.

Theorem neg_correct :
  forall f w i, msat w i (neg f) <-> ~ msat w i f.
Proof.
  induction f; intros w i; simpl.
  - tauto.
  - tauto.
  - tauto.
  - split; [intros H Hn; exact (Hn H)|].
    intros H. apply NNPP. exact H.
  - rewrite IHf1, IHf2. split; [tauto|]. apply not_and_or.
  - rewrite IHf1, IHf2. split; [tauto|]. apply not_or_and.
  - apply IHf.
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (release_neg_until (fun j => (i <= j)%nat) (fun j => msat w j f2)
             (fun j k => (i <= k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (until_neg_release (fun j => (i <= j)%nat) (fun j => msat w j f2)
             (fun j k => (i <= k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (release_neg_until2 (fun j => (i < j)%nat)
             (fun j => tw_time w j - tw_time w i <= r) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (release_neg_until2 (fun j => (i < j)%nat)
             (fun j => r <= tw_time w j - tw_time w i) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (until_neg_release2 (fun j => (i < j)%nat)
             (fun j => tw_time w j - tw_time w i <= r) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (until_neg_release2 (fun j => (i < j)%nat)
             (fun j => r <= tw_time w j - tw_time w i) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (release_neg_until2 (fun j => (i < j)%nat)
             (fun j => tw_time w j - tw_time w i < r) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (release_neg_until2 (fun j => (i < j)%nat)
             (fun j => r < tw_time w j - tw_time w i) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (until_neg_release2 (fun j => (i < j)%nat)
             (fun j => tw_time w j - tw_time w i < r) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
  - setoid_rewrite IHf1. setoid_rewrite IHf2.
    exact (until_neg_release2 (fun j => (i < j)%nat)
             (fun j => r < tw_time w j - tw_time w i) (fun j => msat w j f2)
             (fun j k => (i < k < j)%nat) (fun k => msat w k f1)).
Qed.

Theorem neg_well_formed :
  forall f, well_formed f -> well_formed (neg f).
Proof.
  induction f; simpl; intuition.
Qed.

(* The negations of the derived ordinary operators are the dual derived
   operators. *)
Lemma neg_MUle : forall d p q, neg (MUle d p q) = MRle d (neg p) (neg q).
Proof. reflexivity. Qed.
Lemma neg_MUge : forall d p q, neg (MUge d p q) = MRge d (neg p) (neg q).
Proof. reflexivity. Qed.
Lemma neg_MRle : forall d p q, neg (MRle d p q) = MUle d (neg p) (neg q).
Proof. reflexivity. Qed.
Lemma neg_MRge : forall d p q, neg (MRge d p q) = MUge d (neg p) (neg q).
Proof. reflexivity. Qed.
Lemma neg_MUlt : forall d p q, neg (MUlt d p q) = MRlt d (neg p) (neg q).
Proof. reflexivity. Qed.
Lemma neg_MUgt : forall d p q, neg (MUgt d p q) = MRgt d (neg p) (neg q).
Proof. reflexivity. Qed.
Lemma neg_MRlt : forall d p q, neg (MRlt d p q) = MUlt d (neg p) (neg q).
Proof. reflexivity. Qed.
Lemma neg_MRgt : forall d p q, neg (MRgt d p q) = MUgt d (neg p) (neg q).
Proof. reflexivity. Qed.

Print Assumptions neg_correct.

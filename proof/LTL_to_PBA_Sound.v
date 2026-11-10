(*
  LTL_to_PBA_Sound.v

  Soundness of a breakpoint (Miyano-Hayashi style) automaton for the
  positive LTL fragment [ltl root] of the Core file:
  an "accepting run" (X, O) on a propositional word [s] satisfies the
  formulas it carries.

  X i is the set of formulas that must hold at position i.
  O i is the set of Until-obligations still owed at position i.
  The run is accepting when O is empty infinitely often.

  The obligation set O (S i) is computed from the sets chosen at position i:
  it contains the Untils u in X i whose right operand is not in X i, and
  that were already owed at i (or all of them, when nothing was owed at i).

  This file is abstract: it needs no finiteness of the state space and no
  closure of subformulas.  The concrete automaton is built in
  LTL_to_PBA_Concrete.v.
  Axioms: only [classic], already used by the Core file.
*)
Require Import Arith Lia List Bool Classical.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.

Open Scope nat_scope.

Section Sound.
Variable root : mtl.

Definition fset : Type := ltl root -> Prop.

(* Local consistency of the sets X i with the propositional word s. *)
Definition consistent (s : pword root) (X : nat -> fset) : Prop :=
  forall i : nat,
    ~ X i LFalse
    /\ (forall a, X i (LAtom a) -> s i a)
    /\ (forall p q, X i (LAnd p q) -> X i p /\ X i q)
    /\ (forall p q, X i (LOr p q) -> X i p \/ X i q)
    /\ (forall p, X i (LNext p) -> X (S i) p)
    /\ (forall p q, X i (LUntil p q) ->
          X i q \/ (X i p /\ X (S i) (LUntil p q)))
    /\ (forall p q, X i (LRelease p q) ->
          X i q /\ (X i p \/ X (S i) (LRelease p q))).

(* Breakpoint obligations. *)
Definition obl_init (O : nat -> fset) : Prop :=
  forall u, ~ O 0 u.

Definition obl_step (X O : nat -> fset) : Prop :=
  forall i u,
    O (S i) u <->
      ((exists p q, u = LUntil p q /\ X i u /\ ~ X i q)
       /\ ((forall v, ~ O i v) \/ O i u)).

Definition obl_inf (O : nat -> fset) : Prop :=
  forall n, exists j, n <= j /\ forall u, ~ O j u.

Lemma least_exists :
  forall P : nat -> Prop,
    (exists j, P j) -> exists j, P j /\ forall k, k < j -> ~ P k.
Proof.
  intros P [j Hj].
  induction j as [j IH] using lt_wf_ind.
  destruct (classic (exists k, k < j /\ P k)) as [[k [Hk Hpk]] | Hno].
  - exact (IH k Hk Hpk).
  - exists j. split; [exact Hj |].
    intros k Hk Hp. apply Hno. exists k. split; assumption.
Qed.

Lemma owed_in_X :
  forall s X O,
    consistent s X -> obl_init O -> obl_step X O ->
    forall i u, O i u -> X i u.
Proof.
  intros s X O Hc Hi Hs i u Ho.
  destruct i as [| i].
  - exfalso. exact (Hi u Ho).
  - destruct (proj1 (Hs i u) Ho) as [[p [q [Hu [Hxu Hnq]]]] _].
    subst u.
    destruct (Hc i) as [_ [_ [_ [_ [_ [Hun _]]]]]].
    destruct (Hun p q Hxu) as [H | [_ H]].
    + exfalso. exact (Hnq H).
    + exact H.
Qed.

(* An owed Until is eventually discharged. *)
Lemma owed_fulfilled :
  forall s X O,
    consistent s X -> obl_init O -> obl_step X O -> obl_inf O ->
    forall i p q, O i (LUntil p q) -> exists j, i <= j /\ X j q.
Proof.
  intros s X O Hc Hi Hs Hinf i p q Ho.
  destruct (classic (exists j, i <= j /\ X j q)) as [H | Hn].
  - exact H.
  - exfalso.
    assert (Hnot : forall j, i <= j -> ~ X j q).
    { intros j Hj Hx. apply Hn. exists j. split; assumption. }
    assert (Hall : forall k, O (i + k) (LUntil p q)).
    { induction k as [| k IH].
      - rewrite Nat.add_0_r. exact Ho.
      - assert (HX : X (i + k) (LUntil p q))
          by (eapply owed_in_X; eauto).
        replace (i + S k) with (S (i + k)) by lia.
        apply (proj2 (Hs (i + k) (LUntil p q))).
        split.
        + exists p, q. split; [reflexivity |].
          split; [exact HX | apply Hnot; lia].
        + right. exact IH. }
    destruct (Hinf i) as [j [Hj Hempty]].
    apply (Hempty (LUntil p q)).
    replace j with (i + (j - i)) by lia.
    apply Hall.
Qed.

(* Every Until carried by the run is eventually discharged. *)
Lemma until_fulfilled :
  forall s X O,
    consistent s X -> obl_init O -> obl_step X O -> obl_inf O ->
    forall p q i, X i (LUntil p q) -> exists j, i <= j /\ X j q.
Proof.
  intros s X O Hc Hi Hs Hinf p q i HXi.
  destruct (Hinf i) as [m [Him Hempty]].
  assert (Hgen : forall d i0, i0 + d = m -> X i0 (LUntil p q) ->
                    exists j, i0 <= j /\ X j q).
  { induction d as [| d IH]; intros i0 Hd Hx.
    - destruct (Hc i0) as [_ [_ [_ [_ [_ [Hu _]]]]]].
      destruct (classic (X i0 q)) as [Hq | Hq].
      + exists i0. split; [lia | exact Hq].
      + destruct (Hu p q Hx) as [Hq' | [_ Hn1]];
          [exfalso; exact (Hq Hq') |].
        assert (HO : O (S i0) (LUntil p q)).
        { apply (proj2 (Hs i0 (LUntil p q))).
          split.
          - exists p, q. split; [reflexivity |]. split; assumption.
          - left. replace i0 with m by lia. exact Hempty. }
        destruct (owed_fulfilled s X O Hc Hi Hs Hinf (S i0) p q HO)
          as [j [Hj Hxj]].
        exists j. split; [lia | exact Hxj].
    - destruct (Hc i0) as [_ [_ [_ [_ [_ [Hu _]]]]]].
      destruct (Hu p q Hx) as [Hq | [_ Hn1]].
      + exists i0. split; [lia | exact Hq].
      + destruct (IH (S i0) ltac:(lia) Hn1) as [j [Hj Hxj]].
        exists j. split; [lia | exact Hxj]. }
  exact (Hgen (m - i) i ltac:(lia) HXi).
Qed.

(* Soundness: every formula carried by an accepting run holds. *)
Theorem run_sound :
  forall s X O,
    consistent s X -> obl_init O -> obl_step X O -> obl_inf O ->
    forall f i, X i f -> psat s i f.
Proof.
  intros s X O Hc Hi Hs Hinf f.
  induction f as [ | | a | p IHp q IHq | p IHp q IHq | p IHp
                  | p IHp q IHq | p IHp q IHq ]; intros i Hx; simpl.
  - exact I.
  - exfalso. destruct (Hc i) as [Hf _]. exact (Hf Hx).
  - destruct (Hc i) as [_ [Ha _]]. exact (Ha a Hx).
  - destruct (Hc i) as [_ [_ [Hand _]]].
    destruct (Hand p q Hx) as [H1 H2].
    split; [apply IHp | apply IHq]; assumption.
  - destruct (Hc i) as [_ [_ [_ [Hor _]]]].
    destruct (Hor p q Hx) as [H | H];
      [left; apply IHp | right; apply IHq]; assumption.
  - destruct (Hc i) as [_ [_ [_ [_ [Hnext _]]]]].
    apply IHp. exact (Hnext p Hx).
  - (* Until *)
    destruct (until_fulfilled s X O Hc Hi Hs Hinf p q i Hx)
      as [j0 [Hj0 Hxj0]].
    destruct (least_exists (fun j => i <= j /\ X j q)
                (ex_intro _ j0 (conj Hj0 Hxj0)))
      as [j [[Hij Hxj] Hmin]].
    exists j. split; [exact Hij |].
    split; [apply IHq; exact Hxj |].
    assert (Hu : forall n, i + n < j -> X (i + n) (LUntil p q)).
    { induction n as [| n IHn]; intros Hlt.
      - rewrite Nat.add_0_r. exact Hx.
      - assert (Hprev : X (i + n) (LUntil p q)) by (apply IHn; lia).
        destruct (Hc (i + n)) as [_ [_ [_ [_ [_ [Hun _]]]]]].
        destruct (Hun p q Hprev) as [Hq | [_ Hn1]].
        + exfalso. apply (Hmin (i + n) ltac:(lia)). split; [lia | exact Hq].
        + replace (i + S n) with (S (i + n)) by lia. exact Hn1. }
    intros k [Hik Hkj].
    replace k with (i + (k - i)) by lia.
    apply IHp.
    destruct (Hc (i + (k - i))) as [_ [_ [_ [_ [_ [Hun _]]]]]].
    destruct (Hun p q (Hu (k - i) ltac:(lia))) as [Hq | [Hp _]].
    + exfalso. apply (Hmin (i + (k - i)) ltac:(lia)). split; [lia | exact Hq].
    + exact Hp.
  - (* Release *)
    assert (Hd : forall d i0, X i0 (LRelease p q) ->
               psat s (i0 + d) q \/
               exists k, i0 <= k < i0 + d /\ psat s k p).
    { induction d as [| d IH]; intros i0 Hx0.
      - left. rewrite Nat.add_0_r. apply IHq.
        destruct (Hc i0) as [_ [_ [_ [_ [_ [_ Hr]]]]]].
        exact (proj1 (Hr p q Hx0)).
      - destruct (Hc i0) as [_ [_ [_ [_ [_ [_ Hr]]]]]].
        destruct (Hr p q Hx0) as [_ [Hp | Hn1]].
        + right. exists i0. split; [lia | apply IHp; exact Hp].
        + destruct (IH (S i0) Hn1) as [H | [k [Hk Hpk]]].
          * left. replace (i0 + S d) with (S i0 + d) by lia. exact H.
          * right. exists k. split; [lia | exact Hpk]. }
    intros j Hj.
    replace j with (i + (j - i)) by lia.
    destruct (Hd (j - i) i Hx) as [H | [k [Hk Hpk]]].
    + left. exact H.
    + right. exists k. split; [lia | exact Hpk].
Qed.

End Sound.

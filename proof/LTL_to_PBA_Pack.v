(*
  LTL_to_PBA_Pack.v

  Generic packaging: a finite list [U] of abstract states, an edge relation
  [E] labelled by cubes taken from a finite list [cubes], and an accepting
  predicate [F] are turned into a [PBuchi] over nat-indexed states.  Its
  accepted words are exactly those with an accepting run through [U].
  The equality of states, the edge relation and the accepting predicate
  are assumed decidable; no axiom is used.
*)
Require Import Arith Lia List Bool.
Import ListNotations.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.

Section Pack.
Variable root : mtl.
Variable St : Type.
Variable U : list St.
Variable s0 : St.
Variable cubes : list (list (plit root)).
Variable E : St -> list (plit root) -> St -> Prop.
Variable F : St -> Prop.
Variable St_eq_dec : forall a b : St, {a = b} + {a <> b}.
Variable E_dec : forall x c y, {E x c y} + {~ E x c y}.
Variable F_dec : forall x, {F x} + {~ F x}.

Definition dec {P : Prop} (H : {P} + {~ P}) : bool := if H then true else false.

Lemma dec_iff : forall P (H : {P} + {~ P}), dec H = true <-> P.
Proof.
  intros P H. unfold dec. destruct H; split;
    intro K; auto; discriminate.
Qed.

Fixpoint idx (l : list St) (x : St) : nat :=
  match l with
  | [] => 0
  | y :: l' => if St_eq_dec x y then 0 else Datatypes.S (idx l' x)
  end.

Lemma idx_spec :
  forall l x, In x l -> idx l x < length l /\ nth (idx l x) l s0 = x.
Proof.
  induction l as [| y l IH]; intros x Hin; [destruct Hin |].
  simpl. destruct (St_eq_dec x y) as [e | ne].
  - split; [simpl; lia | symmetry; exact e].
  - destruct Hin as [h | h]; [exfalso; apply ne; symmetry; exact h |].
    destruct (IH x h) as [H1 H2]. split; [lia | exact H2].
Qed.

Definition cand : list (nat * nat * list (plit root)) :=
  flat_map (fun c =>
    flat_map (fun i => map (fun j => (i, j, c)) (seq 0 (length U)))
             (seq 0 (length U))) cubes.

Definition ok_cand (t : nat * nat * list (plit root)) : Prop :=
  match t with (i, j, c) => E (nth i U s0) c (nth j U s0) end.

Definition ok_cand_dec (t : nat * nat * list (plit root)) : {ok_cand t} + {~ ok_cand t} :=
  match t as t0 return {ok_cand t0} + {~ ok_cand t0} with
  | (i, j, c) => E_dec (nth i U s0) c (nth j U s0)
  end.

Definition mk_trans (t : nat * nat * list (plit root)) : ptransition root :=
  match t with
  | (i, j, c) => {| pt_src := i; pt_label := c; pt_tgt := j |}
  end.

Definition trans : list (ptransition root) :=
  map mk_trans (filter (fun t => dec (ok_cand_dec t)) cand).

Definition acc : list nat :=
  filter (fun i => dec (F_dec (nth i U s0))) (seq 0 (length U)).

Definition pack : PBuchi root :=
  {| pb_nstates := length U; pb_init := idx U s0;
     pb_trans := trans; pb_accepting := acc |}.

Lemma in_cand :
  forall i j c, In (i, j, c) cand <->
    i < length U /\ j < length U /\ In c cubes.
Proof.
  intros i j c. unfold cand. rewrite in_flat_map. split.
  - intros [c' [Hc' H]]. rewrite in_flat_map in H.
    destruct H as [i' [Hi' H]]. rewrite in_map_iff in H.
    destruct H as [j' [Heq Hj']]. inversion Heq; subst.
    rewrite in_seq in Hi', Hj'. repeat split; try lia; auto.
  - intros [Hi [Hj Hc]]. exists c. split; [exact Hc |].
    rewrite in_flat_map. exists i. split; [rewrite in_seq; lia |].
    rewrite in_map_iff. exists j. split; [reflexivity | rewrite in_seq; lia].
Qed.

Theorem pack_correct :
  In s0 U ->
  forall s : pword root,
    PBA_accepts pack s <->
    exists r : nat -> St,
      r 0 = s0 /\
      (forall i, In (r i) U /\
         exists c, In c cubes /\ E (r i) c (r (Datatypes.S i)) /\
                   Forall (plit_holds s i) c) /\
      (forall n, exists j, n <= j /\ F (r j)).
Proof.
  intros Hs0 s. split.
  - intros [run [H0 [Hstep Hacc]]].
    exists (fun i => nth (run i) U s0).
    split; [simpl; rewrite H0; simpl; apply idx_spec; exact Hs0 |].
    split.
    + intro i. destruct (Hstep i) as [Hlt [t [Ht [Hsrc [Htgt Hfa]]]]].
      split; [apply nth_In; exact Hlt |].
      unfold pack in Ht; simpl in Ht.
      unfold trans in Ht. rewrite in_map_iff in Ht.
      destruct Ht as [[[i0 j0] c0] [Heq Hin]]. simpl in Heq.
      rewrite filter_In in Hin. destruct Hin as [Hcand Hdec].
      rewrite dec_iff in Hdec. apply in_cand in Hcand.
      destruct Hcand as [_ [_ Hc]].
      subst t. simpl in Hsrc, Htgt, Hfa. subst i0 j0.
      unfold ok_cand in Hdec.
      exists c0. repeat split; assumption.
    + intro n. destruct (Hacc n) as [j [Hj Hin]].
      exists j. split; [exact Hj |].
      unfold pack in Hin; simpl in Hin. unfold acc in Hin.
      rewrite filter_In in Hin. destruct Hin as [_ Hd].
      rewrite dec_iff in Hd. exact Hd.
  - intros [r [H0 [Hstep Hacc]]].
    exists (fun i => idx U (r i)).
    split; [simpl; rewrite H0; reflexivity |].
    split.
    + intro i. destruct (Hstep i) as [Hin [c [Hc [HE Hfa]]]].
      destruct (Hstep (Datatypes.S i)) as [Hin' _].
      destruct (idx_spec U (r i) Hin) as [Hl Hn].
      destruct (idx_spec U (r (Datatypes.S i)) Hin') as [Hl' Hn'].
      split; [exact Hl |].
      exists {| pt_src := idx U (r i); pt_label := c;
                pt_tgt := idx U (r (Datatypes.S i)) |}.
      repeat split; try assumption.
      unfold pack; simpl. unfold trans. rewrite in_map_iff.
      exists (idx U (r i), idx U (r (Datatypes.S i)), c).
      split; [reflexivity |].
      rewrite filter_In. split.
      * apply in_cand. repeat split; assumption.
      * apply dec_iff. simpl. rewrite Hn, Hn'. exact HE.
    + intro n. destruct (Hacc n) as [j [Hj HF]].
      exists j. split; [exact Hj |].
      destruct (Hstep j) as [Hin _].
      destruct (idx_spec U (r j) Hin) as [Hl Hn].
      unfold pack; simpl. unfold acc. rewrite filter_In. split.
      * rewrite in_seq. lia.
      * apply dec_iff. rewrite Hn. exact HF.
Qed.

End Pack.

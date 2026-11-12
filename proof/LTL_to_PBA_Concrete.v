(*
  LTL_to_PBA_Concrete.v

  The concrete breakpoint automaton for a formula [f : ltl root], packaged
  as a [PBuchi root], and its soundness: an accepted word satisfies [f].

  State: a pair (mR, mO) of lists of formulas (subsets of the subformula
  closure of f).  mR: formulas required now.  mO: Until-obligations owed.
  Edge: chooses a saturated list mX of formulas holding now; its cube is the
  list of positive atoms of mX.
*)
Require Import Arith Lia List Bool.
Import ListNotations.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import LTL_to_PBA_Sound LTL_to_PBA_Pack.

(* Choice in a finite list, for a decidable property: no axiom. *)
Lemma list_choice :
  forall (A : Type) (l : list A) (P : A -> Prop),
    (forall a, {P a} + {~ P a}) ->
    (exists a, In a l /\ P a) -> {a : A | In a l /\ P a}.
Proof.
  intros A l P D. induction l as [| b l IH]; intros H.
  - exfalso. destruct H as [a [Ha _]]. destruct Ha.
  - destruct (D b) as [Hb | Hb].
    + exists b. split; [left; reflexivity | exact Hb].
    + assert (H' : exists a, In a l /\ P a).
      { destruct H as [a [[e | h] Pa]];
          [subst; contradiction | exists a; auto]. }
      destruct (IH H') as [a [h Pa]]. exists a. split; [right; exact h | exact Pa].
Defined.

Definition transport {A B : Prop} (H : A <-> B) (D : {B} + {~ B}) : {A} + {~ A} :=
  match D with
  | left b => left (proj2 H b)
  | right nb => right (fun a => nb (proj1 H a))
  end.

Definition forall_in_dec {A : Type} (l : list A) (Q : A -> Prop)
    (D : forall a, {Q a} + {~ Q a}) :
  {forall a, In a l -> Q a} + {~ forall a, In a l -> Q a}.
Proof.
  destruct (Forall_dec Q D l) as [H|H].
  - left. apply Forall_forall. exact H.
  - right. intro H'. apply H. apply Forall_forall. exact H'.
Defined.

Fixpoint subsets {A : Type} (l : list A) : list (list A) :=
  match l with
  | [] => [[]]
  | a :: l' => subsets l' ++ map (cons a) (subsets l')
  end.

Section Concrete.
Variable root : mtl.

Fixpoint subf (f : ltl root) : list (ltl root) :=
  match f with
  | LTrue | LFalse | LAtom _ => [f]
  | LAnd p q | LOr p q | LUntil p q | LRelease p q => f :: subf p ++ subf q
  | LNext p => f :: subf p
  end.

Definition cube (m : list (ltl root)) : list (plit root) :=
  flat_map (fun u => match u with LAtom a => [(a, true)] | _ => [] end) m.

Definition St : Type := (list (ltl root) * list (ltl root))%type.

Definition ok (s : St) (mX : list (ltl root)) (s' : St) : Prop :=
  let mR := fst s in let mO := snd s in
  let mR' := fst s' in let mO' := snd s' in
  (forall u, In u mR -> In u mX)
  /\ ~ In LFalse mX
  /\ (forall p q, In (LAnd p q) mX -> In p mX /\ In q mX)
  /\ (forall p q, In (LOr p q) mX -> In p mX \/ In q mX)
  /\ (forall p, In (LNext p) mX -> In p mR')
  /\ (forall p q, In (LUntil p q) mX ->
        In q mX \/ (In p mX /\ In (LUntil p q) mR'))
  /\ (forall p q, In (LRelease p q) mX ->
        In q mX /\ (In p mX \/ In (LRelease p q) mR'))
  /\ (forall u, In u mO' <->
        ((exists p q, u = LUntil p q /\ In u mX /\ ~ In q mX)
         /\ ((forall v, ~ In v mO) \/ In u mO))).

(* The edge relation, the accepting predicate and the equality of states
   are decidable. *)
Definition in_dec (u : ltl root) (l : list (ltl root)) : {In u l} + {~ In u l} :=
  In_dec (@ltl_eq_dec root) u l.

Definition ok_dec (st : St) (mX : list (ltl root)) (st' : St) :
  {ok st mX st'} + {~ ok st mX st'}.
Proof.
  destruct st as [mR mO], st' as [mR' mO']. unfold ok; simpl.
  apply and_dec.
  { apply forall_in_dec. intro u. apply in_dec. }
  apply and_dec.
  { apply not_dec. apply in_dec. }
  apply and_dec.
  { refine (transport (B := forall u, In u mX ->
                        match u with LAnd p q => In p mX /\ In q mX | _ => True end) _ _).
    - split; [intros H u Hu; destruct u; auto | intros H p q Hin; exact (H _ Hin)].
    - apply forall_in_dec. intro u.
      destruct u; try (left; exact I). apply and_dec; apply in_dec. }
  apply and_dec.
  { refine (transport (B := forall u, In u mX ->
                        match u with LOr p q => In p mX \/ In q mX | _ => True end) _ _).
    - split; [intros H u Hu; destruct u; auto | intros H p q Hin; exact (H _ Hin)].
    - apply forall_in_dec. intro u.
      destruct u; try (left; exact I). apply or_dec; apply in_dec. }
  apply and_dec.
  { refine (transport (B := forall u, In u mX ->
                        match u with LNext p => In p mR' | _ => True end) _ _).
    - split; [intros H u Hu; destruct u; auto | intros H p Hin; exact (H _ Hin)].
    - apply forall_in_dec. intro u.
      destruct u; try (left; exact I). apply in_dec. }
  apply and_dec.
  { refine (transport (B := forall u, In u mX ->
                        match u with
                        | LUntil p q => In q mX \/ (In p mX /\ In (LUntil p q) mR')
                        | _ => True end) _ _).
    - split; [intros H u Hu; destruct u; auto | intros H p q Hin; exact (H _ Hin)].
    - apply forall_in_dec. intro u.
      destruct u; try (left; exact I).
      apply or_dec; [apply in_dec | apply and_dec; apply in_dec]. }
  apply and_dec.
  { refine (transport (B := forall u, In u mX ->
                        match u with
                        | LRelease p q => In q mX /\ (In p mX \/ In (LRelease p q) mR')
                        | _ => True end) _ _).
    - split; [intros H u Hu; destruct u; auto | intros H p q Hin; exact (H _ Hin)].
    - apply forall_in_dec. intro u.
      destruct u; try (left; exact I).
      apply and_dec; [apply in_dec | apply or_dec; apply in_dec]. }
  pose (R := fun u : ltl root =>
               (exists p q, u = LUntil p q /\ In u mX /\ ~ In q mX)
               /\ ((forall v, ~ In v mO) \/ In u mO)).
  assert (DR : forall u, {R u} + {~ R u}).
  { intro u. unfold R. apply and_dec.
    - destruct u as [| | a | p q | p q | p | p q | p q];
        try (right; intros [p' [q' [E _]]]; discriminate E).
      destruct (in_dec (LUntil p q) mX) as [H1|H1];
        [| right; intros [p' [q' [E [H _]]]]; inversion E; subst; contradiction].
      destruct (in_dec q mX) as [H2|H2];
        [right; intros [p' [q' [E [_ H]]]]; inversion E; subst; contradiction|].
      left. exists p, q. auto.
    - apply or_dec; [|apply in_dec].
      destruct mO as [|v l]; [left; intros v []|].
      right. intro H. apply (H v). left. reflexivity. }
  refine (transport (A := forall u, In u mO' <-> R u)
                    (B := (forall u, In u mO' -> R u) /\
                          (forall u, In u mX -> R u -> In u mO')) _ _).
  - split.
    + intro H. split; [intros u Hu; apply H; exact Hu | intros u _ Hr; apply H; exact Hr].
    + intros [H1 H2] u. split; [apply H1|].
      intro Hr. apply (H2 u); [|exact Hr].
      destruct Hr as [[p [q [_ [Hu _]]]] _]. exact Hu.
  - apply and_dec; apply forall_in_dec; [exact DR|].
    intro u. apply impl_dec; [apply DR | apply in_dec].
Defined.

Definition E (C : list (ltl root)) (s : St) (c : list (plit root)) (s' : St) :
  Prop :=
  exists mX, In mX (subsets C) /\ c = cube mX /\ ok s mX s'.

Definition Fa (s : St) : Prop := forall v, ~ In v (snd s).

Definition E_dec (C : list (ltl root)) (st : St) (c : list (plit root)) (st' : St) :
  {E C st c st'} + {~ E C st c st'}.
Proof.
  unfold E.
  destruct (Exists_dec (fun mX => c = cube mX /\ ok st mX st') (subsets C)
              (fun mX => and_dec (list_eq_dec (@plit_eq_dec root) c (cube mX))
                                 (ok_dec st mX st'))) as [H|H].
  - left. apply Exists_exists in H. destruct H as [mX [Hin [Hc Hok]]].
    exists mX. auto.
  - right. intros [mX [Hin [Hc Hok]]]. apply H. apply Exists_exists.
    exists mX. auto.
Defined.

Definition Fa_dec (st : St) : {Fa st} + {~ Fa st}.
Proof.
  unfold Fa. destruct (snd st) as [|v l]; [left; intros v []|].
  right. intro H. apply (H v). left. reflexivity.
Defined.

Definition St_eq_dec (a b : St) : {a = b} + {a <> b}.
Proof.
  destruct a as [a1 a2], b as [b1 b2].
  destruct (list_eq_dec (@ltl_eq_dec root) a1 b1);
    destruct (list_eq_dec (@ltl_eq_dec root) a2 b2);
    [left; congruence | right; congruence | right; congruence | right; congruence].
Defined.

Definition init_st (f : ltl root) : St := ([f], []).

Definition Ust (f : ltl root) : list St :=
  init_st f :: list_prod (subsets (subf f)) (subsets (subf f)).

Definition backend (f : ltl root) : PBuchi root :=
  pack root St (Ust f) (init_st f) (map cube (subsets (subf f)))
       (E (subf f)) Fa St_eq_dec (E_dec (subf f)) Fa_dec.

Lemma backend_accepts :
  forall f s,
    PBA_accepts (backend f) s <->
    exists r : nat -> St,
      r 0 = init_st f /\
      (forall i, In (r i) (Ust f) /\
         exists c, In c (map cube (subsets (subf f))) /\
                   E (subf f) (r i) c (r (S i)) /\
                   Forall (plit_holds s i) c) /\
      (forall n, exists j, n <= j /\ Fa (r j)).
Proof.
  intros f s. unfold backend.
  apply pack_correct. left. reflexivity.
Qed.

(* Soundness: an accepted word satisfies f. *)
Theorem backend_sound :
  forall f s, PBA_accepts (backend f) s -> psat s 0 f.
Proof.
  intros f s Hacc.
  apply backend_accepts in Hacc.
  destruct Hacc as [r [H0 [Hstep Hfin]]].
  assert (Hex : forall i : nat, exists m, In m (subsets (subf f)) /\
                 ok (r i) m (r (S i)) /\ Forall (plit_holds s i) (cube m)).
  { intro i.
    destruct (Hstep i) as [_ [c [_ [[mX [Hm [Hc Hok]]] Hfa]]]].
    exists mX. subst c. exact (conj Hm (conj Hok Hfa)). }
  assert (Hp : forall i : nat, {m | In m (subsets (subf f)) /\
                 ok (r i) m (r (S i)) /\ Forall (plit_holds s i) (cube m)}).
  { intro i.
    exact (list_choice _ (subsets (subf f))
      (fun m => ok (r i) m (r (S i)) /\ Forall (plit_holds s i) (cube m))
      (fun m => and_dec (ok_dec (r i) m (r (S i)))
                  (Forall_dec (plit_holds s i) (fun l => bool_dec (s i (fst l)) (snd l))
                              (cube m)))
      (Hex i)). }
  set (pick := fun i => proj1_sig (Hp i)).
  assert (Hpick : forall i,
            ok (r i) (pick i) (r (S i)) /\
            Forall (plit_holds s i) (cube (pick i))).
  { intro i. exact (proj2 (proj2_sig (Hp i))). }
  set (X := fun i (u : ltl root) => In u (pick i)).
  set (O := fun i (u : ltl root) => In u (snd (r i))).
  assert (Hsub : forall i u, In u (fst (r i)) -> X i u).
  { intros i u Hu. exact (proj1 (proj1 (Hpick i)) u Hu). }
  assert (Hcons : consistent root s X).
  { intro i. destruct (Hpick i) as [Hok Hfa].
    destruct Hok as [_ [Hf [Hand [Hor [Hnext [Hun [Hrel _]]]]]]].
    refine (conj _ (conj _ (conj _ (conj _ (conj _ (conj _ _)))))).
    - exact Hf.
    - intros a Ha.
      assert (Hin : In (a, true) (cube (pick i))).
      { unfold cube. rewrite in_flat_map.
        exists (LAtom a). split; [exact Ha | left; reflexivity]. }
      rewrite Forall_forall in Hfa. exact (Hfa _ Hin).
    - exact Hand.
    - exact Hor.
    - intros p Hx. exact (Hsub (S i) p (Hnext p Hx)).
    - intros p q Hx. destruct (Hun p q Hx) as [H | [H1 H2]];
        [left; exact H | right; split; [exact H1 | exact (Hsub (S i) _ H2)]].
    - intros p q Hx. destruct (Hrel p q Hx) as [H1 [H2 | H2]];
        [split; [exact H1 | left; exact H2]
        | split; [exact H1 | right; exact (Hsub (S i) _ H2)]]. }
  assert (Hinit : obl_init root O).
  { intros u Hu. unfold O in Hu. rewrite H0 in Hu. destruct Hu. }
  assert (Hobl : obl_step root X O).
  { intros i u. destruct (Hpick i) as [Hok _].
    destruct Hok as [_ [_ [_ [_ [_ [_ [_ Ho]]]]]]]. exact (Ho u). }
  assert (Hinf : obl_inf root O).
  { intro n. destruct (Hfin n) as [j [Hj Hf]]. exists j. split; assumption. }
  apply (run_sound root s X O (fun i u => in_dec u (pick i)) Hcons Hinit Hobl Hinf f 0).
  apply Hsub. rewrite H0. left. reflexivity.
Qed.

End Concrete.

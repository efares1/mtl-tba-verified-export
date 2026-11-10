(*
  LTL_to_PBA_Concrete.v

  The concrete breakpoint automaton for a formula [f : ltl root], packaged
  as a [PBuchi root], and its soundness: an accepted word satisfies [f].

  State: a pair (mR, mO) of lists of formulas (subsets of the subformula
  closure of f).  mR: formulas required now.  mO: Until-obligations owed.
  Edge: chooses a saturated list mX of formulas holding now; its cube is the
  list of positive atoms of mX.
*)
Require Import Arith Lia List Bool Classical ClassicalDescription.
Import ListNotations.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import LTL_to_PBA_Sound LTL_to_PBA_Pack.

Lemma list_choice :
  forall (A : Type) (l : list A) (P : A -> Prop),
    (exists a, In a l /\ P a) -> {a : A | In a l /\ P a}.
Proof.
  intros A l P. induction l as [| b l IH]; intros H.
  - exfalso. destruct H as [a [Ha _]]. destruct Ha.
  - destruct (excluded_middle_informative (P b)) as [Hb | Hb].
    + exists b. split; [left; reflexivity | exact Hb].
    + assert (H' : exists a, In a l /\ P a).
      { destruct H as [a [[e | h] Pa]];
          [subst; contradiction | exists a; auto]. }
      destruct (IH H') as [a [h Pa]]. exists a. split; [right; exact h | exact Pa].
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

Definition E (C : list (ltl root)) (s : St) (c : list (plit root)) (s' : St) :
  Prop :=
  exists mX, In mX (subsets C) /\ c = cube mX /\ ok s mX s'.

Definition Fa (s : St) : Prop := forall v, ~ In v (snd s).

Definition init_st (f : ltl root) : St := ([f], []).

Definition Ust (f : ltl root) : list St :=
  init_st f :: list_prod (subsets (subf f)) (subsets (subf f)).

Definition backend (f : ltl root) : PBuchi root :=
  pack root St (Ust f) (init_st f) (map cube (subsets (subf f)))
       (E (subf f)) Fa.

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
  apply (run_sound root s X O Hcons Hinit Hobl Hinf f 0).
  apply Hsub. rewrite H0. left. reflexivity.
Qed.

End Concrete.

(*
  MTL_to_TBA_Slice.v

  Slicing of a conjunction of requirements (for instance the assumptions and the
  negated guarantee of an assume-guarantee check).  A conjunct is dropped when
  (a) every letter it mentions belongs to a set D of letters that no kept conjunct
  mentions, and (b) it holds on every word that never shows a letter it mentions
  (an evaluator folds the formula to true with every atom false; [ev_sound]).

  Theorem [slice_sound]: let S be a set of words closed under replacing the letters
  of D by a letter [eps] that no requirement mentions (the environment treats these
  letters uniformly).  Then S contains a word satisfying the requirement iff it
  contains one satisfying the sliced requirement.  The set D is proposed by an
  untrusted procedure (tool/src/slice.ml); [slice] checks it and returns the input
  unchanged when the check fails, so the theorem holds for every D.
*)

Require Import Arith Lia List Bool Reals Lra.
Require Import Setoid.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Import ListNotations.
Open Scope R_scope.

(* ---------------------------------------------------------------------- *)
(* Letters of a formula                                                    *)
(* ---------------------------------------------------------------------- *)

Fixpoint atoms (f : mtl) : list Action :=
  match f with
  | MTrue | MFalse => []
  | MAtom a | MNotAtom a => [a]
  | MAnd p q | MOr p q | MU p q | MR p q => atoms p ++ atoms q
  | MNext p => atoms p
  | MUhatLe _ p q | MUhatGe _ p q | MRhatLe _ p q | MRhatGe _ p q
  | MUhatLt _ p q | MUhatGt _ p q | MRhatLt _ p q | MRhatGt _ p q => atoms p ++ atoms q
  end.

(* ---------------------------------------------------------------------- *)
(* Relabelling the letters of a word                                       *)
(* ---------------------------------------------------------------------- *)

Definition inb (a : Action) (D : list Action) : bool := existsb (Nat.eqb a) D.

Lemma inb_true : forall a D, inb a D = true <-> In a D.
Proof.
  intros a D. unfold inb. rewrite existsb_exists. split.
  - intros [x [Hx He]]. apply Nat.eqb_eq in He. subst. exact Hx.
  - intros H. exists a. split; [exact H | apply Nat.eqb_refl].
Qed.

Definition relabel (D : list Action) (eps : Action) (w : timed_word) : timed_word :=
  {| tw_action := fun i => if inb (tw_action w i) D then eps else tw_action w i;
     tw_time := tw_time w;
     tw_time_nonnegative := tw_time_nonnegative w;
     tw_time_mono := tw_time_mono w;
     tw_time_divergent := tw_time_divergent w |}.

(* msat only looks at the times and at the letters mentioned by the formula *)
Lemma msat_ext :
  forall f (w w' : timed_word),
    (forall i, tw_time w' i = tw_time w i) ->
    (forall a, In a (atoms f) -> forall i, (tw_action w' i = a <-> tw_action w i = a)) ->
    forall i, msat w' i f <-> msat w i f.
Proof.
  induction f; intros w w' Ht Ha i; simpl.
  1: {tauto. }
  1: {tauto. }
  1: {apply Ha. simpl. auto. }
  1: {simpl in Ha. pose proof (Ha _ (or_introl eq_refl) i). tauto. }
  1: {rewrite (IHf1 w w' Ht (fun a H => Ha a (in_or_app _ _ _ (or_introl H))) i).
    rewrite (IHf2 w w' Ht (fun a H => Ha a (in_or_app _ _ _ (or_intror H))) i). tauto. }
  1: {rewrite (IHf1 w w' Ht (fun a H => Ha a (in_or_app _ _ _ (or_introl H))) i).
    rewrite (IHf2 w w' Ht (fun a H => Ha a (in_or_app _ _ _ (or_intror H))) i). tauto. }
  1: {apply IHf; auto. }
  all: try (
      pose proof (IHf1 w w' Ht (fun a H => Ha a (in_or_app _ _ _ (or_introl H)))) as H1;
      pose proof (IHf2 w w' Ht (fun a H => Ha a (in_or_app _ _ _ (or_intror H)))) as H2;
      (try setoid_rewrite Ht); setoid_rewrite H1; setoid_rewrite H2; reflexivity).
Qed.

Lemma msat_relabel :
  forall D eps f,
    (forall a, In a (atoms f) -> ~ In a D /\ a <> eps) ->
    forall w i, msat (relabel D eps w) i f <-> msat w i f.
Proof.
  intros D eps f Hf w i. apply msat_ext.
  - intros j. reflexivity.
  - intros a Ha j. destruct (Hf a Ha) as [HD Hne]. simpl.
    destruct (inb (tw_action w j) D) eqn:E.
    + apply inb_true in E. split; intros H; exfalso.
      * apply Hne. symmetry. exact H.
      * apply HD. rewrite <- H. exact E.
    + tauto.
Qed.

(* ---------------------------------------------------------------------- *)
(* Evaluation on words that show none of the letters of the formula        *)
(* ---------------------------------------------------------------------- *)

Inductive tri := TT | TF | TU.

Fixpoint ev (f : mtl) : tri :=
  match f with
  | MTrue => TT
  | MFalse => TF
  | MAtom _ => TF
  | MNotAtom _ => TT
  | MAnd p q => match ev p, ev q with
                | TF, _ => TF | _, TF => TF | TT, TT => TT | _, _ => TU end
  | MOr p q => match ev p, ev q with
               | TT, _ => TT | _, TT => TT | TF, TF => TF | _, _ => TU end
  | MNext p => ev p
  | MU _ q => match ev q with TT => TT | TF => TF | TU => TU end
  | MUhatLe _ _ q | MUhatGe _ _ q | MUhatLt _ _ q | MUhatGt _ _ q =>
      match ev q with TF => TF | _ => TU end
  | MR _ q => match ev q with TT => TT | TF => TF | TU => TU end
  | MRhatLe _ _ q | MRhatGe _ _ q | MRhatLt _ _ q | MRhatGt _ _ q =>
      match ev q with TT => TT | _ => TU end
  end.

Definition sem_tri (f : mtl) (w : timed_word) : Prop :=
  match ev f with
  | TT => forall i, msat w i f
  | TF => forall i, ~ msat w i f
  | TU => True
  end.

Lemma ev_sound :
  forall f w, (forall j a, In a (atoms f) -> tw_action w j <> a) -> sem_tri f w.
Proof.
  induction f; intros w Hav; unfold sem_tri in *; simpl.
  1: {intros i. exact I. }
  1: {intros i H. exact H. }
  1: {intros i. simpl in Hav. exact (Hav i _ (or_introl eq_refl)). }
  1: {intros i. simpl in Hav. exact (Hav i _ (or_introl eq_refl)). }
  1: {pose proof (IHf1 w (fun j a H => Hav j a (in_or_app _ _ _ (or_introl H)))) as I1.
    pose proof (IHf2 w (fun j a H => Hav j a (in_or_app _ _ _ (or_intror H)))) as I2.
    destruct (ev f1) eqn:E1; destruct (ev f2) eqn:E2; simpl in *;
      try exact I; intros i; try specialize (I1 i); try specialize (I2 i); simpl; tauto. }
  1: {pose proof (IHf1 w (fun j a H => Hav j a (in_or_app _ _ _ (or_introl H)))) as I1.
    pose proof (IHf2 w (fun j a H => Hav j a (in_or_app _ _ _ (or_intror H)))) as I2.
    destruct (ev f1) eqn:E1; destruct (ev f2) eqn:E2; simpl in *;
      try exact I; intros i; try specialize (I1 i); try specialize (I2 i); simpl; tauto. }
  1: {pose proof (IHf w Hav) as I1.
    destruct (ev f) eqn:E1; simpl in *; try exact I; intros i; apply I1. }
  1: {(* MU *)
    pose proof (IHf2 w (fun j a H => Hav j a (in_or_app _ _ _ (or_intror H)))) as I2.
    destruct (ev f2) eqn:E2; simpl in *; try exact I.
    + intros i. exists i. split; [lia | split; [apply I2 | intros k Hk; lia]].
    + intros i [j [_ [Hq _]]]. exact (I2 j Hq). }
  1: {(* MR *)
    pose proof (IHf2 w (fun j a H => Hav j a (in_or_app _ _ _ (or_intror H)))) as I2.
    destruct (ev f2) eqn:E2; simpl in *; try exact I.
    + intros i j Hj. left. apply I2.
    + intros i H. specialize (H i (le_n i)). destruct H as [H | [k [Hk _]]].
      * exact (I2 i H).
      * lia. }
  all: pose proof (IHf2 w (fun j a H => Hav j a (in_or_app _ _ _ (or_intror H)))) as I2;
      destruct (ev f2) eqn:E2; simpl in *; try exact I;
      first [ intros i [j [Hij [Ht [Hq Hp]]]]; exact (I2 j Hq)
            | intros i j Hij Ht; left; apply I2 ].
Qed.

(* ---------------------------------------------------------------------- *)
(* Conjunctions                                                            *)
(* ---------------------------------------------------------------------- *)

Fixpoint conjuncts (f : mtl) : list mtl :=
  match f with
  | MAnd p q => conjuncts p ++ conjuncts q
  | _ => [f]
  end.

Definition conj_list (l : list mtl) : mtl := fold_right MAnd MTrue l.

Lemma conj_list_sat :
  forall l w i, msat w i (conj_list l) <-> forall c, In c l -> msat w i c.
Proof.
  induction l; intros w i; simpl.
  - split; [intros _ c [] | intros _; exact I].
  - rewrite IHl. split.
    + intros [H1 H2] c [Hc | Hc]; [subst; exact H1 | exact (H2 c Hc)].
    + intros H. split; [apply H; auto | intros c Hc; apply H; auto].
Qed.

Lemma conjuncts_sat :
  forall f w i, msat w i f <-> forall c, In c (conjuncts f) -> msat w i c.
Proof.
  induction f; intros w i; try (cbn [conjuncts]; split; [intros H c [Hc | []]; subst; exact H | intros H; apply H; left; reflexivity]).
  simpl. rewrite IHf1, IHf2. split.
  - intros [H1 H2] c Hc. apply in_app_or in Hc. destruct Hc as [Hc | Hc]; auto.
  - intros H. split; intros c Hc; apply H; apply in_or_app; auto.
Qed.

Lemma conjuncts_atoms :
  forall f c, In c (conjuncts f) -> forall a, In a (atoms c) -> In a (atoms f).
Proof.
  induction f; simpl; intros c Hc x Hx;
    try (destruct Hc as [Hc | []]; subst; exact Hx).
  apply in_app_or in Hc. apply in_or_app. destruct Hc as [Hc | Hc].
  - left. eapply IHf1; eauto.
  - right. eapply IHf2; eauto.
Qed.

(* ---------------------------------------------------------------------- *)
(* The pass                                                                *)
(* ---------------------------------------------------------------------- *)

Definition dropb (D : list Action) (c : mtl) : bool :=
  forallb (fun a => inb a D) (atoms c) &&
  match ev c with TT => true | _ => false end.

Definition kept (D : list Action) (f : mtl) : list mtl :=
  filter (fun c => negb (dropb D c)) (conjuncts f).

Definition slice_ok (D : list Action) (f : mtl) : bool :=
  forallb (fun c => forallb (fun a => negb (inb a D)) (atoms c)) (kept D f).

Definition slice (D : list Action) (f : mtl) : mtl :=
  if slice_ok D f then conj_list (kept D f) else f.

Lemma dropb_true :
  forall D c, dropb D c = true -> (forall a, In a (atoms c) -> In a D) /\ ev c = TT.
Proof.
  intros D c H. unfold dropb in H. apply andb_true_iff in H. destruct H as [H1 H2].
  split.
  - intros a Ha. rewrite forallb_forall in H1. apply inb_true. apply H1. exact Ha.
  - destruct (ev c); [reflexivity | discriminate | discriminate].
Qed.

Theorem slice_sound :
  forall D f eps (S : timed_word -> Prop),
    ~ In eps (atoms f) ->
    (forall w, S w -> S (relabel D eps w)) ->
    ((exists w, S w /\ msat w 0 f) <-> (exists w, S w /\ msat w 0 (slice D f))).
Proof.
  intros D f eps S Heps Hcl. unfold slice.
  destruct (slice_ok D f) eqn:Hok; [| tauto].
  split.
  - intros [w [Hw Hsat]]. exists w. split; [exact Hw |].
    rewrite conj_list_sat. rewrite conjuncts_sat in Hsat.
    intros c Hc. unfold kept in Hc. apply filter_In in Hc. destruct Hc as [Hc _].
    apply Hsat. exact Hc.
  - intros [w [Hw Hsat]]. exists (relabel D eps w). split; [apply Hcl; exact Hw |].
    rewrite conj_list_sat in Hsat.
    rewrite conjuncts_sat. intros c Hc.
    destruct (dropb D c) eqn:Hd.
    + destruct (dropb_true D c Hd) as [HD Hev].
      pose proof (ev_sound c (relabel D eps w)) as Hs.
      assert (Hav : forall j a, In a (atoms c) -> tw_action (relabel D eps w) j <> a).
      { intros j a Ha Heq. simpl in Heq.
        destruct (inb (tw_action w j) D) eqn:E.
        - apply Heps. subst a. eapply conjuncts_atoms; eauto.
        - rewrite Heq in E. pose proof (proj2 (inb_true a D) (HD a Ha)) as T.
          rewrite T in E. discriminate. }
      specialize (Hs Hav). unfold sem_tri in Hs. rewrite Hev in Hs. apply Hs.
    + assert (Hk : In c (kept D f)).
      { unfold kept. apply filter_In. split; [exact Hc | rewrite Hd; reflexivity]. }
      unfold slice_ok in Hok. rewrite forallb_forall in Hok.
      specialize (Hok c Hk). rewrite forallb_forall in Hok.
      rewrite msat_relabel.
      * apply Hsat. exact Hk.
      * intros a Ha. split.
        -- pose proof (Hok a Ha) as H. apply negb_true_iff in H.
           intros HD. apply inb_true in HD. rewrite HD in H. discriminate.
        -- intros Hae. apply Heps. subst a. eapply conjuncts_atoms; eauto.
Qed.

Print Assumptions slice_sound.

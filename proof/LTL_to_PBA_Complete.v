(*
  LTL_to_PBA_Complete.v

  Completeness of the concrete breakpoint automaton: a word satisfying f
  is accepted by [backend f].  The run takes as required sets the closure
  subformulas that are true at each position.
*)
Require Import Arith Lia List Bool Classical ClassicalDescription.
Import ListNotations.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import LTL_to_PBA_Sound LTL_to_PBA_Pack LTL_to_PBA_Concrete.

Section Closure.
Variable root : mtl.

Definition closed (C : list (ltl root)) : Prop :=
  (forall p q, In (LAnd p q) C \/ In (LOr p q) C \/
               In (LUntil p q) C \/ In (LRelease p q) C ->
     In p C /\ In q C)
  /\ (forall p, In (LNext p) C -> In p C).

Lemma closed_nil : closed [].
Proof.
  split; intros; [destruct H as [H|[H|[H|H]]] | ]; destruct H.
Qed.

Lemma closed_app : forall C1 C2, closed C1 -> closed C2 -> closed (C1 ++ C2).
Proof.
  intros C1 C2 [B1 N1] [B2 N2]. split.
  - intros p q H.
    assert (Hs : In (LAnd p q) C1 \/ In (LOr p q) C1 \/ In (LUntil p q) C1 \/
                 In (LRelease p q) C1 \/ In (LAnd p q) C2 \/ In (LOr p q) C2 \/
                 In (LUntil p q) C2 \/ In (LRelease p q) C2).
    { destruct H as [H|[H|[H|H]]]; apply in_app_or in H; tauto. }
    destruct Hs as [Hs|[Hs|[Hs|[Hs|[Hs|[Hs|[Hs|Hs]]]]]]];
    first
      [ (destruct (B1 p q ltac:(tauto)) as [A B];
         split; apply in_or_app; tauto)
      | (destruct (B2 p q ltac:(tauto)) as [A B];
         split; apply in_or_app; tauto) ].
  - intros p H. apply in_app_or in H. apply in_or_app.
    destruct H as [H|H]; [left; apply N1 | right; apply N2]; exact H.
Qed.

Lemma closed_cons :
  forall (g : ltl root) C, closed C ->
    (forall p q, (g = LAnd p q \/ g = LOr p q \/ g = LUntil p q \/
                  g = LRelease p q) -> In p C /\ In q C) ->
    (forall p, g = LNext p -> In p C) ->
    closed (g :: C).
Proof.
  intros g C [B N] Hgb Hgn. split.
  - intros p q H.
    assert (key : forall X, (X = LAnd p q \/ X = LOr p q \/ X = LUntil p q \/
                             X = LRelease p q) -> In X (g :: C) ->
                    In p (g :: C) /\ In q (g :: C)).
    { intros X HX [HXg | HXC].
      - subst X. destruct (Hgb p q HX) as [A B']. split; right; assumption.
      - destruct (B p q) as [A B'].
        + destruct HX as [E|[E|[E|E]]]; rewrite E in HXC; tauto.
        + split; right; assumption. }
    destruct H as [H|[H|[H|H]]];
      [ exact (key _ (or_introl eq_refl) H)
      | exact (key _ (or_intror (or_introl eq_refl)) H)
      | exact (key _ (or_intror (or_intror (or_introl eq_refl))) H)
      | exact (key _ (or_intror (or_intror (or_intror eq_refl))) H) ].
  - intros p H. destruct H as [E | H].
    + right. exact (Hgn p E).
    + right. exact (N p H).
Qed.

Lemma subf_self : forall f : ltl root, In f (subf root f).
Proof. intro f. destruct f; simpl; left; reflexivity. Qed.

Lemma closed_subf : forall f : ltl root, closed (subf root f).
Proof.
  induction f as [ | | a | p IHp q IHq | p IHp q IHq | p IHp
                  | p IHp q IHq | p IHp q IHq ]; simpl.
  1-3: apply closed_cons; [ apply closed_nil
       | intros p q H; exfalso; destruct H as [E|[E|[E|E]]]; discriminate E
       | intros p H; discriminate H ].
  all: first
    [ (apply closed_cons;
       [ apply closed_app; assumption
       | intros p0 q0 E; destruct E as [E|[E|[E|E]]]; try discriminate E;
         injection E as <- <-; split; apply in_or_app; [left|right];
         apply subf_self
       | intros p0 E; discriminate E ])
    | (apply closed_cons;
       [ exact IHp
       | intros p0 q0 E; destruct E as [E|[E|[E|E]]]; discriminate E
       | intros p0 E; injection E as <-; apply subf_self ]) ].
Qed.

Lemma subsets_rep :
  forall (A : Type) (l : list A) (P : A -> Prop),
    (forall a, P a -> In a l) ->
    exists m, In m (subsets l) /\ forall a, In a m <-> P a.
Proof.
  intros A l. induction l as [| b l IH]; intros P HP.
  - exists []. split; [left; reflexivity |].
    intro a. split; [intros [] | intro H; exact (HP a H)].
  - destruct (IH (fun a => P a /\ In a l)) as [m [Hm Hspec]].
    { intros a [_ H]. exact H. }
    destruct (classic (P b /\ ~ In b l)) as [Hb | Hb].
    + exists (b :: m). split.
      * simpl. apply in_or_app. right. apply in_map_iff.
        exists m. split; [reflexivity | exact Hm].
      * intro a. simpl. split.
        -- intros [E | H]; [subst a; exact (proj1 Hb)
                           | exact (proj1 (proj1 (Hspec a) H))].
        -- intro H. destruct (HP a H) as [E | E];
             [left; exact E | right; apply Hspec; split; assumption].
    + exists m. split.
      * simpl. apply in_or_app. left. exact Hm.
      * intro a. rewrite Hspec. split.
        -- intros [H _]. exact H.
        -- intro H. split; [exact H |].
           destruct (HP a H) as [E | E]; [| exact E].
           subst a. destruct (classic (In b l)) as [Hi | Hi];
             [exact Hi | exfalso; apply Hb; split; assumption].
Qed.

Definition rep_exists (C : list (ltl root)) (P : ltl root -> Prop)
  (HP : forall u, P u -> In u C) :
  {m : list (ltl root) | In m (subsets C) /\ forall u, In u m <-> P u}.
Proof.
  apply (list_choice _ (subsets C) (fun m => forall u, In u m <-> P u)).
  destruct (subsets_rep _ C P HP) as [m H]. exists m. exact H.
Defined.

(* Breakpoint obligations computed from a family of sets X. *)
Fixpoint Ofun (X : nat -> ltl root -> Prop) (i : nat) : ltl root -> Prop :=
  match i with
  | 0 => fun _ => False
  | S k => fun u =>
      ((exists p q, u = LUntil p q /\ X k u /\ ~ X k q)
       /\ ((forall v, ~ Ofun X k v) \/ Ofun X k u))
  end.

Lemma Ofun_S : forall X i u,
  Ofun X (S i) u <->
    ((exists p q, u = LUntil p q /\ X i u /\ ~ X i q)
     /\ ((forall v, ~ Ofun X i v) \/ Ofun X i u)).
Proof. intros. split; intro H; exact H. Qed.

Section Live.
Variable f : ltl root.
Variable s : pword root.

Definition Xt (i : nat) (u : ltl root) : Prop :=
  In u (subf root f) /\ psat s i u.

Lemma O_in_C : forall i u, Ofun Xt i u -> In u (subf root f).
Proof.
  intros i u H. destruct i as [| k]; [destruct H |].
  apply Ofun_S in H. destruct H as [[p [q [_ [Hx _]]]] _]. exact (proj1 Hx).
Qed.

Lemma O_step_back :
  forall n, (forall j, n <= j -> exists v, Ofun Xt j v) ->
    forall j u, n <= j -> Ofun Xt (S j) u -> Ofun Xt j u.
Proof.
  intros n Hne j u Hj H. apply Ofun_S in H. destruct H as [_ [Hn | Ho]].
  - destruct (Hne j Hj) as [v Hv]. exfalso. exact (Hn v Hv).
  - exact Ho.
Qed.

Lemma O_chain :
  forall n, (forall j, n <= j -> exists v, Ofun Xt j v) ->
    forall d u j, n <= j -> Ofun Xt (j + d) u -> Ofun Xt j u.
Proof.
  intros n Hne d. induction d as [| d IH]; intros u j Hj H.
  - rewrite Nat.add_0_r in H. exact H.
  - replace (j + S d) with (S (j + d)) in H by lia.
    apply (IH u j Hj). apply (O_step_back n Hne (j + d) u ltac:(lia) H).
Qed.

Lemma until_witness :
  forall m p q, Xt m (LUntil p q) -> ~ Xt m q ->
    exists j, S m <= j /\ Xt j q.
Proof.
  intros m p q [Hc Hps] Hnq.
  assert (Hq : In q (subf root f)).
  { exact (proj2 ((proj1 (closed_subf f)) p q
             (or_intror (or_intror (or_introl Hc))))). }
  destruct Hps as [j [Hmj [Hqj Hp]]].
  destruct (Nat.eq_dec j m) as [E | E].
  - subst j. exfalso. apply Hnq. split; assumption.
  - exists j. split; [lia | split; assumption].
Qed.

Lemma bound :
  forall n m, n = S m ->
    forall L : list (ltl root), exists K,
      forall u, In u L -> Ofun Xt n u ->
        exists j, n <= j /\ j <= K /\ exists p q, u = LUntil p q /\ Xt j q.
Proof.
  intros n m Hn L. induction L as [| a L IH].
  - exists 0. intros u [].
  - destruct IH as [K HK].
    destruct (classic (Ofun Xt n a)) as [Ha | Ha].
    + subst n. apply Ofun_S in Ha.
      destruct Ha as [[p [q [E [Hx Hnq]]]] _].
      assert (Hx' : Xt m (LUntil p q)) by (rewrite <- E; exact Hx).
      destruct (until_witness m p q Hx' Hnq) as [j [Hj Hxj]].
      exists (Nat.max K j). intros u [<- | Hu] Hou.
      * exists j. split; [exact Hj |]. split; [lia |].
        exists p, q. split; [exact E | exact Hxj].
      * destruct (HK u Hu Hou) as [j' [H1 [H2 H3]]].
        exists j'. split; [exact H1 |]. split; [lia | exact H3].
    + exists K. intros u [<- | Hu] Hou.
      * exfalso. exact (Ha Hou).
      * exact (HK u Hu Hou).
Qed.

Theorem O_live :
  forall n, exists j, n <= j /\ forall v, ~ Ofun Xt j v.
Proof.
  intro n. destruct n as [| m].
  - exists 0. split; [lia | intros v H; exact H].
  - destruct (classic (exists j, S m <= j /\ forall v, ~ Ofun Xt j v))
      as [H | Hno]; [exact H |]. exfalso.
    assert (Hne : forall j, S m <= j -> exists v, Ofun Xt j v).
    { intros j Hj.
      destruct (classic (exists v, Ofun Xt j v)) as [H | H]; [exact H |].
      exfalso. apply Hno. exists j. split; [exact Hj |].
      intros v Hv. apply H. exists v. exact Hv. }
    destruct (bound (S m) m eq_refl (subf root f)) as [K HK].
    destruct (Hne (S m + (K + 1)) ltac:(lia)) as [v Hv].
    assert (Hv0 : Ofun Xt (S m) v).
    { exact (O_chain (S m) Hne (K + 1) v (S m) (le_n _) Hv). }
    pose proof (O_in_C _ _ Hv0) as Hin.
    destruct (HK v Hin Hv0) as [j [Hj1 [Hj2 [p [q [E Hxq]]]]]].
    assert (Hvj : Ofun Xt (S j) v).
    { replace (S m + (K + 1)) with (S j + (S m + (K + 1) - S j)) in Hv by lia.
      exact (O_chain (S m) Hne _ v (S j) ltac:(lia) Hv). }
    apply Ofun_S in Hvj. destruct Hvj as [[p' [q' [E' [_ Hnq]]]] _].
    rewrite E in E'. injection E' as <- <-. exact (Hnq Hxq).
Qed.

Section Run.
Hypothesis Hf : psat s 0 f.

Definition repX (i : nat) : list (ltl root) :=
  proj1_sig (rep_exists (subf root f) (Xt i) (fun u H => proj1 H)).

Definition repO (i : nat) : list (ltl root) :=
  proj1_sig (rep_exists (subf root f) (Ofun Xt i) (O_in_C i)).

Lemma repX_spec : forall i,
  In (repX i) (subsets (subf root f)) /\ forall u, In u (repX i) <-> Xt i u.
Proof. intro i. exact (proj2_sig (rep_exists (subf root f) (Xt i) (fun u H => proj1 H))). Qed.

Lemma repO_spec : forall i,
  In (repO i) (subsets (subf root f)) /\
  forall u, In u (repO i) <-> Ofun Xt i u.
Proof. intro i. exact (proj2_sig (rep_exists (subf root f) (Ofun Xt i) (O_in_C i))). Qed.

Definition run (i : nat) : St root :=
  match i with
  | 0 => init_st root f
  | S k => (repX (S k), repO (S k))
  end.

Lemma run_fst : forall i u, In u (fst (run i)) -> In u (repX i).
Proof.
  intros i u H. destruct i as [| k]; [| exact H].
  simpl in H. destruct H as [<- | []].
  apply (proj2 (proj2 (repX_spec 0) f)). split; [apply subf_self | exact Hf].
Qed.

Lemma run_fst' : forall i u, In u (fst (run (S i))) <-> Xt (S i) u.
Proof. intros i u. exact (proj2 (repX_spec (S i)) u). Qed.

Lemma run_snd : forall i u, In u (snd (run i)) <-> Ofun Xt i u.
Proof.
  intros i u. destruct i as [| k].
  - simpl. split; intros [].
  - exact (proj2 (repO_spec (S k)) u).
Qed.

Lemma clo : closed (subf root f). Proof. exact (closed_subf f). Qed.

Lemma ok_O : forall i u,
  In u (snd (run (S i))) <->
    ((exists p q, u = LUntil p q /\ In u (repX i) /\ ~ In q (repX i))
     /\ ((forall v, ~ In v (snd (run i))) \/ In u (snd (run i)))).
Proof.
  intros i u. rewrite (run_snd (S i) u). rewrite Ofun_S. split.
  - intros [[p [q [E [Hx Hnq]]]] H3]. split.
    + exists p, q. split; [exact E |]. split.
      * apply (proj2 (proj2 (repX_spec i) u)). exact Hx.
      * intro Hq. apply Hnq. apply (proj1 (proj2 (repX_spec i) q)). exact Hq.
    + destruct H3 as [H3 | H3].
      * left. intros v Hv. apply (H3 v). apply run_snd. exact Hv.
      * right. apply run_snd. exact H3.
  - intros [[p [q [E [Hx Hnq]]]] H3]. split.
    + exists p, q. split; [exact E |]. split.
      * apply (proj1 (proj2 (repX_spec i) u)). exact Hx.
      * intro Hq. apply Hnq. apply (proj2 (proj2 (repX_spec i) q)). exact Hq.
    + destruct H3 as [H3 | H3].
      * left. intros v Hv. apply (H3 v). apply run_snd. exact Hv.
      * right. apply run_snd. exact H3.
Qed.

Lemma ok_run : forall i, ok root (run i) (repX i) (run (S i)).
Proof.
  intro i.
  pose proof (proj2 (repX_spec i)) as HX.
  destruct clo as [CB CN].
  refine (conj _ (conj _ (conj _ (conj _ (conj _ (conj _ (conj _ _))))))).
  - intros u Hu. exact (run_fst i u Hu).
  - intro H. exact (proj2 (proj1 (HX _) H)).
  - intros p q H. destruct (proj1 (HX _) H) as [Hc [A B]].
    destruct (CB p q (or_introl Hc)) as [Cp Cq].
    split; apply (proj2 (HX _)); split; assumption.
  - intros p q H. destruct (proj1 (HX _) H) as [Hc Hps].
    destruct (CB p q (or_intror (or_introl Hc))) as [Cp Cq].
    destruct Hps as [A | A]; [left | right]; apply (proj2 (HX _)); split;
      assumption.
  - intros p H. destruct (proj1 (HX _) H) as [Hc Hps].
    apply run_fst'. split; [exact (CN p Hc) | exact Hps].
  - intros p q H. destruct (proj1 (HX _) H) as [Hc [j [Hij [Hq Hp]]]].
    destruct (CB p q (or_intror (or_intror (or_introl Hc)))) as [Cp Cq].
    destruct (Nat.eq_dec j i) as [E | E].
    + subst j. left. apply (proj2 (HX _)). split; assumption.
    + right. split.
      * apply (proj2 (HX _)). split; [exact Cp | apply Hp; lia].
      * apply run_fst'. split; [exact Hc |].
        exists j. split; [lia |]. split; [exact Hq |].
        intros k Hk. apply Hp. lia.
  - intros p q H. destruct (proj1 (HX _) H) as [Hc Hps].
    destruct (CB p q (or_intror (or_intror (or_intror Hc)))) as [Cp Cq].
    assert (Hqi : psat s i q).
    { destruct (Hps i (le_n i)) as [Hq | [k [Hk _]]]; [exact Hq | lia]. }
    split; [apply (proj2 (HX _)); split; assumption |].
    destruct (classic (psat s i p)) as [Hp | Hp].
    + left. apply (proj2 (HX _)). split; assumption.
    + right. apply run_fst'. split; [exact Hc |].
      intros j Hj. destruct (Hps j ltac:(lia)) as [Hq' | [k [Hk Hpk]]];
        [left; exact Hq' | right].
      exists k. split; [| exact Hpk].
      destruct (Nat.eq_dec k i) as [E | E];
        [subst k; exfalso; exact (Hp Hpk) | lia].
  - exact (ok_O i).
Qed.

Lemma cube_holds : forall i,
  Forall (plit_holds s i) (cube root (repX i)).
Proof.
  intro i. rewrite Forall_forall. intros l Hl. unfold cube in Hl.
  rewrite in_flat_map in Hl. destruct Hl as [x [Hx Hl]].
  destruct x; simpl in Hl; try (destruct Hl; fail).
  destruct Hl as [<- | []].
  destruct (proj1 (proj2 (repX_spec i) _) Hx) as [_ Hps].
  exact Hps.
Qed.

Theorem backend_complete_run : PBA_accepts (backend root f) s.
Proof.
  apply backend_accepts. exists run. split; [reflexivity |]. split.
  - intro i. split.
    + destruct i as [| k]; [left; reflexivity |].
      right. simpl. apply in_prod;
        [exact (proj1 (repX_spec (S k))) | exact (proj1 (repO_spec (S k)))].
    + exists (cube root (repX i)). split.
      * apply in_map. exact (proj1 (repX_spec i)).
      * split.
        -- exists (repX i). split; [exact (proj1 (repX_spec i)) |].
           split; [reflexivity | exact (ok_run i)].
        -- exact (cube_holds i).
  - intro n. destruct (O_live n) as [j [Hj Hv]]. exists j. split; [exact Hj |].
    unfold Fa. intros v Hin. apply (Hv v). apply run_snd. exact Hin.
Qed.

End Run.
End Live.
End Closure.

(*
  MTL_to_TBA_ClockAlloc.v

  Reuse of clocks by liveness.  A clock allocation maps every clock to a
  representative; the automaton obtained by renaming the clocks in guards
  and resets uses fewer clocks when several clocks are never needed at
  the same time (for instance the clocks of the different branches of the
  negation of a conjunction of bounded responses).

  The allocation and the liveness sets are given by an unverified
  procedure.  What is proved is a checker: a boolean test of four local
  conditions on a certificate (alloc, live), and the theorem that the
  renaming preserves the language of timed words whenever the test
  succeeds.  The pass [try_allocate] returns the automaton unchanged when
  the test fails, so it preserves the language for every certificate.

  The sets [live q] only have to satisfy two local closure conditions,
  hence they may over-approximate the clocks that are read later:

    (guard)  a clock read by the guard of a transition is in live(source);
    (flow)   a clock in live(target) is reset by the transition or is in
             live(source);

  and the allocation must not identify clocks that the sets keep apart:

    (reset)  a clock reset by a transition has no other clock of its class
             in live(target);
    (init)   the allocation is injective on live(initial location).

  Nothing in the shared foundation is changed: the clocks of the new
  automaton are clocks of the same type [Clock root], the semantics is that
  of [TBA_accepts], and no axiom is added to those already used by
  MTL_to_TBA_Optimizations.v.
*)

Require Import Arith Lia List Bool Reals Lra.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import MTL_to_TBA_Invariants.
Require Import MTL_to_TBA_Optimizations.
Require Import MTL_to_TBA_Export.
Import ListNotations.
Open Scope R_scope.

Section ClockAlloc.

Variable root : mtl.
Variable alloc : Clock root -> Clock root.
Variable live : nat -> list (Clock root).

(* ====================================================================== *)
(* 1. The renaming                                                        *)
(* ====================================================================== *)

Definition alloc_item (o : option (clock_constraint root))
    : option (clock_constraint root) :=
  match o with
  | Some k =>
      Some {| guard_clock := alloc (guard_clock k);
              guard_comparison := guard_comparison k;
              guard_bound := guard_bound k |}
  | None => None
  end.

Definition alloc_resets (rs : list (Clock root)) : list (Clock root) :=
  nodup (@clock_eq_dec root) (map alloc rs).

Lemma alloc_resets_In :
  forall rs c, In c (alloc_resets rs) <-> exists x, In x rs /\ alloc x = c.
Proof.
  intros rs c. unfold alloc_resets. rewrite nodup_In, in_map_iff.
  split; intros [x [H1 H2]]; exists x; split; assumption.
Qed.

Definition alloc_transition (t : tba_transition root) : tba_transition root :=
  {| bt_source := bt_source t;
     bt_label := bt_label t;
     bt_guard := map alloc_item (bt_guard t);
     bt_resets := alloc_resets (bt_resets t);
     bt_target := bt_target t |}.

Definition allocate_clocks (A : TBA root) : TBA root :=
  with_transitions A (map alloc_transition (tba_transitions A)).

(* ====================================================================== *)
(* 2. The certificate                                                     *)
(* ====================================================================== *)

Definition guard_clocks (g : guard root) : list (Clock root) :=
  flat_map (fun o => match o with
                     | Some k => [guard_clock k]
                     | None => []
                     end) g.

Record alloc_valid (A : TBA root) : Prop := {
  av_guard : forall t, In t (tba_transitions A) ->
    forall x, In x (guard_clocks (bt_guard t)) -> In x (live (bt_source t));
  av_flow : forall t, In t (tba_transitions A) ->
    forall x, In x (live (bt_target t)) ->
      In x (bt_resets t) \/ In x (live (bt_source t));
  av_reset : forall t, In t (tba_transitions A) ->
    forall r y, In r (bt_resets t) -> In y (live (bt_target t)) ->
      alloc r = alloc y -> r = y;
  av_init : forall x y,
    In x (live (tba_init A)) -> In y (live (tba_init A)) ->
    alloc x = alloc y -> x = y
}.

Arguments av_guard {A} _ {t} _ x _.
Arguments av_flow {A} _ {t} _ x _.
Arguments av_reset {A} _ {t} _ r y _ _ _.
Arguments av_init {A} _ x y _ _ _.

(* The boolean checker of the certificate. *)
Definition same_class_eq (r y : Clock root) : bool :=
  if @clock_eq_dec root (alloc r) (alloc y) then clock_eqb r y else true.

Definition alloc_ok (A : TBA root) : bool :=
  forallb (fun t =>
    forallb (fun x => clock_in x (live (bt_source t)))
            (guard_clocks (bt_guard t)) &&
    forallb (fun x => clock_in x (bt_resets t) || clock_in x (live (bt_source t)))
            (live (bt_target t)) &&
    forallb (fun r => forallb (fun y => same_class_eq r y) (live (bt_target t)))
            (bt_resets t))
    (tba_transitions A) &&
  forallb (fun x => forallb (fun y => same_class_eq x y) (live (tba_init A)))
          (live (tba_init A)).

Lemma same_class_eq_true :
  forall r y, same_class_eq r y = true -> alloc r = alloc y -> r = y.
Proof.
  intros r y H Heq. unfold same_class_eq in H.
  destruct (@clock_eq_dec root (alloc r) (alloc y)) as [_|N];
    [apply clock_eqb_true; exact H | contradiction].
Qed.

Lemma alloc_ok_sound : forall A, alloc_ok A = true -> alloc_valid A.
Proof.
  intros A H. unfold alloc_ok in H.
  apply andb_true_iff in H. destruct H as [Ht Hi].
  rewrite forallb_forall in Ht, Hi.
  split.
  - intros t Hin x Hx. specialize (Ht t Hin).
    apply andb_true_iff in Ht. destruct Ht as [Ht _].
    apply andb_true_iff in Ht. destruct Ht as [H1 _].
    rewrite forallb_forall in H1. apply clock_in_iff. exact (H1 x Hx).
  - intros t Hin x Hx. specialize (Ht t Hin).
    apply andb_true_iff in Ht. destruct Ht as [Ht _].
    apply andb_true_iff in Ht. destruct Ht as [_ H2].
    rewrite forallb_forall in H2. specialize (H2 x Hx).
    apply orb_true_iff in H2. destruct H2 as [H2|H2];
      [left | right]; apply clock_in_iff; exact H2.
  - intros t Hin r y Hr Hy Heq. specialize (Ht t Hin).
    apply andb_true_iff in Ht. destruct Ht as [_ H3].
    rewrite forallb_forall in H3. specialize (H3 r Hr).
    rewrite forallb_forall in H3. specialize (H3 y Hy).
    exact (same_class_eq_true r y H3 Heq).
  - intros x y Hx Hy Heq. specialize (Hi x Hx).
    rewrite forallb_forall in Hi. specialize (Hi y Hy).
    exact (same_class_eq_true x y Hi Heq).
Qed.

(* The pass: apply the renaming when the certificate is accepted. *)
Definition try_allocate (A : TBA root) : TBA root :=
  if alloc_ok A then allocate_clocks A else A.

(* ====================================================================== *)
(* 3. From a word of A to a word of the renamed automaton                 *)
(* ====================================================================== *)

Section Forward.

Variable A : TBA root.

(* A representative class is reset when one of its members is reset. *)
Definition fwd_reset (rho : ext_word root) (i : nat) (c : Clock root) : bool :=
  existsb (fun x => clock_eqb (alloc x) c && ew_reset rho i x) (all_clocks root).

Lemma fwd_reset_true :
  forall rho i c, fwd_reset rho i c = true <->
    exists x, alloc x = c /\ ew_reset rho i x = true.
Proof.
  intros rho i c. unfold fwd_reset. rewrite existsb_exists. split.
  - intros [x [_ H]]. apply andb_true_iff in H. destruct H as [H1 H2].
    exists x. split; [exact (clock_eqb_true H1) | exact H2].
  - intros [x [H1 H2]]. exists x. split; [apply all_clocks_complete|].
    rewrite H2, andb_true_r. unfold clock_eqb.
    destruct (@clock_eq_dec root (alloc x) c); [reflexivity | contradiction].
Qed.

(* Initial value of a class: the value of its (unique) live member at the
   initial location. *)
Definition init_val (rho : ext_word root) (c : Clock root) : R :=
  match find (fun x => clock_eqb (alloc x) c) (live (tba_init A)) with
  | Some x => ew_val rho 0 x
  | None => 0
  end.

Fixpoint fwd_val (rho : ext_word root) (i : nat) (c : Clock root) : R :=
  match i with
  | 0%nat => init_val rho c
  | S j => if fwd_reset rho j c
           then delta (ew_base rho) j
           else fwd_val rho j c + delta (ew_base rho) j
  end.

Definition fwd_word (rho : ext_word root) : ext_word root :=
  {| ew_base := ew_base rho;
     ew_val := fwd_val rho;
     ew_reset := fwd_reset rho |}.

Lemma fwd_consistent :
  forall rho, clock_consistent rho -> clock_consistent (fwd_word rho).
Proof.
  intros rho [Hnn Hstep]. split.
  - intros i c. simpl. induction i as [|j IH]; simpl.
    + unfold init_val.
      destruct (find (fun x => clock_eqb (alloc x) c) (live (tba_init A)));
        [apply Hnn | lra].
    + destruct (fwd_reset rho j c); pose proof (delta_nonneg (ew_base rho) j);
        [assumption | lra].
  - intros i c. simpl. reflexivity.
Qed.

Lemma fwd_invariant :
  alloc_valid A ->
  forall (rho : ext_word root) (run : nat -> nat),
    run 0%nat = tba_init A ->
    clock_consistent rho ->
    (forall i, exists t,
        In t (tba_transitions A) /\
        bt_source t = run i /\ bt_target t = run (S i) /\
        tba_transition_enabled rho i t) ->
    forall i x, In x (live (run i)) ->
      ew_val (fwd_word rho) i (alloc x) = ew_val rho i x.
Proof.
  intros Hv rho run Hinit [Hnn Hstep] Hsteps.
  induction i as [|i IH]; intros x Hx.
  - rewrite Hinit in Hx. simpl. unfold init_val.
    destruct (find (fun y => clock_eqb (alloc y) (alloc x)) (live (tba_init A)))
      as [y|] eqn:Ef.
    + apply find_some in Ef. destruct Ef as [Hy Hq].
      apply clock_eqb_true in Hq.
      assert (y = x) as ->.
      { exact (av_init Hv y x Hy Hx Hq). }
      reflexivity.
    + exfalso.
      assert (Hf : forall z, In z (live (tba_init A)) ->
                       (fun y => clock_eqb (alloc y) (alloc x)) z = false)
        by (apply find_none; exact Ef).
      specialize (Hf x Hx). simpl in Hf.
      unfold clock_eqb in Hf.
      destruct (@clock_eq_dec root (alloc x) (alloc x)) as [_|N];
        [discriminate | apply N; reflexivity].
  - destruct (Hsteps i) as [t [Hin [Hsrc [Hdst Hen]]]].
    destruct Hen as [_ [_ Hrm]].
    rewrite <- Hdst in Hx.
    rewrite (Hstep i x).
    simpl.
    destruct (ew_reset rho i x) eqn:Er.
    + assert (Hfr : fwd_reset rho i (alloc x) = true).
      { apply fwd_reset_true. exists x. split; [reflexivity | exact Er]. }
      rewrite Hfr. reflexivity.
    + assert (Hnr : ~ In x (bt_resets t)).
      { intro Hin'. apply (proj2 (Hrm x)) in Hin'. congruence. }
      assert (Hfr : fwd_reset rho i (alloc x) = false).
      { destruct (fwd_reset rho i (alloc x)) eqn:Ef; [|reflexivity].
        exfalso. apply fwd_reset_true in Ef.
        destruct Ef as [y [Hy Hry]].
        assert (Hyin : In y (bt_resets t)) by (apply (proj1 (Hrm y)); exact Hry).
        assert (y = x) by (exact (av_reset Hv Hin y x Hyin Hx Hy)).
        subst y. congruence. }
      rewrite Hfr.
      assert (Hxs : In x (live (run i))).
      { destruct (av_flow Hv Hin x Hx)
          as [H|H]; [contradiction | rewrite <- Hsrc; exact H]. }
      specialize (IH x Hxs). simpl in IH. rewrite IH. reflexivity.
Qed.

Lemma item_transfer :
  forall (rho1 rho2 : ext_word root) i o,
    (match o with
     | Some k => ew_val rho2 i (alloc (guard_clock k)) = ew_val rho1 i (guard_clock k)
     | None => True
     end) ->
    guard_item_holds rho1 i o -> guard_item_holds rho2 i (alloc_item o).
Proof.
  intros rho1 rho2 i [k|] H Hh; simpl in *; [|exact I].
  unfold clock_constraint_holds in *. simpl in *.
  destruct (guard_comparison k); rewrite H; exact Hh.
Qed.

Lemma item_transfer_back :
  forall (rho1 rho2 : ext_word root) i o,
    (match o with
     | Some k => ew_val rho2 i (alloc (guard_clock k)) = ew_val rho1 i (guard_clock k)
     | None => True
     end) ->
    guard_item_holds rho2 i (alloc_item o) -> guard_item_holds rho1 i o.
Proof.
  intros rho1 rho2 i [k|] H Hh; simpl in *; [|exact I].
  unfold clock_constraint_holds in *. simpl in *.
  destruct (guard_comparison k); rewrite H in Hh; exact Hh.
Qed.

Lemma guard_item_clock_in :
  forall g o, In o g ->
    match o with
    | Some k => In (guard_clock k) (guard_clocks g)
    | None => True
    end.
Proof.
  intros g [k|] Ho; [|exact I].
  unfold guard_clocks. apply in_flat_map. exists (Some k). split; [exact Ho|].
  simpl. left. reflexivity.
Qed.

Lemma forward_ext :
  alloc_valid A ->
  forall (rho : ext_word root),
    clock_consistent rho ->
    TBA_ext_accepts A rho ->
    TBA_ext_accepts (allocate_clocks A) (fwd_word rho).
Proof.
  intros Hv rho Hcc Hacc.
  destruct Hacc as [run [Hinit [Hsteps Hbuchi]]].
  assert (Hinv := fwd_invariant Hv rho run Hinit Hcc
                    (fun i => match Hsteps i with
                              | conj _ H => H
                              end)).
  exists run. split; [exact Hinit|]. split; [|exact Hbuchi].
  intro i. destruct (Hsteps i) as [Hb [t [Hin [Hsrc [Hdst Hen]]]]].
  split; [exact Hb|].
  exists (alloc_transition t). split.
  { simpl. apply in_map. exact Hin. }
  split; [exact Hsrc|]. split; [exact Hdst|].
  destruct Hen as [Hlab [Hg Hrm]].
  split; [exact Hlab|]. split.
  - simpl. unfold alloc_transition. simpl. apply Forall_forall.
    intros o' Ho'. apply in_map_iff in Ho'. destruct Ho' as [o [<- Ho]].
    rewrite Forall_forall in Hg. specialize (Hg o Ho).
    apply item_transfer with (rho1 := rho).
    + pose proof (guard_item_clock_in (bt_guard t) o Ho) as Hc.
      destruct o as [k|]; [|exact I].
      assert (Hl : In (guard_clock k) (live (run i))).
      { rewrite <- Hsrc. exact (av_guard Hv Hin _ Hc). }
      exact (Hinv i _ Hl).
    + exact Hg.
  - unfold alloc_transition. simpl. intro c. rewrite alloc_resets_In.
    simpl. rewrite fwd_reset_true. split.
    + intros [x [Hx Hr]]. exists x. split; [apply (proj1 (Hrm x)); exact Hr | exact Hx].
    + intros [x [Hx Hxc]]. exists x. split; [exact Hxc|].
      apply (proj2 (Hrm x)). exact Hx.
Qed.

End Forward.

(* ====================================================================== *)
(* 4. From a word of the renamed automaton to a word of A                 *)
(* ====================================================================== *)

Section Backward.

(* Choice of the transition of A behind each step, without axiom: the
   first transition of the list that fits, for a decidable property. *)
Fixpoint pick {P : tba_transition root -> Prop} (P_dec : forall t, {P t} + {~ P t})
    (l : list (tba_transition root))
    (d : tba_transition root) : tba_transition root :=
  match l with
  | [] => d
  | t :: l' => if P_dec t then t else pick P_dec l' d
  end.

Lemma pick_spec :
  forall P (P_dec : forall t, {P t} + {~ P t}) l d,
    (exists t, In t l /\ P t) -> In (pick P_dec l d) l /\ P (pick P_dec l d).
Proof.
  intros P P_dec l d. induction l as [|t l IH]; intros [t0 [Hin HP]]; [contradiction|].
  simpl. destruct (P_dec t) as [H|N].
  - split; [left; reflexivity | exact H].
  - destruct Hin as [->|Hin]; [contradiction|].
    destruct (IH (ex_intro _ t0 (conj Hin HP))) as [H1 H2].
    split; [right; exact H1 | exact H2].
Qed.

Variable rho' : ext_word root.
Variable rs : nat -> list (Clock root).

Fixpoint bwd_val (i : nat) (x : Clock root) : R :=
  match i with
  | 0%nat => ew_val rho' 0 (alloc x)
  | S j => if clock_in x (rs j)
           then delta (ew_base rho') j
           else bwd_val j x + delta (ew_base rho') j
  end.

Definition bwd_word : ext_word root :=
  {| ew_base := ew_base rho';
     ew_val := bwd_val;
     ew_reset := fun i x => clock_in x (rs i) |}.

Lemma bwd_consistent : clock_consistent rho' -> clock_consistent bwd_word.
Proof.
  intros [Hnn Hstep]. split.
  - intros i x. simpl. induction i as [|j IH]; simpl.
    + apply Hnn.
    + destruct (clock_in x (rs j)); pose proof (delta_nonneg (ew_base rho') j);
        [assumption | lra].
  - intros i x. simpl. reflexivity.
Qed.

End Backward.

(* ====================================================================== *)
(* 5. Preservation                                                        *)
(* ====================================================================== *)

Section Preservation.

Variable A : TBA root.
Variable Hv : alloc_valid A.

Lemma backward_ext :
  forall (rho' : ext_word root),
    clock_consistent rho' ->
    TBA_ext_accepts (allocate_clocks A) rho' ->
    exists rho, ew_base rho = ew_base rho' /\ clock_consistent rho /\
                TBA_ext_accepts A rho.
Proof.
  intros rho' Hcc Hacc.
  destruct Hacc as [run [Hinit [Hsteps Hbuchi]]].
  simpl in Hinit, Hbuchi.
  (* the transition of A behind each step *)
  assert (Hex : forall i, exists t,
            In t (tba_transitions A) /\
            bt_source t = run i /\ bt_target t = run (S i) /\
            tba_transition_enabled rho' i (alloc_transition t)).
  { intro i. destruct (Hsteps i) as [_ [t' [Hin' [Hs [Hd He]]]]].
    simpl in Hin'. apply in_map_iff in Hin'. destruct Hin' as [t [<- Hin]].
    exists t. split; [exact Hin|]. split; [exact Hs|]. split; [exact Hd|]. exact He. }
  destruct (Hex 0%nat) as [t0 [Hin0 _]].
  assert (P_dec : forall i t,
            {bt_source t = run i /\ bt_target t = run (S i) /\
             tba_transition_enabled rho' i (alloc_transition t)} +
            {~ (bt_source t = run i /\ bt_target t = run (S i) /\
                tba_transition_enabled rho' i (alloc_transition t))}).
  { intros i t.
    destruct (Nat.eq_dec (bt_source t) (run i)); [|right; tauto].
    destruct (Nat.eq_dec (bt_target t) (run (S i))); [|right; tauto].
    destruct (tba_transition_enabled_dec rho' i (alloc_transition t)); [left | right]; tauto. }
  set (chosen := fun i => pick (P_dec i) (tba_transitions A) t0).
  assert (Hch : forall i,
            In (chosen i) (tba_transitions A) /\
            bt_source (chosen i) = run i /\ bt_target (chosen i) = run (S i) /\
            tba_transition_enabled rho' i (alloc_transition (chosen i))).
  { intro i. destruct (Hex i) as [t [Hin [Hs [Hd He]]]].
    destruct (@pick_spec _ (P_dec i)
            (tba_transitions A) t0 (ex_intro _ t (conj Hin (conj Hs (conj Hd He)))))
      as [H1 [H2 [H3 H4]]].
    split; [exact H1|]. split; [exact H2|]. split; [exact H3|]. exact H4. }
  set (rs := fun i => bt_resets (chosen i)).
  set (rho := bwd_word rho' rs).
  assert (Hrcons : clock_consistent rho) by (apply bwd_consistent; exact Hcc).
  assert (Hinv : forall i x, In x (live (run i)) ->
                   ew_val rho i x = ew_val rho' i (alloc x)).
  { induction i as [|i IH]; intros x Hx.
    - reflexivity.
    - destruct (Hch i) as [Hin [Hs [Hd He]]].
      destruct He as [_ [_ Hrm]].
      assert (Hxt : In x (live (bt_target (chosen i)))) by (rewrite Hd; exact Hx).
      destruct Hcc as [Hnn Hstep].
      change (ew_val rho (S i) x) with
        (if clock_in x (rs i) then delta (ew_base rho') i
         else ew_val rho i x + delta (ew_base rho') i).
      rewrite (Hstep i (alloc x)).
      destruct (clock_in x (rs i)) eqn:Er.
      + apply clock_in_iff in Er.
        assert (Hfr : ew_reset rho' i (alloc x) = true).
        { apply (proj2 (Hrm (alloc x))). simpl. apply alloc_resets_In.
          exists x. split; [exact Er | reflexivity]. }
        rewrite Hfr. reflexivity.
      + assert (Hnr : ~ In x (bt_resets (chosen i))).
        { intro H. apply clock_in_iff in H. unfold rs in Er. congruence. }
        assert (Hfr : ew_reset rho' i (alloc x) = false).
        { destruct (ew_reset rho' i (alloc x)) eqn:Ef; [|reflexivity].
          exfalso. apply (proj1 (Hrm (alloc x))) in Ef. simpl in Ef.
          apply alloc_resets_In in Ef. destruct Ef as [y [Hy Hya]].
          assert (y = x) by exact (av_reset Hv Hin y x Hy Hxt Hya).
          subst y. contradiction. }
        rewrite Hfr.
        assert (Hxs : In x (live (run i))).
        { destruct (av_flow Hv Hin x Hxt) as [H|H];
            [contradiction | rewrite <- Hs; exact H]. }
        rewrite (IH x Hxs). reflexivity. }
  exists rho. split; [reflexivity|]. split; [exact Hrcons|].
  exists run. split; [exact Hinit|]. split; [|exact Hbuchi].
  intro i. destruct (Hsteps i) as [Hb _]. split; [exact Hb|].
  destruct (Hch i) as [Hin [Hs [Hd He]]].
  exists (chosen i). split; [exact Hin|]. split; [exact Hs|]. split; [exact Hd|].
  destruct He as [Hlab [Hg Hrm]].
  split; [exact Hlab|]. split.
  - apply Forall_forall. intros o Ho.
    simpl in Hg. rewrite Forall_forall in Hg.
    assert (Hmap : In (alloc_item o) (map alloc_item (bt_guard (chosen i))))
      by (apply in_map; exact Ho).
    specialize (Hg _ Hmap).
    apply item_transfer_back with (rho2 := rho').
    + pose proof (guard_item_clock_in (bt_guard (chosen i)) o Ho) as Hc.
      destruct o as [k|]; [|exact I].
      assert (Hl : In (guard_clock k) (live (run i))).
      { rewrite <- Hs. exact (av_guard Hv Hin _ Hc). }
      symmetry. exact (Hinv i _ Hl).
    + exact Hg.
  - intro x. simpl. rewrite <- clock_in_iff. split; intro H; exact H.
Qed.

Theorem allocate_clocks_accepts :
  forall w, TBA_accepts A w <-> TBA_accepts (allocate_clocks A) w.
Proof.
  intro w. unfold TBA_accepts. split.
  - intros [rho [Hb [Hcc Ha]]].
    exists (fwd_word A rho). split.
    + unfold same_base in *. simpl. exact Hb.
    + split; [exact (fwd_consistent A rho Hcc) | exact (forward_ext A Hv rho Hcc Ha)].
  - intros [rho' [Hb [Hcc Ha]]].
    destruct (backward_ext rho' Hcc Ha) as [rho [Hb' [Hcc' Ha']]].
    exists rho. split.
    + unfold same_base in *. rewrite Hb', Hb. reflexivity.
    + split; assumption.
Qed.

End Preservation.

Theorem try_allocate_accepts :
  forall A w, TBA_accepts A w <-> TBA_accepts (try_allocate A) w.
Proof.
  intros A w. unfold try_allocate.
  destruct (alloc_ok A) eqn:E; [|reflexivity].
  apply allocate_clocks_accepts. apply alloc_ok_sound. exact E.
Qed.

End ClockAlloc.

Print Assumptions try_allocate_accepts.

(* ====================================================================== *)
(* 6. The pass in the pipeline                                            *)
(* ====================================================================== *)

(* A certificate producer: the unverified procedure that proposes an
   allocation and liveness sets for an automaton.  It is a parameter, so
   that the theorems below hold for every producer, including a wrong one. *)
Definition certifier (root : mtl) : Type :=
  TBA root -> (Clock root -> Clock root) * (nat -> list (Clock root)).

(* The clock-allocation pass, run once on the automaton that the
   optimization rounds have reached.  It is not part of [optimize_step]
   because its certificate is computed from the automaton it renames. *)
Definition alloc_pass (root : mtl) (cert : certifier root) (A : TBA root)
    : TBA root :=
  try_allocate root (fst (cert A)) (snd (cert A)) A.

Theorem alloc_pass_accepts :
  forall root (cert : certifier root) A w,
    TBA_accepts A w <-> TBA_accepts (alloc_pass root cert A) w.
Proof.
  intros root cert A w. unfold alloc_pass. apply try_allocate_accepts.
Qed.

Definition optimize_alloc (root : mtl) (cert : certifier root) (n : nat)
    (A : TBA root) : TBA root :=
  alloc_pass root cert (optimize n A).

Theorem optimize_alloc_accepts :
  forall root (cert : certifier root) n A w,
    TBA_accepts A w <-> TBA_accepts (optimize_alloc root cert n A) w.
Proof.
  intros root cert n A w. unfold optimize_alloc.
  rewrite (optimize_accepts n A w). apply alloc_pass_accepts.
Qed.

Definition optimize_alloc_export (root : mtl) (cert : certifier root) (n : nat)
    (A : TBA root) : DTA root :=
  export (optimize_alloc root cert n A).

Definition optimize_alloc_export_all (root : mtl) (cert : certifier root)
    (n : nat) (A : TBA root) : DTA root :=
  export_all (optimize_alloc root cert n A).

Theorem MTL_to_exported_alloc_correct :
  forall (cert : forall f, certifier f) (n : nat) (f : mtl) (w : timed_word),
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (optimize_alloc_export f (cert f) n (compile f)) w).
Proof.
  intros cert n f w Hwf.
  rewrite (MTL_to_TBA_correct w Hwf).
  unfold optimize_alloc_export.
  rewrite (optimize_alloc_accepts f (cert f) n (compile f) w).
  apply export_accepts.
Qed.

Theorem MTL_to_exported_all_alloc_correct :
  forall (cert : forall f, certifier f) (n : nat) (f : mtl) (w : timed_word),
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (optimize_alloc_export_all f (cert f) n (compile f)) w).
Proof.
  intros cert n f w Hwf.
  rewrite (MTL_to_TBA_correct w Hwf).
  unfold optimize_alloc_export_all.
  rewrite (optimize_alloc_accepts f (cert f) n (compile f) w).
  apply export_all_accepts.
Qed.

(* The same for an automaton A that is correct for T f, such as the one
   returned by Spot (the form the tool runs). *)
Theorem MTL_to_exported_alloc_correct_with :
  forall (n : nat) (f : mtl) (cert : certifier f) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (T f))) ->
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (optimize_alloc_export f cert n (compile_with A)) w).
Proof.
  intros n f cert A w HA Hwf.
  rewrite (@MTL_to_TBA_correct_with f A w HA Hwf).
  unfold optimize_alloc_export.
  rewrite (optimize_alloc_accepts f cert n (compile_with A) w).
  apply export_accepts.
Qed.

Print Assumptions MTL_to_exported_alloc_correct_with.

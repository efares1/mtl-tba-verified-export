(* ====================================================================== *)
(* Symbolic transitions: merging of the transitions with the same source, *)
(* target, and resets, with Boolean labels                                *)
(*                                                                        *)
(* The exported automaton has one transition per cube: a conjunction of   *)
(* action literals and a conjunction of clock constraints.  [symbolic]    *)
(* merges all the transitions with the same source, target, and resets    *)
(* into one symbolic transition, labeled by a disjunction of cases        *)
(* "set of events /\ conjunction of clock constraints"; the cases with    *)
(* the same clock constraints are merged by union of their sets of        *)
(* events.  A set of events is either a finite set or the complement of   *)
(* a finite set.  The symbolic automaton accepts the same extended words  *)
(* as the exported one ([symbolic_ext_accepts]), hence the same timed     *)
(* words, for the existential and for the conventional acceptance.        *)
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

(* ---------------------------------------------------------------------- *)
(* Sets of events                                                         *)

Inductive evset : Type :=
| EvIn  : list Action -> evset     (* the events of the list *)
| EvOut : list Action -> evset.    (* the events not in the list *)

Definition in_evset (a : Action) (E : evset) : Prop :=
  match E with
  | EvIn l => In a l
  | EvOut l => ~ In a l
  end.

Definition memb (a : Action) (l : list Action) : bool :=
  if in_dec Nat.eq_dec a l then true else false.

Lemma memb_iff : forall a l, memb a l = true <-> In a l.
Proof.
  intros a l. unfold memb. destruct (in_dec Nat.eq_dec a l); split; intro H;
    auto; discriminate.
Qed.

(* Intersection with the set of events allowed by an action literal. *)
Definition meet (E : evset) (lit : alit) : evset :=
  let (a, pos) := lit in
  if pos then
    match E with
    | EvIn l => if memb a l then EvIn [a] else EvIn []
    | EvOut l => if memb a l then EvIn [] else EvIn [a]
    end
  else
    match E with
    | EvIn l => EvIn (remove Nat.eq_dec a l)
    | EvOut l => EvOut (a :: l)
    end.

Lemma meet_correct :
  forall x E lit, in_evset x (meet E lit) <-> in_evset x E /\ alit_holds x lit.
Proof.
  intros x E [a [|]]; unfold alit_holds; simpl.
  - destruct E as [l|l]; simpl; destruct (memb a l) eqn:M;
      [apply memb_iff in M | rewrite <- Bool.not_true_iff_false, memb_iff in M
      |apply memb_iff in M | rewrite <- Bool.not_true_iff_false, memb_iff in M];
      simpl; split.
    + intros [<-|[]]. split; [exact M | reflexivity].
    + intros [_ ->]. left. reflexivity.
    + intros [].
    + intros [Hx ->]. exact (M Hx).
    + intros [].
    + intros [Hx ->]. exact (Hx M).
    + intros [<-|[]]. split; [exact M | reflexivity].
    + intros [_ ->]. left. reflexivity.
  - destruct E as [l|l]; simpl; split.
    + intro H. apply in_remove in H. exact H.
    + intros [H1 H2]. apply in_in_remove; assumption.
    + intro H. split; [intro Hx; apply H; right; exact Hx|].
      intro E. apply H. left. symmetry. exact E.
    + intros [H1 H2] [E|Hx]; [apply H2; symmetry; exact E | exact (H1 Hx)].
Qed.

(* The events allowed by a conjunction of action literals. *)
Definition evset_of_label (l : list alit) : evset := fold_left meet l (EvOut []).

Lemma fold_meet_correct :
  forall x l E, in_evset x (fold_left meet l E) <->
                in_evset x E /\ Forall (alit_holds x) l.
Proof.
  intros x l. induction l as [|lit l IH]; intro E; simpl.
  - split; [intro H; split; [exact H | constructor] | tauto].
  - rewrite IH, meet_correct. rewrite Forall_cons_iff. tauto.
Qed.

Lemma evset_of_label_correct :
  forall x l, in_evset x (evset_of_label l) <-> Forall (alit_holds x) l.
Proof.
  intros x l. unfold evset_of_label. rewrite fold_meet_correct. simpl. tauto.
Qed.

Definition ev_union (E F : evset) : evset :=
  match E, F with
  | EvIn A, EvIn B => EvIn (A ++ B)
  | EvOut A, EvOut B => EvOut (filter (fun y => memb y B) A)
  | EvIn A, EvOut B => EvOut (filter (fun y => negb (memb y A)) B)
  | EvOut A, EvIn B => EvOut (filter (fun y => negb (memb y B)) A)
  end.

Lemma ev_union_correct :
  forall x E F, in_evset x (ev_union E F) <-> in_evset x E \/ in_evset x F.
Proof.
  intros x [A|A] [B|B]; simpl.
  - apply in_app_iff.
  - rewrite filter_In, negb_true_iff, <- Bool.not_true_iff_false, memb_iff.
    destruct (in_dec Nat.eq_dec x A); tauto.
  - rewrite filter_In, negb_true_iff, <- Bool.not_true_iff_false, memb_iff.
    destruct (in_dec Nat.eq_dec x B); tauto.
  - rewrite filter_In, memb_iff.
    destruct (in_dec Nat.eq_dec x A); destruct (in_dec Nat.eq_dec x B); tauto.
Qed.

Section Symbolic.

Variable root : mtl.

(* ---------------------------------------------------------------------- *)
(* Symbolic automata                                                      *)

Definition scase := (evset * dconj root)%type.

Record strans : Type := {
  st_src : nat;
  st_resets : list (Clock root);
  st_tgt : nat;
  st_cases : list scase
}.

Record SDTA : Type := {
  sdta_nstates : nat;
  sdta_init : nat;
  sdta_trans : list strans;
  sdta_accepting : list nat;
  sdta_inv : nat -> option (list (uinv root))
}.

Definition cases_hold (a : Action) (v : valuation root) (cs : list scase) : Prop :=
  exists E c, In (E, c) cs /\ in_evset a E /\ conj_holds v c.

Definition strans_enabled (rho : ext_word root) (i : nat) (t : strans) : Prop :=
  cases_hold (tw_action (ew_base rho) i) (at_event rho i) (st_cases t) /\
  resets_match rho i (st_resets t).

Definition SDTA_ext_accepts (SA : SDTA) (rho : ext_word root) : Prop :=
  exists run : nat -> nat,
    run 0%nat = sdta_init SA /\
    (forall i,
       (run i < sdta_nstates SA)%nat /\
       dinv_during rho i (sdta_inv SA (run i)) /\
       exists t,
         In t (sdta_trans SA) /\
         st_src t = run i /\
         st_tgt t = run (S i) /\
         strans_enabled rho i t) /\
    (forall n,
       exists j,
         (n <= j)%nat /\ In (run j) (sdta_accepting SA)).

Definition SDTA_accepts (SA : SDTA) (w : timed_word) : Prop :=
  exists rho : ext_word root,
    same_base rho w /\ clock_consistent rho /\ SDTA_ext_accepts SA rho.

Definition SDTA_accepts0 (SA : SDTA) (w : timed_word) : Prop :=
  exists rho : ext_word root,
    same_base rho w /\ clock_consistent rho /\
    (forall x, ew_val rho 0 x = tw_time w 0) /\ SDTA_ext_accepts SA rho.

(* ---------------------------------------------------------------------- *)
(* Construction                                                           *)

(* Adds a case, merging it with a case of the same clock constraints. *)
Fixpoint add_case (x : scase) (cs : list scase) : list scase :=
  match cs with
  | [] => [x]
  | y :: r => if dconj_dec (snd x) (snd y)
              then (ev_union (fst y) (fst x), snd y) :: r
              else y :: add_case x r
  end.

Lemma add_case_hold :
  forall a v x cs, cases_hold a v (add_case x cs) <-> cases_hold a v [x] \/ cases_hold a v cs.
Proof.
  intros a v [E c] cs. induction cs as [|[F d] r IH]; simpl.
  - unfold cases_hold. split; [tauto|].
    intros [H|[E' [c' [[] _]]]]. exact H.
  - destruct (dconj_dec c d) as [<-|Hne]; simpl.
    + unfold cases_hold. split.
      * intros [E' [c' [[Eq|Hin] [He Hc]]]].
        -- inversion Eq; subst E' c'. apply ev_union_correct in He.
           destruct He as [He|He].
           ++ right. exists F, c. split; [left; reflexivity | tauto].
           ++ left. exists E, c. split; [left; reflexivity | tauto].
        -- right. exists E', c'. split; [right; exact Hin | tauto].
      * intros [[E' [c' [[Eq|[]] [He Hc]]]]|[E' [c' [[Eq|Hin] [He Hc]]]]].
        -- inversion Eq; subst E' c'. exists (ev_union F E), c.
           split; [left; reflexivity|]. split; [|exact Hc].
           apply ev_union_correct. right. exact He.
        -- inversion Eq; subst E' c'. exists (ev_union F E), c.
           split; [left; reflexivity|]. split; [|exact Hc].
           apply ev_union_correct. left. exact He.
        -- exists E', c'. split; [right; exact Hin | tauto].
    + unfold cases_hold in *. split.
      * intros [E' [c' [[Eq|Hin] [He Hc]]]].
        -- inversion Eq; subst E' c'. right. exists F, d.
           split; [left; reflexivity | tauto].
        -- assert (H : exists E0 c0, In (E0, c0) (add_case (E, c) r) /\
                         in_evset a E0 /\ conj_holds v c0)
             by (exists E', c'; tauto).
           apply IH in H. destruct H as [H|[E0 [c0 [Hin0 H0]]]]; [left; exact H|].
           right. exists E0, c0. split; [right; exact Hin0 | exact H0].
      * intros [H|[E' [c' [[Eq|Hin] [He Hc]]]]].
        -- assert (H' : exists E0 c0, In (E0, c0) (add_case (E, c) r) /\
                          in_evset a E0 /\ conj_holds v c0)
             by (apply IH; left; exact H).
           destruct H' as [E0 [c0 [Hin0 H0]]]. exists E0, c0.
           split; [right; exact Hin0 | exact H0].
        -- inversion Eq; subst E' c'. exists F, d.
           split; [left; reflexivity | tauto].
        -- assert (H' : exists E0 c0, In (E0, c0) (add_case (E, c) r) /\
                          in_evset a E0 /\ conj_holds v c0)
             by (apply IH; right; exists E', c'; tauto).
           destruct H' as [E0 [c0 [Hin0 H0]]]. exists E0, c0.
           split; [right; exact Hin0 | exact H0].
Qed.

Definition add_cases (xs cs : list scase) : list scase := fold_right add_case cs xs.

Lemma add_cases_hold :
  forall a v xs cs, cases_hold a v (add_cases xs cs) <-> cases_hold a v xs \/ cases_hold a v cs.
Proof.
  intros a v xs. induction xs as [|x xs IH]; intro cs; simpl.
  - unfold cases_hold at 2. split; [tauto|]. intros [[E [c [[] _]]]|H]. exact H.
  - rewrite add_case_hold, IH. unfold cases_hold. split.
    + intros [[E [c [[Eq|[]] H]]]|[[E [c [Hin H]]]|H]].
      * left. exists E, c. split; [left; exact Eq | exact H].
      * left. exists E, c. split; [right; exact Hin | exact H].
      * right. exact H.
    + intros [[E [c [[Eq|Hin] H]]]|H].
      * left. exists E, c. split; [left; exact Eq | exact H].
      * right. left. exists E, c. split; [exact Hin | exact H].
      * right. right. exact H.
Qed.

Definition cases_of (t : dtrans root) : list scase :=
  map (fun c => (evset_of_label (dt_label t), c)) (dt_guard t).

Lemma cases_of_hold :
  forall a v t, cases_hold a v (cases_of t) <->
                Forall (alit_holds a) (dt_label t) /\ dguard_holds v (dt_guard t).
Proof.
  intros a v t. unfold cases_hold, cases_of, dguard_holds. split.
  - intros [E [c [Hin [He Hc]]]]. apply in_map_iff in Hin.
    destruct Hin as [c' [Eq Hc']]. inversion Eq; subst E c'.
    apply evset_of_label_correct in He. split; [exact He|]. exists c. tauto.
  - intros [Hl [c [Hc Hh]]]. exists (evset_of_label (dt_label t)), c.
    split; [apply in_map_iff; exists c; tauto|].
    split; [apply evset_of_label_correct; exact Hl | exact Hh].
Qed.

Definition same_skey (g : strans) (t : dtrans root) : bool :=
  Nat.eqb (st_src g) (dt_src t) && Nat.eqb (st_tgt g) (dt_tgt t) &&
  (if list_eq_dec (@clock_eq_dec root) (st_resets g) (dt_resets t) then true else false).

Fixpoint ins (t : dtrans root) (gs : list strans) : list strans :=
  match gs with
  | [] => [{| st_src := dt_src t; st_resets := dt_resets t; st_tgt := dt_tgt t;
              st_cases := add_cases (cases_of t) [] |}]
  | g :: r => if same_skey g t
              then {| st_src := st_src g; st_resets := st_resets g; st_tgt := st_tgt g;
                      st_cases := add_cases (cases_of t) (st_cases g) |} :: r
              else g :: ins t r
  end.

Definition group (ts : list (dtrans root)) : list strans := fold_right ins [] ts.

Definition symbolic (D : DTA root) : SDTA :=
  {| sdta_nstates := dta_nstates D; sdta_init := dta_init D;
     sdta_trans := group (dta_trans D); sdta_accepting := dta_accepting D;
     sdta_inv := dta_inv D |}.

(* ---------------------------------------------------------------------- *)
(* Correctness                                                            *)

Definition holdsG (gs : list strans) s z s' a v : Prop :=
  exists g, In g gs /\ st_src g = s /\ st_resets g = z /\ st_tgt g = s' /\
            cases_hold a v (st_cases g).

Definition holdsT (ts : list (dtrans root)) s z s' a v : Prop :=
  exists t, In t ts /\ dt_src t = s /\ dt_resets t = z /\ dt_tgt t = s' /\
            cases_hold a v (cases_of t).

Lemma ins_hold :
  forall t gs s z s' a v,
    holdsG (ins t gs) s z s' a v <->
    (dt_src t = s /\ dt_resets t = z /\ dt_tgt t = s' /\ cases_hold a v (cases_of t)) \/
    holdsG gs s z s' a v.
Proof.
  intros t gs s z s' a v. induction gs as [|g r IH]; simpl.
  - unfold holdsG. split.
    + intros [g [[<-|[]] [Hs [Hz [Ht Hc]]]]]. simpl in *.
      rewrite add_cases_hold in Hc. destruct Hc as [Hc|[E [c [[] _]]]]. left. tauto.
    + intros [[Hs [Hz [Ht Hc]]]|[g [[] _]]].
      eexists. split; [left; reflexivity|]. simpl. repeat split; try assumption.
      apply add_cases_hold. left. exact Hc.
  - destruct (same_skey g t) eqn:K.
    + unfold same_skey in K. repeat rewrite andb_true_iff in K.
      destruct K as [[K1 K2] K3]. apply Nat.eqb_eq in K1. apply Nat.eqb_eq in K2.
      destruct (list_eq_dec (@clock_eq_dec root) (st_resets g) (dt_resets t)) as [K3'|];
        [|discriminate].
      unfold holdsG. split.
      * intros [g' [[<-|Hin] [Hs [Hz [Ht Hc]]]]].
        -- simpl in *. rewrite add_cases_hold in Hc. destruct Hc as [Hc|Hc].
           ++ left. split; [congruence|]. split; [congruence|]. split; [congruence|exact Hc].
           ++ right. exists g. split; [left; reflexivity|]. tauto.
        -- right. exists g'. split; [right; exact Hin | tauto].
      * intros [[Hs [Hz [Ht Hc]]]|[g' [[<-|Hin] [Hs [Hz [Ht Hc]]]]]].
        -- eexists. split; [left; reflexivity|]. simpl.
           split; [congruence|]. split; [congruence|]. split; [congruence|].
           apply add_cases_hold. left. exact Hc.
        -- eexists. split; [left; reflexivity|]. simpl.
           split; [exact Hs|]. split; [exact Hz|]. split; [exact Ht|].
           apply add_cases_hold. right. exact Hc.
        -- exists g'. split; [right; exact Hin | tauto].
    + unfold holdsG in *. split.
      * intros [g' [[<-|Hin] H]].
        -- right. exists g. split; [left; reflexivity | exact H].
        -- assert (H' : exists g0, In g0 (ins t r) /\ st_src g0 = s /\
                          st_resets g0 = z /\ st_tgt g0 = s' /\
                          cases_hold a v (st_cases g0)) by (exists g'; tauto).
           apply IH in H'. destruct H' as [H'|[g0 [Hin0 H0]]]; [left; exact H'|].
           right. exists g0. split; [right; exact Hin0 | exact H0].
      * intros [H|[g' [[<-|Hin] H]]].
        -- assert (H' : exists g0, In g0 (ins t r) /\ st_src g0 = s /\
                          st_resets g0 = z /\ st_tgt g0 = s' /\
                          cases_hold a v (st_cases g0)) by (apply IH; left; exact H).
           destruct H' as [g0 [Hin0 H0]]. exists g0. split; [right; exact Hin0 | exact H0].
        -- exists g. split; [left; reflexivity | exact H].
        -- assert (H' : exists g0, In g0 (ins t r) /\ st_src g0 = s /\
                          st_resets g0 = z /\ st_tgt g0 = s' /\
                          cases_hold a v (st_cases g0))
             by (apply IH; right; exists g'; tauto).
           destruct H' as [g0 [Hin0 H0]]. exists g0. split; [right; exact Hin0 | exact H0].
Qed.

Lemma group_hold :
  forall ts s z s' a v, holdsG (group ts) s z s' a v <-> holdsT ts s z s' a v.
Proof.
  intros ts. induction ts as [|t ts IH]; intros s z s' a v; simpl.
  - unfold holdsG, holdsT. split; intros [g [[] _]].
  - rewrite ins_hold, IH. unfold holdsT. split.
    + intros [H|[t' [Hin H]]].
      * exists t. split; [left; reflexivity | exact H].
      * exists t'. split; [right; exact Hin | exact H].
    + intros [t' [[<-|Hin] H]].
      * left. exact H.
      * right. exists t'. split; [exact Hin | exact H].
Qed.

Lemma step_equiv :
  forall D (rho : ext_word root) i s s',
    (exists t, In t (dta_trans D) /\ dt_src t = s /\ dt_tgt t = s' /\ dtrans_enabled rho i t) <->
    (exists g, In g (sdta_trans (symbolic D)) /\ st_src g = s /\ st_tgt g = s' /\
               strans_enabled rho i g).
Proof.
  intros D rho i s s'. simpl. split.
  - intros [t [Ht [Hs [Hd [Hl [Hg Hr]]]]]].
    assert (H : holdsT (dta_trans D) s (dt_resets t) s' (tw_action (ew_base rho) i)
                       (at_event rho i)).
    { exists t. split; [exact Ht|]. split; [exact Hs|]. split; [reflexivity|].
      split; [exact Hd|]. apply cases_of_hold. split; [exact Hl | exact Hg]. }
    apply group_hold in H. destruct H as [g [Hgin [Hgs [Hgz [Hgt Hgc]]]]].
    exists g. split; [exact Hgin|]. split; [exact Hgs|]. split; [exact Hgt|].
    split; [exact Hgc|]. rewrite Hgz. exact Hr.
  - intros [g [Hg [Hs [Hd [Hc Hr]]]]].
    assert (H : holdsG (group (dta_trans D)) s (st_resets g) s'
                       (tw_action (ew_base rho) i) (at_event rho i))
      by (exists g; tauto).
    apply group_hold in H. destruct H as [t [Ht [Hts [Htz [Htt Htc]]]]].
    apply cases_of_hold in Htc. destruct Htc as [Hl Hgd].
    exists t. split; [exact Ht|]. split; [exact Hts|]. split; [exact Htt|].
    split; [exact Hl|]. split; [exact Hgd|]. rewrite Htz. exact Hr.
Qed.

Theorem symbolic_ext_accepts :
  forall D (rho : ext_word root),
    DTA_ext_accepts D rho <-> SDTA_ext_accepts (symbolic D) rho.
Proof.
  intros D rho. unfold DTA_ext_accepts, SDTA_ext_accepts. simpl. split.
  - intros [run [H0 [Hs Hb]]]. exists run. split; [exact H0|]. split; [|exact Hb].
    intro i. destruct (Hs i) as [Hn [Hi Ht]]. split; [exact Hn|]. split; [exact Hi|].
    apply (proj1 (step_equiv D rho i (run i) (run (S i)))). exact Ht.
  - intros [run [H0 [Hs Hb]]]. exists run. split; [exact H0|]. split; [|exact Hb].
    intro i. destruct (Hs i) as [Hn [Hi Ht]]. split; [exact Hn|]. split; [exact Hi|].
    apply (proj2 (step_equiv D rho i (run i) (run (S i)))). exact Ht.
Qed.

Theorem symbolic_accepts :
  forall D w, DTA_accepts D w <-> SDTA_accepts (symbolic D) w.
Proof.
  intros D w. unfold DTA_accepts, SDTA_accepts. split;
    intros [rho [Hb [Hc Ha]]]; exists rho; split; try exact Hb; split; try exact Hc;
    apply symbolic_ext_accepts; exact Ha.
Qed.

Theorem symbolic_accepts0 :
  forall D w, DTA_accepts0 D w <-> SDTA_accepts0 (symbolic D) w.
Proof.
  intros D w. unfold DTA_accepts0, SDTA_accepts0. split;
    intros [rho [Hb [Hc [H0 Ha]]]]; exists rho; split; try exact Hb; split; try exact Hc;
    split; try exact H0; apply symbolic_ext_accepts; exact Ha.
Qed.

End Symbolic.

(* End-to-end correctness of the symbolic automaton. *)
Theorem MTL_to_symbolic_correct_with :
  forall (n : nat) (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (T f))) ->
    well_formed f ->
    (msat w 0 f <-> SDTA_accepts (symbolic (export (optimize n (compile_with A)))) w).
Proof.
  intros n f A w HA Hwf.
  rewrite (MTL_to_exported_correct_with n w HA Hwf). apply symbolic_accepts.
Qed.

Theorem MTL_to_symbolic_correct0_with :
  forall (n : nat) (f : mtl) (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (T f))) ->
    well_formed f ->
    init_free (export (optimize n (compile_with A))) = true ->
    (msat w 0 f <-> SDTA_accepts0 (symbolic (export (optimize n (compile_with A)))) w).
Proof.
  intros n f A w HA Hwf Hfree.
  rewrite (@MTL_to_exported_correct0_with n f A w HA Hwf Hfree). apply symbolic_accepts0.
Qed.

Print Assumptions MTL_to_symbolic_correct0_with.

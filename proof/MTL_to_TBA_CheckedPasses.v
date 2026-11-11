(*
  MTL_to_TBA_CheckedPasses.v

  The two certificate-checked passes (removal of dominated transitions, then
  reuse of clocks) after the optimization rounds, and the end-to-end theorem
  of the chain with both.  Both certificate producers are parameters, so the
  theorems hold for every producer, including a wrong one.
*)

Require Import Arith Lia List Bool Reals Lra.
Require Import Classical ClassicalDescription.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import MTL_to_TBA_Invariants.
Require Import MTL_to_TBA_Optimizations.
Require Import MTL_to_TBA_Export.
Require Import MTL_to_TBA_ClockAlloc.
Require Import MTL_to_TBA_DomPrune.
Import ListNotations.

Definition checked_passes (root : mtl) (pc : prune_certifier root)
    (ac : certifier root) (n : nat) (A : TBA root) : TBA root :=
  alloc_pass root ac (prune_pass root pc (split_cells root (optimize n A))).

Theorem checked_passes_accepts :
  forall root pc ac n A w,
    TBA_accepts A w <-> TBA_accepts (checked_passes root pc ac n A) w.
Proof.
  intros root pc ac n A w. unfold checked_passes.
  rewrite (optimize_accepts n A w).
  rewrite (split_cells_accepts root (optimize n A) w).
  rewrite (prune_pass_accepts root pc (split_cells root (optimize n A)) w).
  apply alloc_pass_accepts.
Qed.

Definition checked_export (root : mtl) (pc : prune_certifier root)
    (ac : certifier root) (n : nat) (A : TBA root) : DTA root :=
  export (checked_passes root pc ac n A).

Definition checked_export_all (root : mtl) (pc : prune_certifier root)
    (ac : certifier root) (n : nat) (A : TBA root) : DTA root :=
  export_all (checked_passes root pc ac n A).

Theorem MTL_to_exported_checked_correct :
  forall (pc : forall f, prune_certifier f) (ac : forall f, certifier f)
         (n : nat) (f : mtl) (w : timed_word),
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (checked_export f (pc f) (ac f) n (compile f)) w).
Proof.
  intros pc ac n f w Hwf.
  rewrite (MTL_to_TBA_correct w Hwf).
  unfold checked_export.
  rewrite (checked_passes_accepts f (pc f) (ac f) n (compile f) w).
  apply export_accepts.
Qed.

Theorem MTL_to_exported_all_checked_correct :
  forall (pc : forall f, prune_certifier f) (ac : forall f, certifier f)
         (n : nat) (f : mtl) (w : timed_word),
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (checked_export_all f (pc f) (ac f) n (compile f)) w).
Proof.
  intros pc ac n f w Hwf.
  rewrite (MTL_to_TBA_correct w Hwf).
  unfold checked_export_all.
  rewrite (checked_passes_accepts f (pc f) (ac f) n (compile f) w).
  apply export_all_accepts.
Qed.

Theorem MTL_to_exported_checked_correct_with :
  forall (n : nat) (f : mtl) (pc : prune_certifier f) (ac : certifier f)
         (A : PBuchi f) (w : timed_word),
    (forall s : pword f, action_consistent s ->
       (PBA_accepts A s <-> psat s 0 (T f))) ->
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (checked_export f pc ac n (compile_with A)) w).
Proof.
  intros n f pc ac A w HA Hwf.
  rewrite (@MTL_to_TBA_correct_with f A w HA Hwf).
  unfold checked_export.
  rewrite (checked_passes_accepts f pc ac n (compile_with A) w).
  apply export_accepts.
Qed.

Print Assumptions MTL_to_exported_checked_correct_with.

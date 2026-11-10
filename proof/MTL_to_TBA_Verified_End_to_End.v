(*
  MTL_to_TBA_Verified_End_to_End.v

  End-to-end correctness of the pipeline MTL -> clocked LTL -> propositional
  Buchi automaton (verified backend) -> TBA -> optimization -> export, with
  no hypothesis on the backend.  The statements instantiate the generic
  compositions of MTL_to_TBA_Export.v with the verified backend of
  LTL_to_PBA_Final.v.
*)
Require Import Arith Lia List.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import LTL_to_PBA_Sound LTL_to_PBA_Pack LTL_to_PBA_Concrete
               LTL_to_PBA_Complete LTL_to_PBA_Final.
Require Import MTL_to_TBA_Invariants MTL_to_TBA_Optimizations MTL_to_TBA_Export.

(* The verified backend meets the backend contract for every formula. *)
Lemma verified_backend_contract :
  forall (f : mtl),
    forall s : pword f, action_consistent s ->
      (PBA_accepts (backend f (T f)) s <-> psat s 0 (T f)).
Proof.
  intros f s _. split.
  - exact (backend_sound f (T f) s).
  - exact (backend_complete_run f (T f) s).
Qed.

(* Optimization followed by explicit-guard export, for every number of
   optimization rounds. *)
Theorem MTL_to_exported_correct_verified :
  forall (n : nat) (f : mtl) (w : timed_word),
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (export (optimize n (compile_with (backend f (T f))))) w).
Proof.
  intros n f w Hwf.
  apply (@MTL_to_exported_correct_with n f (backend f (T f)) w);
    [apply verified_backend_contract | exact Hwf].
Qed.

(* The same with the all-copy exporter. *)
Theorem MTL_to_exported_all_correct_verified :
  forall (n : nat) (f : mtl) (w : timed_word),
    well_formed f ->
    (msat w 0 f <->
     DTA_accepts (export_all (optimize n (compile_with (backend f (T f))))) w).
Proof.
  intros n f w Hwf.
  apply (@MTL_to_exported_all_correct_with n f (backend f (T f)) w);
    [apply verified_backend_contract | exact Hwf].
Qed.

Print Assumptions MTL_to_exported_correct_verified.
Print Assumptions MTL_to_exported_all_correct_verified.

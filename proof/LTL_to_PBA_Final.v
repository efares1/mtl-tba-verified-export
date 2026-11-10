(*
  LTL_to_PBA_Final.v

  The statement of the axiom LTL_TO_BUCHI_CORRECT, proved, and the main
  theorem of the paper without the backend contract as an assumption.
*)
Require Import Arith Lia List.
Require Import MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.
Require Import EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.
Require Import LTL_to_PBA_Sound LTL_to_PBA_Pack LTL_to_PBA_Concrete
               LTL_to_PBA_Complete.

(* Same type as the axiom of the Core file, but proved.  The conclusion
   holds for every propositional word, not only the action-consistent ones. *)
Theorem LTL_TO_BUCHI_PROVED :
  forall (root : mtl) (f : ltl root),
    { A : PBuchi root |
      forall s : pword root, action_consistent s ->
        (PBA_accepts A s <-> psat s 0 f) }.
Proof.
  intros root f. exists (backend root f). intros s _. split.
  - exact (backend_sound root f s).
  - exact (backend_complete_run root f s).
Qed.

(* The main theorem with the verified backend: no contract hypothesis. *)
Theorem MTL_to_TBA_correct_verified :
  forall (f : mtl) (w : timed_word),
    well_formed f ->
    (msat w 0 f <-> TBA_accepts (compile_with (backend f (T f))) w).
Proof.
  intros f w Hwf.
  apply (@MTL_to_TBA_correct_with f (backend f (T f)) w); [| exact Hwf].
  intros s _. split.
  - exact (backend_sound f (T f) s).
  - exact (backend_complete_run f (T f) s).
Qed.

Print Assumptions MTL_to_TBA_correct_verified.

# Experiment 5: do the Rocq proofs reject the mutants?

Method: scratch copy of `proof/*.v` (`ctrl/`, original files untouched), Rocq Platform 9.0 `coqc.exe`.
Control (unmutated) compiles all 10 files of the chain in about 43 s; `Print Assumptions` on the principal
theorems (Audit_Revision_20261010.v, `logs/CTRL_audit.txt`) gives the 4 standard axioms, as in ROCQ_ASSUMPTIONS_AUDIT.md.
Each mutant is a one-line change to the Rocq definition corresponding to the OCaml mutant; only the mutated file and its dependents are rebuilt.
"Time" is seconds from the start of the mutated-file build to the first error.

| Mutant | Rocq-level change | Compiles? | First failing lemma (file:line) and message | Time | Notes |
|---|---|---|---|---|---|
| M01 | `inv_item_of`: `Rle_dec 0 M` -> `Rlt_dec 0 M` (Optimizations) | no | `inv_guard_w_eq`, Optimizations:2575, "Unable to unify" the mutated `match ... Rlt_dec 0 M` with the specification form `Rle_dec 0 M` | 4.7 s | The proof ties the fast invariant computation to the specification `inv_guard_item` (Invariants.v), which still uses `Rle_dec`. Caveat: this shows the implementation disagrees with the specification. A coherent change to both was not tried. |
| M10 | `sim`: reset-set test replaced by `true` (Optimizations) | no | `sim_spec`, Optimizations:1783, "Unable to apply lemma ... b1 && b2 = true <-> ... on hypothesis true = true" | 3.8 s | The simulation relation no longer implies reset-set equality, needed by `sim_spec`. |
| M12 | `compl`: `CLt => mk CGe` -> `mk CGt` (Optimizations) | no | `compl_cases`, Optimizations:2229, "Tactic failure: Cannot find witness" | 4.8 s | The complement lemma fails. |
| M16 | `const_true`: `Rle_dec 0 (guard_bound k)` -> `Rlt_dec` for `CLe` (Export) | no | `const_true_spec`, Export:816, cannot unify `true` with `if Rlt_dec 0 (guard_bound k) ...` given `0 <= guard_bound k` | 3.0 s | The equality case 0 <= 0 breaks the lemma. |
| M13 | `min_all`: `Rmin` -> `Rmax` | no | `min_all_le`, Optimizations:207, "Not convertible" | 1.8 s | Extra mutant (OCaml survivors list did not include it). |
| M14 | difference constraint reversed `DDiff (fst p) (fst q) (snd p - snd q)` | no | `notlonger_complete`, Export:724, "Not convertible" | 2.5 s | Extra mutant. |
| M19 | `dprune`: `Nat.eqb (dt_src t) (dta_init D) ||` -> `false ||` | no | `dprune_accepts`, Export:1679, cannot unify `dhas_incoming D (dt_src t) = true` with the needed disjunction | 7.7 s | Extra mutant: initial-state edges are no longer kept. |

Result: 7 of 7 attempted mutants are rejected by compilation; none compiles, so no specification gap was found for these mutants
and no `Print Assumptions` check on a mutant was needed.

Caveats (honest limits):
- Rocq-level mutants are my transcriptions of the OCaml mutants, not the extracted code. M01 in particular fails against the spec rather than the main theorem; a mutant that changed the spec as well would not be caught by this check.
- The first error is where Rocq stops; later lemmas (and the final preservation theorems `optimize_accepts`, `export_accepts`) are not reached, so "which theorem becomes unprovable" is answered by the lemma on which they depend.
- M01 and M19: the line recorded by the driver in `logs/*_result.json` is a deprecation warning; the actual error lines are 2575 and 1679 (see logs).
- Not tested: remaining OCaml mutants (M02..M09, M11, M15, M17, M18, M20..M22), which T1/T2 already detect.

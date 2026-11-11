# Rocq assumptions audit (2026-10-11)

Source: `Print Assumptions` (logs in `output/rocq/assumptions*.txt`) and `coqchk` context summaries.

## Two different kinds of dependency

| Assumption | Kind | Meaning |
|---|---|---|
| `LTL_TO_BUCHI_CORRECT` (project `Axiom`, Core) | **project-specific hypothesis about an external component** | states the existence of a correct LTL-to-Büchi translator; used only by the convenience theorems without the suffix `_with` (`MTL_to_TBA_correct`). The `_with` theorems take the backend contract as an explicit premise instead. It is not a mathematical axiom of the logic and is not discharged by Rocq. |
| `ClassicalDedekindReals.sig_forall_dec` | standard library | used by the construction of the real numbers (decidable comparisons of bounds) |
| `FunctionalExtensionality.functional_extensionality_dep` | standard library | functional extensionality |
| `Description.constructive_definite_description` | standard library | definite description (used by the classical Boolean reflection `decide_b`) |
| `Classical_Prop.classic` | standard library | excluded middle |

`coqchk` also lists `ClassicalDedekindReals.sig_not_dec` in the global context of the loaded
libraries; it does not appear in `Print Assumptions` of any principal theorem below.

## Principal theorems (fresh builds)

| Theorem | Project | Assumptions |
|---|---|---|
| `EncodingCorrect_proved`, `canonical_encoding_all` | both | 4 standard |
| `MTL_to_TBA_correct_with` | both | 4 standard |
| `MTL_to_TBA_correct` | both | 4 standard + `LTL_TO_BUCHI_CORRECT` |
| `alarm_response_tba_correct_with`, `alarm_response_spot_backend_contract`, `alarm_response_spot_tba_correct`, `alarm_overlap_trace_accepted_by_spot_tba`, `alarm_response_trace_rejected_by_any_correct_backend`, `alarm_response_trace_rejected_by_spot_tba` | the earlier translation article | 4 standard |
| `alarm_response_trace_violates`, `alarm_overlap_trace_satisfies` | the earlier translation article | `sig_forall_dec`, `functional_extensionality_dep` |
| `optimize_accepts`, `export_accepts`, `export_all_accepts` | this article | 4 standard |
| `split_accepts`, `split_all_accepts`, `export_guards_conjunctive`, `export_invariants_conjunctive`, `export_all_guards_conjunctive`, `export_all_invariants_conjunctive`, `symbolic_ext_accepts` | this article | `classic`, `functional_extensionality_dep`, `sig_forall_dec` |
| `MTL_to_exported_correct_with`, `MTL_to_exported_correct0_with`, `MTL_to_exported_all_correct_with` | this article | 4 standard |
| `MTL_to_exported_correct_recur_weak_with`, `MTL_to_exported_correct0_recur_weak_with` (default front end: recur + weak until) | this article | 4 standard |
| `allocate_clocks_accepts`, `try_allocate_accepts`, `alloc_pass_accepts`, `optimize_alloc_accepts` (clock reuse by liveness, `MTL_to_TBA_ClockAlloc.v`, opt-in `-alloc`; added 2026-11-11) | this article | 4 standard |
| `alloc_ok_sound` (the boolean checker implies the four local conditions) | this article | `classic`, `functional_extensionality_dep`, `sig_forall_dec` |
| `MTL_to_exported_alloc_correct_with` (Spot contract as premise) | this article | 4 standard |
| `MTL_to_exported_alloc_correct`, `MTL_to_exported_all_alloc_correct` | this article | 4 standard + `LTL_TO_BUCHI_CORRECT` |

Before unification, the earlier translation article's copy additionally depended on
`IndefiniteDescription.constructive_indefinite_description` (through `functional_choice`) for
`MTL_to_TBA_correct_with` and six alarm-response theorems; that dependency is gone.

The clock-reuse theorems hold for every certificate producer: the allocation and the liveness sets are arguments
(`certifier`), the pass returns the automaton unchanged when `alloc_ok` fails, and the colouring in
`tool/src/alloc.ml` is outside the trusted base for the language guarantee (its output is checked by the extracted
`alloc_ok`). Clean build of all `proof/*.v` files, `Print Assumptions` and the audit script were rerun on 2026-11-11.

## Verified versus unverified components

Kernel-checked: everything stated by the theorems above, for the formula-indexed definitions
of the Core file. Not covered by Rocq: correctness of Spot and of its graph-to-record
transcription (backend contract), the parser and printers of `mtl2tba`, the floating-point
realization of real bounds in extracted code, the extraction mechanism, and the use of the
printed automata in UPPAAL or TChecker.

## Regeneration from the final snapshot

`output/rocq/` was regenerated from the final sources: `make` (extraction to
`tool/src/optim.ml`, identical to the file in the repository ignoring line endings),
`Audit_Revision_20261010.v` (17 `Print Assumptions` blocks, including the two
`_recur_weak_with` theorems), and `coqchk` on the ten modules, with Rocq 9.0.1 (Platform
2025.08). `output/rocq/build_info.txt` lists the SHA-256 of every `proof/*.v` file used.

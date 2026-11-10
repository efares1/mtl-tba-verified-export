# Rocq development used by Paper 2: generic TBA optimization and export

This Rocq development (the proof assistant formerly called Coq) contains the verified transformations that post-process a TBA and produce an explicit UPPAAL-oriented automaton. Paper 2's central preservation results quantify over arbitrary input TBAs and hold for any requested number of optimization rounds. The upstream MTL-to-TBA translation is also present because the extracted `mtl2tba` executable composes it with these generic passes; it is a separate prerequisite for formula-level end-to-end claims.

| File | Role relevant to Paper 2 |
|---|---|
| `MTL_to_TBA_Invariants.v` | Invariant semantics, synthesis, backward propagation, and their language-preservation results such as `add_invariants_accepts` and `propagate_n_accepts` |
| `MTL_to_TBA_Optimizations.v` | Forward propagation, simplification, dead resets, synchronous clock merging, guard/transition/location reduction, and generic `optimize_accepts` |
| `MTL_to_TBA_Export.v` | Transition merging, disjunctive-invariant/guard elimination, symbolic output, and `export_accepts` |
| `MTL_to_TBA_Initialization.v` | Zero-initialization check used by the formula-generated workflow; not a generic initialization theorem for arbitrary external TBAs |
| `MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.v` and `EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof.v` | Upstream MTL construction and its semantic contract, retained as tool-chain dependencies |
| `Extract_Optim.v` | Extraction of verified functions to the OCaml tool |

## Build

From this directory, `make` compiles the Coq/Rocq files and extracts the verified functions. `make tool` builds the OCaml executable in `../tool/`. The proof development was reported with Rocq 9.0.1; see the top-level README for the article build and `evaluation/README.md` for experiment dependencies.

The `*_accepts` theorems preserve timed-word acceptance under the development's existential initial-clock semantics. UPPAAL's all-clocks-zero convention is handled by an additional check only on the formula-generated workflow. The generic Rocq pass theorems do not depend on Spot or on the source of the TBA. `CheckGenericAssumptions.v` regenerates the `Print Assumptions` record in `ASSUMPTIONS_GENERIC.txt`.

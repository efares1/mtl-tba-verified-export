# Rocq development used by Paper 2: generic TBA optimization and export

This Rocq development (the proof assistant formerly called Coq) contains the verified transformations that post-process a TBA and produce an explicit UPPAAL-oriented automaton. Paper 2's central preservation results quantify over arbitrary input TBAs and hold for any requested number of optimization rounds. The upstream MTL-to-TBA translation is also present because the extracted `mtl2tba` executable composes it with these generic passes; it is a separate prerequisite for formula-level end-to-end claims.

| File | Role relevant to Paper 2 |
|---|---|
| `MTL_to_TBA_Invariants.v` | Invariant semantics, synthesis, backward propagation, and their language-preservation results such as `add_invariants_accepts` and `propagate_n_accepts` |
| `MTL_to_TBA_Optimizations.v` | Forward propagation, simplification, dead resets, synchronous clock merging, guard/transition/location reduction, and generic `optimize_accepts` |
| `MTL_to_TBA_Export.v` | Transition merging, disjunctive-invariant/guard elimination, symbolic output, and `export_accepts` |

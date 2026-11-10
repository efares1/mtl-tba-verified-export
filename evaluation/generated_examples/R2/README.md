# Generated R2 example

This directory snapshots one current run of the integrated tool for the R2
two-bounded-response benchmark. It is included as a continuation example: the
paper begins at the automaton after reset completion and discusses only the
subsequent optimizer and export stages.

Formula:

```text
[](a1 -> <>[<=5] b1) & [](a2 -> <>[<=5] b2)
```

The recorded files are `R2_noinit_tba.dot` (optimizer input after upstream
translation and reset completion), `R2_noinit_opt.dot` (after the iterated
optimizer), and `R2_noinit.dot` / `R2_noinit.xml` (explicit and symbolic
export outputs). They were regenerated from the repository's current
`tool/_build/default/src/mtl2tba.exe` on 2026-10-09. The five-run median
measurements remain those in `evaluation/ours_results.tsv`; this snapshot is
one deterministic regeneration and is not a replacement for those medians.

From the repository root, the command was:

```sh
./tool/_build/default/src/mtl2tba.exe -tba -nopdf -stats \
  -o evaluation/generated_examples/R2/R2_noinit \
  '[](a1 -> <>[<=5] b1) & [](a2 -> <>[<=5] b2)'
```

The measured reachable counts are: optimizer input, 4 locations / 25
transitions / 2 active clocks; after two changed optimization rounds, 4 / 16
/ 2; explicit export, 4 / 19 / 2, with three invariant-bearing locations
and two diagonal-guard occurrences. The exporter increases explicit edges
because it splits Boolean/disjunctive guards and adds entry predicates for
invariant copies. The XML printer and parser are not mechanically verified.

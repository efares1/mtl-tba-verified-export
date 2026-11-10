# this article — evaluation report (run of 2026-10-13/14)

The tool-dependent evaluation was re-run on 2026-10-12/13 after two changes of
the translation article's tool and proof: the negated event atom is printed
as `!"p"` (option `-explicit-neg`, default) and the backend contract is
required on action-consistent words only (see section 11). Sections 1, 2, 4,
6, 9 and 10 below give the numbers of that run; the archived run of
2026-10-10 is in `evaluation/runs/2026-10-10-full-eval-v1/`.

Labels: **fresh** = run during this revision; **archived** = recorded earlier in
`evaluation/runs/`, re-read and recomputed but not re-run; **source** = read
from source files; **kernel** = Rocq theorem checked by `coqc`/`coqchk`.

## 1. Generated F/R/N group (fresh, 2026-10-13/14)

Source: `evaluation/ours_results.tsv`, copied to
`evaluation/runs/2026-10-14-full-eval-v3/` (five-run medians, Ubuntu 26.04/WSL 2, i7-8650U, OCaml 5.4.0, Spot 2.16,
300 s limit, tool default front end = recur + weak until).

| Quantity | Recomputed | In the article |
|---|---|---|
| attempted / completed | 31 / 29 (R7, R8 time out) | same |
| transitions after reset completion (optimizer input) | 20,204 | 20,204 |
| after optimization | 1,500 (−92.58 %) | 1,500 |
| after explicit export | 3,209 (+113.93 %) | 3,209 |
| symbolic transitions after export | 984 | not stated in aggregate |
| fewer transitions after optimization / unchanged | 19 / 10 | same |
| exports that grow | 6 | same |
| active clocks | 77 → 74 (F2, F11, F13) | same |
| removed by R family / R6 | 18,441 / 14,985 of 18,704 | same |
| F / N removed | 46 / 217 | same |

R6: 64 locations, 15,625 transitions, 6 clocks → 6 rounds → 640 transitions
→ export 1,837 explicit transitions, 63 invariant locations, 3,360 diagonal
atoms, 448 symbolic transitions. All numbers in the article match.

Changed by the explicit negation (Spot automaton, states/transitions): F11 5/11 ->
4/7, F12 4/17 -> 3/9, F13 5/17 -> 3/6, F14 6/26 -> 6/23; R and N unchanged.
Timings: R6 optimizer 17.8 s, export 10.7 s; N8 total 98.3 s.

## 2. CASAAL as an external output-size reference (fresh sizes, CASAAL data archived)

Source: `evaluation/casaal_exclusive.tsv` (CASAAL with mutually exclusive
events) against our optimized output. Over the 27 configurations completed
by both tools with an exact CASAAL encoding (F3, F13 are hatted and have no
exact CASAAL encoding; R7, R8 time out for us):

- locations and symbolic transitions coincide in **22/27**;
- F5, F6: ours 7 locations / 25 symbolic transitions, CASAAL 4 / 15 (ours larger);
- F11: ours 3 / 4, CASAAL 4 / 7; F12: ours 2 / 5, CASAAL 3 / 9; F14: ours 6 / 14, CASAAL 8 / 18 (ours smaller);
- clocks coincide except F11 (ours 1, CASAAL 2; reduced by the optimizer from 2)
  and F8 (ours 0, CASAAL 1; due to the upstream recur rewriting, not credited
  to the optimizer);
- R6: 64 / 448 / 6 for both.

Note: `evaluation/casaal_results.tsv` (CASAAL without mutual exclusion)
gives different transition counts (R6: 4,096) and only 11/27 matches; the
exclusive run is the one matching our one-event-per-position semantics.
A new subsection "External output-size reference" states this in the article.
Language agreement is not claimed here (the earlier translation article).

## 3. Synthetic suite and ablation (fresh)

`evaluation/run_synthetic_ablation_v2.sh` re-run on 2026-10-11 into
`evaluation/runs/2026-10-11-synthetic-ablation-fresh/` with the same sources
(SHA-256 of `optim.ml` and `synthetic_tba_bench.ml` identical to the archived v6 run).

- `leave_one_out.tsv`, `mechanism_examples.txt`: structural columns identical to v6.
- `pass_trace.tsv`, `parameterized_trace.tsv`: identical except time/heap columns.
- Leave-one-out aggregates (reachable locations, transitions, active clocks):
  full 30/33/9; −backward synthesis 31/34/10; −forward 33/36/9;
  −contradiction removal 40/43/11; −unsatisfiable labels 31/34/9;
  −no-incoming sources 30/39/10; −normalization 30/33/12; −dead resets 30/33/13;
  −synchronous clocks 32/35/11; −transition subsumption 30/35/9;
  −equivalent locations 31/35/9. All agree with the article.

The requested mechanism records already exist and are measured:
backward tightening (x≤5 → x≤2), forward lower bound (x≥2 added),
forward contradiction cascade (7 → 4 edges; 7 retained without forward
propagation), backward contradiction cascade, normalization enabling
dead-reset removal, clock merging followed by a contradiction in a later
round. The optimizer was not modified.

## 4. Regression tests (fresh)

`evaluation/run_boundary_tests.sh` + `check_boundaries.py`: 18/18 finite-word
boundary checks pass with the tool rebuilt from `tool/` on 2026-10-12.
`evaluation/test_tck_product_acceptance.py`: regression test of the reading of
CASAAL automata without acceptance marks (`tck_product.py`).

## 5. UPPAAL (re-run 2026-10-11)

After the licence was renewed, `verifyta.exe` 5.0.0 (rev. 714BA9DB36F49691)
was run on the eight packaged models (`bash run_uppaal.sh`, `-t0 -q`):
the four `E<> P.A4` queries give not satisfied / satisfied / not satisfied /
satisfied (spor_ok, spor_bad, resp_ok, resp_bad), and the four
`A[] not deadlock` queries are satisfied. All eight verdicts are identical to
the archived ones in `evaluation/case_study/expected.txt` and
`uppaal_results.txt`. Output:
`evaluation/case_study/uppaal_results_rerun_2026-10-11.txt`.
These runs give verdicts only (no before/after runtime or zone counts).

## 6. TChecker before/after (fresh, 2026-10-13)

`evaluation/runs/2026-10-13-tchecker-before-after/` (`run_tck_before_after.sh`):
byte-identical exported XML and products before/after, same verdicts and
explored states as in the run of 2026-10-10 (resp_ok: CYCLE false, 77/77/127;
resp_bad: CYCLE true, 15/7/19); checker times and RSS differ.

## 7. Figures S3/S4 of an earlier draft of the supplement — not restored

The earlier Fig. S3 (Example S1, ◇≤5(p U≤2 q), split of a disjunctive
invariant x_u1 ≤ 2 ∨ x_u0 ≤ 5) and Fig. S4 (Example S2, three clocks) were
produced by an earlier version of the front end (Spot options -B -D, option
-init). With the current tool, for both formulas and with or without
`-init`, `-noweak`, `-B -D`, the optimized automaton has no disjunctive
invariant (S1: 4 locations, 7 transitions; S2: 5 locations, 11 transitions;
0 diagonal atoms after export). Restoring the original TikZ as "output of
mtl2tba" would therefore misdescribe the current tool; the decision is left
to the authors; decided on 2026-10-11: not restored. The worked maximal-delay example in
Section IV and the R2 generated-stage figure illustrate the split with
current outputs.

## 8. Generality and initialization wording (source)

All claims of "generic"/"arbitrary TBA" theorems were replaced by: "The
preservation theorems hold for every TBA represented by the formula-indexed
clock interface, independently of whether the automaton was generated by the
MTL translator." The interface paragraph now explains that clocks are the
timed subformulas of a fixed formula `root`, used only as clock names; the
synthetic suite paragraph explains its six-clock root formula.
`init_free_accepts0` holds for every DTA on which the check succeeds; the
former sentences "not a zero-initialization result for arbitrary imported
TBAs" were corrected accordingly (the restriction is that the check may fail,
not that the lemma is specific to generated automata).
The default front end (recur + weak until) is now named with its theorem
`MTL_to_exported_correct0_recur_weak_with` (4 standard axioms, kernel).

## 9. Symbolic before/after and Spot level (added 2026-10-11)

- `evaluation/run_symbolic_before_after.sh` + `make_symbolic_before_after.py`:
  symbolic transitions of the exported automaton with the optimizer disabled
  (`-n 0`) and enabled, both with symbolic grouping. On the 27 configurations
  where the unoptimized export completes: 704 → 354 (50 %); F+N 364 → 226;
  R1–R4 340 → 128; smaller in 14, equal in 13, larger in 0. R5, R6: the
  unoptimized export does not finish in 300 s (optimized: 2.3 s, 33.7 s).
  Symbolic output equals CASAAL's on 24/27 (F5, F6 larger: 25 vs 15; F14
  smaller).
- Earlier attempt to attribute reductions by comparing `compile(f)` with the
  column `sym_trans` was discarded: `sym_trans` is counted after the final
  symbolic grouping, so the comparison mixes representations.
- `-spot-level low` (default unchanged), one repetition on 2026-10-13
  (`ours_results_low.tsv`): total time over the 29 completing configurations
  163 s (five-run medians) → 46 s; N8 101.6 s → 8.9 s; sizes identical except
  F5, F6 (symbolic 25 → 27). R6 46.8 s → 32.1 s, with optimizer and export also
  faster in that run, so the difference is not attributed to the level.

## 10. Consistency of the grouped counts in the two articles

`evaluation/run_chain.sh` runs the tool with the front end of the translation
article (`-noweak -norecur`) and the optimizer disabled (`-n 0`), and writes
`evaluation/chain_noweak.tsv` (explicit transitions of compile(f) and symbolic
transitions). Re-run on 2026-10-13 with the tool after the explicit-negation change:
on the 27 configurations that complete within 300 s (F1--F14, F3b,
R1--R4, N1--N8), both columns equal the "explicit" and "grouped" columns of the
translation article's `grouped_edges.tsv`. R5 does not finish within 300 s
under this setting; R6--R8 do not build. The symbolic counts of Section 5 use the default
front end (weak-until and recurrence rewritings enabled) and are therefore not
comparable with the grouped column of the translation article for the F and R families.

## 11. Re-run of 2026-10-12/13: changes and verification

- `bash evaluation/run_all.sh` (12 steps: full, noweak, boundary, spot,
  interface, accept, randopt, policies, tckeq, tckcomp, randdiff, symbolic),
  2026-10-12 16:35 to 2026-10-13 02:05 (+04); log `evaluation/run_all.log`,
  copy in `evaluation/runs/2026-10-12-full-eval-v2/`. Extra runs:
  `run_tck_before_after.sh` (2026-10-13), `run_generated_split_comparison.sh`
  (2026-10-13, `runs/2026-10-13-generated-split/`), `run_chain.sh`,
  and one repetition with `-spot-level low`.
- Interface check: 31/31 "same / equivalent". Spot validation: 25 yes, 6 ltl2ba
  timeouts (R6–R8, N6–N8), as before. TChecker equivalence: 17 configurations
  conclude on the exported automata, 3 (F14, R2, R3) only before optimization,
  9 without conclusion (R4–R6, N5, N6; R7, R8, N7, N8 tool timeouts); no
  disagreement. All unchanged.
- Random formulas (`random_diff.tsv`): all empty on 96, four with partial
  timeouts (X31, X62, X64, X83), none non-empty (CASAAL automata without an
  acceptance mark are read by their state labels, `tck_product.py`).
  `random_opt.tsv`: input/optimized/exported transitions 2,507 / 1,526 / 1,564;
  `init_free` fails on X35, X38, X65, X84, X100 (previously four).
- Article text updated: optimizer aggregates, family breakdown, symbolic
  counts, R6 timings, F11 running example (input now 4/7/2, figure renumbered),
  export-policy table and RSS, spot-level paragraph, TChecker before/after
  table, validation section (random formulas), supplement statistics.

## 12. Run of 2026-10-13/14: merging of locations under the entry invariant

- Optimizer: `merge_states_all` compares guards by subsumption under the entry
  invariant of the merged location (`entry_lb_loop_sound`); proof, audit
  (same four standard axioms) and `coqchk` on the ten modules exit 0.
  Regression test `evaluation/test_entry_invariant_merging.sh`: F1 2/5/1,
  F11 3/4/1, F12 2/5/2, F13 2/3/1; P1, P2, S empty on F11 and F12.
- `bash evaluation/run_all.sh`, 12 steps, 2026-10-13 19:35 to 2026-10-14 04:59
  (+04); log `evaluation/run_all.log`, copy in
  `evaluation/runs/2026-10-14-full-eval-v3/`. One repetition with
  `-spot-level low` was run afterwards (`ours_results_low.tsv`).
- Sizes (section 1): F11 4/7/2 -> 3/4/1 (locations/transitions/clocks), F12
  3/9/2 -> 2/5/2, F13 3/6/2 -> 2/3/1 after optimization; the other
  configurations of the group have the sizes recorded in `ours_results.tsv`.
  Random formulas (`random_opt.tsv`): input / optimized / exported transitions
  2,507 / 1,509 / 1,547; locations 696 / 564 / 566; clocks 160 / 128;
  57 formulas have fewer transitions, 25 fewer locations, 26 fewer clocks, none more.
- Interface check: 31/31 "same / equivalent". Spot validation: 25 yes, 6 ltl2ba
  timeouts (R6–R8, N6–N8). TChecker equivalence: 17 configurations conclude on
  the exported automata (F1–F12 except F3, R1, N1–N4: P1, P2, S empty), 3 (F14,
  R2, R3) only before optimization, 9 without conclusion; no disagreement.
- Random formulas (`random_diff.tsv`): all empty on 96, four with partial
  timeouts (X31, X62, X64, X83), none non-empty. `init_free` fails on X35, X38,
  X65, X84, X100.
- Article text updated: optimizer aggregates, family breakdown, symbolic
  counts, R6 timings, CASAAL comparison, supplement statistics.

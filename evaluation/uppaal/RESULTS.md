# UPPAAL experiment (experiment 2) - results

Tool: UPPAAL 5.0.0 `verifyta` (C:\Program Files (x86)\UPPAAL-5.0.0\bin), options `-u -s -q -t0 -o 0`
(summary, breadth-first, default extrapolation, default state representation).
Statistics: `States stored / States explored` and `Resident memory used` are verifyta's own output
(`-u`); wall time = median of 3 runs measured by the script (includes parsing and process start).
CPU time printed by verifyta is 0-16 ms (resolution), so it is not used.

Files: `gen_models.py` (WSL; builds 311 models in `models/` and `manifest.json`), `run_uppaal_eval.py`
(runs verifyta, writes `results.tsv`), `make_table.py` (writes `summary.md`, `uppaal_table.tex`),
`tck_acceptance_encoding_check.{sh,txt}` (side check on the TChecker numbers, see below).

## Design
Property automaton of the NEGATED requirement in 7 variants: ours default (optimizer + maximal-delay
export), ours `-n 0`, ours `-all-copy`; CASAAL plain (CASAAL's .gv, acceptance converted to locations by
casaal_to_tba.py, written as UPPAAL XML by the plain converter in gen_models.py: no invariants, none of
our passes); CASAAL through our export (`tba_opt -n 0`, default, `-all-copy`).
Systems: `ok`/`bad` (single-request response system of make_resp_system.py, case-study response and
sporadic systems), `parok`/`parbad` (n independent request/response components with their own clocks, so
the product has real concurrency; `parbad` answers 1 within 6 instead of 2), `free` (emits any event at any
later time; query `A[] true` explores the whole zone graph of the property automaton).
Query: `E<> P.<universal accepting sink>` (violation of the safety requirement); expected "not satisfied"
for ok systems, "satisfied" for bad systems. Positive block: the requirement itself with the ok system,
only to check that UPPAAL reads the default (maximal-delay) export and the diagonal guards.
Limitation: these are reachability (safety-style) checks of an accepting sink, not Buchi acceptance.
The systems are small; verdicts come from UPPAAL's exhaustive zone search.

## Results
* 311 runs, 0 errors, 0 timeouts. Verdict equals the expected verdict in all 296 runs with an expectation;
  15 positive-form runs are acceptance-only checks (UPPAAL parsed the default maximal-delay export,
  including exports with diagonal guards in R3/R4, and answered).
* Full explorations (parok, free, ok): the number of stored states is IDENTICAL in all 7 variants for
  F1-F4, F7, F11, F12, R1-R6, N1-N5 (e.g. R6 par-ok 11,743 in every variant; N5 free 33).
  Differences only on F5 and F8 (ours 3 and 2 states, CASAAL 4 and 4: the smaller translation, not the export).
  In `bad` runs (query satisfied, search stops at the first hit) the counts are partial and differ
  by search order (e.g. R2 9 vs 11); they are not a measure of size.
* Time: for R5/R6 par-ok and N4/N5 free, ours is faster than CASAAL (R6: 1.3 s vs 3.5 s; N5 0.19 vs 0.29 s),
  but CASAAL's automaton after OUR export (casaal_opt) is as slow as CASAAL plain (3.6 s): the time tracks
  the number of explicit Property edges (R6: 182 ours vs 330 CASAAL in every export variant), not the export
  or the optimizer. Memory differs by < 3%.
* Invariants: the negated automata of F1-F9, R1-R6, N1-N3 contain NO location invariant in any variant
  (only F10, F11, F12 have 1-2 invariants). The exports of CASAAL's automata add none either (R6: 0 in all 7 variants).

## Side finding that affects the TChecker claim (please check)
The TChecker advantage attributed to "the location invariants of the verified export" cannot come from
invariants on these products: the negated automata have none. `tck_acceptance_encoding_check.txt`
re-runs tck-liveness (couvscc, all-copy REF as in the paper) with five versions of the NEG automaton:
```
        CASAAL .gv   CASAAL plain XML   CASAAL +our export (-n0 / opt)   ours
F1         461           280                280 / 280                    280
F5         459           231                231 / 231                    228
R2      21,017         7,513              7,513 / 7,513                  7,513
R3     674,698       168,484            168,484 / 168,484              168,484
```
The "plain XML" version has location acceptance, no invariants and none of our passes. It already gives
exactly the numbers of "CASAAL through our export" and of ours. The only difference to the `.gv` run is how
tck_product.py reads CASAAL's transition-based acceptance: from_gv puts a committed intermediate location
(labels acc..., edge `tau`) after every accepting edge and event, which adds stored states; the XML path
labels the accepting locations directly. So the 3.5x (and the 1.7x) gap is explained by the encoding of
acceptance in the TChecker product, not by invariants, translation or optimizer. The conclusion, abstract and
Section 7 text attributing the gap to the verified export's invariants should be revisited; the experiment
that supports "CASAAL's automaton, read with location acceptance, costs TChecker the same as ours" is this one.
(Caveat: only F1, F5, R2, R3 re-run here; the other products were not re-checked.)

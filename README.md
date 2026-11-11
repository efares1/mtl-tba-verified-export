# Verified optimization, export and evaluation of a translation from real-time requirements to timed Büchi automata

Artifact of the article submitted to the Journal of Systems and Software by
Elie Fares, Jean-Paul Bodeveix, Hussain Al-Aqrabi and Azar Salami.
It contains the Rocq development, the extracted OCaml tool `mtl2tba`, the evaluation scripts, the
inputs and the raw results behind the tables of the article and its supplement.

The article builds on "A Mechanically Verified Translation of MTL<sub>0,∞</sub> into Timed Büchi
Automata" (<https://github.com/efares1/rocq-mtl-to-tba-translation>), whose translation theorem it
cites and does not re-prove, and on an earlier optimization article
(<https://github.com/efares1/rocq-tba-optimization-uppaal-export>).

## What is proved

Each optimization and export pass preserves the timed-word language of every TBA over the
formula-indexed clock interface; the optimizer does so for every number of rounds; the output of
export has conjunctive guards and invariants. The end-to-end theorems compose these results with the
verified translation. Spot, the reader of its output, the XML printer, UPPAAL and TChecker are outside
the proofs. `proof/Audit_Revision_20261010.v` prints the assumptions of the main theorems, and
`ROCQ_ASSUMPTIONS_AUDIT.md` records the result.

## Contents

| Path | Content |
|---|---|
| `jss_paper.tex`, `jss_supp.tex` and the files they include | article and supplement sources |
| `proof/` | Rocq development and extraction (`Extract_Optim.v` writes `tool/src/optim.ml`) |
| `tool/` | `mtl2tba` and `tba_opt`: extracted optimizer/exporter and hand-written front end |
| `evaluation/` | benchmark data, TChecker and CASAAL comparison, results and generated tables |
| `evaluation/baselines/` | ablations: invariant-free and acceptance-converted arms, same-driver timing |
| `evaluation/uppaal/` | 311 UPPAAL models, runner and results |
| `evaluation/differential/` | independent MTL evaluator and the 6,160,000-word differential test |
| `evaluation/mutation/` | 22 seeded defects in the extracted code; `rocq/` holds the Rocq-level rejection runs and logs |
| `evaluation/independent/` | optimizer and export on 600 TBAs that no MTL translator produced (`run_independent.py`; results in `results/`; `reduce.py` and `trace_can.py` minimize and trace a mismatch) |
| `scripts/`, `reproduce.sh` | build, reproduction and table scripts (`scripts/build_jss.sh` builds the article and supplement) |
| `JSS_highlights.txt` | highlights |

## Building

```
cd proof && make COQC=<path>/coqc      # checks the proofs and re-extracts tool/src/optim.ml
cd tool && dune build                  # builds mtl2tba and tba_opt
```

Recorded versions: Rocq 9.0.1, OCaml 5.4.0, Spot 2.16, UPPAAL 5.0.0, Ubuntu 26.04 under WSL 2.
The experiments also use TChecker (`tck-liveness`) and the translator CASAAL, which are not
redistributed here. The CASAAL automata that the comparison reads are stored under
`evaluation/casaal_out*` as produced by the unmodified executable.

## Limits of the artifact

The mutation study changes copies of the extracted code only. The Rocq-level mutants are
transcriptions of all 22 mutants, tested in scratch copies of the proof sources that are not
stored here; `evaluation/mutation/rocq/run_mut.py` recreates them. Some scripts contain absolute
paths of the authors' machine.

## Licence and citation

MIT licence (`LICENSE`) for the Rocq sources, the OCaml tool, the scripts, the benchmark inputs and the
results written by the authors.

Third-party software is used but not redistributed here, and keeps its own licence: Rocq, OCaml and
Spot (called by `mtl2tba`), TChecker, UPPAAL (free for academic use only) and CASAAL. The files in
`evaluation/casaal_out/` are outputs of CASAAL on our inputs, kept for reproducibility. Files from
publisher LaTeX templates (class and style files, fonts) are not covered by the MIT licence.

`CITATION.cff` carries the citation metadata; the DOI of the archived
release is added to it once Zenodo has issued it.

## Branches of this repository

| Branch | Content |
|---|---|
| `main` | shared verified foundation (proofs, tool, evaluation data, scripts), no paper |
| `jss` | this branch: `main` plus the article and supplement submitted to JSS |
| `clockreuse` | `main` plus the pruning and clock-reuse passes and their separate paper |

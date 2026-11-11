# Verified optimization and export of timed Büchi automata (shared foundation)

This branch (`main`) holds the shared verified foundation and no paper:

| Path | Content |
|---|---|
| `proof/` | Rocq development and extraction (`Extract_Optim.v` writes `tool/src/optim.ml`) |
| `tool/` | `mtl2tba` and `tba_opt`: extracted optimizer/exporter and hand-written front end |
| `evaluation/` | benchmark data, TChecker and CASAAL comparison, results and generated tables |
| `scripts/`, `reproduce.sh` | build, reproduction and table scripts |
| `ROCQ_ASSUMPTIONS_AUDIT.md` | assumptions of the main theorems |

Papers live on their own branches, each built on this foundation:

| Branch | Content |
|---|---|
| `jss` | article and supplement submitted to the Journal of Systems and Software |
| `clockreuse` | verified dominated-transition pruning and clock reuse, with its paper (`clockreuse/`) |

Fixes to the proofs, the tool or the shared data are made here and merged into the paper branches.
`reproduce.sh` checks the artifact (builds the proofs, audits assumptions, rebuilds the tool).

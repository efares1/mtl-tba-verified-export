# Case study: pacemaker and gateway (UPPAAL 5.0.0)

`python run_pacemaker.py` (pacemaker, 105 runs) and `python run_pacemaker.py gateway` (gateway, 45 runs).
Needs WSL with `tool/_build/default/src/mtl2tba.exe` and UPPAAL's `verifyta` (path set at the top of the script).

For each requirement the automaton of its negation is produced by `mtl2tba` in four variants (default,
`-n 0`, `-all-copy`, `-alloc`), composed with a correct system and faulty variants, and `verifyta` decides
whether an accepting sink of the property automaton is reachable. Every system is also checked for
timelocks (`A[] not deadlock`) with a receiver of every channel. Results: `pacemaker_results.tsv`,
`gateway_results.tsv` (columns: verdict, expected verdict, agreement, states explored, automaton sizes).
All 150 runs agree with the verdict fixed by the construction of the systems. `models/` holds the generated XML.

## Requirement under assumptions (TChecker)

UPPAAL cannot decide requirements whose negation contains a conjunction of bounded responses (assumptions),
because that needs a Büchi emptiness check. `gen_casaal_ag.py` (Windows) makes CASAAL's automata (`casaal/agK.gv`) and
`ag_tck.py` (WSL) composes our automata (`-n 0`, default optimizer, checked pruning and clock reuse, all with the
all-copy export) and CASAAL's with a correct and a faulty gateway and decides emptiness with `tck-liveness -a couvscc`.
Results: `ag_tck_results.tsv`. Requirement: (a1 -> <>[<=5] b1) & ... & (ak -> <>[<=5] bk) -> [](a1 -> <>[<=5] done).

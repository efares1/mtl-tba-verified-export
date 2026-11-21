# Case study: pacemaker and gateway (UPPAAL 5.0.0)

`python run_pacemaker.py` (pacemaker, 105 runs) and `python run_pacemaker.py gateway` (gateway, 45 runs).
Needs WSL with `tool/_build/default/src/mtl2tba.exe` and UPPAAL's `verifyta` (path set at the top of the script).

For each requirement the automaton of its negation is produced by `mtl2tba` in four variants (default,
`-n 0`, `-all-copy`, `-alloc`), composed with a correct system and faulty variants, and `verifyta` decides
whether an accepting sink of the property automaton is reachable. Every system is also checked for
timelocks (`A[] not deadlock`) with a receiver of every channel. Results: `pacemaker_results.tsv`,
`gateway_results.tsv` (columns: verdict, expected verdict, agreement, states explored, automaton sizes).
All 150 runs agree with the verdict fixed by the construction of the systems. `models/` holds the generated XML.

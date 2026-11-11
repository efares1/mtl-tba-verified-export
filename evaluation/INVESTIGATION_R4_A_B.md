# Investigation of the R4 result, clock reuse (A) and location merging (B)

All runs: WSL 2, TChecker `tck-liveness -a couvscc`, mtl2tba default with `-all-copy`, limit as stated. Counts of stored
states are exact; times are single runs on a shared machine (other jobs were running), so time differences below 20% are
indicative only.

## 1. Why ours stores 48 states and CASAAL's automaton 34,107 (positive R4)

Files: `baselines/baselines_posbad_allcopy.tsv` (original workload), `baselines/baselines_posbadall_allcopy.tsv` (new
workload), `struct_probe.py` (structure), `make_resp_system.py` (mode `badall`), `baselines/run_baselines.py` (workload `posbadall`).

Finding 1: the original workload exercises one response only. The violating system (`bad`) emits `a1` and then only
`other`, so ours stores 48 states for every n, and the constant says nothing about n.

Finding 2: with a violating system that exercises all n responses (the requests `a2..an` are answered in time, then `a1` is
never answered; workload `posbadall`), the difference persists and grows:

| n | ours | ours, optimizer off | CASAAL | CASAAL through our export | ratio |
|---|---:|---:|---:|---:|---:|
| 1 | 48 | 48 | 52 | 48 | 1.1 |
| 2 | 70 | 70 | 986 | 890 | 14 |
| 3 | 92 | 92 | 50,974 | 47,008 | 554 |
| 4 | 114 | 114 | 2,000,526 | 1,736,096 | 17,548 |
| 5 | 136 | not generated | timeout (180 s) | not run | - |

Ours grows by 22 states per response. CASAAL's grows by a factor of about 50 per response.

Finding 3: the optimizer and the export are not the cause. `-n 0` gives the same counts as the default; passing CASAAL's
automaton through our export changes its count by at most 14% (R2: 986 to 890; R4: 2.00M to 1.74M).

Finding 4: the automata have the same number of locations and clocks (R4: 16 locations, 4 clocks each) but differ in the
explicit edges the model checker sees (`struct_probe.py`):

| | R2 | R3 | R4 | R5 |
|---|---:|---:|---:|---:|
| edges, ours / CASAAL | 24 / 51 | 68 / 216 | 176 / 837 | 432 / 3,078 |
| distinct (source, target, guard, resets), ours / CASAAL | 12 / 15 | 32 / 54 | 80 / 189 | 192 / 648 |
| edges per (location, event), ours | 1.2 | 1.2 | 1.2 | 1.2 |
| edges per (location, event), CASAAL | 2.6 | 3.9 | 5.8 | 8.7 |

Ours is close to deterministic (about 1.2 edges per location and event); CASAAL's automaton has overlapping guarded edges.
That is consistent with zone fragmentation in the product, but the fragmentation itself was not measured: the causal
statement is a hypothesis.

Finding 5: the effect is specific to the workload. On the natural workload (negated requirement against a system that
satisfies it, `baselines_resp_ok_allcopy.tsv`) the ratio is 1.15 to 1.8, and CASAAL through our export equals ours exactly
(41, 79, 117). On the negated requirement against its own automaton the totals are equal (204,564 against 204,819).

Not shown: generality beyond the bounded-response family; any benefit of the optimizer (none: the counts are equal with it
off); a causal explanation by guard overlap.

## 2. Clock reuse by liveness (A)

Files: `clock_liveness.py`, `clock_liveness_lib.py`, `clock_liveness.tsv` (survey); `alloc_probe.py`, `alloc_probe.tsv`
(prototype). The prototype renames clocks outside Rocq and is unverified.

Survey of clocks that a liveness-based allocation could save beyond the verified optimizer (upper bound by greedy colouring
of the interference graph, exported all-copy automaton):

| set | polarity | automata | clocks | after allocation | automata reduced |
|---|---|---:|---:|---:|---:|
| benchmark | positive | 27 | 59 | 58 | 1 (F10) |
| benchmark | negated (N6 timed out) | 26 | 55 | 37 | 8 (F11, F12, F13, R2-R6) |
| random | positive | 100 | 131 | 117 | 14 |
| random | negated | 100 | 125 | 109 | 16 |

On the negated bounded responses R2-R6, n clocks reduce to 1: each branch of the negation uses its own clock.

Prototype on TChecker (negated automaton against: the requirement's own automaton `ref`, and the response systems):

| id | workload | clocks | stored before / after | seconds before / after | verdicts |
|---|---|---|---|---|---|
| R2 | ref | 2 to 1 | 7,513 / 7,513 | 0.22 / 0.18 | equal |
| R3 | ref | 3 to 1 | 168,484 / 168,484 | 12.4 / 10.3 | equal |
| R2-R5 | resp_ok | n to 1 | 79, 117, 155, 193 / same | all under 3 ms (differences are noise) | equal |
| R2-R5 | resp_bad | n to 1 | 7 / 7 | equal order | equal |
| F11, F12, F13 | ref | 2 to 1 | 67, 1,688, 87 / same | within noise | equal |
| R4, R5 | ref | 4, 5 to 1 | timeout both | - | - |

Result: fewer clocks, identical stored states and verdicts on every completed run, time about 17% lower on the one large
product (R3, single run). The clock reduction is real on the negated bounded-response family and on 16% of random
negations; the model-checking gain is small and not demonstrated beyond R3.

## 3. Location merging by bisimulation (B, syntactic form)

Files: `bisim_probe.py`, `bisim_probe.tsv`. The probe computes the coarsest syntactic bisimulation of the exported negated
automaton (equal accepting mark, invariant, and outgoing (event, guard, resets, class of target)). It is sound for the
timed language but is not complete for timed bisimulation, so it is a lower bound on what a semantic pass could merge.

Result: no location of any of the benchmark automata that completed is merged (F1-F13, R1-R4, N1-N4; see the table in
`bisim_probe.tsv`); it only drops a duplicate edge on F2 (7 to 6) and F12 (17 to 16). Stored states are unchanged. The
verified optimizer is already at the syntactic bisimulation fixed point on these inputs. A semantic (zone-based) merge was
not attempted; these data give no sign that one is needed for the benchmarks.

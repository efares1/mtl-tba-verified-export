# Investigation of the R4 result and of location merging

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

## 2. Location merging by bisimulation (B, syntactic form)

Files: `bisim_probe.py`, `bisim_probe.tsv`. The probe computes the coarsest syntactic bisimulation of the exported negated
automaton (equal accepting mark, invariant, and outgoing (event, guard, resets, class of target)). It is sound for the
timed language but is not complete for timed bisimulation, so it is a lower bound on what a semantic pass could merge.

Result: no location of any of the benchmark automata that completed is merged (F1-F13, R1-R4, N1-N4; see the table in
`bisim_probe.tsv`); it only drops a duplicate edge on F2 (7 to 6) and F12 (17 to 16). Stored states are unchanged. The
verified optimizer is already at the syntactic bisimulation fixed point on these inputs. A semantic (zone-based) merge was
not attempted; these data give no sign that one is needed for the benchmarks.

## 3. Zone-graph structure of the R4 stress workload

Files: `zone_probe.py` (graph certificate of `tck-liveness -C graph`, `tck-reach`), `zone_probe.tsv`, `zone_cov.tsv`,
`make_zone_table.py`, `zone_table.tex`. All counts are TChecker's own (stored states reproduce 70, 890, 92, 47,008).

| | R1 | R2 | R3 |
|---|---:|---:|---:|
| ours: states / location vectors / max zones per vector | 48 / 4 / 17 | 70 / 10 / 17 | 92 / 16 / 17 |
| CASAAL: states / location vectors / max zones per vector | 48 / 4 / 17 | 890 / 25 / 240 | 47,008 / 85 / 7,444 |
| reachability with inclusion subsumption (covreach), ours / CASAAL | 4 / 4 | 10 / 28 | 16 / 103 (R4: 22 / 304) |

Findings:
1. The extra states are zones of the same location vectors (max zones per vector stays 17 for ours; grows for CASAAL),
   plus 2.5 to 5 times more reachable location vectors.
2. Not dead clocks: adding a reset of every clock that is dead at the target to every edge leaves the counts unchanged
   (R2 890, R3 47,008; for ours too).
3. Not clock differences: dropping every constraint between two clocks from the zones removes 1% (R2) and 14% (R3) of
   the distinct zones.
4. Most of the blow-up is covered zones: with inclusion subsumption the gap is 2.8x (R2), 6.4x (R3), 14x (R4), against
   13x, 511x and 15,229x with the Couvreur-based algorithm. The headline ratio is a property of that algorithm.
5. Isolated (section 4): removing the dominated nondeterministic edges gives exactly our counts.
6. Mean out-degree of the zone graph is similar (1.46 against 1.56 on R2), so it is not a larger branching of the graph.

## 4. Pruning CASAAL's dominated edges (isolating experiment)

Files: `prune_casaal.py`, `prune_results.txt`, `prune_R2.xml`..`prune_R4.xml`.
CASAAL's positive automaton (location acceptance, our export, `-n 0 -all-copy`) has only upper-bound guards and invariants.
A syntactic simulation (clock liveness; q1 covers q2 if invariants/guards are weaker and every edge of q2 is matched by an
edge of q1 whose target covers and which does not leave a live clock unreset that the matched edge resets) identifies
dominated edges; they are removed one at a time, recomputing the relation. The argument is ours, not mechanized.

| | edges | (loc,event) pairs with 2+ edges | Couvreur stored | covreach stored |
|---|---:|---:|---:|---:|
| R2 CASAAL / pruned / ours | 51 / 20 / 20 | 15 / 0 | 890 / 70 / 70 | 28 / 10 / 10 |
| R3 CASAAL / pruned / ours | 216 / 56 / 56 | 49 / 0 | 47,008 / 92 / 92 | 103 / 16 / 16 |
| R4 CASAAL / pruned / ours | 837 / 144 / 144 | 135 / 0 | (1.7M) / 114 / 114 | 304 / 22 / 22 |

R5 CASAAL / pruned / ours: 3,078 / 352 / 352 edges, 341 / 0 pairs, pruned Couvreur 136 (ours 136), covreach 28 (ours 28);
the original R5 does not finish. Language check on 2,000 words (424 accepted): no disagreement.

Language check (not a proof): pruned vs original vs the MTL judge of `differential/` on random lasso words, all
locations accepting: R2 2,000 words (660 accepted), R3 5,000 (1,306), R4 3,000 (687; pruned vs judge only): no disagreement.
Example redundant edge (R2, `a1` at the initial location): one edge to the location that tracks response 1 (reset x0), one to
the location that also guesses response 2 pending (reset x0, x1); the second only adds restrictions.
Conclusion: the extra states come from redundant nondeterministic edges; a deterministic automaton of the same size gives
our counts under both algorithms.


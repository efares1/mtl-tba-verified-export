#!/usr/bin/env python3
"""Summarize the measured extracted-optimizer ablation TSV as LaTeX."""

from __future__ import annotations

import csv
import os
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN_ENV = os.environ.get("SYNTH_RUN_DIR")
RUN = Path(RUN_ENV).resolve() if RUN_ENV else ROOT / "evaluation"
DATA = RUN / ("leave_one_out.tsv" if RUN_ENV else "synthetic_tba_ablation.tsv")
OUTPUT = ROOT / "evaluation" / "synthetic_tba_ablation_table.tex"

LABELS = {
    "none": "Full optimizer",
    "synthesis_backward": "Omit bound synthesis/backward propagation",
    "forward": "Omit forward propagation",
    "contradictory": "Omit contradictory-edge removal",
    "unsatisfiable_label": "Omit unsatisfiable-label removal",
    "source_without_incoming": "Omit no-incoming-source pruning",
    "normalization": "Omit guard normalization",
    "dead_resets": "Omit dead-reset removal",
    "synchronous_clocks": "Omit synchronous-clock merging",
    "transition_subsumption": "Omit transition merging",
    "equivalent_locations": "Omit equivalent-location merging",
}


def main() -> None:
    with DATA.open(newline="", encoding="utf-8") as source:
        rows = list(csv.DictReader(source, delimiter="\t"))
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        groups[row["variant"]].append(row)
    baseline = {row["model"]: int(row["out_transitions"])
                for row in groups["none"]}

    output = [
        r"\begin{table*}[t]",
        r"\centering",
        r"\caption{Iterated leave-one-operation-out ablations on sixteen fixed synthetic TBA records. Reachable-location, transition, and active-clock counts are summed across the same inputs; rounds and runtime are medians across inputs. Runtime is the median of each model's mean over 200 in-memory runs. Each variant repeats its retained composite to structural stability. The full variant is checked against the extracted optimizer; the modified ablation driver is not a separate Rocq theorem.}",
        r"\label{tab:synthetic-ablation}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\begin{tabular}{@{}p{0.32\textwidth}rrrrrr@{}}",
        r"\toprule",
        r"Variant & $\sum L_{\rm reach}$ & $\sum E$ & $\sum C$ & med. rounds & med. time (ms) & cases with $E$ above full\\",
        r"\midrule",
    ]
    order = ["none", "synthesis_backward", "forward", "contradictory",
             "unsatisfiable_label", "source_without_incoming", "normalization",
             "dead_resets", "synchronous_clocks", "transition_subsumption",
             "equivalent_locations"]
    for variant in order:
        sample = groups[variant]
        edges = [int(r["out_transitions"]) for r in sample]
        clocks = [int(r["out_clocks"]) for r in sample]
        reachable = [int(r["out_reachable"]) for r in sample]
        rounds = [int(r["changed_rounds"]) for r in sample]
        times_ms = [1000 * float(r["mean_seconds_200"]) for r in sample]
        above = sum(int(r["out_transitions"]) > baseline[r["model"]]
                    for r in sample)
        label = LABELS[variant].replace("&", r"\&")
        output.append(
            f"{label} & {sum(reachable)} & {sum(edges)} & {sum(clocks)} & "
            f"{statistics.median(rounds):g} & {statistics.median(times_ms):.3f} & {above} "
            + r"\\"
        )
    output += [r"\bottomrule", r"\end{tabular}", r"\end{table*}"]
    OUTPUT.write_text("\n".join(output) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

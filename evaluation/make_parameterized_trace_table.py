#!/usr/bin/env python3
"""Generate the main-paper two-round synchronous-reset trace table."""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "evaluation" / "synthetic_tba_parameterized.tsv"
OUT = ROOT / "evaluation" / "synthetic_tba_round_trace_table.tex"
MODEL = "synchronous_clocks_6"
SELECT = (
    ("input", "Input"),
    ("unsatisfiable_label", "R1: unsatisfiable-label removal"),
    ("dead_resets", "R1: dead-reset elimination"),
    ("synchronous_clocks", "R1: synchronous-clock pass"),
    ("dead_resets", "R2: dead-reset elimination"),
    ("round_end", "Optimized fixed point"),
    ("explicit_export_avg_200", "Explicit export"),
)


def main() -> None:
    with DATA.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    chosen = []
    for stage, label in SELECT:
        round_number = {
            "input": "0",
            "unsatisfiable_label": "1",
            "dead_resets": "1" if label.startswith("R1") else "2",
            "synchronous_clocks": "1",
            "round_end": "2",
            "explicit_export_avg_200": "0",
        }[stage]
        row = next(
            row for row in rows
            if row["model"] == MODEL
            and row["round"] == round_number
            and row["stage"] == stage
        )
        chosen.append((label, row))

    lines = [
        r"\begin{table*}[t]",
        r"\centering",
        r"\caption{Measured trace for the six-clock synchronous-reset synthetic input. Counts are declared / reachable locations, transitions, active clocks, reset occurrences, guard atoms, invariant locations / atoms, and diagonal guard atoms. The export row is the internal explicit DTA.}",
        r"\label{tab:synchronous-trace}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\begin{tabular}{@{}p{0.27\textwidth}rrrrrrr@{}}",
        r"\toprule",
        r"Stage & $L/R$ & $E$ & $C$ & Resets & Guard atoms & Inv. $L/A$ & Diag.\\",
        r"\midrule",
    ]
    for label, row in chosen:
        loc = f"{row['locations']}/{row['reachable']}"
        inv = f"{row['invariant_locations']}/{row['invariant_atoms']}"
        lines.append(
            f"{label} & {loc} & {row['transitions']} & {row['clocks']} & "
            f"{row['resets']} & {row['guard_atoms']} & {inv} & "
            f"{row['difference_atoms']} " + r"\\"
        )
    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table*}"]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

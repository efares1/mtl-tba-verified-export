#!/usr/bin/env python3
"""Summarize every instance in the synthetic TBA parameter sweeps."""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "evaluation" / "synthetic_tba_parameterized.tsv"
OUT = ROOT / "evaluation" / "synthetic_tba_parameterized_table.tex"
FAMILIES = (
    ("duplicate_", "Duplicate edges"),
    ("unreachable_cascade_", "Unreachable cascade"),
    ("redundant_bounds_", "Redundant bounds"),
    ("synchronous_clocks_", "Synchronous resets"),
    ("invariant_disjunction_", "Disjunctive invariant"),
)
STAGES = ("input", "unprofiled_optimize_avg_200", "explicit_export_avg_200")


def size(row: dict[str, str]) -> str:
    return "/".join(
        row[key] for key in ("locations", "reachable", "transitions", "clocks")
    )


def main() -> None:
    with DATA.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    grouped: dict[str, dict[str, dict[str, str]]] = {}
    for row in rows:
        grouped.setdefault(row["model"], {})[row["stage"]] = row

    lines = [
        r"\begin{table*}[t]",
        r"\centering",
        r"\caption{Complete parameter sweeps for five translator-independent synthetic TBA families. Tuples report declared locations / graph-reachable locations / transitions / active clocks. The optimizer count is the number of structurally changed rounds; optimization time is the mean over 200 in-memory calls. Rows marked $^*$ reached the 50-round driver cap without a stability check; their exported counts are from that capped result. Export diagonals are explicit clock-difference guard occurrences.}",
        r"\label{tab:parameterized-synthetic}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{2.5pt}",
        r"\begin{tabular}{@{}p{0.19\textwidth}r p{0.16\textwidth}p{0.16\textwidth}r p{0.16\textwidth}rr@{}}",
        r"\toprule",
        r"Family & $k$ & Input $L/R/E/C$ & Opt. $L/R/E/C$ & Rnds. & Export $L/R/E/C$ & Opt. (ms) & Diag.\\",
        r"\midrule",
    ]
    for prefix, label in FAMILIES:
        names = sorted(
            (name for name in grouped if name.startswith(prefix)),
            key=lambda name: int(name.removeprefix(prefix)),
        )
        for name in names:
            data = grouped[name]
            inp, opt, exp = (data[stage] for stage in STAGES)
            k = int(name.removeprefix(prefix))
            rounds = opt["round"] + (r"$^*$" if "round_cap" in data else "")
            lines.append(
                f"{label} & {k} & {size(inp)} & {size(opt)} & {rounds} & "
                f"{size(exp)} & {1000 * float(opt['seconds']):.3f} & "
                f"{exp['difference_atoms']} " + r"\\"
            )
    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table*}"]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

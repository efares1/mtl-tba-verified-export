#!/usr/bin/env python3
"""Generate family aggregates from the recorded post-processing medians."""

from __future__ import annotations

import csv
import os
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN = Path(os.environ.get("EVAL_RUN_DIR", ROOT / "evaluation")).resolve()
DATA = RUN / "ours_results.tsv"
OUTPUT = ROOT / "evaluation" / "optimizer_aggregate_table.tex"


def main() -> None:
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)
    with DATA.open(newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source, delimiter="\t"):
            if row["status"] == "ok":
                groups[row["id"][0]].append(row)

    labels = {"F": "F group", "R": "bounded-response R group", "N": "N group"}
    lines = [
        r"\begin{table*}[t]",
        r"\centering",
        r"\caption{Family aggregates derived from the completed rows of Table~\ref{tab:optimizer-benchmarks}. Edge totals are measured at the post-reset-completion optimizer boundary, after optimization, and after explicit export.}",
        r"\label{tab:optimizer-aggregates}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\begin{tabular}{@{}p{0.22\textwidth}rrrrrr@{}}",
        r"\toprule",
        r"Group & $n$ & Input $\sum E$ & Opt. $\sum E$ & Reduction & Exp. $\sum E$ & Cases $\downarrow/= /\uparrow$\\",
        r"\midrule",
    ]
    for group in ("F", "R", "N"):
        rows = groups[group]
        edge_in = sum(int(r["comp_trans"]) for r in rows)
        edge_opt = sum(int(r["opt_trans"]) for r in rows)
        edge_exp = sum(int(r["exp_trans"]) for r in rows)
        reduced = sum(int(r["opt_trans"]) < int(r["comp_trans"]) for r in rows)
        same = sum(int(r["opt_trans"]) == int(r["comp_trans"]) for r in rows)
        increased = sum(int(r["opt_trans"]) > int(r["comp_trans"]) for r in rows)
        pct = 100 * (edge_in - edge_opt) / edge_in if edge_in else 0.0
        lines.append(
            f"{labels[group]} & {len(rows)} & {edge_in:,} & {edge_opt:,} & "
            f"{pct:.2f}\\% & {edge_exp:,} & {reduced}/{same}/{increased} "
            + r"\\"
        )
    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table*}"]
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

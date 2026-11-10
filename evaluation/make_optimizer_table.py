#!/usr/bin/env python3
"""Generate the optimizer/export table from the five-run upstream medians."""

from __future__ import annotations

import csv
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN = Path(os.environ.get("EVAL_RUN_DIR", ROOT / "evaluation")).resolve()
DATA = RUN / "ours_results.tsv"
OUTPUT = ROOT / "evaluation" / "optimizer_table.tex"


def fmt_time(value):
    seconds = float(value)
    return "$<0.01$" if seconds < 0.005 else f"{seconds:.2f}"


def main():
    with DATA.open(newline="", encoding="utf-8") as source:
        rows = list(csv.DictReader(source, delimiter="\t"))
    lines = [
        r"\begin{table*}[t]",
        r"\centering",
        r"\caption{Fresh five-run post-processing measurements (13--14 October 2026) for 31 attempted upstream-generated configurations; 29 produced optimizer inputs. Comp. is the automaton after reset completion. $L$ counts graph-reachable locations, $E$ counts transitions from those locations, and $C$ counts active clocks used in guards or resets; $n_f$ is the formula-clock-key count. Opt. and Exp. give reachable $L/E/C$, changed optimization rounds, stage medians, invariant-bearing locations, and diagonal-guard occurrences. R7 and R8 time out upstream, before the optimizer boundary.}",
        r"\label{tab:optimizer-benchmarks}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\begin{tabular}{@{}lccccccccc@{}}",
        r"\toprule",
        r"ID & Comp. $L/E/C$ & $n_f$ & Opt. $L/E/C$ & Rnds & Opt. (s) & Exp. $L/E/C$ & Inv. & Diag. & Exp. (s)\\",
        r"\midrule",
    ]
    for row in rows:
        if row["status"] != "ok":
            lines.append(f"{row['id']} & -- & -- & -- & -- & -- & -- & -- & -- & --" + r"\\")
            continue
        cells = [
            row["id"],
            f"{row['comp_locs']}/{row['comp_trans']}/{row['comp_clocks']}",
            row["formula_clocks"],
            f"{row['opt_locs']}/{row['opt_trans']}/{row['opt_clocks']}",
            row["opt_rounds"],
            fmt_time(row["opt_s_med"]),
            f"{row['exp_locs']}/{row['exp_trans']}/{row['exp_clocks']}",
            row["exp_invs"],
            row["exp_diffs"],
            fmt_time(row["exp_s_med"]),
        ]
        lines.append(" & ".join(cells) + r"\\")
    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table*}"]
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate the compact article table from the pass-by-pass benchmark TSV."""

from __future__ import annotations

import csv
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN_ENV = os.environ.get("SYNTH_RUN_DIR")
RUN = Path(RUN_ENV).resolve() if RUN_ENV else ROOT / "evaluation"
DATA = RUN / ("pass_trace.tsv" if RUN_ENV else "synthetic_tba_passes.tsv")
MEMORY = RUN / ("memory.tsv" if RUN_ENV else "synthetic_tba_memory.tsv")
OUTPUT = ROOT / "evaluation" / "synthetic_tba_table.tex"


def read_rows():
    with DATA.open(newline="", encoding="utf-8") as source:
        return list(csv.DictReader(source, delimiter="\t"))


def counts(row, include_differences=False):
    fields = ["locations", "transitions", "clocks", "resets", "guard_atoms"]
    if include_differences:
        fields.append("difference_atoms")
    return "/".join(row[field] for field in fields)


def main():
    rows = read_rows()
    with MEMORY.open(newline="", encoding="utf-8") as source:
        memory = {row["model"]: row["peak_rss_kib"]
                  for row in csv.DictReader(source, delimiter="\t")}
    names = list(dict.fromkeys(row["model"] for row in rows))
    lines = [
        r"\begin{table*}[t]",
        r"\centering",
        r"\caption{Sixteen translator-independent synthetic TBA records. Count tuples are declared locations / transitions / distinct clocks / reset occurrences / unary guard atoms; the export tuple adds diagonal guard atoms. The $I$ field gives nonempty invariant locations:bound atoms. Optimization and export times are per-call means over 200 repeated in-memory runs; RSS is the peak for a separate single-model process. Full per-pass and reachability data are supplied in the artifact.}",
        r"\label{tab:synthetic-tba}",
        r"\scriptsize",
        r"\begin{tabular}{@{}lrrrrrrr@{}}",
        r"\toprule",
        r"Model & Input & Optimized & Rounds & Opt. (ms) & RSS (KiB) & Export & Exp. (ms)\\",
        r"\midrule",
    ]
    for name in names:
        group = [row for row in rows if row["model"] == name]
        input_row = next(row for row in group if row["stage"] == "input")
        optimized = next(row for row in group if row["stage"].startswith("unprofiled_optimize_avg_"))
        exported = next(row for row in group if row["stage"].startswith("explicit_export_avg_"))
        opt_ms = 1000 * float(optimized["seconds"])
        exp_ms = 1000 * float(exported["seconds"])
        exp_counts = counts(exported, include_differences=True)
        inv = f"{optimized['invariant_locations']}:{optimized['invariant_atoms']}"
        safe_name = name.replace("_", r"\_")
        lines.append(
            f"{safe_name} & {counts(input_row)} & "
            f"{counts(optimized)}; $I={inv}$ & {optimized['round']} & "
            f"{opt_ms:.3f} & {memory[name]} & {exp_counts}; $I={exported['invariant_locations']}:{exported['invariant_atoms']}$ & {exp_ms:.3f}"
            + r"\\"
        )
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\end{table*}",
    ]
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUN=${RUN:-"$HERE/runs/2026-10-10-tchecker-before-after"}
EXE=${EXE:-"$ROOT/tool/_build/default/src/mtl2tba.exe"}
TCK=${TCK:-"$HOME/local/bin/tck-liveness"}
LIMIT=${LIMIT:-180}
mkdir -p "$RUN"
RUN="$(cd "$RUN" && pwd)"
if [[ ! -x "$EXE" || ! -x "$TCK" ]]; then
  echo "missing executable: EXE=$EXE TCK=$TCK" >&2; exit 2
fi
{
  date -u +'%Y-%m-%dT%H:%M:%SZ'
  printf 'user: '; id -un
  printf 'kernel: '; uname -r
  "$EXE" --help 2>&1 | head -1 || true
  "$TCK" --help 2>&1 | head -2 || true
  ocaml -version
  printf 'TChecker: '; "$TCK" --version 2>&1 | head -1 || true
  printf 'limit_seconds: %s\n' "$LIMIT"
} > "$RUN/provenance.txt" 2>&1
git -C "$ROOT" rev-parse HEAD > "$RUN/source_commit.txt"
"$EXE" -stats-header > "$RUN/tool_stats_header.tsv"
printf 'system\toptimization\tinit_free\tverdict\tchecker_seconds\twall_seconds\tpeak_rss_kib\tstored_states\tvisited_states\tvisited_transitions\tcertificate_bytes\tstatus\n' \
  > "$RUN/results.tsv"
FORMULA='<>(p & ^[][<=5] !q)'
for system in resp_ok resp_bad; do
  python3 "$HERE/tck_normalize_system.py" \
    "$HERE/case_study/models/${system}_alone.xml" \
    "$RUN/${system}_system.xml"
  for optimization in before after; do
    if [[ "$optimization" == before ]]; then rounds=0; else rounds=50; fi
    base="$RUN/${system}_${optimization}"
    (cd "$RUN" && /usr/bin/time -f '%M' -o "$base.tool.rss" \
      "$EXE" -n "$rounds" -stats -nopdf -o "${system}_${optimization}" \
      "$FORMULA" > "$base.tool.stdout" 2> "$base.tool.stderr")
    python3 - "$RUN/tool_stats_header.tsv" "$base.tool.stdout" "$base.tool.stats.tsv" <<'PY'
import pathlib, sys
header = pathlib.Path(sys.argv[1]).read_text().strip()
row = pathlib.Path(sys.argv[2]).read_text().strip()
pathlib.Path(sys.argv[3]).write_text(header + "\n" + row + "\n")
PY
    labels=$(python3 "$HERE/tck_product.py" "$base.product.tck" p,q \
      "P:$base.xml" "SYS:$RUN/${system}_system.xml")
    set +e
    /usr/bin/time -f '%e\t%M' -o "$base.tck.time_mem.tsv" \
      timeout "$LIMIT" "$TCK" -a couvscc -l "$labels" -C graph \
        -o "$base.graph.txt" "$base.product.tck" \
        > "$base.tck.stdout" 2> "$base.tck.stderr"
    status=$?
    set -e
    verdict=$(grep -E '^CYCLE (true|false)$' "$base.tck.stdout" | tail -1 | awk '{print $2}' || true)
    [[ -n "$verdict" ]] || verdict=none
    if [[ -f "$base.graph.txt" ]]; then cert_bytes=$(wc -c < "$base.graph.txt"); else cert_bytes=0; fi
    if [[ -f "$base.tck.time_mem.tsv" ]]; then read -r wall_seconds rss < "$base.tck.time_mem.tsv"; else wall_seconds=NA; rss=NA; fi
    read -r checker_seconds stored_states visited_states visited_transitions < <(python3 - "$base.tck.stdout" <<'PY'
import sys
values = {}
for line in open(sys.argv[1]):
    fields = line.split()
    if len(fields) == 2:
        values[fields[0]] = fields[1]
print(values.get("RUNNING_TIME_SECONDS", "NA"),
      values.get("STORED_STATES", "NA"),
      values.get("VISITED_STATES", "NA"),
      values.get("VISITED_TRANSITIONS", "NA"))
PY
)
    init_free=$(python3 - "$RUN/tool_stats_header.tsv" "$base.tool.stdout" <<'PY'
import sys
h=open(sys.argv[1]).read().strip().split("\t")
r=open(sys.argv[2]).read().strip().split("\t")
print(r[h.index("init_free")])
PY
)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$system" "$optimization" "$init_free" "$verdict" "$checker_seconds" \
      "$wall_seconds" "$rss" "$stored_states" "$visited_states" \
      "$visited_transitions" "$cert_bytes" "$status" >> "$RUN/results.tsv"
  done
  cmp "$RUN/${system}_before.product.tck" "$RUN/${system}_after.product.tck" \
    > "$RUN/${system}_product_cmp.txt" || true
done
rm -f "$RUN/tool_stats_header.tsv"
date -u +'%Y-%m-%dT%H:%M:%SZ' > "$RUN/completed_utc.txt"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$ROOT/evaluation"
RUN=${RUN:-"$HERE/runs/2026-10-13-generated-split"}
EXE="$ROOT/tool/_build/default/src/mtl2tba.exe"
LIMIT=${LIMIT:-300}
mkdir -p "$RUN"
printf 'date_utc: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$RUN/provenance.txt"
printf 'user: %s\n' "$(id -un)" >> "$RUN/provenance.txt"
printf 'kernel: %s\n' "$(uname -r)" >> "$RUN/provenance.txt"
ocaml -version >> "$RUN/provenance.txt" 2>&1
"$EXE" -stats-header > "$RUN/header.tsv"
printf 'id\tvariant\tmem_kb\t' > "$RUN/results.tsv"
cat "$RUN/header.tsv" >> "$RUN/results.tsv"
for id in R2 R3 R4 R5 R6; do
  formula=$(awk -F '\t' -v wanted="$id" '$1 == wanted {print $3; exit}' "$HERE/formulas.tsv")
  if [[ -z "$formula" ]]; then echo "missing formula $id" >&2; exit 1; fi
  for variant in maximal_delay all_copy; do
    flags=()
    [[ "$variant" == all_copy ]] && flags=(-all-copy)
    mem="$RUN/${id}_${variant}.mem"
    output=$(cd "$RUN" && /usr/bin/time -f '%M' -o "$mem" \
      timeout "$LIMIT" "$EXE" -stats -nopdf -tba "${flags[@]}" \
      -o "${id}_${variant}" "$formula")
    printf '%s\t%s\t%s\t%s\n' "$id" "$variant" "$(cat "$mem")" "$output" \
      >> "$RUN/results.tsv"
  done
  cmp "$RUN/${id}_maximal_delay_opt.dot" "$RUN/${id}_all_copy_opt.dot" \
    && printf '%s\tidentical_optimizer_input_dot\n' "$id" \
      >> "$RUN/input_comparison.tsv"
done
rm -f "$RUN"/*.mem "$RUN/header.tsv"

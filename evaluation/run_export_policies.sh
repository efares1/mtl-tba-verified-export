#!/bin/bash
# Both export policies side by side on every configuration of formulas.tsv:
# maximal-delay (default) and -all-copy. Writes export_policies.tsv. LIMIT seconds per run.
EXE=${EXE:-$HOME/chain_build/_build/default/src/mtl2tba.exe}
LIMIT=${LIMIT:-300}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUTFILE:-$HERE/export_policies.tsv}"
printf 'id\topt_locs\topt_trans\tmd_status\tmd_locs\tmd_trans\tmd_invs\tmd_diffs\tmd_exp_s\tac_status\tac_locs\tac_trans\tac_invs\tac_diffs\tac_exp_s\n' > "$OUT"
grep -v '^#' "$HERE/formulas.tsv" | while IFS=$'\t' read -r id desc ours cas; do
  [ -z "$id" ] && continue
  row="$id"; first=1
  for mode in "" "-all-copy"; do
    d=$(mktemp -d); cd "$d"
    s=$(timeout "$LIMIT" "$EXE" $mode -nopdf -stats -o a "$ours" 2>/dev/null | tail -1)
    cd /; rm -rf "$d"
    if [ -n "$s" ]; then
      if [ $first = 1 ]; then row="$row$(echo "$s" | awk -F'\t' '{printf "\t%s\t%s", $9,$10}')"; fi
      row="$row$(echo "$s" | awk -F'\t' '{printf "\tok\t%s\t%s\t%s\t%s\t%s", $12,$13,$15,$16,$18}')"
    else
      if [ $first = 1 ]; then row="$row\t\t"; fi
      row="$row\ttimeout/error\t\t\t\t\t"
    fi
    first=0
  done
  printf '%b\n' "$row" >> "$OUT"
done

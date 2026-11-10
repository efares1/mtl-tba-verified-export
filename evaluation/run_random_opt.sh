#!/bin/bash
# The 100 random formulas of random_formulas.tsv through the default pipeline (optimizer on).
# Writes random_opt.tsv: id, status, then selected -stats columns. LIMIT seconds per formula.
EXE=${EXE:-$HOME/chain_build/_build/default/src/mtl2tba.exe}
LIMIT=${LIMIT:-120}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUTFILE:-$HERE/random_opt.tsv}"
printf 'id\tstatus\tspot_states\tspot_trans\tcomp_locs\tcomp_trans\tcomp_clocks\topt_rounds\topt_locs\topt_trans\topt_clocks\texp_locs\texp_trans\texp_invs\tinit_free\tsym_trans\ttotal_s\n' > "$OUT"
grep -v '^#' "$HERE/random_formulas.tsv" | while IFS=$'\t' read -r id ours cas; do
  [ -z "$id" ] && continue
  d=$(mktemp -d); cd "$d"
  s=$(timeout "$LIMIT" "$EXE" -nopdf -stats -o a "$ours" 2>/dev/null | tail -1); rc=$?
  cd /; rm -rf "$d"
  if [ -n "$s" ]; then
    echo "$s" | awk -v id="$id" -F'\t' '{print id"\tok\t"$2"\t"$3"\t"$5"\t"$6"\t"$7"\t"$8"\t"$9"\t"$10"\t"$11"\t"$12"\t"$13"\t"$15"\t"$20"\t"$21"\t"$19}' >> "$OUT"
  else
    printf '%s\ttimeout/error\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\n' "$id" >> "$OUT"
  fi
done

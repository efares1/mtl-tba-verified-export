#!/bin/bash
# Chain: compile(f) cubes -> grouped (sym_trans with -n 0) under the Paper-1 front end (-noweak -norecur).
EXE=${EXE:-$HOME/chain_build/_build/default/src/mtl2tba.exe}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/chain_noweak.tsv"; : > "$OUT"
grep -v '^#' "$HERE/formulas.tsv" | while IFS=$'\t' read -r id desc ours cas; do
  [ -z "$id" ] && continue
  d=$(mktemp -d); cd "$d"
  s=$(timeout 300 "$EXE" -noweak -norecur -n 0 -nopdf -stats -o a "$ours" 2>/dev/null)
  cd /; rm -rf "$d"
  echo "$s" | awk -v id="$id" -F'\t' '{print id"\t"$6"\t"$21}' >> "$OUT"
done

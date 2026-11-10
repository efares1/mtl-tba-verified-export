#!/bin/bash
# Wrapper given to mtl2tba with -spot: runs ltl2tgba with the arguments of the
# tool, unchanged, and keeps a copy of the formula file (-F) and of the LBTT
# output in $SPOT_SAVE (<base>.ltl, <base>.lbtt).  Used by run_spot_validation.sh.
f=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  [ "${args[$i]}" = "-F" ] && f="${args[$((i + 1))]}"
done
out=$(mktemp)
ltl2tgba "$@" > "$out" || { rm -f "$out"; exit 1; }
if [ -n "$SPOT_SAVE" ]; then
  cp "$f" "$SPOT_SAVE.ltl"
  cp "$out" "$SPOT_SAVE.lbtt"
fi
cat "$out"
rm -f "$out"

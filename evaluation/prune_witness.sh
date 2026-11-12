#!/bin/bash
# Dominance witness of Supplement Section 3.2: CASAAL's automaton for R1, pruned
# with the full certifier (live/lle) and with the equality-only one (-prune-eq).
# PRUNE_DEBUG prints, per location, the sizes of live and lle, and the number of
# pairs kept in the simulation relation. Run from the repository root after building tool/.
set -e
D="$(cd "$(dirname "$0")/.." && pwd)"
W=$(mktemp -d)
cd "$D/evaluation"
python3 casaal_to_tba.py casaal_out/R1.gv "$W/c.tba" a1,b1 > /dev/null
for f in "-prune-split" "-prune-split -prune-eq"; do
  echo "== tba_opt $f"
  PRUNE_DEBUG=1 "$D/tool/_build/default/src/tba_opt.exe" -o "$W/o" -n 0 $f "$W/c.tba" 2>&1 \
    | grep -E "^loc |sim pairs|^tba "
done

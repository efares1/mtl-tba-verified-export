#!/bin/bash
# Run the case study with UPPAAL's command-line verifier.
#   VERIFYTA=/path/to/verifyta bash run_uppaal.sh
# Expected: spor_ok, resp_ok: E<> P.A4 not satisfied; spor_bad, resp_bad:
# satisfied (with a diagnostic trace); every *_alone model: A[] not deadlock satisfied.
VERIFYTA=${VERIFYTA:-verifyta}
cd "$(dirname "$0")/models"
for m in spor_ok spor_bad resp_ok resp_bad spor_ok_alone spor_bad_alone resp_ok_alone resp_bad_alone; do
  printf '%-16s %-18s ' "$m" "$(cat $m.q)"
  "$VERIFYTA" -t0 -q $m.xml $m.q 2>&1 | grep -E "satisfied|error" | head -1
done

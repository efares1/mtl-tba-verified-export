#!/bin/bash
# One-command check of the artifact (Linux or WSL):
#   1. compile the Coq development and extract the code of the tool;
#   2. audit the development (no Admitted/admit/Parameter/Hypothesis; Axioms);
#   3. print the assumptions of the main theorems;
#   4. build the tool mtl2tba;
#   5. translate the examples of the paper;
#   6. run the 18 boundary and overlap implementation checks.
# Usage:  bash reproduce.sh            (coqc, dune, menhir, ltl2tgba on PATH)
#         COQC=/path/to/coqc bash reproduce.sh
# The full evaluation of the paper is described in evaluation/README.md.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
COQC=${COQC:-coqc}
step() { printf '\n== %s\n' "$*"; }

step "1. Coq proofs and extraction ($($COQC --version | head -1))"
make -C "$ROOT/proof" -s COQC="$COQC" > "$ROOT/proof/build.log" 2>&1 \
  || { tail -20 "$ROOT/proof/build.log"; exit 1; }
echo "ok (log: proof/build.log)"

step "2. Audit of the development"
(cd "$ROOT/proof" && python3 tools/audit.py)

step "3. Assumptions of the main theorems"
AUD="$ROOT/proof/Audit_main.v"
cat > "$AUD" <<'EOF'
Require Import MTL_to_TBA_Recur.
Print Assumptions MTL_to_exported_correct_recur_weak_with.
Print Assumptions MTL_to_exported_correct0_recur_weak_with.
EOF
(cd "$ROOT/proof" && $COQC -w -deprecated-missing-stdlib Audit_main.v)
rm -f "$ROOT"/proof/Audit_main.*

step "4. Build of the tool"
(cd "$ROOT/tool" && dune build 2>&1 | head -20)
EXE="$ROOT/tool/_build/default/src/mtl2tba.exe"
echo "ok: $EXE"

step "5. Examples"
OUT=$(mktemp -d)
cd "$OUT"
"$EXE" -nopdf -o sporadic '[](e -> ^[][<2] !e)'
"$EXE" -nopdf -o running '(<>[<=5] p) & [][<2] !p'
"$EXE" -nopdf -o response '[](p -> <>[<=5] q)'
echo "outputs (.xml for UPPAAL, .dot): $OUT"

step "6. Implementation checks (18 boundary and overlap tests)"
EXE="$EXE" bash "$ROOT/evaluation/run_boundary_tests.sh"

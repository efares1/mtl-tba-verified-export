#!/bin/bash
# control build of the unmutated sources (WSL)
cd "$(dirname "$0")/ctrl" || exit 1
R="/mnt/c/Rocq-Platform~9.0~2025.08/bin/coqc.exe"
FL="-w -deprecated-missing-stdlib -w -extraction-opaque-accessed -w -extraction-axiom-to-realize -w -extraction-default-directory"
s=$(date +%s)
for f in MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof MTL_to_TBA_Invariants MTL_to_TBA_Optimizations MTL_to_TBA_Export MTL_to_TBA_Initialization MTL_to_TBA_Simplify MTL_to_TBA_Symbolic MTL_to_TBA_Negation MTL_to_TBA_Weak MTL_to_TBA_Recur; do
  t=$(date +%s)
  "$R" $FL $f.v > ../logs/ctrl_$f.log 2>&1; rc=$?
  echo "$f rc=$rc $(( $(date +%s) - t ))s"
  [ $rc -ne 0 ] && break
done
echo "total $(( $(date +%s) - s ))s"
touch ../logs/ctrl.done

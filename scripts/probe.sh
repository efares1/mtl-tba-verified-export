#!/bin/bash
ROCQ_BIN="/mnt/c/Rocq-Platform~9.0~2025.08/bin"
cd /mnt/c/Users/user/Desktop/JSS_paper/proof || exit 1
"$ROCQ_BIN/coqc.exe" --version
echo "version rc=$?"
time "$ROCQ_BIN/coqc.exe" -w -deprecated-missing-stdlib MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core.v
echo "core rc=$?"
ls -la *.vo 2>&1 | head -3
cd /mnt/c/Users/user/Desktop/paper1_access/proof || exit 1
"$ROCQ_BIN/coqc.exe" -w -deprecated-missing-stdlib ZeroInit.v 2>&1 | head -3
echo "paper1 zeroinit rc=$?"

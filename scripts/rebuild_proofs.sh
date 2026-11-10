#!/bin/bash
# Build the Rocq development (Windows Rocq Platform called from WSL).
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ROCQ_BIN=${ROCQ_BIN:-"/mnt/c/Rocq-Platform~9.0~2025.08/bin"}
LOG="$ROOT/output/rebase"
mkdir -p "$LOG"
cd "$ROOT/proof" || exit 1
make -k COQC="$ROCQ_BIN/coqc.exe" > "$LOG/build1.log" 2>&1
echo "make exit: $?" >> "$LOG/build1.log"

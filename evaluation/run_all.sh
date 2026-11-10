#!/bin/bash
# Re-run of the tool-dependent evaluation after the change of the printing of
# the negated event atom (!"p" instead of "!p", option -indep-neg for the
# previous printing).
#
#   bash run_all.sh                       # all steps below, in order
#   STEPS="full noweak" bash run_all.sh   # a subset
#   WAIT_FOR=<file> bash run_all.sh       # wait until <file> contains "finished"
#                                         # (to avoid sharing the CPU with another run)
#
# Not repeated: the synthetic TBA suite, which does not involve Spot or the
# translation (synthetic_tba_*), and the CASAAL runs themselves (run_casaal*.py,
# Windows executable); their results in casaal_out* are reused.
# Logs: run_all.log.  Tables: python make_tables.py after the steps.
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG="$HERE/run_all.log"
STEPS=${STEPS:-"full noweak boundary spot interface accept randopt policies tckeq tckcomp randdiff symbolic"}
say() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
cd "$HERE" || exit 1
# the tool built from ../tool (some scripts default to another build directory)
export EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
if [ -n "$WAIT_FOR" ]; then
  say "waiting for $WAIT_FOR"
  until grep -q finished "$WAIT_FOR" 2>/dev/null; do sleep 60; done
fi
for step in $STEPS; do
  say "start $step"
  case $step in
    full)      bash run_full_eval.sh >> "$LOG" 2>&1 ;;
    noweak)    OPTS=-noweak SUFFIX=_noweak bash run_full_eval.sh >> "$LOG" 2>&1 ;;
    boundary)  bash run_boundary_tests.sh >> "$LOG" 2>&1 ;;
    spot)      bash run_spot_validation.sh >> "$LOG" 2>&1 ;;
    interface) bash run_interface_check.sh >> "$LOG" 2>&1 ;;
    accept)    bash run_acceptance_eval.sh >> "$LOG" 2>&1 ;;
    randopt)   bash run_random_opt.sh >> "$LOG" 2>&1 ;;
    policies)  bash run_export_policies.sh >> "$LOG" 2>&1 ;;
    tckeq)     bash run_tck_equivalence.sh >> "$LOG" 2>&1 ;;
    tckcomp)   bash run_tck_compiled.sh >> "$LOG" 2>&1 ;;
    randdiff)  bash run_random_diff.sh >> "$LOG" 2>&1 ;;
    symbolic)  bash run_symbolic_before_after.sh >> "$LOG" 2>&1 ;;
    *)         say "unknown step $step" ;;
  esac
  say "end $step"
done
say "finished"

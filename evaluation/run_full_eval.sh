#!/bin/bash
# ONLY="F8 R1": only these configurations; the rows go to <file>.only (merge_rows.py)
# Full evaluation of mtl2tba: sizes, repeated timings, peak memory, stage
# times, and the effect of the Spot options.
# Run in WSL Ubuntu (Spot, dune, menhir installed):
#     bash run_full_eval.sh            # 5 runs per formula, limit 300 s
#     REPS=3 LIMIT=120 bash run_full_eval.sh
#     OPTS=-noweak SUFFIX=_noweak bash run_full_eval.sh   # ablation of the
#         weak until (ours_results_noweak.tsv, spot_det_noweak.tsv, ...)
# Writes ours_results.tsv (median of the runs), ours_runs.tsv (every run),
# spot_det.tsv (Spot with -B -D instead of the default -B --small), machine.txt,
# and the exported automata in out/.
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOL="$HERE/../tool"
REPS=${REPS:-5}
LIMIT=${LIMIT:-300}
OPTS=${OPTS:-}      # extra options of the tool
SUFFIX=${SUFFIX:-}  # suffix of the result files
[ -n "$ONLY" ] && SUFFIX="$SUFFIX.only"
(cd "$TOOL" && dune build)
EXE="$TOOL/_build/default/src/mtl2tba.exe"
mkdir -p "$HERE/out"

# Spot with -B -D instead of the default -B --small
SMALL=$(mktemp "$HERE/spot_det.XXXXXX")
trap 'rm -f -- "$SMALL"' EXIT
cat > "$SMALL" <<'EOS'
#!/bin/bash
args=()
for a in "$@"; do [ "$a" = "--small" ] && a="-D"; args+=("$a"); done
exec ltl2tgba "${args[@]}"
EOS
chmod +x "$SMALL"

{
  echo "date: $(date -u +%Y-%m-%dT%H:%MZ)"
  lscpu | grep -E "Model name|^CPU\(s\)"
  free -m | awk '/Mem:/ {print "memory (MB): " $2}'
  echo "kernel: $(uname -r)"
  grep PRETTY /etc/os-release
  ltl2tgba --version | head -1
  ocaml -version
  echo "dune $(dune --version)"
  echo "repetitions: $REPS, limit: $LIMIT s"
} > "$HERE/machine$SUFFIX.txt"

HDR=$("$EXE" -stats-header)
printf 'id\trun\tstatus\tmem_kb\t%s\n' "$HDR" > "$HERE/ours_runs$SUFFIX.tsv"
printf 'id\tstatus\t%s\n' "$HDR" > "$HERE/spot_det$SUFFIX.tsv"
grep -v '^#' "$HERE/formulas.tsv" | while IFS=$'\t' read -r id desc ours cas; do
  [ -n "$ONLY" ] && ! [[ " $ONLY " == *" $id "* ]] && continue
  [ -z "$id" ] && continue
  for r in $(seq 1 "$REPS"); do
    line=$(cd "$HERE/out" && /usr/bin/time -f '%M' -o /tmp/mem.txt \
             timeout "$LIMIT" "$EXE" -stats -nopdf $OPTS -o "$id" "$ours" 2>"$HERE/out/$id.err")
    code=$?
    mem=$(tail -1 /tmp/mem.txt)
    if [ $code -eq 0 ]; then st=ok; elif [ $code -eq 124 ]; then st=timeout; else st=error; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$r" "$st" "$mem" "$line" >> "$HERE/ours_runs$SUFFIX.tsv"
    echo "$id run $r: $st"
    [ "$st" = ok ] || break
  done
  line=$(cd /tmp && timeout "$LIMIT" "$EXE" -stats -nopdf $OPTS -spot "$SMALL" -o small "$ours" 2>/dev/null)
  code=$?
  if [ $code -eq 0 ]; then st=ok; elif [ $code -eq 124 ]; then st=timeout; else st=error; fi
  printf '%s\t%s\t%s\n' "$id" "$st" "$line" >> "$HERE/spot_det$SUFFIX.tsv"
done
python3 "$HERE/summarize_runs.py" "ours_runs$SUFFIX.tsv" "ours_results$SUFFIX.tsv"

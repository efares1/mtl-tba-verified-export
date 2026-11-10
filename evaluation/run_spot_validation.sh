#!/bin/bash
# ONLY="F8 R1": only these configurations; the rows go to <file>.only (merge_rows.py)
# Translation validation of the Spot step (the only hypothesis of the
# end-to-end theorem), on every configuration of formulas.tsv; the tool is
# unchanged.  For each configuration:
#   1. mtl2tba runs with -spot spot_tee.sh, which keeps the clocked-LTL formula
#      T(f) given to Spot and the LBTT automaton A returned by Spot;
#   2. an independent translator, ltl2ba (Gastin and Oddoux), translates T(f),
#      after its atoms are renamed p0, p1, ... (ltlfilt --relabel=pnn);
#   3. the back-end contract  PBA_accepts A s <-> s,0 |= T(f)  is checked for
#      the run by two emptiness checks of autfilt, with the same renaming:
#      A x ltl2ba(!T(f)) is empty (A accepts only models of T(f)), and
#      complement(A) x ltl2ba(T(f)) is empty (A accepts every model); only the
#      small automaton of Spot is complemented (autfilt --product, --is-empty,
#      --complement; a check that fails or exceeds the limit is reported as such);
#   4. the numbers of states and transitions that the reader of the tool reports
#      are compared with those of autfilt on the LBTT file.
# Requires ltl2ba 1.3 in $LTL2BA (default ~/tools/ltl2ba-big/ltl2ba), compiled
# with its formula buffers (uform, formula, yytext, dumpbuf in main.c, lex.c,
# trans.c) enlarged from 4096/2048 to 1048576 characters, since T(f) exceeds
# 4096 characters on N7 and N8: gcc -O3 -ansi -DNXT -o ltl2ba *.c
# Limits: LIMIT (tool and ltl2ba, default 300 s), EQLIMIT (equivalence, 600 s).
# Writes spot_validation.tsv.
HERE="$(cd "$(dirname "$0")" && pwd)"
EXE=${EXE:-"$HERE/../tool/_build/default/src/mtl2tba.exe"}
LTL2BA=${LTL2BA:-"$HOME/tools/ltl2ba-big/ltl2ba"}
LIMIT=${LIMIT:-300}
EQLIMIT=${EQLIMIT:-600}
W=$(mktemp -d)
trap 'rm -rf -- "$W"' EXIT
OUT="$HERE/spot_validation.tsv"
[ -n "$ONLY" ] && OUT="$OUT.only"
# FROM=<id>: resume at this configuration and append to the existing file;
# UNTIL=<id>: stop after this configuration
if [ -z "$FROM" ]; then
  printf 'id\tatoms\tspot_states\tspot_edges\treader_states\treader_trans\tltl2ba_states\tequivalent\ttime_s\n' > "$OUT"
fi
started=${FROM:+no}
chmod +x "$HERE/spot_tee.sh"
grep -v '^#' "$HERE/formulas.tsv" | while IFS=$'\t' read -r id desc ours cas; do
  [ -n "$ONLY" ] && ! [[ " $ONLY " == *" $id "* ]] && continue
  [ -z "$id" ] && continue
  if [ "$started" = no ]; then
    [ "$id" = "$FROM" ] && started=yes || continue
  fi
  [ "$started" = done ] && continue
  [ -n "$UNTIL" ] && [ "$id" = "$UNTIL" ] && started=done
  rm -f "$W"/*
  log=$(cd "$W" && SPOT_SAVE="$W/s" timeout "$LIMIT" "$EXE" -v -nopdf \
        -spot "$HERE/spot_tee.sh" -o out "$ours" 2>&1)
  if [ ! -s "$W/s.lbtt" ]; then
    printf '%s\t\t\t\t\t\t\ttool timeout\t\n' "$id" >> "$OUT"; echo "$id: tool timeout"; continue
  fi
  read rs rt < <(echo "$log" | sed -n 's/^Spot: \([0-9]*\) states, \([0-9]*\) transitions.*/\1 \2/p')
  # common renaming of the atoms
  ltlfilt --relabel=pnn --define="$W/map" -F "$W/s.ltl" > "$W/r.ltl"
  natoms=$(grep -c '^#define' "$W/map")
  autfilt "$W/s.lbtt" > "$W/s.hoa"
  # rename the atomic propositions of Spot's automaton in one pass, on its AP
  # line only (the body refers to them by index)
  python3 - "$W/map" "$W/s.hoa" "$W/r.hoa" <<'PY'
import re, sys
defs = {}
for l in open(sys.argv[1]):
    m = re.match(r'#define (p\d+) \((.*)\)$', l.strip())
    if m:
        k = m.group(2)
        defs[k[1:-1] if k.startswith('"') else k] = m.group(1)
out = []
for line in open(sys.argv[2]):
    if line.startswith('AP:'):
        n, names = line.split(None, 2)[1], re.findall(r'"((?:[^"\\]|\\.)*)"', line)
        line = 'AP: %s %s\n' % (n, ' '.join('"%s"' % defs[a] for a in names))
    out.append(line)
open(sys.argv[3], 'w').write(''.join(out))
PY
  read ss se < <(autfilt --stats='%s %e' "$W/s.hoa")
  t0=$(date +%s.%N)
  ltlfilt --spin -F "$W/r.ltl" > "$W/r.spin"
  ltlfilt --negate --spin -F "$W/r.ltl" > "$W/n.spin"
  timeout "$LIMIT" "$LTL2BA" -F "$W/r.spin" > "$W/b.never" 2>/dev/null; c1=$?
  timeout "$LIMIT" "$LTL2BA" -F "$W/n.spin" > "$W/n.never" 2>/dev/null; c2=$?
  if [ $c1 -eq 124 ] || [ $c2 -eq 124 ]; then bs=""; eq="ltl2ba timeout"
  elif [ $c1 -ne 0 ] || [ $c2 -ne 0 ]; then bs=""; eq="ltl2ba error"
  else
    bs=$(autfilt --stats='%s' "$W/b.never")
    # A accepts only models: A x ltl2ba(!T(f)) is empty
    timeout "$EQLIMIT" bash -c 'autfilt "$1" --product="$2" | autfilt -q --is-empty' _ "$W/r.hoa" "$W/n.never"; e1=$?
    # A accepts every model: complement(A) x ltl2ba(T(f)) is empty
    timeout "$EQLIMIT" bash -c 'autfilt --complement "$1" | autfilt --product="$2" | autfilt -q --is-empty' _ "$W/r.hoa" "$W/b.never"; e2=$?
    if [ $e1 -eq 0 ] && [ $e2 -eq 0 ]; then eq=yes
    elif [ $e1 -eq 124 ] || [ $e2 -eq 124 ]; then eq="check timeout"
    elif [ $e1 -eq 1 ] || [ $e2 -eq 1 ]; then eq=NO
    else eq="check error"; fi
  fi
  dt=$(python3 -c "print(f'{$(date +%s.%N)-$t0:.2f}')")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$natoms" "$ss" "$se" "$rs" "$rt" "$bs" "$eq" "$dt" >> "$OUT"
  echo "$id: $eq"
done
column -t -s $'\t' "$OUT"

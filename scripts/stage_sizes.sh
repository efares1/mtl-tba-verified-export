#!/bin/bash
# sizes per stage for the negated requirement: after reset completion (before optimization),
# after optimization, after export (explicit / symbolic). usage: stage_sizes.sh ID...
D=/mnt/c/Users/user/Desktop/JSS_paper; X=$D/tool/_build/default/src/mtl2tba.exe
W=$(mktemp -d); cd $W
H=$($X -stats-header)
printf 'id\tcomp_locs/trans\topt_locs/trans\texp_locs/trans\tsym_trans\texp_trans_n0\tsym_n0\n'
for id in "$@"; do
  f=$(awk -F'\t' -v id="$id" '$1==id {print $3}' $D/evaluation/formulas.tsv)
  a=$($X -nopdf -stats -o a "!($f)" 2>/dev/null | tail -1)
  b=$($X -nopdf -stats -n 0 -o b "!($f)" 2>/dev/null | tail -1)
  python3 - "$H" "$a" "$b" "$id" <<'PY'
import sys
h=sys.argv[1].split('\t'); a=dict(zip(h,sys.argv[2].split('\t'))); b=dict(zip(h,sys.argv[3].split('\t')))
print('\t'.join([sys.argv[4], '%s/%s'%(a['comp_locs'],a['comp_trans']) if 'comp_locs' in a else str([k for k in h][:12]),
  '%s/%s'%(a.get('opt_locs'),a.get('opt_trans')), '%s/%s'%(a.get('exp_locs'),a.get('exp_trans')), a.get('sym_trans'), b.get('exp_trans'), b.get('sym_trans')]))
PY
done

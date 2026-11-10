/dta_nstates/ { print }
/INITFREE (inv_table|live_set|live_ok)/ { t[$2] += $3; n[$2]++ }
/\|S\|/ { split($2, a, "="); s += a[2]; c++ }
END {
  for (k in t) printf "%s total %.2fs over %d calls\n", k, t[k], n[k]
  if (c) printf "mean |S| = %.0f\n", s / c
}

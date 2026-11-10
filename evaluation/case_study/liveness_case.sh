#!/bin/bash
# Liveness use of the exported automaton, with the timed Buechi emptiness
# checker of TChecker: requirement [](p -> <> q) (unbounded response).
# mtl2tba translates its negation <>(p & [] !q); the automaton is composed
# with a system that answers every request within 4 time units (ok) and with
# a system that may stay busy forever (bad), on infinite timed words with
# strictly increasing, divergent timestamps (tck_product.py).  A non-empty
# product is a run of the system that violates the requirement.
# The system XML is passed with the SYS: prefix so it adds no Büchi obligation.
# Expected: ok -> CYCLE false, bad -> CYCLE true.  Writes liveness_results.txt.
HERE="$(cd "$(dirname "$0")" && pwd)"
EV="$HERE/.."
EXE=${EXE:-"$EV/../tool/_build/default/src/mtl2tba.exe"}
TCK=${TCK:-"$HOME/local/bin/tck-liveness"}
W=$(mktemp -d)
cd "$W"
"$EXE" -nopdf -o neglive '<>(p & [] !q)' > /dev/null
sys() {  # $1 name, $2 invariant of Busy ("" for none), $3 guard of other in Busy
  inv=""; [ -n "$2" ] && inv="<label kind=\"invariant\">$2</label>"
  cat > "$W/$1.xml" <<EOF
<nta><template><name>Property</name><declaration>clock x0;</declaration>
<location id="i"><name>LIdle</name></location>
<location id="b"><name>LBusy</name>$inv</location>
<init ref="i"/>
<transition><source ref="i"/><target ref="b"/><label kind="synchronisation">p?</label><label kind="assignment">x0 = 0</label></transition>
<transition><source ref="i"/><target ref="i"/><label kind="synchronisation">other?</label></transition>
<transition><source ref="b"/><target ref="b"/>$3<label kind="synchronisation">other?</label></transition>
<transition><source ref="b"/><target ref="i"/><label kind="guard">x0 &gt;= 1</label><label kind="synchronisation">q?</label></transition>
</template></nta>
EOF
}
sys ok 'x0 &lt;= 4' '<label kind="guard">x0 &lt; 4</label>'
sys bad '' ''
for s in ok bad; do
  lab=$(python3 "$EV/tck_product.py" "$W/m_$s.tck" p,q P:"$W/neglive.xml" SYS:"$W/$s.xml")
  r=$(timeout 600 "$TCK" -a couvscc -l "$lab" "$W/m_$s.tck" 2>&1 | grep '^CYCLE')
  echo "$s: $r"
done | tee "$HERE/liveness_results.txt"
rm -rf "$W"

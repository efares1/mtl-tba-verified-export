"""System for the bounded-response family Rn: one outstanding request at a time,
a_i then b_i after 1 to 2 time units; every other event ('other') may occur at any time.
Writes the template Sys in the format of case_study/models (to be normalized by
tck_normalize_system.py).  Usage: make_resp_system.py n out.xml"""
import sys
n = int(sys.argv[1]); out = sys.argv[2]; bad = len(sys.argv) > 3 and sys.argv[3] == 'bad'
badall = len(sys.argv) > 3 and sys.argv[3] == 'badall'
chans = ', '.join(['a%d' % i for i in range(1, n + 1)] + ['b%d' % i for i in range(1, n + 1)] + ['other'])
L = ['<?xml version="1.0" encoding="utf-8"?>',
     "<!DOCTYPE nta PUBLIC '-//Uppaal Team//DTD Flat System 1.1//EN' 'http://www.it.uu.se/research/group/darts/uppaal/flat-1_2.dtd'>",
     '<nta>', '  <declaration>chan %s;</declaration>' % chans, '  <template>', '    <name>Sys</name>',
     '    <declaration>clock y, z;</declaration>',
     '    <location id="s0" x="0" y="0"><name>Idle</name></location>']
for i in range(1, n + 1):
    L.append('    <location id="w%d" x="0" y="0"><name>Wait%d</name><label kind="invariant">y &lt;= 2</label></location>' % (i, i))
L.append('    <init ref="s0"/>')
def tr(src, dst, guard, sync, assign):
    return ('    <transition><source ref="%s"/><target ref="%s"/><label kind="guard">%s</label>'
            '<label kind="synchronisation">%s!</label><label kind="assignment">%s</label></transition>') % (src, dst, guard, sync, assign)
L.append(tr('s0', 's0', 'z &gt; 0', 'other', 'z = 0'))
for i in range(1, n + 1):
    L.append(tr('s0', 'w%d' % i, 'z &gt; 0', 'a%d' % i, 'y = 0, z = 0'))
    L.append(tr('w%d' % i, 'w%d' % i, 'z &gt; 0 &amp;&amp; y &lt; 2', 'other', 'z = 0'))
    L.append(tr('w%d' % i, 's0', 'z &gt; 0 &amp;&amp; y &gt;= 1', 'b%d' % i, 'z = 0'))
if badall:
    # violates R_n on every run but exercises all n responses: the requests a_2, ..., a_n are each made once and
    # answered in time, then a_1 is made and b_1 is never given (the run ends in a sink that only lets time pass)
    L = [x for x in L if 'transition' not in x]
    L.append('    <location id="bad" x="0" y="0"><name>Bad</name></location>')
    for i in range(1, n):
        L.append('    <location id="p%d" x="0" y="0"><name>P%d</name></location>' % (i, i))
    chain = ['s0'] + ['p%d' % i for i in range(1, n)]
    for k, i in enumerate(range(2, n + 1)):
        L.append(tr(chain[k], 'w%d' % i, 'z &gt; 0', 'a%d' % i, 'y = 0, z = 0'))
        L.append(tr('w%d' % i, 'w%d' % i, 'z &gt; 0 &amp;&amp; y &lt; 2', 'other', 'z = 0'))
        L.append(tr('w%d' % i, chain[k + 1] if k + 1 < len(chain) else 'p%d' % (n - 1), 'z &gt; 0 &amp;&amp; y &gt;= 1', 'b%d' % i, 'z = 0'))
    L.append(tr(chain[-1], 'bad', 'z &gt; 0', 'a1', 'y = 0, z = 0'))
    L.append(tr('bad', 'bad', 'z &gt; 0', 'other', 'z = 0'))
elif bad:
    L = [x for x in L if 'transition' not in x]
    L.append('    <location id="bad" x="0" y="0"><name>Bad</name></location>')
    L.append(tr('s0', 'bad', 'z &gt; 0', 'a1', 'y = 0, z = 0'))
    L.append(tr('bad', 'bad', 'z &gt; 0', 'other', 'z = 0'))
L += ['  </template>', '  <system>Process = Sys();system Process;</system>', '</nta>']
open(out, 'w', encoding='utf8').write('\n'.join(L) + '\n')

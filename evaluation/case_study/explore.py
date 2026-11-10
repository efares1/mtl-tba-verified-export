"""Sanity check of the case study without UPPAAL: explicit exploration of the
product of models/<name>.xml with time advancing in steps of 1/4 and clock
values capped above the largest constant.  For these models (integer
constants, at most three clocks) this grid shows the same reachability as
UPPAAL's zone analysis; it is a cross-check of verifyta, not a replacement.
Usage: python explore.py   (prints the expected verdict of each query)
"""
import os, re, xml.etree.ElementTree as ET
from fractions import Fraction as F
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'models')
STEP, CAP = F(1, 4), 12

def cond(e):
    e = (e or '').strip()
    if not e:
        return lambda v: True
    parts = [p.strip() for p in e.split('&&')]
    fs = []
    for p in parts:
        x, op, b = re.fullmatch(r'(\w+)\s*(<=|<|>=|>|==)\s*(\d+)', p).groups()
        b = int(b)
        fs.append((x, op, b))
    ops = {'<=': lambda a, b: a <= b, '<': lambda a, b: a < b, '>=': lambda a, b: a >= b,
           '>': lambda a, b: a > b, '==': lambda a, b: a == b}
    return lambda v: all(ops[op](v[x], b) for x, op, b in fs)

def load(path):
    root = ET.parse(path).getroot()
    tps = {}
    for t in root.findall('template'):
        name = t.find('name').text
        d = t.find('declaration')
        clocks = re.findall(r'\w+', d.text.replace('clock', '')) if d is not None else []
        locs = {l.get('id'): (l.find('name').text if l.find('name') is not None else l.get('id'),
                              cond(l.findtext("label[@kind='invariant']"))) for l in t.findall('location')}
        edges = []
        for tr in t.findall('transition'):
            g = cond(tr.findtext("label[@kind='guard']"))
            s = tr.findtext("label[@kind='synchronisation']")
            a = tr.findtext("label[@kind='assignment']") or ''
            edges.append((tr.find('source').get('ref'), tr.find('target').get('ref'), g, s,
                          re.findall(r'(\w+)\s*=\s*0', a)))
        tps[name] = (clocks, locs, edges, t.find('init').get('ref'))
    return tps

def explore(path, target=None):
    tps = load(path)
    names = list(tps)
    clocks = [c for n in names for c in tps[n][0]]
    inv = lambda st, v: all(tps[n][1][st[i]][1](v) for i, n in enumerate(names))
    start = (tuple(tps[n][3] for n in names), tuple(F(0) for _ in clocks))
    seen, todo, dead = {start}, [start], False
    while todo:
        st, vals = todo.pop()
        v = dict(zip(clocks, vals))
        if target and any(tps[n][1][st[i]][0] == target[1] for i, n in enumerate(names) if n == target[0]):
            return True, False
        succ = []
        # delay
        v2 = {c: min(x + STEP, F(CAP)) for c, x in v.items()}
        if inv(st, v2):
            succ.append((st, tuple(v2[c] for c in clocks)))
        # synchronisations (sender ! with one receiver ?)
        for i, n in enumerate(names):
            for (s, t, g, sy, r) in tps[n][2]:
                if s != st[i] or not sy.endswith('!') or not g(v):
                    continue
                ch = sy[:-1]
                for j, m in enumerate(names):
                    if j == i:
                        continue
                    for (s2, t2, g2, sy2, r2) in tps[m][2]:
                        if s2 == st[j] and sy2 == ch + '?' and g2(v):
                            nst = list(st); nst[i] = t; nst[j] = t2
                            nv = dict(v)
                            for c in r + r2:
                                nv[c] = F(0)
                            if inv(tuple(nst), nv):
                                succ.append((tuple(nst), tuple(nv[c] for c in clocks)))
        if not succ:
            dead = True
        for x in succ:
            if x not in seen:
                seen.add(x); todo.append(x)
    return False, dead

for m in ['spor_ok', 'spor_bad', 'resp_ok', 'resp_bad']:
    q = open(os.path.join(HERE, m + '.q')).read().strip()
    tgt = re.fullmatch(r'E<> (\w+)\.(\w+)', q).groups()
    r, _ = explore(os.path.join(HERE, m + '.xml'), ('Property', tgt[1]))
    print(f'{m:16s} {q:18s} {"satisfied" if r else "not satisfied"}')
for m in ['spor_ok', 'spor_bad', 'resp_ok', 'resp_bad']:
    _, dead = explore(os.path.join(HERE, m + '_alone.xml'))
    print(f'{m + "_alone":16s} {"A[] not deadlock":18s} {"not satisfied" if dead else "satisfied"}')

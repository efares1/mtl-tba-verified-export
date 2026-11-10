"""Probe: how much would a simulation-quotient pass shrink the exported negated automata?
Treats (event, guard, resets) and the location invariant as atomic letters (syntactic,
hence conservative), computes direct-simulation equivalence of locations (acceptance must
agree), and reports locations/transitions before and after the quotient.
Usage (WSL): python3 sim_quotient_probe.py [ID ...]"""
import os, re, subprocess, sys, tempfile, shutil
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe')
ONLY = set(sys.argv[1:])

def load(path):
    root = ET.parse(path).getroot()
    t = [t for t in root.findall('template') if t.find('name').text == 'Property'][0]
    inv, acc = {}, {}
    for l in t.findall('location'):
        lid = l.get('id')
        inv[lid] = l.findtext("label[@kind='invariant']") or ''
        acc[lid] = l.find('name').text.startswith('A')
    init = t.find('init').get('ref')
    edges = set()
    for tr in t.findall('transition'):
        g = tr.findtext("label[@kind='guard']") or ''
        sy = tr.findtext("label[@kind='synchronisation']") or ''
        asg = tr.findtext("label[@kind='assignment']") or ''
        edges.add((tr.find('source').get('ref'), tr.find('target').get('ref'), (sy, g, asg)))
    return inv, acc, init, edges

def quotient(inv, acc, init, edges):
    locs = sorted(inv)
    out = {l: set() for l in locs}
    for s, t, a in edges:
        out[s].add((a, t))
    sim = {(p, q) for p in locs for q in locs
           if inv[p] == inv[q] and (not acc[p] or acc[q])}
    ch = True
    while ch:
        ch = False
        for (p, q) in list(sim):
            ok = all(any(a == b and (p2, q2) in sim for (b, q2) in out[q]) for (a, p2) in out[p])
            if not ok:
                sim.discard((p, q)); ch = True
    cls = {}
    for p in locs:
        cls[p] = min(q for q in locs if (p, q) in sim and (q, p) in sim)
    # reachable part
    seen, todo = {cls[init]}, [cls[init]]
    qe = set()
    for s, t, a in edges:
        qe.add((cls[s], cls[t], a))
    while todo:
        x = todo.pop()
        for s, t, a in qe:
            if s == x and t not in seen:
                seen.add(t); todo.append(t)
    qe = {e for e in qe if e[0] in seen}
    return len(locs), len(edges), len(seen), len(qe)

def run(formula, W):
    r = subprocess.run([EXE, '-nopdf', '-stats', '-o', 'neg', formula], cwd=W, capture_output=True, text=True, timeout=300)
    return r.returncode == 0

print('id\tlocs\ttrans\tq_locs\tq_trans')
with open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8') as f:
    for l in f:
        rec = l.rstrip('\n').split('\t')
        if len(rec) < 4 or l.startswith('#'):
            continue
        i, ours = rec[0], rec[2]
        if ONLY and i not in ONLY:
            continue
        if i.startswith(('N6', 'N7', 'N8')) or i in ('N5', 'R6', 'R5', 'F14'):
            continue
        W = tempfile.mkdtemp()
        try:
            if not run('!(%s)' % ours, W):
                print(i, 'tool-fail'); continue
            r = quotient(*load(os.path.join(W, 'neg.xml')))
            print(i, *r, sep='\t', flush=True)
        except Exception as e:
            print(i, 'error', e)
        finally:
            shutil.rmtree(W, ignore_errors=True)

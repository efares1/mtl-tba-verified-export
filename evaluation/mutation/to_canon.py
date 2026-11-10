"""Convert automata to the canonical text format read by lang_cmp.cpp.

  to_canon.py tba  in.tba            out.can          (tba_opt input format)
  to_canon.py xml  in.xml EV1,EV2,.. out.can          (UPPAAL XML written by mtl2tba / tba_opt)

Time is counted in half units: every bound b is stored as 2*b (must be a multiple of 1/2).
Events: the listed events get ids 0..n-1, the event "other" gets id n.
"""
import re, sys
import xml.etree.ElementTree as ET

OPS = {'<=': 0, '<': 1, '>=': 2, '>': 3, '==': 4, '=': 4}


def half(x):
    v = float(x) * 2
    if abs(v - round(v)) > 1e-9:
        raise ValueError('bound %s is not a multiple of 1/2' % x)
    return int(round(v))


def emit(path, E, nc, nl, init, acc, inv, trans):
    with open(path, 'w') as f:
        f.write('E %d\nC %d\nL %d\nI %d\n' % (E, nc, nl, init))
        f.write('A %d %s\n' % (len(acc), ' '.join(map(str, sorted(acc)))))
        for l, u in sorted(inv.items()):
            if u:
                f.write('V %d %d %s\n' % (l, len(u), ' '.join('%d %d' % p for p in u)))
        for (s, d, mask, g, rs) in trans:
            f.write('T %d %d %d %d %s %d %s\n' % (s, d, mask, len(g), ' '.join('%d %d %d %d' % a for a in g), len(rs), ' '.join(map(str, rs))))


def from_tba(path, out):
    evs = []; nc = 0; init = 0; nst = 0; acc = []; trs = []
    for line in open(path):
        line = line.split('#')[0].strip()
        if not line:
            continue
        w = line.split()
        if w[0] == 'events': evs = w[1:]
        elif w[0] == 'clocks': nc = int(w[1])
        elif w[0] == 'init': init = int(w[1])
        elif w[0] == 'states': nst = int(w[1])
        elif w[0] == 'acc': acc = [int(x) for x in w[1:]]
        elif w[0] == 't':
            body = line[1:].split('|')
            sd = body[0].split(); lab = body[1].split(); gd = body[2].split(); rs = [int(x) for x in body[3].split()]
            trs.append((int(sd[0]), int(sd[1]), lab, gd, rs))
    E = len(evs) + 1
    T = []
    for (s, d, lab, gd, rs) in trs:
        mask = 0
        for e in range(E):
            ok = True
            for lit in lab:
                a, pol = int(lit[:-1]), lit[-1] == '+'
                if (e == a) != pol: ok = False
            if ok: mask |= 1 << e
        g = []
        for a in gd:
            m = re.match(r'(\d+)(<=|<|>=|>|==|=)(.+)$', a)
            g.append((OPS[m.group(2)], int(m.group(1)), 0, half(m.group(3))))
        T.append((s, d, mask, g, rs))
    emit(out, E, nc, nst, init, acc, {}, T)


def clk(name):
    return int(re.match(r'x(\d+)$', name.strip()).group(1))


def parse_atoms(text):
    g = []
    for a in [t.strip() for t in text.split('&&') if t.strip() and t.strip() != 'true']:
        m = re.match(r'(\w+)\s*-\s*(\w+)\s*<=\s*(-?[\d.]+)$', a)
        if m:
            g.append((5, clk(m.group(1)), clk(m.group(2)), half(m.group(3)))); continue
        m = re.match(r'(\w+)\s*(<=|<|>=|>|==)\s*(-?[\d.]+)$', a)
        if not m: raise ValueError('cannot parse atom: ' + a)
        g.append((OPS[m.group(2)], clk(m.group(1)), 0, half(m.group(3))))
    return g


def from_xml(path, evs, out):
    root = ET.parse(path).getroot()
    ids = {n: i for i, n in enumerate(evs)}
    ids['other'] = len(evs)
    E = len(evs) + 1
    prop = [t for t in root.findall('template') if t.find('name').text == 'Property'][0]
    locs = {}; acc = set(); inv = {}
    for l in prop.findall('location'):
        n = int(l.get('id')[2:]); locs[l.get('id')] = n
        if l.find('name').text.startswith('A'): acc.add(n)
        iv = l.find("label[@kind='invariant']")
        if iv is not None:
            inv[n] = [(a[1], a[3]) for a in parse_atoms(iv.text)]
    init = locs[prop.find('init').get('ref')]
    nc = 0; T = []
    for t in prop.findall('transition'):
        s = locs[t.find('source').get('ref')]; d = locs[t.find('target').get('ref')]
        gl = t.find("label[@kind='guard']"); sl = t.find("label[@kind='synchronisation']"); al = t.find("label[@kind='assignment']")
        g = parse_atoms(gl.text) if gl is not None else []
        ev = sl.text.strip()[:-1]
        rs = [clk(x.split('=')[0]) for x in al.text.split(',')] if al is not None else []
        T.append((s, d, 1 << ids[ev], g, rs))
        for a in g: nc = max(nc, a[1] + 1, (a[2] + 1) if a[0] == 5 else 0)
        for r in rs: nc = max(nc, r + 1)
    for l, u in inv.items():
        for (c, b) in u: nc = max(nc, c + 1)
    emit(out, E, nc, max(locs.values()) + 1, init, acc, inv, T)


if __name__ == '__main__':
    if sys.argv[1] == 'tba':
        from_tba(sys.argv[2], sys.argv[3])
    else:
        from_xml(sys.argv[2], [e for e in sys.argv[3].split(',') if e], sys.argv[4])

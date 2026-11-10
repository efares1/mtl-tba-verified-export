"""Convert a CASAAL automaton (DOT, transition-based acceptance, one acceptance set)
to the text format of tba_opt (location acceptance).
Locations of the result are the reachable pairs (s, f), f = 1 when the transition that
entered the location carries the acceptance mark; accepting locations are those with f = 1.
Edge labels are put in DNF over event literals, guard atoms "xK<=c" and reset(xK).
Usage: python3 casaal_to_tba.py in.gv out.tba [event,event,...]
Exit code 3: several acceptance sets (not converted)."""
import re, sys, itertools

def tokens(s):
    return re.findall(r'"[^"]*"|reset\(\w+\)|!|&|\||\(|\)|[A-Za-z_]\w*|\d+', s)

def parse_label(s):
    """Return DNF: list of cubes; a cube is a list of atoms (kind, text, polarity)."""
    toks = tokens(s); pos = [0]
    def peek(): return toks[pos[0]] if pos[0] < len(toks) else None
    def eat(): pos[0] += 1; return toks[pos[0] - 1]
    def orx():
        c = andx()
        while peek() == '|':
            eat(); c = c + andx()
        return c
    def andx():
        c = notx()
        while peek() == '&':
            eat(); d = notx()
            c = [a + b for a in c for b in d]
        return c
    def notx():
        if peek() == '!':
            eat(); return neg(notx())
        if peek() == '(':
            eat(); c = orx(); eat(); return c
        t = eat()
        if t in ('true', '1'): return [[]]
        if t in ('false', '0'): return []
        if t.startswith('reset('): return [[('reset', t[6:-1], True)]]
        if t.startswith('"'): return [[('guard', t[1:-1], True)]]
        return [[('ev', t, True)]]
    def neg(c):
        # negation of a DNF: conjunction over cubes of the disjunction of negated literals
        res = [[]]
        for cube in c:
            lits = [[(k, x, not p)] for (k, x, p) in cube]
            if not lits: return []
            res = [a + b for a in res for b in lits]
        return res
    return orx()

def main():
    src, dst = sys.argv[1], sys.argv[2]
    txt = open(src, encoding='utf8').read()
    init = None; edges = []; accsets = set()
    for m in re.finditer(r'^\s*(\w+)\s*->\s*(\w+)\s*(?:\[label="(.*?)"\])?\s*$', txt, re.M | re.S):
        a, b, lab = m.group(1), m.group(2), m.group(3) or ''
        if a == '0' and not lab and init is None:
            init = b; continue
        mk = re.search(r'\{Acc\[(.*)\]\}', lab, re.S)
        if mk: accsets.add(mk.group(1))
        body = re.sub(r'\{Acc\[.*\]\}', '', lab, flags=re.S).replace('\n', ' ').strip()
        body = body.replace('\\"', '"')
        edges.append((a, b, body, mk is not None))
    if len(accsets) > 1:
        sys.exit(3)
    events = sys.argv[3].split(',') if len(sys.argv) > 3 else None
    cubes = []
    evset = set()
    for (a, b, body, acc) in edges:
        for cube in parse_label(body):
            cubes.append((a, b, cube, acc))
            for k, x, p in cube:
                if k == 'ev': evset.add(x)
    events = events or sorted(evset)
    eid = {e: i for i, e in enumerate(events)}
    clk = set()
    def guard_text(x, p):
        m = re.match(r'x(\d+)\s*(<=|<|>=|>|==)\s*([\d.]+)$', x)
        if not m: raise SystemExit('guard %r' % x)
        k, op, c = m.groups(); clk.add(int(k))
        if not p: op = {'<=': '>', '<': '>=', '>=': '<', '>': '<=', '==': '!='}[op]
        if op == '!=': raise SystemExit('disequality guard')
        return '%s%s%s' % (k, op, c)
    # states (s, f)
    out_edges = {}
    for (a, b, cube, acc) in cubes:
        out_edges.setdefault(a, []).append((b, cube, acc))
    ids = {}; todo = [(init, 0)]; ids[(init, 0)] = 0; trans = []
    while todo:
        s, f = todo.pop(0)
        for (b, cube, acc) in out_edges.get(s, []):
            nf = 1 if acc else 0
            if (b, nf) not in ids:
                ids[(b, nf)] = len(ids); todo.append((b, nf))
            lab = ' '.join('%d%s' % (eid[x], '+' if p else '-') for k, x, p in cube if k == 'ev')
            gd = ' '.join(guard_text(x, p) for k, x, p in cube if k == 'guard')
            rs = ' '.join(re.match(r'x(\d+)$', x).group(1) for k, x, p in cube if k == 'reset' and p)
            trans.append((ids[(s, f)], ids[(b, nf)], lab, gd, rs))
    with open(dst, 'w', encoding='utf8') as o:
        o.write('events %s\n' % ' '.join(events))
        o.write('clocks %d\n' % (max(clk) + 1 if clk else 0))
        o.write('init 0\nstates %d\n' % len(ids))
        o.write('acc %s\n' % ' '.join(str(i) for (s, f), i in ids.items() if f == 1))
        for (a, b, lab, gd, rs) in trans:
            o.write('t %d %d | %s | %s | %s\n' % (a, b, lab, gd, rs))
main()

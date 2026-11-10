"""Products of timed Buechi automata in the input format of TChecker.

    python tck_product.py out.tck EVENTS A:ours.xml B:casaal.gv ...

Each argument NAME:FILE is an automaton: an UPPAAL model written by mtl2tba
(.xml, template Property; accepting locations named An) or a CASAAL output
(.gv; acceptance marks {Acc[...]} on transitions).  EVENTS is a comma-separated
list of the events of the formula; the event `other` stands for every other
event.  The automata read the same timed word: every event is synchronized
between all of them.  Two processes are added:
  - Z forces strictly increasing timestamps (clock z > 0 at every event);
  - D forces infinitely many events and time divergence: its committed
    location `div` is visited after one time unit and at least one event since
    its previous visit, and the label `div` is accepting.
Use SYS:FILE.xml for a plain system model that constrains traces but contributes
no Büchi acceptance condition.
The labels printed on stdout, separated by commas, are the accepting labels to
give to tck-liveness: the product accepts an infinite timed word with one
event per position, strictly increasing and divergent timestamps, that every
automaton accepts.  Clocks start at 0 at time 0 in every automaton.
"""
import re
import sys
import xml.etree.ElementTree as ET


def num(c):
    return c.replace(' ', '')


class Auto:
    def __init__(self, name):
        self.name = name
        self.locs = {}          # id -> (labels, invariant, committed)
        self.init = None
        self.edges = []         # (src, tgt, event, guard, resets, labels)
        self.clocks = set()
        self.state_based = False

    def clk(self, x):
        self.clocks.add(x)
        return f'{self.name}_{x}'


def ren(a, expr):
    """rename the clocks x0, x1, ... of an expression into A_x0, ..."""
    def f(m):
        return a.clk(m.group(0))
    return re.sub(r'\bx\d+\b', f, expr)


def from_xml(name, path):
    a = Auto(name)
    # Most XML inputs are mtl2tba TBAs and require a state-based acceptance
    # label.  A name beginning with SYS denotes a plain system model instead;
    # it constrains traces but must not add an acceptance obligation.
    a.state_based = not name.startswith('SYS')
    root = ET.parse(path).getroot()
    t = [t for t in root.findall('template') if t.find('name').text == 'Property'][0]
    for l in t.findall('location'):
        lid = l.get('id')
        nm = l.find('name').text
        inv = l.findtext("label[@kind='invariant']")
        labels = [f'acc{name}'] if a.state_based and nm.startswith('A') else []
        a.locs[lid] = (labels, ren(a, inv) if inv else None, False)
    a.init = t.find('init').get('ref')
    for tr in t.findall('transition'):
        g = tr.findtext("label[@kind='guard']")
        sy = tr.findtext("label[@kind='synchronisation']").rstrip('?')
        asg = tr.findtext("label[@kind='assignment']") or ''
        resets = re.findall(r'(x\d+)\s*=\s*0', asg)
        a.edges.append((tr.find('source').get('ref'), tr.find('target').get('ref'), sy,
                        ren(a, g) if g else None, [a.clk(x) for x in resets], []))
    return a


def dnf(text):
    """Disjunctive normal form of a CASAAL label: list of lists of literals."""
    toks = re.findall(r'!?\\"[^\\]*\\"|!?\w+\([^)]*\)|!?\w+|[()&|!]', text)
    pos = [0]

    def peek():
        return toks[pos[0]] if pos[0] < len(toks) else None

    def disj():
        r = conj()
        while peek() == '|':
            pos[0] += 1
            r = r + conj()
        return r

    def conj():
        r = atom()
        while peek() == '&':
            pos[0] += 1
            b = atom()
            r = [x + y for x in r for y in b]
        return r

    def atom():
        t = peek()
        pos[0] += 1
        if t == '(':
            r = disj()
            assert peek() == ')', text
            pos[0] += 1
            return r
        if t == '!' and peek() == '(':
            raise ValueError('negated parenthesis in ' + text)
        return [[t]]

    return disj()


def acc_names(text):
    """names of the marks {Acc[...]}, with balanced brackets (the names
    contain intervals such as 0R[x<=5]p)"""
    out, i = [], 0
    while True:
        j = text.find('Acc[', i)
        if j < 0:
            return out
        d, k = 0, j + 3
        while k < len(text):
            if text[k] == '[':
                d += 1
            elif text[k] == ']':
                d -= 1
                if d == 0:
                    break
            k += 1
        out.append(text[j + 4:k])
        i = k


def from_gv(name, path, events):
    a = Auto(name)
    s = open(path, encoding='utf-8').read()
    nodes = set(re.findall(r'^\s*(\d+)\s*\[label', s, re.M)) - {'0'}
    for n in nodes:
        a.locs[n] = ([], None, False)
    a.init = re.search(r'^\s*0\s*->\s*(\d+)', s, re.M).group(1)
    k = 0
    for src, tgt, lab in re.findall(r'^\s*(\d+)\s*->\s*(\d+)\s*\[label="((?:[^"\\]|\\.)*)"\]', s, re.M):
        if src == '0':
            continue
        parts = lab.split('\\n')
        cube = parts[0].strip()
        accs = acc_names(' '.join(parts[1:]))
        for lits in (dnf(cube) if cube not in ('', '1') else [[]]):
            add_cube(a, src, tgt, lits, accs, events)
    a.acc_labels = sorted({l for v in a.locs.values() for l in v[0]})
    if not a.acc_labels:
        # No acceptance mark is printed.  CASAAL then relies on the state
        # labels: a state whose label still contains an unbounded eventuality
        # (F or U without an interval) has an undischarged obligation, so a
        # run that stays in such states forever is not accepting.  Accepting
        # states are the others; if there are none, the language is empty.
        # (Bounded operators carry their obligation in a clock guard.)
        text = dict(re.findall(r'^\s*(\d+)\s*\[label="((?:[^"\\]|\\.)*)"\]', s, re.M))
        pending = {n for n in nodes if UNBOUNDED_EVENTUALITY.search(text.get(n, ''))}
        if pending:
            lab = f'acc{a.name}_weak'
            good = [n for n in nodes if n not in pending]
            for n in good:
                a.locs[n] = ([lab], None, False)
            if not good:
                a.locs['unreach'] = ([lab], None, False)
            a.acc_labels = [lab]
    return a


# F or U in a CASAAL state label that leaves an obligation which no clock
# guard enforces: without an interval, or with a lower bound (x>d, x>=d).
# Operators are upper case, so no look-behind is needed (`pU[x>1]!r`).
UNBOUNDED_EVENTUALITY = re.compile(
    r'(F|U)(?![A-Za-z\[])|(F|U)\[x\d*>')


def add_cube(a, src, tgt, lits, accs, events):
    name = a.name
    if True:
        props, guards, resets = {}, [], []
        for l in lits:
            m = re.fullmatch(r'reset\((x\d+)\)', l)
            if m:
                resets.append(a.clk(m.group(1)))
                continue
            neg = l.startswith('!')
            body = l[1:] if neg else l
            if body.startswith('\\"'):
                c = body.strip('\\"').replace('\\"', '')
                m = re.fullmatch(r'(x\d+)(<=|<|>=|>)(\d+)', c)
                x, op, d = m.groups()
                if neg:
                    op = {'<=': '>', '<': '>=', '>=': '<', '>': '<='}[op]
                guards.append(f'{a.clk(x)}{op}{d}')
            elif body == '1':
                if neg:
                    props = None
                    break
            else:
                if props.get(body, not neg) != (not neg):
                    props = None
                    break
                props[body] = not neg
        if props is None:
            return
        labels = []
        for acc in accs:
            labels.append(f'acc{name}_{re.sub(r"[^A-Za-z0-9]", "_", acc)}')
        for ev in events + ['other']:
            # the event ev makes its proposition true and every other false
            if all((ev == p) == v for p, v in props.items()):
                g = '&&'.join(guards) if guards else None
                if labels:
                    a.k = getattr(a, 'k', 0) + 1
                    mid = f'm{a.k}'
                    a.locs[mid] = (labels, None, True)
                    a.edges.append((src, mid, ev, g, resets, []))
                    a.edges.append((mid, tgt, 'tau', None, [], []))
                else:
                    a.edges.append((src, tgt, ev, g, resets, []))


def from_tbadot(name, path, events):
    """the automaton after relaxation and reset completion (mtl2tba -tba,
    <base>_tba.dot): no invariant, conjunctive guards, accepting locations
    drawn as double circles"""
    a = Auto(name)
    a.state_based = True
    s = open(path, encoding='utf-8').read()
    for lid, shape in re.findall(r'^\s*L(\d+) \[shape=(\w+)', s, re.M):
        a.locs[lid] = ([f'acc{name}'] if shape == 'doublecircle' else [], None, False)
    a.init = re.search(r'init -> L(\d+);', s).group(1)
    for src, tgt, lab in re.findall(r'^\s*L(\d+) -> L(\d+) \[label="([^"]*)"\]', s, re.M):
        parts = lab.split('\\n')
        guard = None
        if parts and re.search(r'[<>]', parts[0]) and ':=' not in parts[0]:
            guard = parts.pop(0)
        evline = parts.pop(0) if parts else ''
        resets = []
        if parts and ':=' in parts[0]:
            resets = [a.clk(x) for x in re.findall(r'x\d+', parts[0])]
        evs = (events + ['other']) if evline == 'any' else [e for e in evline.split(',') if e]
        g = ren(a, guard).replace(' ', '') if guard else None
        for ev in evs:
            a.edges.append((src, tgt, ev, g, resets, []))
    return a


def write(out, autos, events):
    evs = events + ['other']
    L = ['system:product', '']
    for e in evs + ['tau', 'go', 'back']:
        L.append(f'event:{e}')
    L.append('')
    for a in autos:
        for x in sorted(a.clocks):
            L.append(f'clock:1:{a.name}_{x}')
    L += ['clock:1:z', 'clock:1:t', '']
    for a in autos:
        L.append(f'process:{a.name}')
        for lid, (labels, inv, com) in a.locs.items():
            attrs = []
            if lid == a.init:
                attrs.append('initial:')
            if labels:
                attrs.append('labels:' + ','.join(labels))
            if inv:
                attrs.append('invariant:' + inv.replace(' ', ''))
            if com:
                attrs.append('committed:')
            L.append(f'location:{a.name}:l{lid}{{{":".join(attrs)}}}')
        for src, tgt, ev, g, resets, _ in a.edges:
            attrs = []
            if g:
                attrs.append('provided:' + g.replace(' ', ''))
            if resets:
                attrs.append('do:' + ';'.join(f'{r}=0' for r in resets))
            L.append(f'edge:{a.name}:l{src}:l{tgt}:{ev}{{{":".join(attrs)}}}')
        L.append('')
    L += ['process:Z', 'location:Z:z0{initial:}']
    for e in evs:
        L.append(f'edge:Z:z0:z0:{e}{{provided:z>0:do:z=0}}')
    # D: the label div is visited only after one time unit and at least one
    # event since its previous visit (infinitely many events, divergent time)
    L += ['', 'process:D', 'location:D:wait{initial:}', 'location:D:seen{}',
          'location:D:div{committed::labels:div}',
          'edge:D:seen:div:back{provided:t>=1}', 'edge:D:div:wait:go{do:t=0}']
    for e in evs:
        L.append(f'edge:D:wait:seen:{e}{{}}')
        L.append(f'edge:D:seen:seen:{e}{{}}')
    L.append('')
    for e in evs:
        L.append('sync:' + ':'.join(f'{a.name}@{e}' for a in autos) + f':Z@{e}:D@{e}')
    open(out, 'w').write('\n'.join(L) + '\n')


def main():
    out, events = sys.argv[1], sys.argv[2].split(',')
    autos = []
    for arg in sys.argv[3:]:
        name, path = arg.split(':', 1)
        if path.endswith('.xml'):
            autos.append(from_xml(name, path))
        elif path.endswith('_tba.dot'):
            autos.append(from_tbadot(name, path, events))
        else:
            autos.append(from_gv(name, path, events))
    labels = ['div']
    for a in autos:
        ls = sorted({l for v in a.locs.values() for l in v[0]})
        if a.state_based and not ls:
            # state-based Buechi automaton of mtl2tba without an accepting
            # location: it accepts no run; its label is put on an unreachable
            # location, so that it is declared but never visited
            ls = [f'acc{a.name}']
            a.locs['unreach'] = (ls, None, False)
        labels += ls
    # a CASAAL automaton without acceptance mark accepts every infinite run
    write(out, autos, events)
    print(','.join(labels))


if __name__ == '__main__':
    main()

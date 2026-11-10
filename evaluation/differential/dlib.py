"""Independent evaluators for the differential test (new, unverified code).

Word class (documented in RESULTS.md).  A word is an ultimately periodic timed word
u v^omega: letters L[0..n-1] (one letter per position: a proposition or 'other'),
start of the loop s, delays D[0..n-1] with D[i] = t_{i+1} - t_i (D[n-1] is the delay from the
last loop position to the first loop position of the next iteration), first timestamp t0.
All times are integers in HALF-UNITS (1 = 1/2 time unit); constants of formulas and
automata are multiplied by 2.  Timestamps are strictly increasing (all delays >= 1) and
diverge (the loop has positive duration).  Clocks start at 0 at time 0.

Three evaluators:
  judge       pointwise MTL semantics (as in the Rocq development, msat), evaluated on the lasso
  ours_accept acceptance of an mtl2tba UPPAAL XML (location acceptance, invariants, diagonals)
  gv_accept   acceptance of a CASAAL .gv automaton (transition-based, possibly generalized acceptance)
"""
import re
import xml.etree.ElementTree as ET

# ---------------------------------------------------------------- MTL parsing
# Syntax of mtl2tba (tool/src/lexer.mll, parser.mly): precedence from lowest to highest
#   U R ^U ^R (left) < | < & < -> (right) < <-> < prefix operators (! X [] G <> F ^[] ^<> ^G ^F)

TOK = re.compile(r'\s*(\^\[\]|\^<>|\^G|\^F|\^U|\^R|<->|<=>|->|=>|<=|>=|\[\]|<>|[()\[\]!&|<>]|\d+|[A-Za-z_][A-Za-z0-9_]*)')


def tokenize(s):
    out, pos = [], 0
    s = s.strip()
    while pos < len(s):
        m = TOK.match(s, pos)
        if not m:
            raise ValueError('cannot tokenize %r at %d' % (s, pos))
        out.append(m.group(1))
        pos = m.end()
    return out


class Parser:
    def __init__(self, s):
        self.t = tokenize(s)
        self.i = 0

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else None

    def eat(self, x=None):
        tok = self.peek()
        if x is not None and tok != x:
            raise ValueError('expected %r got %r' % (x, tok))
        self.i += 1
        return tok

    def ctr(self):
        if self.peek() == '[' and self.t[self.i + 1] in ('<=', '<', '>=', '>'):
            self.eat('[')
            op = self.eat()
            d = int(self.eat())
            self.eat(']')
            return (op, 2 * d)
        return None

    def parse(self):
        f = self.lvl_until()
        if self.peek() is not None:
            raise ValueError('trailing %r' % self.peek())
        return f

    def lvl_until(self):
        l = self.lvl_or()
        while self.peek() in ('U', 'R', '^U', '^R'):
            op = self.eat()
            c = self.ctr()
            r = self.lvl_or()
            l = ('U' if op in ('U', '^U') else 'R', c, l, r, op.startswith('^'))
        return l

    def lvl_or(self):
        l = self.lvl_and()
        while self.peek() == '|':
            self.eat()
            l = ('or', l, self.lvl_and())
        return l

    def lvl_and(self):
        l = self.lvl_imp()
        while self.peek() == '&':
            self.eat()
            l = ('and', l, self.lvl_imp())
        return l

    def lvl_imp(self):
        l = self.lvl_eqv()
        if self.peek() in ('->', '=>'):
            self.eat()
            r = self.lvl_imp()
            return ('or', ('not', l), r)
        return l

    def lvl_eqv(self):
        l = self.unary()
        if self.peek() in ('<->', '<=>'):
            self.eat()
            r = self.unary()
            return ('and', ('or', ('not', l), r), ('or', ('not', r), l))
        return l

    def unary(self):
        t = self.peek()
        if t == '!':
            self.eat()
            return ('not', self.unary())
        if t == 'X':
            self.eat()
            return ('next', self.unary())
        if t in ('[]', 'G', '^[]', '^G'):
            self.eat()
            c = self.ctr()
            return ('R', c, ('false',), self.unary(), t.startswith('^'))
        if t in ('<>', 'F', '^<>', '^F'):
            self.eat()
            c = self.ctr()
            return ('U', c, ('true',), self.unary(), t.startswith('^'))
        if t == '(':
            self.eat()
            f = self.lvl_until()
            self.eat(')')
            return f
        if t == 'true':
            self.eat()
            return ('true',)
        if t == 'false':
            self.eat()
            return ('false',)
        if t is not None and re.match(r'[A-Za-z_]', t):
            self.eat()
            return ('atom', t)
        raise ValueError('unexpected %r' % t)


def parse_mtl(s):
    return Parser(s).parse()


def mtl_props(f, acc=None):
    acc = set() if acc is None else acc
    if f[0] == 'atom':
        acc.add(f[1])
    else:
        for x in f[1:]:
            if isinstance(x, tuple) and x and isinstance(x[0], str):
                mtl_props(x, acc)
    return acc


# ---------------------------------------------------------------- the lasso word
class Word:
    def __init__(self, letters, s, delays, t0):
        self.L = list(letters)
        self.n = len(self.L)
        self.s = s
        self.q = self.n - s
        self.D = list(delays)
        self.t0 = t0
        assert 0 <= s < self.n and len(self.D) == self.n and t0 >= 1 and all(d >= 1 for d in self.D)
        # absolute times of positions 0..n-1 and period length
        self.T = [t0]
        for i in range(self.n - 1):
            self.T.append(self.T[-1] + self.D[i])
        self.P = sum(self.D[s:])           # duration of one loop iteration
        assert self.P > 0

    def can(self, pos):
        return pos if pos < self.n else self.s + (pos - self.s) % self.q

    def time(self, pos):
        if pos < self.n:
            return self.T[pos]
        k, r = divmod(pos - self.s, self.q)
        return self.T[self.s + r] + k * self.P

    def nxt(self, i):
        return i + 1 if i + 1 < self.n else self.s

    def __repr__(self):
        parts = []
        for i in range(self.n):
            mark = '|' if i == self.s else ''
            parts.append('%s%s@%g' % (mark, self.L[i], self.T[i] / 2))
        return 'word[' + ' '.join(parts) + ' ...loop dur %g]' % (self.P / 2)


# ---------------------------------------------------------------- judge
def in_interval(c, dt):
    if c is None:
        return True
    op, d = c
    return {'<=': dt <= d, '<': dt < d, '>=': dt >= d, '>': dt > d}[op]


def upper_violated(c, dt):
    if c is None:
        return False
    op, d = c
    return (op == '<=' and dt > d) or (op == '<' and dt >= d)


def judge(f, w, memo=None):
    """truth of f at position 0 of the lasso word w under the pointwise MTL semantics"""
    memo = {} if memo is None else memo
    return sat(f, w, memo)[0]


def sat(f, w, memo):
    key = f
    if key in memo:
        return memo[key]
    n = w.n
    k = f[0]
    if k == 'true':
        r = [True] * n
    elif k == 'false':
        r = [False] * n
    elif k == 'atom':
        r = [w.L[i] == f[1] for i in range(n)]
    elif k == 'not':
        r = [not x for x in sat(f[1], w, memo)]
    elif k == 'and':
        a, b = sat(f[1], w, memo), sat(f[2], w, memo)
        r = [x and y for x, y in zip(a, b)]
    elif k == 'or':
        a, b = sat(f[1], w, memo), sat(f[2], w, memo)
        r = [x or y for x, y in zip(a, b)]
    elif k == 'next':
        a = sat(f[1], w, memo)
        r = [a[w.nxt(i)] for i in range(n)]
    elif k == 'U':
        _, c, p, q, hat = f
        P, Q = sat(p, w, memo), sat(q, w, memo)
        r = [until_at(i, c, P, Q, hat, w) for i in range(n)]
    elif k == 'R':
        # p R_I q  =  not (not p U_I not q)   (the duality proved in the development)
        _, c, p, q, hat = f
        P = [not x for x in sat(p, w, memo)]
        Q = [not x for x in sat(q, w, memo)]
        r = [not until_at(i, c, P, Q, hat, w) for i in range(n)]
    else:
        raise ValueError(f)
    memo[key] = r
    return r


def until_at(i, c, P, Q, hat, w):
    """exists j >= i (j > i when hat) with t_j - t_i in I, Q at j, P at every k in [i,j) ((i,j) when hat)"""
    start = i + 1 if hat else i
    ti = w.time(i)
    j = start
    after_lower = 0          # positions seen since the lower bound was first met
    lower_met = False
    while True:
        dt = w.time(j) - ti
        if upper_violated(c, dt):
            return False
        ok = in_interval(c, dt)
        if ok:
            lower_met = True
            if Q[w.can(j)]:
                return True
        if lower_met:
            after_lower += 1
            if after_lower > w.n + w.q + 2:
                return False
        if not P[w.can(j)]:
            return False
        j += 1


# ---------------------------------------------------------------- automata: shared guard code
ATOM = re.compile(r'^\s*(\w+)\s*(?:-\s*(\w+)\s*)?(<=|>=|==|<|>|!=|=)\s*(-?\d+)\s*$')


def parse_constraint(text, clocks):
    """conjunction -> list of (i, j or None, op, const*2); i, j clock indices"""
    out = []
    if not text:
        return out
    for atom in re.split(r'&&|&amp;&amp;', text):
        atom = atom.strip().replace('&lt;', '<').replace('&gt;', '>')
        if not atom or atom == 'true':
            continue
        m = ATOM.match(atom)
        if not m:
            raise ValueError('constraint %r' % atom)
        x, y, op, c = m.groups()
        out.append((clocks[x], clocks[y] if y else None, '==' if op == '=' else op, 2 * int(c)))
    return out


class ClockState:
    """abstract clock state: values clipped at cap, pairwise differences clipped at +-cap"""

    def __init__(self, nclk, cap, diag):
        self.nclk, self.cap, self.diag = nclk, cap, diag

    def init(self):
        return (tuple([0] * self.nclk), tuple([0] * (self.nclk * self.nclk)) if self.diag else ())

    def delay(self, st, d):
        v, df = st
        return (tuple(min(x + d, self.cap) for x in v), df)

    def reset(self, st, rs):
        if not rs:
            return st
        v, df = st
        v = list(v)
        n = self.nclk
        if self.diag:
            df = list(df)
        for x in rs:
            v[x] = 0
        if self.diag:
            for x in rs:
                for y in range(n):
                    if y == x:
                        continue
                    d = max(-self.cap, min(self.cap, v[x] - v[y]))
                    # v[y] is clipped; difference with a reset clock is exact up to the clip
                    df[x * n + y] = d
                    df[y * n + x] = -d
        return (tuple(v), tuple(df) if self.diag else ())

    def holds(self, st, cons):
        v, df = st
        n = self.nclk
        for (x, y, op, c) in cons:
            val = v[x] if y is None else df[x * n + y]
            if op == '<=' and not val <= c: return False
            if op == '<' and not val < c: return False
            if op == '>=' and not val >= c: return False
            if op == '>' and not val > c: return False
            if op == '==' and not val == c: return False
            if op == '!=' and not val != c: return False
        return True


def tarjan_scc(nodes, succ):
    index, low, onst, st, sccs = {}, {}, set(), [], []
    counter = [0]
    import sys
    sys.setrecursionlimit(100000)

    def strong(v):
        index[v] = low[v] = counter[0]; counter[0] += 1
        st.append(v); onst.add(v)
        for u in succ.get(v, ()):
            if u not in index:
                strong(u); low[v] = min(low[v], low[u])
            elif u in onst:
                low[v] = min(low[v], index[u])
        if low[v] == index[v]:
            comp = []
            while True:
                u = st.pop(); onst.discard(u); comp.append(u)
                if u == v: break
            sccs.append(comp)
    for v in nodes:
        if v not in index:
            strong(v)
    return sccs


# ---------------------------------------------------------------- ours
class OursAut:
    def __init__(self, path):
        root = ET.parse(path).getroot()
        t = [t for t in root.findall('template') if t.findtext('name') == 'Property'][0]
        decl = t.findtext('declaration') or ''
        m = re.search(r'clock\s+([^;]+);', decl)
        names = [x.strip() for x in m.group(1).split(',')] if m else []
        self.clocks = {nm: i for i, nm in enumerate(names)}
        self.locs, self.acc, self.inv = {}, set(), {}
        for l in t.findall('location'):
            lid, nm = l.get('id'), l.findtext('name')
            self.locs[lid] = nm
            if nm.startswith('A'):
                self.acc.add(lid)
            inv = l.findtext("label[@kind='invariant']")
            self.inv[lid] = parse_constraint(inv, self.clocks)
        self.init = t.find('init').get('ref')
        self.edges = {}     # (src, letter) -> list of (guard, resets, tgt)
        consts, self.diag = [0], False
        for tr in t.findall('transition'):
            src, tgt = tr.find('source').get('ref'), tr.find('target').get('ref')
            g = parse_constraint(tr.findtext("label[@kind='guard']"), self.clocks)
            sy = tr.findtext("label[@kind='synchronisation']").rstrip('?')
            asg = tr.findtext("label[@kind='assignment']") or ''
            rs = [self.clocks[x] for x in re.findall(r'(\w+)\s*=\s*0', asg)]
            self.edges.setdefault((src, sy), []).append((g, rs, tgt))
            for cons in (g,):
                for (x, y, op, c) in cons:
                    consts.append(abs(c))
                    if y is not None: self.diag = True
        for cons in self.inv.values():
            for (x, y, op, c) in cons:
                consts.append(abs(c))
                if y is not None: self.diag = True
        self.cap = max(consts) + 1
        self.cs = ClockState(len(self.clocks), self.cap, self.diag)

    def accepts(self, w):
        cs = self.cs
        # nodes: (i, loc, state) = after event i; start pseudo node i = -1
        start = (-1, self.init, cs.init())
        succ, nodes, stack, seen = {}, [], [start], {start}
        while stack:
            node = stack.pop()
            i, loc, st = node
            ni = 0 if i == -1 else w.nxt(i)
            d = w.t0 if i == -1 else w.D[i]
            st2 = cs.delay(st, d)
            if not cs.holds(st2, self.inv[loc]):
                continue
            outs = []
            for (g, rs, tgt) in self.edges.get((loc, w.L[ni]), ()):
                if cs.holds(st2, g):
                    st3 = cs.reset(st2, rs)
                    outs.append((ni, tgt, st3))
            succ[node] = outs
            for o in outs:
                if o not in seen:
                    seen.add(o); stack.append(o)
        # loop part: nodes with i >= s (all reachable nodes with i != -1 and i >= s)
        loop_nodes = [v for v in seen if v[0] >= w.s]
        sub = {v: [u for u in succ.get(v, ()) if u[0] >= w.s] for v in loop_nodes}
        for comp in tarjan_scc(loop_nodes, sub):
            cset = set(comp)
            nontrivial = len(comp) > 1 or any(u in cset for u in sub.get(comp[0], ()))
            if nontrivial and any(v[1] in self.acc for v in comp):
                return True
        return False


# ---------------------------------------------------------------- CASAAL .gv
def _gv_tokens(text):
    toks, i = [], 0
    while i < len(text):
        ch = text[i]
        if ch.isspace():
            i += 1
        elif text.startswith('\\"', i):
            j = text.index('\\"', i + 2)
            toks.append(('q', text[i + 2:j])); i = j + 2
        elif ch in '()&|!':
            toks.append((ch, None)); i += 1
        else:
            m = re.match(r'reset\(\s*\w+\s*\)|\w+', text[i:])
            if not m:
                raise ValueError('gv token %r' % text[i:i + 20])
            toks.append(('w', m.group(0))); i += len(m.group(0))
    return toks


def _gv_dnf(text):
    """DNF of a CASAAL label: list of conjunctions; literal = ('p', name, positive) | ('c', clock, op, const, ) |
    ('r', clock)"""
    toks = _gv_tokens(text)
    pos = [0]

    def peek():
        return toks[pos[0]][0] if pos[0] < len(toks) else None

    def disj(neg):
        r = conj(neg)
        while peek() == '|':
            pos[0] += 1
            r2 = conj(neg)
            r = (r + r2) if not neg else cross(r, r2)  # under negation | becomes &
        return r

    def conj(neg):
        r = unary(neg)
        while peek() == '&':
            pos[0] += 1
            r2 = unary(neg)
            r = cross(r, r2) if not neg else (r + r2)  # under negation & becomes |
        return r

    def cross(a, b):
        return [x + y for x in a for y in b]

    def unary(neg):
        if peek() == '!':
            pos[0] += 1
            return unary(not neg)
        if peek() == '(':
            pos[0] += 1
            r = disj(neg)
            assert peek() == ')'
            pos[0] += 1
            return r
        kind, val = toks[pos[0]]
        pos[0] += 1
        if kind == 'q':
            m = re.fullmatch(r'\s*(\w+)\s*(<=|<|>=|>)\s*(\d+)\s*', val)
            x, op, c = m.groups()
            if neg:
                op = {'<=': '>', '<': '>=', '>=': '<', '>': '<='}[op]
            return [[('c', x, op, 2 * int(c))]]
        if val == '1':
            return [[]] if not neg else []
        if val == '0':
            return [] if not neg else [[]]
        m = re.fullmatch(r'reset\(\s*(\w+)\s*\)', val)
        if m:
            assert not neg
            return [[('r', m.group(1))]]
        return [[('p', val, not neg)]]
    r = disj(False)
    assert pos[0] == len(toks), text
    return r


def _acc_names(text):
    out, i = [], 0
    while True:
        j = text.find('Acc[', i)
        if j < 0:
            return out
        d, k = 0, j + 3
        while k < len(text):
            if text[k] == '[': d += 1
            elif text[k] == ']':
                d -= 1
                if d == 0: break
            k += 1
        out.append(text[j + 4:k]); i = k


UNBOUNDED_EVENTUALITY = re.compile(r'(F|U)(?![A-Za-z\[])|(F|U)\[x\d*>')


class GvAut:
    def __init__(self, path, props):
        s = open(path, encoding='utf-8').read()
        self.props = set(props)
        nodes = set(re.findall(r'^\s*(\d+)\s*\[label', s, re.M)) - {'0'}
        self.init = re.search(r'^\s*0\s*->\s*(\d+)', s, re.M).group(1)
        self.clocks, raw = {}, []
        for src, tgt, lab in re.findall(r'^\s*(\d+)\s*->\s*(\d+)\s*\[label="((?:[^"\\]|\\.)*)"\]', s, re.M):
            if src == '0':
                continue
            parts = lab.split('\\n')
            cube = parts[0].strip()
            marks = _acc_names(' '.join(parts[1:]))
            raw.append((src, tgt, cube, marks))
        consts, self.diag = [0], False
        self.edges = {}
        self.marks = set()
        for src, tgt, cube, marks in raw:
            alts = _gv_dnf(cube) if cube not in ('', '1') else [[]]
            for lits in alts:
                props, cons, rs = {}, [], []
                ok = True
                for l in lits:
                    if l[0] == 'p':
                        if props.get(l[1], l[2]) != l[2]: ok = False
                        props[l[1]] = l[2]
                    elif l[0] == 'c':
                        x = self.clocks.setdefault(l[1], len(self.clocks))
                        cons.append((x, None, l[2], l[3])); consts.append(l[3])
                    else:
                        rs.append(self.clocks.setdefault(l[1], len(self.clocks)))
                if not ok:
                    continue
                self.edges.setdefault(src, []).append((props, cons, rs, tgt, frozenset(marks)))
                self.marks |= set(marks)
        self.cap = max(consts) + 1
        self.cs = ClockState(len(self.clocks), self.cap, False)
        # no acceptance mark printed: accepting states are those without an undischarged eventuality
        self.good = None
        if not self.marks:
            text = dict(re.findall(r'^\s*(\d+)\s*\[label="((?:[^"\\]|\\.)*)"\]', s, re.M))
            pending = {n for n in nodes if UNBOUNDED_EVENTUALITY.search(text.get(n, ''))}
            if pending:
                self.good = set(n for n in nodes if n not in pending)
            else:
                self.good = None   # every infinite run accepts (marks empty, nothing pending)
        self.nodes = nodes

    def letter_ok(self, props, letter):
        # a letter makes its own proposition true and every other false ('other': all false)
        return all((p == letter) == v for p, v in props.items())

    def accepts(self, w):
        cs = self.cs
        start = (-1, self.init, cs.init())
        succ, stack, seen = {}, [start], {start}
        while stack:
            node = stack.pop()
            i, loc, st = node
            ni = 0 if i == -1 else w.nxt(i)
            d = w.t0 if i == -1 else w.D[i]
            st2 = cs.delay(st, d)
            outs = []
            for (props, cons, rs, tgt, marks) in self.edges.get(loc, ()):
                if self.letter_ok(props, w.L[ni]) and cs.holds(st2, cons):
                    outs.append(((ni, tgt, cs.reset(st2, rs)), marks))
            succ[node] = outs
            for o, _ in outs:
                if o not in seen:
                    seen.add(o); stack.append(o)
        loop_nodes = [v for v in seen if v[0] >= w.s]
        sub = {v: [u for u, _ in succ.get(v, ()) if u[0] >= w.s] for v in loop_nodes}
        for comp in tarjan_scc(loop_nodes, sub):
            cset = set(comp)
            inner = [(v, u, m) for v in comp for (u, m) in succ.get(v, ()) if u in cset]
            if not inner:
                continue
            if self.marks:
                have = set()
                for _, _, m in inner:
                    have |= m
                if self.marks <= have:
                    return True
            elif self.good is not None:
                if any(v[1] in self.good for v in comp):
                    return True
            else:
                return True
        return False

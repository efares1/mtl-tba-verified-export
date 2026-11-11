"""Clock interference and colouring for an automaton read by tck_product.from_xml (see clock_liveness.py)."""
import re
CLK = re.compile(r'[A-Za-z_]\w*')


def _reads(expr, clocks):
    return {c for c in CLK.findall(expr or '') if c in clocks}


def colouring(a):
    """Map each clock to a colour such that clocks of one colour never interfere."""
    clocks = {'%s_%s' % (a.name, x) for x in a.clocks}
    if not clocks:
        return {}
    live = {l: _reads(v[1], clocks) for l, v in a.locs.items()}
    changed = True
    while changed:
        changed = False
        for (s, t, ev, g, rs, _) in a.edges:
            new = _reads(g, clocks) | (live[t] - set(rs))
            if not new <= live[s]:
                live[s] |= new
                changed = True
    adj = {c: set() for c in clocks}

    def link(x, y):
        if x != y:
            adj[x].add(y)
            adj[y].add(x)
    for l in a.locs:
        for x in live[l]:
            for y in live[l]:
                link(x, y)
    for (s, t, ev, g, rs, _) in a.edges:
        for r in rs:
            for c in live[t]:
                link(r, c)
    col = {}
    while len(col) < len(clocks):
        u = max((c for c in clocks if c not in col), key=lambda c: (len({col[n] for n in adj[c] if n in col}), len(adj[c])))
        used = {col[n] for n in adj[u] if n in col}
        k = 0
        while k in used:
            k += 1
        col[u] = k
    return col

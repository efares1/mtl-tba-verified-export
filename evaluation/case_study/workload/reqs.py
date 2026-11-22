r"""Requirement and system families of the broader workload (assumptions -> guarantee).
 gateway(k):   (a_i -> <>[<=5] b_i for i<=k)  ->  [](a1 -> <>[<=5] done);  system: k-channel gateway, 'done' after the answer of channel 1
 pipeline(k):  (s_{i-1} -> <>[<=5] s_i for i<=k) -> [](s0 -> <>[<=L] s_k);  system: k stages of latency 1..5; ok: L=5k, bad: L=5k-1
 twosided(k):  (a_i -> <>[<=5] b_i for i<=k) -> [](a1 -> <>[<=5] done1) /\ [](a2 -> <>[<=5] done2); system: gateway with two follow-up events
Each entry: (name, ours formula, CASAAL formula, events, system xml builder) for the NEGATED requirement."""

def conj(parts, sep):
    return sep.join(f'({p})' for p in parts)

def imp(l, r):
    return f'(({l}) -> ({r}))'

def box_resp(a, b, n):
    return f'[]({a} -> <>[<={n}] {b})'

def build(family, k, variant):
    if family == 'gateway':
        asm = [box_resp(f'a{i}', f'b{i}', 5) for i in range(1, k + 1)]
        gua = box_resp('a1', 'done', 5)
        events = [f'a{i}' for i in range(1, k + 1)] + [f'b{i}' for i in range(1, k + 1)] + ['done']
    elif family == 'pipeline':
        asm = [box_resp(f's{i-1}', f's{i}', 5) for i in range(1, k + 1)]
        L = 5 * k if variant == 'ok' else 5 * k - 1
        gua = box_resp('s0', f's{k}', L)
        events = [f's{i}' for i in range(0, k + 1)]
    elif family == 'twosided':
        asm = [box_resp(f'a{i}', f'b{i}', 5) for i in range(1, k + 1)]
        gua = box_resp('a1', 'done1', 5) + ' & ' + box_resp('a2', 'done2', 5)
        events = [f'a{i}' for i in range(1, k + 1)] + [f'b{i}' for i in range(1, k + 1)] + ['done1', 'done2']
    ours = '!(' + imp(conj(asm, ' & '), gua) + ')'
    AND = ' /' + chr(92) + ' '
    cas = '!(' + imp(conj(asm, AND), gua.replace(' & ', AND)) + ')'
    return ours, cas, events

def system_xml(family, k, variant):
    """plain system model (template Property): each event is an input, y is the only clock"""
    locs, trans = [('i', 'Idle', None)], []
    def L(i, n, inv): locs.append((i, n, inv))
    def T(s, t, ev, g=None, reset=True):
        trans.append((s, t, ev, g, reset))
    if family in ('gateway', 'twosided'):
        for j in range(1, k + 1):
            L(f'w{j}', f'Busy{j}', 'x0 <= 2')
        L('d', 'Done', 'x0 <= 2' if variant == 'ok' else 'x0 <= 6')
        if family == 'twosided':
            L('d2', 'Done2', 'x0 <= 2' if variant == 'ok' else 'x0 <= 6')
        for j in range(1, k + 1):
            T('i', f'w{j}', f'a{j}')
            nxt = 'd' if j == 1 else ('d2' if (j == 2 and family == 'twosided') else 'i')
            T(f'w{j}', nxt, f'b{j}', 'x0 >= 1')
        if family == 'twosided':
            T('d', 'i', 'done1', 'x0 >= 1')
            T('d2', 'i', 'done2', 'x0 >= 1')
        else:
            T('d', 'i', 'done', 'x0 >= 1')
    else:  # pipeline: s0 starts, stage i completes after 1..5
        for j in range(1, k + 1):
            L(f'w{j}', f'Stage{j}', 'x0 <= 5')
        T('i', 'w1', 's0')
        for j in range(1, k + 1):
            T(f'w{j}', f'w{j+1}' if j < k else 'i', f's{j}', 'x0 >= 1')
    s = '<nta><template><name>Property</name><declaration>clock x0;</declaration>\n'
    for i, n, inv in locs:
        s += f'<location id="{i}"><name>{n}</name>' + (f'<label kind="invariant">{inv.replace("<", "&lt;")}</label>' if inv else '') + '</location>\n'
    s += '<init ref="i"/>\n'
    for sct, t, ev, g, r in trans:
        s += f'<transition><source ref="{sct}"/><target ref="{t}"/>'
        if g:
            s += f'<label kind="guard">{g.replace(">", "&gt;")}</label>'
        s += f'<label kind="synchronisation">{ev}?</label><label kind="assignment">x0 = 0</label></transition>\n'
    return s + '</template></nta>\n'

ALL = [('gateway', k) for k in (2, 3, 4, 5)] + [('pipeline', k) for k in (2, 3, 4, 5)] + [('twosided', k) for k in (3, 4)]

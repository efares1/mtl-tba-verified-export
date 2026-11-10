"""Build the UPPAAL models of the case study (Section VI, conditions C1-C5).

For each safety requirement, the automaton that mtl2tba produces for its
negation (negspor.xml, negresp.xml) is composed with a correct and a faulty
system model; the Env template of the tool is removed (condition C1).
Every system clock z is reset by each emission and tested by z > 0, so that
event times strictly increase, and every system can let time diverge.
Queries (models/*.q):
  E<> P.A4          violation reachable (expected: false / true)
and, on the system alone with a receiver of every channel,
  A[] not deadlock  the system never blocks time (expected: true).
Usage: python make_models.py   (then run run_uppaal.sh with verifyta)
"""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'models')
os.makedirs(OUT, exist_ok=True)

def edge(src, tgt, sync, guard=None, assign=None):
    s = f'    <transition>\n      <source ref="{src}"/>\n      <target ref="{tgt}"/>\n'
    if guard:
        s += f'      <label kind="guard">{guard.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")}</label>\n'
    s += f'      <label kind="synchronisation">{sync}</label>\n'
    if assign:
        s += f'      <label kind="assignment">{assign}</label>\n'
    return s + '    </transition>\n'

def loc(i, name, inv=None):
    s = f'    <location id="{i}" x="0" y="0">\n      <name>{name}</name>\n'
    if inv:
        s += f'      <label kind="invariant">{inv.replace("<", "&lt;")}</label>\n'
    return s + '    </location>\n'

def sporadic(k):
    """emits e at least k time units apart, and other events at any time"""
    return ('  <template>\n    <name>Sys</name>\n    <declaration>clock y, z;</declaration>\n'
            + loc('s0', 'S') + '    <init ref="s0"/>\n'
            + edge('s0', 's0', 'e!', f'y >= {k} && z > 0', 'y = 0, z = 0')
            + edge('s0', 's0', 'other!', 'z > 0', 'z = 0')
            + '  </template>\n')

def response(d):
    """grants q within d time units after each request p"""
    return ('  <template>\n    <name>Sys</name>\n    <declaration>clock y, z;</declaration>\n'
            + loc('s0', 'Idle') + loc('s1', 'Busy', f'y <= {d}') + '    <init ref="s0"/>\n'
            + edge('s0', 's1', 'p!', 'z > 0', 'y = 0, z = 0')
            + edge('s0', 's0', 'other!', 'z > 0', 'z = 0')
            + edge('s1', 's1', 'other!', f'z > 0 && y < {d}', 'z = 0')
            + edge('s1', 's0', 'q!', 'z > 0 && y >= 1', 'z = 0')
            + '  </template>\n')

def sink(chans):
    return ('  <template>\n    <name>Recv</name>\n' + loc('r0', 'R') + '    <init ref="r0"/>\n'
            + ''.join(edge('r0', 'r0', c + '?') for c in chans) + '  </template>\n')

def property_part(xml):
    decl = re.search(r'<declaration>(chan [^<]*)</declaration>', xml).group(1)
    tpl = re.search(r'  <template>\s*<name>Property</name>.*?</template>\n', xml, re.S).group(0)
    return decl, tpl

HEAD = ("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!DOCTYPE nta PUBLIC '-//Uppaal Team//DTD Flat "
        "System 1.1//EN' 'http://www.it.uu.se/research/group/darts/uppaal/flat-1_2.dtd'>\n<nta>\n")

cases = [('spor', 'negspor.xml', ['e', 'other'], [('ok', sporadic(2)), ('bad', sporadic(1))]),
         ('resp', 'negresp.xml', ['p', 'q', 'other'], [('ok', response(4)), ('bad', response(6))])]
for name, src, chans, systems in cases:
    decl, prop = property_part(open(os.path.join(HERE, src), encoding='utf-8').read())
    acc = sorted(set(re.findall(r'<name>(A\d+)</name>', prop)))
    sinkloc = acc[-1]
    for tag, sys_t in systems:
        with open(os.path.join(OUT, f'{name}_{tag}.xml'), 'w', encoding='utf-8') as f:
            f.write(HEAD + f'  <declaration>{decl}</declaration>\n' + prop + sys_t
                    + '  <system>P = Property();\nS = Sys();\nsystem P, S;</system>\n</nta>\n')
        with open(os.path.join(OUT, f'{name}_{tag}.q'), 'w', encoding='utf-8') as f:
            f.write(f'E<> P.{sinkloc}\n')
        with open(os.path.join(OUT, f'{name}_{tag}_alone.xml'), 'w', encoding='utf-8') as f:
            f.write(HEAD + f'  <declaration>{decl}</declaration>\n' + sys_t + sink(chans)
                    + '  <system>S = Sys();\nR = Recv();\nsystem S, R;</system>\n</nta>\n')
        with open(os.path.join(OUT, f'{name}_{tag}_alone.q'), 'w', encoding='utf-8') as f:
            f.write('A[] not deadlock\n')
print(sorted(os.listdir(OUT)))

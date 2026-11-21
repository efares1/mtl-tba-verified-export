"""Realistic case study: a dual-chamber pacemaker (heart and controller as one timed system).

Observable events: asn (atrial sense), apc (atrial pace), vsn (ventricular sense), vpc (ventricular pace).
Requirements (MTL, time unit = 10 ms):
  P1 atrioventricular delay:  every atrial event is followed by a ventricular event within 15
  P2 lower rate:              every ventricular event is followed by an atrial event within 50
  P3 upper rate:              ventricular events are at least 24 apart
  P4 atrial refractory:       no atrial pace within 3 after an atrial sense
  ALL = P1 & P2 & P3 & P4
For each requirement the automaton of its negation is produced by mtl2tba (WSL), in three variants
(default optimizer, no optimizer -n 0, all-copy export), composed with five systems (one correct, four faulty),
and UPPAAL 5 (verifyta) decides whether a violation is reachable.  Conditions C1-C3 of the article:
a global clock z is reset by each event and tested by z>0, and the timelock check A[] not deadlock is run
on every system with a receiver of every channel.
Usage: python run_pacemaker.py
"""
import os, re, subprocess, sys, csv, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
TOOL = '/mnt/c/' + REPO[3:].replace('\\', '/') + '/tool/_build/default/src/mtl2tba.exe'
VERIFYTA = r'C:\Program Files (x86)\UPPAAL-5.0.0\bin\verifyta.exe'
OUT = os.path.join(HERE, 'models')
os.makedirs(OUT, exist_ok=True)
A = '(asn | apc)'
V = '(vsn | vpc)'
REQS = {
    'P1': f'[]({A} -> <>[<=15] {V})',
    'P2': f'[]({V} -> <>[<=50] {A})',
    'P3': f'[]({V} -> ^[][<24] !{V})',
    'P4': '[](asn -> ^[][<=3] !apc)',
}
REQS['ALL'] = ' & '.join('(' + REQS[k] + ')' for k in ['P1', 'P2', 'P3', 'P4'])
VARIANTS = {'opt': '', 'noopt': '-n 0', 'allcopy': '-all-copy', 'alloc': '-alloc'}
# systems: (avi, lri_wait, min_aa, min_av, spurious atrial pace after sense)
SYSTEMS = {
    'ok':   dict(avi=15, wa=35, minaa=20, minav=5, spur=False),
    'bad1': dict(avi=20, wa=35, minaa=20, minav=5, spur=False),   # AV delay 20 > 15
    'bad2': dict(avi=15, wa=60, minaa=20, minav=5, spur=False),   # atrial wait up to 60: ventricular to atrial 75 > 50
    'bad3': dict(avi=15, wa=35, minaa=10, minav=5, spur=False),   # ventricular events 15 apart < 24
    'bad4': dict(avi=15, wa=35, minaa=20, minav=5, spur=True),    # atrial pace 1..2 after an atrial sense
}
EXPECT = {  # requirement violated by the system
    'ok': set(), 'bad1': {'P1', 'ALL'}, 'bad2': {'P2', 'ALL'}, 'bad3': {'P3', 'ALL'}, 'bad4': {'P4', 'ALL'},
}
CHANS = ['asn', 'apc', 'vsn', 'vpc']


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def loc(i, name, inv=None):
    s = f'    <location id="{i}" x="0" y="0">\n      <name>{name}</name>\n'
    if inv:
        s += f'      <label kind="invariant">{esc(inv)}</label>\n'
    return s + '    </location>\n'


def edge(src, tgt, sync, guard=None, assign=None):
    s = f'    <transition>\n      <source ref="{src}"/>\n      <target ref="{tgt}"/>\n'
    if guard:
        s += f'      <label kind="guard">{esc(guard)}</label>\n'
    if sync:
        s += f'      <label kind="synchronisation">{sync}</label>\n'
    if assign:
        s += f'      <label kind="assignment">{assign}</label>\n'
    return s + '    </transition>\n'


def system_template(p, alpha=None):
    """Heart and pacemaker.  A: waiting for an atrial event (x since the last ventricular event);
    V: waiting for a ventricular event (u since the atrial event); VS: like V after an atrial sense."""
    alpha = alpha or set(CHANS)

    def ch(c):
        return (c if c in alpha else 'other') + '!'
    t = '  <template>\n    <name>Sys</name>\n    <declaration>clock x, u;</declaration>\n'
    t += loc('a', 'A', f"x <= {p['wa']}") + loc('v', 'V', f"u <= {p['avi']}") + loc('vs', 'VS', f"u <= {p['avi']}")
    t += '    <init ref="a"/>\n'
    t += edge('a', 'vs', ch('asn'), f"x >= {p['minaa']} && x < {p['wa']} && z > 0", 'u = 0, z = 0')
    t += edge('a', 'v', ch('apc'), f"x >= {p['wa']} && z > 0", 'u = 0, z = 0')
    for src in ('v', 'vs'):
        t += edge(src, 'a', ch('vsn'), f"u >= {p['minav']} && u < {p['avi']} && z > 0", 'x = 0, z = 0')
        t += edge(src, 'a', ch('vpc'), f"u >= {p['avi']} && z > 0", 'x = 0, z = 0')
    if p['spur']:
        t += edge('vs', 'vs', ch('apc'), 'u >= 1 && u <= 2 && z > 0', 'z = 0')
    return t + '  </template>\n'


def receiver():
    return ('  <template>\n    <name>Recv</name>\n' + loc('r0', 'R') + '    <init ref="r0"/>\n'
            + ''.join(edge('r0', 'r0', c + '?') for c in CHANS + ['other']) + '  </template>\n')


HEAD = ("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!DOCTYPE nta PUBLIC '-//Uppaal Team//DTD Flat "
        "System 1.1//EN' 'http://www.it.uu.se/research/group/darts/uppaal/flat-1_2.dtd'>\n<nta>\n")


def property_part(xml):
    decl = re.search(r'<declaration>(chan [^<]*)</declaration>', xml).group(1)
    tpl = re.search(r'  <template>\s*<name>Property</name>.*?</template>\n', xml, re.S).group(0)
    return decl, tpl


def wsl_path(p):
    return '/mnt/c/' + p[3:].replace('\\', '/')


def gen_property(req, variant, key):
    base = os.path.join(OUT, f'prop_{key}_{variant}')
    cmd = f"{TOOL} -nopdf -stats {VARIANTS[variant]} -o {wsl_path(base)} '!({REQS[req]})'"
    r = subprocess.run(['wsl', '-e', 'bash', '-lc', cmd], capture_output=True, text=True)
    lines = [l for l in r.stdout.strip().splitlines() if l.strip()]
    stats = lines[-1].split('\t') if lines else []
    return base + '.xml', stats


def uppaal(xml, query):
    qf = xml[:-4] + '.q'
    open(qf, 'w').write(query + '\n')
    t0 = time.time()
    r = subprocess.run([VERIFYTA, '-t0', '-s', '-u', xml, qf], capture_output=True, text=True)
    out = r.stdout + r.stderr
    verdict = 'sat' if re.search(r'Formula is satisfied', out) else ('unsat' if 'NOT satisfied' in out else 'ERR')
    m = re.search(r'States explored\s*:\s*(\d+)', out)
    states = int(m.group(1)) if m else -1
    return verdict, states, time.time() - t0


def main():
    rows = []
    for req in REQS:
        for variant in VARIANTS:
            pxml, stats = gen_property(req, variant, req)
            decl, prop = property_part(open(pxml, encoding='utf-8').read())
            acc = sorted(set(re.findall(r'<name>(A\d+)</name>', prop)), key=lambda n: int(n[1:]))
            alpha = set(re.findall(r'\w+', decl)) - {'chan'}
            ids = dict((n, i) for i, n in re.findall(r'<location id="(\w+)"[^>]*>\s*<name>(\w+)</name>', prop))
            trs = re.findall(r'<source ref="(\w+)"/>\s*<target ref="(\w+)"/>', prop)
            sinks = [n for n in acc if all(t == ids[n] for s, t in trs if s == ids[n])]
            assert sinks, 'no accepting sink in ' + pxml
            query = 'E<> ' + ' || '.join('P.' + n for n in sinks)
            for sysname, p in SYSTEMS.items():
                model = os.path.join(OUT, f'{req}_{variant}_{sysname}.xml')
                with open(model, 'w', encoding='utf-8') as f:
                    f.write(HEAD + f'  <declaration>{decl} clock z;</declaration>\n' + prop + system_template(p, alpha)
                            + '  <system>P = Property();\nS = Sys();\nsystem P, S;</system>\n</nta>\n')
                v, st, sec = uppaal(model, query)
                expected = 'sat' if req in EXPECT[sysname] else 'unsat'
                rows.append([req, variant, sysname, v, expected, v == expected, st, round(sec, 2)] + [stats[5]] + stats[7:14])
                print(rows[-1], flush=True)
    for sysname, p in SYSTEMS.items():
        model = os.path.join(OUT, f'alone_{sysname}.xml')
        with open(model, 'w', encoding='utf-8') as f:
            f.write(HEAD + f'  <declaration>chan {", ".join(CHANS)}, other; clock z;</declaration>\n' + system_template(p)
                    + receiver() + '  <system>S = Sys();\nR = Recv();\nsystem S, R;</system>\n</nta>\n')
        v, st, sec = uppaal(model, 'A[] not deadlock')
        rows.append(['timelock', '-', sysname, v, 'sat', v == 'sat', st, round(sec, 2)])
        print(rows[-1], flush=True)
    with open(os.path.join(HERE, 'pacemaker_results.tsv'), 'w', newline='') as f:
        w = csv.writer(f, delimiter='\t')
        w.writerow(['requirement', 'automaton', 'system', 'verdict', 'expected', 'agree', 'states', 'seconds',
                    'comp_trans', 'opt_rounds', 'opt_locs', 'opt_trans', 'opt_clocks', 'exp_locs', 'exp_trans', 'exp_clocks'])
        w.writerows(rows)
    bad = [r for r in rows if not r[5]]
    print('runs:', len(rows), 'disagreements:', len(bad))


def gateway_template(k, d_bad=None):
    """A single-threaded gateway: it accepts request a_i (any i) and answers with b_i after 1 to d time units.
    d = 4 (correct); with d_bad the last channel answers after up to d_bad (faulty)."""
    t = '  <template>\n    <name>Sys</name>\n    <declaration>clock y;</declaration>\n' + loc('idle', 'Idle')
    for i in range(1, k + 1):
        d = d_bad if (d_bad and i == k) else 4
        t += loc(f'b{i}', f'Busy{i}', f'y <= {d}')
    t += '    <init ref="idle"/>\n'
    for i in range(1, k + 1):
        t += edge('idle', f'b{i}', f'a{i}!', 'z > 0', 'y = 0, z = 0')
        t += edge(f'b{i}', 'idle', f'b{i}!', 'y >= 1 && z > 0', 'z = 0')
    return t + '  </template>\n'


def gateway():
    rows = []
    for k in (2, 3, 4, 5, 6):
        req = ' & '.join(f'[](a{i} -> <>[<=5] b{i})' for i in range(1, k + 1))
        chans = [f'{c}{i}' for i in range(1, k + 1) for c in 'ab']
        for variant in VARIANTS:
            base = os.path.join(OUT, f'gw{k}_{variant}')
            cmd = f"{TOOL} -nopdf -stats {VARIANTS[variant]} -o {wsl_path(base)} '!({req})'"
            r = subprocess.run(['wsl', '-e', 'bash', '-lc', cmd], capture_output=True, text=True)
            stats = [l for l in r.stdout.strip().splitlines() if l.strip()][-1].split('\t')
            decl, prop = property_part(open(base + '.xml', encoding='utf-8').read())
            acc = sorted(set(re.findall(r'<name>(A\d+)</name>', prop)), key=lambda n: int(n[1:]))
            ids = dict((n, i) for i, n in re.findall(r'<location id="(\w+)"[^>]*>\s*<name>(\w+)</name>', prop))
            trs = re.findall(r'<source ref="(\w+)"/>\s*<target ref="(\w+)"/>', prop)
            sinks = [n for n in acc if all(t == ids[n] for s, t in trs if s == ids[n])]
            query = 'E<> ' + ' || '.join('P.' + n for n in sinks)
            for sysname, dbad in (('ok', None), ('bad', 6)):
                model = base + f'_{sysname}.xml'
                with open(model, 'w', encoding='utf-8') as f:
                    f.write(HEAD + f'  <declaration>{decl} clock z;</declaration>\n' + prop + gateway_template(k, dbad)
                            + '  <system>P = Property();\nS = Sys();\nsystem P, S;</system>\n</nta>\n')
                v, st, sec = uppaal(model, query)
                expected = 'sat' if sysname == 'bad' else 'unsat'
                rows.append([f'gateway k={k}', variant, sysname, v, expected, v == expected, st, round(sec, 2),
                             stats[5], stats[7], stats[8], stats[9], stats[10], stats[11], stats[12], stats[13]])
                print(rows[-1], flush=True)
        model = os.path.join(OUT, f'gwalone{k}.xml')
        with open(model, 'w', encoding='utf-8') as f:
            f.write(HEAD + f'  <declaration>chan {", ".join(chans)}; clock z;</declaration>\n' + gateway_template(k, 6)
                    + '  <template>\n    <name>Recv</name>\n' + loc('r0', 'R') + '    <init ref="r0"/>\n'
                    + ''.join(edge('r0', 'r0', c + '?') for c in chans) + '  </template>\n'
                    + '  <system>S = Sys();\nR = Recv();\nsystem S, R;</system>\n</nta>\n')
        v, st, sec = uppaal(model, 'A[] not deadlock')
        rows.append([f'gateway k={k}', '-', 'timelock', v, 'sat', v == 'sat', st, round(sec, 2)])
        print(rows[-1], flush=True)
    with open(os.path.join(HERE, 'gateway_results.tsv'), 'w', newline='') as f:
        w = csv.writer(f, delimiter='\t')
        w.writerow(['requirement', 'automaton', 'system', 'verdict', 'expected', 'agree', 'states', 'seconds',
                    'comp_trans', 'opt_rounds', 'opt_locs', 'opt_trans', 'opt_clocks', 'exp_locs', 'exp_trans', 'exp_clocks'])
        w.writerows(rows)
    print('gateway runs:', len(rows), 'disagreements:', len([r for r in rows if not r[5]]))


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'gateway':
        gateway()
    else:
        main()

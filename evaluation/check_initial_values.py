"""Check that the acceptance of the exported automata does not depend on the
initial values of the clocks.

For every automaton out/<id>.dot written by run_tool_eval.sh, the script
checks that the initial location has no invariant and that no clock is read,
by a guard or an invariant, on a path from the initial location before it has
been reset.  The existential acceptance notion of the Coq development, in
which clocks may start at any nonnegative value, then coincides with the runs
of UPPAAL, which start the clocks at 0, whatever the time of the first event.

    python check_initial_values.py [out-directory]
"""
import glob
import os
import re
import sys


def check(path):
    s = open(path, encoding='utf-8').read()
    init = re.search(r'init -> (L\d+);', s).group(1)
    inv = {m.group(1): set(re.findall(r'x\d+', m.group(2)))
           for m in re.finditer(r'\n\s*(L\d+) \[shape=\w+, label="([^"]*)"\]', s)}
    edges = []
    for m in re.finditer(r'\n\s*(L\d+) -> (L\d+) \[label="([^"]*)"\]', s):
        guard, reset = set(), set()
        for line in m.group(3).split('\\n'):
            (reset if ':=' in line else guard).update(re.findall(r'x\d+', line))
        edges.append((m.group(1), m.group(2), guard, reset))
    problems = []
    if inv.get(init):
        problems.append('invariant on the initial location')
    for c in set(re.findall(r'\bx\d+\b', s)):
        # locations from which c may be read before being reset
        live = {l for l, v in inv.items() if c in v}
        live |= {a for a, _, g, _ in edges if c in g}
        changed = True
        while changed:
            changed = False
            for a, b, _, r in edges:
                if b in live and c not in r and a not in live:
                    live.add(a)
                    changed = True
        if init in live:
            problems.append('clock %s may be read before being reset' % c)
    return problems


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), 'out')
    ok = True
    for path in sorted(glob.glob(os.path.join(d, '*.dot'))):
        problems = check(path)
        ok = ok and not problems
        print('%-8s %s' % (os.path.basename(path)[:-4], '; '.join(problems) or 'ok'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Spot wrapper for the primed configurations (experiment, not used by the tool).

Called by mtl2tba through its option -spot with the arguments of ltl2tgba
(... -F file).  It replaces, in the clocked-LTL formula, the Until of the
clauses of upper-bounded hatted Until,
    (("x <= d" & ("unch(x)" & P)) U Q   or   (("x < d" & ("unch(x)" & P)) U Q,
by a weak until W, then calls ltl2tgba on the rewritten formula.  On the
clock-consistent extensions of divergent timed words the two formulas are
equivalent, since x is never reset while the clause waits and time diverges;
the correctness theorem of mtl2tba does not cover this variant.
"""
import os
import re
import subprocess
import sys
import tempfile

PAT = re.compile(r'(\(\("x\d+ <=? [0-9.]+" & \("unch\(x\d+\)" & )')


def rewrite(s):
    out, i = [], 0
    while True:
        m = PAT.search(s, i)
        if not m:
            out.append(s[i:])
            return ''.join(out)
        # find the parenthesis that closes the left operand
        start = m.start() + 1        # the parenthesis that opens the left operand
        depth, j = 0, start
        while True:
            if s[j] == '(':
                depth += 1
            elif s[j] == ')':
                depth -= 1
                if depth == 0:
                    break
            elif s[j] == '"':
                j = s.index('"', j + 1)
            j += 1
        # s[start..j] is the left operand; it must be followed by " U "
        if s.startswith(' U ', j + 1):
            out.append(s[i:j + 1] + ' W ')
            i = j + 4
        else:
            out.append(s[i:j + 1])
            i = j + 1


def main():
    args = sys.argv[1:]
    k = args.index('-F')
    src = args[k + 1]
    f = open(src, encoding='utf-8').read()
    g = rewrite(f)
    fd, tmp = tempfile.mkstemp(suffix='.ltl')
    with os.fdopen(fd, 'w', encoding='utf-8') as h:
        h.write(g)
    args[k + 1] = tmp
    if os.environ.get('SPOT_WEAK_LOG'):
        with open(os.environ['SPOT_WEAK_LOG'], 'a', encoding='utf-8') as h:
            h.write(f'{f.count(" U ")} U -> {g.count(" W ")} W\n')
    r = subprocess.call(['ltl2tgba'] + args)
    os.remove(tmp)
    sys.exit(r)


if __name__ == '__main__':
    main()

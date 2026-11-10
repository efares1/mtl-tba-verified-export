"""Audit of the Coq development: no Admitted, admit, Abort, Parameter,
Hypothesis, or Conjecture outside comments, and the list of the Axioms.

    python3 tools/audit.py          (from the folder proof/)

Comments (* ... *), possibly nested, and string literals are removed before
the search.  Exit status 1 if a forbidden command is found.
"""
import glob
import os
import re
import sys

FORBIDDEN = ['Admitted', 'admit', 'Abort', 'Parameter', 'Parameters',
             'Hypothesis', 'Hypotheses', 'Conjecture']


def strip(text):
    out, i, depth, n = [], 0, 0, len(text)
    while i < n:
        if text.startswith('(*', i):
            depth += 1
            i += 2
        elif depth and text.startswith('*)', i):
            depth -= 1
            i += 2
        elif depth:
            out.append('\n' if text[i] == '\n' else ' ')
            i += 1
        elif text[i] == '"':
            j = text.find('"', i + 1)
            j = n - 1 if j < 0 else j
            out.append(' ' * (j - i + 1))
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad, axioms = [], []
    for f in sorted(glob.glob(os.path.join(here, '*.v'))):
        code = strip(open(f, encoding='utf-8').read())
        for k, line in enumerate(code.splitlines(), 1):
            for w in FORBIDDEN:
                if re.search(r'(?<![\w.])' + w + r'(?![\w])', line):
                    bad.append(f'{os.path.basename(f)}:{k}: {w}')
            m = re.match(r'\s*Axiom\s+(\w+)', line)
            if m:
                axioms.append(f'{os.path.basename(f)}:{k}: {m.group(1)}')
    print('forbidden commands outside comments:', 'none' if not bad else '')
    for b in bad:
        print('  ' + b)
    print('Axiom declarations:')
    for a in axioms:
        print('  ' + a)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()

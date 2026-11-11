"""Step 1 of the isomorphism check against CASAAL (run under WSL).
For every pattern with a CASAAL automaton of the negated requirement
(casaal_out_neg/<id>.gv), write to isomorphism/dots/:
  <id>_ours.dot   mtl2tba on the negated requirement (default options, exported)
  <id>_imp.dot    CASAAL's automaton, imported (casaal_to_tba.py), exported with -n 0
  <id>_impopt.dot the same import after the verified optimizer, exported
Step 2 (iso_compare.py) decides isomorphism.
Usage: python3 iso_generate.py [LIMIT_SECONDS] [ID ...]"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.environ.get('EXE', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'mtl2tba.exe'))
OPT = os.environ.get('OPT', os.path.join(HERE, '..', 'tool', '_build', 'default', 'src', 'tba_opt.exe'))
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 300
ONLY = set(sys.argv[2:])
D = os.path.join(HERE, 'isomorphism', 'dots')
os.makedirs(D, exist_ok=True)


def sh(cmd, cwd=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=LIMIT)
        return r.returncode
    except subprocess.TimeoutExpired:
        return 124


for l in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf8'):
    rec = l.rstrip('\n').split('\t')
    if l.startswith('#') or len(rec) < 4:
        continue
    i, desc, ours, cas = rec[:4]
    if ONLY and i not in ONLY:
        continue
    if cas.startswith('~') or cas == '-' or not cas:
        continue
    gv = os.path.join(HERE, 'casaal_out_neg', i + '.gv')
    if not os.path.exists(gv):
        continue
    events = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', ours)) - {'true', 'false'})
    tba = os.path.join(D, i + '.tba')
    os.environ['CASAAL_ACCEPT_UNMARKED'] = '1'
    rc = sh([sys.executable, os.path.join(HERE, 'casaal_to_tba.py'), gv, tba, ','.join(events)])
    if rc != 0:
        print(i, 'not converted', rc, flush=True)
        continue
    r1 = sh([EXE, '-nopdf', '-o', os.path.join(D, i + '_ours'), '!(%s)' % ours], cwd=D)
    r2 = sh([OPT, '-n', '0', '-o', os.path.join(D, i + '_imp'), tba])
    r3 = sh([OPT, '-o', os.path.join(D, i + '_impopt'), tba])
    print(i, r1, r2, r3, flush=True)

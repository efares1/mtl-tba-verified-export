"""Helpers for the mutation study (run inside WSL)."""
import os, re, subprocess, sys, hashlib, glob
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import to_canon

HOME = os.path.expanduser('~')
LC = HOME + '/mut/exe/lang_cmp'
CORPUS = sorted(glob.glob(os.path.join(HERE, 'corpus', '*.tba')))
POLICIES = [('md', []), ('ac', ['-all-copy'])]


def sh(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout, r.stderr
    except subprocess.TimeoutExpired:
        return 124, '', 'timeout'


def events_of(tba):
    for line in open(tba):
        if line.startswith('events'):
            return line.split()[1:]
    return []


def run_corpus(exe, outdir):
    """Run tba_opt (default rounds) on every corpus TBA under both export policies.
    Writes <name>.<pol>.xml and <name>.opt.tba; returns {name: status}."""
    os.makedirs(outdir, exist_ok=True)
    st = {}
    for p in CORPUS:
        name = os.path.basename(p)[:-4]
        for pol, flags in POLICIES:
            base = os.path.join(outdir, name + '.' + pol)
            rc, out, err = sh([exe, '-o', base, '-dump', os.path.join(outdir, name + '.' + pol + '.opt.tba')] + flags + [p], timeout=30)
            st[(name, pol)] = rc
    return st


def file_bytes(p):
    try:
        return open(p, 'rb').read()
    except OSError:
        return None


def compare_outputs(gold_dir, mut_dir, statuses_gold, statuses_mut):
    """T1: byte-for-byte regression comparison of outputs; returns set of differing (name,pol)"""
    diff = set()
    for p in CORPUS:
        name = os.path.basename(p)[:-4]
        for pol, _ in POLICIES:
            sg, sm = statuses_gold[(name, pol)], statuses_mut[(name, pol)]
            if sg != sm:
                diff.add((name, pol)); continue
            for suf in ('.xml', '.opt.tba'):
                if file_bytes(os.path.join(gold_dir, name + '.' + pol + suf)) != file_bytes(os.path.join(mut_dir, name + '.' + pol + suf)):
                    diff.add((name, pol)); break
    return diff


def canon_input(p, d):
    can = os.path.join(d, os.path.basename(p)[:-4] + '.in.can')
    if not os.path.exists(can):
        to_canon.from_tba(p, can)
    return can


def lang_check(mut_dir, nwords, seed, work, stop_first=True):
    """T2: compare each corpus input with (a) the optimized TBA and (b) the exported XML (both policies).
    Returns dict (name, kind) -> (mismatch, first, accA)   kind in {'opt','md','ac','crash'}"""
    os.makedirs(work, exist_ok=True)
    res = {}
    for p in CORPUS:
        name = os.path.basename(p)[:-4]
        evs = events_of(p)
        a = canon_input(p, work)
        for pol, _ in POLICIES:
            base = os.path.join(mut_dir, name + '.' + pol)
            kinds = [('opt', base + '.opt.tba', 'tba')] if pol == 'md' else []
            kinds.append((pol, base + '.xml', 'xml'))
            for kind, f, typ in kinds:
                if not os.path.exists(f):
                    res[(name, kind)] = (-1, -1, 0); continue
                b = os.path.join(work, '%s.%s.can' % (name, kind))
                try:
                    if typ == 'tba': to_canon.from_tba(f, b)
                    else: to_canon.from_xml(f, evs, b)
                except Exception as ex:
                    res[(name, kind)] = (-2, -1, 0); continue
                rc, out, err = sh([LC, a, b, str(nwords), str(seed)], timeout=600)
                m = re.search(r'mismatch=(\d+) first=(-?\d+) accA=(\d+)', out)
                res[(name, kind)] = (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else (-3, -1, 0)
    return res

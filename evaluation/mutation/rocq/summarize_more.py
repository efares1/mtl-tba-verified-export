"""For each mutant: status, the first real error (not a warning), its line, the enclosing Lemma/Theorem/Definition
in the mutated source, and the seconds to the first error.  Usage: python summarize_more.py ID [ID ...]"""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
for m in sys.argv[1:]:
    p = os.path.join(HERE, 'logs', m + '_result.json')
    if not os.path.exists(p):
        print(m, 'missing'); continue
    r = json.load(open(p))
    if r['status'] != 'rejected':
        print(m, r['status'], r.get('seconds')); continue
    g = r['failing_file']
    log = open(os.path.join(HERE, 'logs', '%s_%s.log' % (m, g)), encoding='utf8', errors='replace').read().replace('\r', '')
    # blocks start with: File "...", line N, characters a-b:
    blocks = re.split(r'(?=^File ")', log, flags=re.M)
    err = None
    for b in blocks:
        if re.search(r'^Error', b, re.M) or 'Error:' in b[:400]:
            err = b; break
    line = int(re.search(r'line (\d+)', err).group(1)) if err else None
    src = open(os.path.join(HERE, 'mut', m, g + '.v'), encoding='utf8', errors='replace').read().replace('\r', '').split('\n')
    name = None
    if line:
        for i in range(min(line, len(src)) - 1, -1, -1):
            mm = re.match(r'\s*(?:Lemma|Theorem|Corollary|Definition|Fixpoint)\s+([A-Za-z0-9_\']+)', src[i])
            if mm:
                name = mm.group(1); break
    msg = re.sub(r'\s+', ' ', err.split('Error:', 1)[-1])[:160] if err else ''
    print(m, g.replace('MTL_to_TBA_', ''), line, name, r.get('seconds_to_fail'), '|', msg)

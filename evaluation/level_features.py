"""Syntactic features of each benchmark formula and the best Spot configuration
(from level_feature_check.tsv).  Prints a table."""
import re, csv, sys, os
D = os.path.dirname(os.path.abspath(__file__))
TIMED = re.compile(r'\[(<=|<|>=|>|=)\s*\d+\]|U\[|R\[')  # bounded operator marker

def feats(s):
    # timed depth: nesting of parentheses containing timed operators, approximated by
    # a stack walk: depth of a timed marker = number of enclosing timed scopes
    stack = []  # for each open paren: number of timed markers seen at this level
    depth = 0; maxd = 0; ntimed = 0
    i = 0
    # tokenise: handle markers and parens
    cur = 0  # timed operators open in the enclosing chain
    chain = [0]
    for m in re.finditer(r'\(|\)|<>\[[^\]]*\]|\[\]\[[^\]]*\]|\^?<>\[[^\]]*\]|\^?\[\]\[[^\]]*\]|U\[[^\]]*\]|R\[[^\]]*\]', s):
        t = m.group(0)
        if t == '(':
            chain.append(chain[-1])
        elif t == ')':
            chain.pop()
        else:
            ntimed += 1
            chain[-1] += 1
            maxd = max(maxd, chain[-1])
    conj = s.count('&') // (2 if '&&' in s else 1) + 1
    return dict(len=len(s), ntimed=ntimed, tdepth=maxd, conj=conj)

forms = {}
for row in csv.reader(open(os.path.join(D, 'formulas.tsv'), encoding='utf-8'), delimiter='\t'):
    if row and not row[0].startswith('#'):
        forms[row[0]] = row[2]
res = {}
p = os.path.join(D, 'level_feature_check.tsv')
for r in csv.DictReader(open(p), delimiter='\t'):
    res[(r['id'], r['pol'], r['config'])] = (r['status'], float(r['seconds']))
print("%-4s %4s %6s %6s %5s | %-14s %-14s | %-14s %-14s" % ("id","len","ntimed","tdepth","conj","pos low","pos any","neg low","neg any"))
for i, f in forms.items():
    ft = feats(f)
    def c(pol, cfg):
        st, s = res.get((i, pol, cfg), ('-', 0))
        return ("%.1fs" % s) if st == 'ok' else ("FAIL/%.0fs" % s)
    print("%-4s %4d %6d %6d %5d | %-14s %-14s | %-14s %-14s" % (i, ft['len'], ft['ntimed'], ft['tdepth'], ft['conj'], c('pos','low'), c('pos','any'), c('neg','low'), c('neg','any')))

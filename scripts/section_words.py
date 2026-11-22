"""Words of prose per section and subsection of the article (tables and figures excluded)."""
import re, os, sys
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))


def expand(f):
    s = open(f, encoding='utf-8', errors='ignore').read()
    s = re.sub(r'(?m)^%.*$', '', s)

    def sub(m):
        g = m.group(1) + '.tex'
        return expand(g) if os.path.exists(g) else ''
    return re.sub(r'\\input\{([^}]+)\}', sub, s)


s = expand('jss_paper.tex')
parts = re.split(r'(\\section\*?\{[^}]*\}|\\subsection\*?\{[^}]*\})', s)
cur = 'start'
cnt = {}
order = ['start']
cnt['start'] = 0
for p in parts:
    if p.startswith('\\section') or p.startswith('\\subsection'):
        cur = p[:70]
        order.append(cur)
        cnt[cur] = 0
    else:
        t = re.sub(r'\\begin\{(table|figure)\}.*?\\end\{\1\}', '', p, flags=re.S)
        cnt[cur] += len(t.split())
for o in order:
    print(cnt[o], o)

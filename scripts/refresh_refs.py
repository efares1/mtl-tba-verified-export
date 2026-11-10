"""Regenerate suppref.tex (labels of the supplement, prefix S-) and articleref.tex (labels of the article)
from the .aux files of the last builds, so that the article and the supplement can cite each other.
Usage: python scripts/refresh_refs.py supp.aux article.aux
The article.aux should come from the non-review (single-spaced) build."""
import re, sys, os
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


def labels(aux, prefix):
    out = ['\\makeatletter']
    for m in re.finditer(r'^\\newlabel\{([^}]+)\}\{(\{.*\})\}\s*$', open(aux, encoding='utf8').read(), re.M):
        name, body = m.groups()
        if name.startswith('S-') or '@' in name:
            continue
        out.append('\\@namedef{r@%s%s}{%s}' % (prefix, name, body))
    out.append('\\makeatother')
    return '\n'.join(out) + '\n'


supp_aux, art_aux = sys.argv[1], sys.argv[2]
for fn, aux, pre in (('suppref.tex', supp_aux, 'S-'), ('articleref.tex', art_aux, '')):
    p = os.path.join(HERE, fn)
    if os.path.exists(p):
        os.replace(p, p + '.bak_refresh')
    open(p, 'w', encoding='utf8').write(labels(aux, pre))
    print(fn, 'written')

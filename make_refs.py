# Generates suppref.tex (labels of the supplement, prefixed S-, for the article)
# and articleref.tex (labels of the article, for the supplement) from the .aux files,
# so that neither document needs the other's .aux at compile time.
import re
BS=chr(92)
def gen(aux,out,prefix):
    lines=[]
    pat=re.compile(re.escape(BS+'newlabel{')+r'([^}]*)\}(.*)$')
    for l in open(aux,encoding='utf-8',errors='replace'):
        m=pat.match(l.rstrip('\n'))
        if m and not m.group(1).endswith('@cref'):
            lines.append(BS+'@namedef{r@'+prefix+m.group(1)+'}'+m.group(2))
    open(out,'w',encoding='utf-8').write(BS+'makeatletter\n'+'\n'.join(lines)+'\n'+BS+'makeatother\n')
    print(out,len(lines))
gen('jss_supp.aux','suppref.tex','S-')
gen('jss_paper.aux','articleref.tex','')

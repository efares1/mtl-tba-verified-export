"""Assemble jss_paper.tex from the new front/back parts and the retained
sections of paper2.tex (line ranges are by the original file)."""
import re, io
R = r'C:\Users\user\Desktop\JSS_paper'
p2 = open(R + r'\paper2.tex', encoding='utf8').read().split('\n')
def seg(a, b):  # 1-based inclusive
    return '\n'.join(p2[a - 1:b]) + '\n'
def rd(n):
    return open(R + '\\' + n, encoding='utf8').read()
body_model_to_export = seg(88, 443)      # sections 2..6 up to composition
body_tool = seg(530, 711)                # tool architecture
body_eval = seg(712, 717)                # evaluation + related work
out = (rd('jss_head.tex') + '\n' + rd('jss_intro.tex') + '\n' + body_model_to_export + '\n'
       + rd('jss_composition.tex') + '\n' + body_tool + '\n' + body_eval + '\n' + rd('jss_tail.tex'))
# label fixes
out = out.replace('Sections~\\ref{sec:optimization}--\\ref{sec:export}', 'Sections~\\ref{sec:post}--\\ref{sec:export}')
out = out.replace('Section~\\ref{sec:tool})', 'Section~\\ref{sec:toolchain})')
# nondecreasing timestamps
out = out.replace('timestamps satisfy $t_i\\ge0$ and are strictly increasing', 'timestamps satisfy $t_i\\ge0$ and are nondecreasing')
out = out.replace('strictly increasing timestamps', 'nondecreasing timestamps')
open(R + r'\jss_paper.tex', 'w', encoding='utf8').write(out)
print(len(out.split('\n')), 'lines')
for pat in ['fares_bodeveix_mtl_translation', 'earlier article', 'earlier translation', 'Paper 1', 'IEEE', 'ieeeaccess', 'strictly increasing', '\\\\EOD']:
    for m in re.finditer(pat, out):
        ln = out[:m.start()].count('\n') + 1
        print(pat, 'line', ln)

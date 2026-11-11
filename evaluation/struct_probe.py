import sys, os, re, subprocess, tempfile, collections
sys.path.insert(0, '/mnt/c/Users/user/Desktop/JSS_paper/evaluation')
import tck_product as tp
EV='/mnt/c/Users/user/Desktop/JSS_paper/evaluation'
EXE='/mnt/c/Users/user/Desktop/JSS_paper/tool/_build/default/src/mtl2tba.exe'
recs={}
for l in open(EV+'/formulas.tsv',encoding='utf8'):
    if l.startswith('#') or not l.strip(): continue
    p=l.rstrip('\n').split('\t'); recs[p[0]]=p[2]
def stats(a):
    out=collections.defaultdict(list)
    for (s,t,ev,g,rs,_) in a.edges: out[s].append((ev,g,tuple(rs),t))
    byev=0; maxout=0
    for s,es in out.items():
        c=collections.Counter(e[0] for e in es)
        byev+=sum(1 for k,v in c.items() if v>1)
        maxout=max(maxout,len(es))
    accl=sum(1 for v in a.locs.values() if v[0])
    trip=len({(sx,t,g,tuple(rs)) for (sx,t,ev,g,rs,_) in a.edges})
    evs=len({(sx,ev) for (sx,t,ev,g,rs,_) in a.edges})
    return len(a.locs),len(a.edges),len(a.clocks),accl,byev,maxout,trip,evs
W=tempfile.mkdtemp()
print('id\tarm\tlocs\tedges\tclocks\tacc_locs\tloc_event_pairs_with_>=2_edges\tmax_out	distinct_(src,tgt,guard,resets)	distinct_(src,event)')
for i in sys.argv[1:]:
    f=recs[i]
    ev=sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b',f))-{'true','false'})
    subprocess.run([EXE,'-nopdf','-all-copy','-o',W+'/o',f],cwd=W,capture_output=True)
    a=tp.from_xml('NEG',W+'/o.xml'); print(i,'ours_pos',*stats(a),sep='\t')
    gv=EV+'/casaal_out/'+i+'.gv'
    if os.path.exists(gv):
        b=tp.from_gv('NEG',gv,ev); print(i,'casaal_pos',*stats(b),sep='\t')

"""CASAAL automaton of the negated train_gate requirement.  Usage (Windows): python gen_casaal_tg.py N B D [limit_s]"""
import os, shutil, subprocess, sys, tempfile, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.argv, args = sys.argv[:1], sys.argv[1:]
import run_casaal as rc
N, B, D = map(int, args[:3]); LIMIT = int(args[3]) if len(args) > 3 else 900
AND = ' /' + chr(92) + ' '
A = AND.join(f'([](stop{i} -> <>[<={B}] go{i}))' for i in range(1, N + 1))
G = AND.join(f'([](stop{i} -> <>[<={D}] leave{i}))' for i in range(1, N + 1))
f = f'!(({A}) -> ({G}))'
work = tempfile.mkdtemp()
for x in os.listdir(rc.CASAAL_DIR):
    if x.lower().endswith(('.exe', '.dll')) and os.path.isfile(os.path.join(rc.CASAAL_DIR, x)):
        shutil.copy(os.path.join(rc.CASAAL_DIR, x), work)
open(os.path.join(work, 'f.txt'), 'w').write(rc.exclusive(f) + '\n')
t0 = time.time()
try:
    subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work, capture_output=True, timeout=LIMIT)
except subprocess.TimeoutExpired:
    print('timeout'); sys.exit(1)
dot = os.path.join(work, 'dot_output.gv')
if not os.path.exists(dot):
    print('no-output'); sys.exit(1)
out = os.path.join(HERE, 'casaal', f'tg_N{N}_B{B}_D{D}.gv')
shutil.copy(dot, out)
print(out, rc.count(open(dot).read()), '%.1f s' % (time.time() - t0))

r"""Run CASAAL on every formula of formulas.tsv and count states, transitions,
and clocks of the produced timed Buchi automaton (dot output).

Usage (Windows, from this folder):
    python run_casaal.py [--exclusive] [--runs=N] [path-to-casaal-folder]
(--runs=N: time is the median of N runs, wall-clock, including the start of the process)
Writes casaal_results.tsv, or casaal_exclusive.tsv with --exclusive, plus a
SHA-256 manifest for the supplied executable and DLL files. Record the tool
version separately. With --exclusive, the formula is conjoined with
[](!(a /\ b)) for every pair of distinct propositions a, b of the formula,
so that CASAAL, which reads sets of propositions, is restricted to at most
one proposition per position, the event semantics of mtl2tba (positions
where no proposition holds play the role of the event "other").
"""
import hashlib, itertools, os, re, shutil, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ARGS = [a for a in sys.argv[1:] if not a.startswith('--')]
RUNS = next((int(a.split('=')[1]) for a in sys.argv[1:] if a.startswith('--runs=')), 1)
EXCLUSIVE = '--exclusive' in sys.argv[1:]
CASAAL_DIR = ARGS[0] if ARGS else r'C:\Users\user\Desktop\casaal\casaal'


def formulas():
    for line in open(os.path.join(HERE, 'formulas.tsv'), encoding='utf-8'):
        if line.startswith('#') or not line.strip():
            continue
        fid, desc, ours, cas = line.rstrip('\n').split('\t')
        yield fid, desc, ours, cas


def exclusive(f):
    props = sorted(set(re.findall(r'\b[a-z][a-z0-9_]*\b', f)))
    pairs = [f'([](!({a} /\\ {b})))' for a, b in itertools.combinations(props, 2)]
    return ' /\\ '.join([f'({f})'] + pairs) if pairs else f


def count(dot):
    nodes = set(re.findall(r'^\s*(\d+)\s*\[label', dot, re.M)) - {'0'}
    edges = [e for e in re.findall(r'^\s*(\d+)\s*->\s*(\d+)', dot, re.M) if e[0] != '0']
    clocks = set(re.findall(r'\bx(\d+)\b', dot))
    return len(nodes), len(edges), len(clocks)


def write_binary_manifest(casaal_dir, manifest_name):
    files = sorted((f for f in os.listdir(casaal_dir)
                    if (f.lower().endswith(('.exe', '.dll')) and
                        os.path.isfile(os.path.join(casaal_dir, f)))),
                   key=str.lower)
    with open(os.path.join(HERE, manifest_name), 'w', encoding='utf-8',
              newline='\n') as manifest:
        manifest.write('# SHA-256 identity of supplied CASAAL binaries; '
                       'version metadata is not inferred.\n')
        for name in files:
            path = os.path.join(casaal_dir, name)
            digest = hashlib.sha256()
            with open(path, 'rb') as binary:
                for block in iter(lambda: binary.read(1024 * 1024), b''):
                    digest.update(block)
            manifest.write(f'{name}\t{os.path.getsize(path)}\t'
                           f'{digest.hexdigest()}\n')


def main():
    manifest_name = ('casaal_manifest_exclusive.txt' if EXCLUSIVE
                     else 'casaal_manifest.txt')
    write_binary_manifest(CASAAL_DIR, manifest_name)
    work = tempfile.mkdtemp()
    for f in os.listdir(CASAAL_DIR):
        if (f.lower().endswith(('.exe', '.dll')) and
                os.path.isfile(os.path.join(CASAAL_DIR, f))):
            shutil.copy(os.path.join(CASAAL_DIR, f), work)
    name = 'casaal_exclusive.tsv' if EXCLUSIVE else 'casaal_results.tsv'
    out = open(os.path.join(HERE, name), 'w', encoding='utf-8')
    out.write('id\texact\tstates\ttransitions\tclocks\ttime_s\n')
    for fid, desc, ours, cas in formulas():
        if cas == '-':
            out.write(f'{fid}\t-\t-\t-\t-\t-\n')
            continue
        exact = 'no' if cas.startswith('~') else 'yes'
        cas = cas.lstrip('~')
        if EXCLUSIVE:
            cas = exclusive(cas)
        open(os.path.join(work, 'f.txt'), 'w').write(cas + '\n')
        dotf = os.path.join(work, 'dot_output.gv')
        if os.path.exists(dotf):
            os.remove(dotf)
        try:
            times = []
            for _ in range(RUNS):
                if os.path.exists(dotf):
                    os.remove(dotf)
                t0 = time.time()
                subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work,
                               capture_output=True, timeout=600)
                times.append(time.time() - t0)
            times.sort()
            dt = times[len(times) // 2]   # median of the runs
            dot = open(dotf).read()
            s, t, c = count(dot)
            outdir = os.path.join(HERE, 'casaal_out_x' if EXCLUSIVE else 'casaal_out')
            os.makedirs(outdir, exist_ok=True)
            open(os.path.join(outdir, fid + '.gv'), 'w').write(dot)
            out.write(f'{fid}\t{exact}\t{s}\t{t}\t{c}\t{dt:.2f}\n')
            print(fid, exact, s, t, c, f'{dt:.2f}s')
        except Exception as e:
            out.write(f'{fid}\t{exact}\terror\t\t\t\n')
            print(fid, 'error', e)
    out.close()


if __name__ == '__main__':
    main()

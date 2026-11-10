r"""Run CASAAL on the negation of every formula of formulas.tsv whose CASAAL
encoding is exact, on the common domain (conjunction with the mutual
exclusion of the propositions), and keep the automata in casaal_out_neg/.
Used by run_tck_equivalence.sh.
    python run_casaal_neg.py [path-to-casaal-folder]
Also writes casaal_manifest_neg.txt with SHA-256 hashes of the supplied
executable and DLL files; record the tool version separately.
"""
import os, shutil, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_casaal as rc

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    cdir = sys.argv[1] if len(sys.argv) > 1 else rc.CASAAL_DIR
    rc.write_binary_manifest(cdir, 'casaal_manifest_neg.txt')
    work = tempfile.mkdtemp()
    for f in os.listdir(cdir):
        if (f.lower().endswith(('.exe', '.dll')) and
                os.path.isfile(os.path.join(cdir, f))):
            shutil.copy(os.path.join(cdir, f), work)
    outdir = os.path.join(HERE, 'casaal_out_neg')
    os.makedirs(outdir, exist_ok=True)
    for fid, desc, ours, cas in rc.formulas():
        if cas == '-' or cas.startswith('~'):
            continue
        f = rc.exclusive('!(' + cas + ')')
        open(os.path.join(work, 'f.txt'), 'w').write(f + '\n')
        dotf = os.path.join(work, 'dot_output.gv')
        if os.path.exists(dotf):
            os.remove(dotf)
        try:
            subprocess.run([os.path.join(work, 'casaal.exe'), 'f.txt'], cwd=work,
                           capture_output=True, timeout=600)
            shutil.copy(dotf, os.path.join(outdir, fid + '.gv'))
            s, t, c = rc.count(open(dotf).read())
            print(fid, s, t, c)
        except Exception as e:
            print(fid, 'error', e)


if __name__ == '__main__':
    main()

"""Apply a Rocq-level mutation to a scratch copy of the proof sources, rebuild the files that
depend on the mutated one (in dependency order), stop at the first failure and record it.
Run natively on Windows (Git Bash): python run_mut.py ID [ID ...]   (ID CTRL = unmutated control build)
Writes mut/<ID>/ (copy of ctrl/ with the edit), logs/<ID>_<file>.log and logs/<ID>_result.json."""
import json, os, re, shutil, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
CTRL = os.path.join(HERE, 'ctrl')
COQC = 'C:/Rocq-Platform~9.0~2025.08/bin/coqc.exe'
FLAGS = ['-w', '-deprecated-missing-stdlib', '-w', '-extraction-opaque-accessed',
         '-w', '-extraction-axiom-to-realize', '-w', '-extraction-default-directory']
CHAIN = ['MTL_to_TBA_Shared_Clock_Derived_Strict_Direct_Core', 'EncodingCorrect_Shared_Clock_Derived_Strict_Direct_Proof',
         'MTL_to_TBA_Invariants', 'MTL_to_TBA_Optimizations', 'MTL_to_TBA_Export', 'MTL_to_TBA_Initialization',
         'MTL_to_TBA_Simplify', 'MTL_to_TBA_Symbolic', 'MTL_to_TBA_Weak', 'MTL_to_TBA_Recur']
OPT, EXP = 'MTL_to_TBA_Optimizations', 'MTL_to_TBA_Export'

# id -> (file, old, new, Rocq-level description)
M = {
 'M01': (OPT, "      if In_dec (@clock_eq_dec root) x Z then\n        if Rle_dec 0 M then None\n        else Some {| guard_clock := x; guard_comparison := CLt;\n                     guard_bound := 0 |}\n      else Some {| guard_clock := x; guard_comparison := CLe;\n                   guard_bound := M |}\n  | None => None\n  end.\n\nDefinition inv_guard_item_w",
         "      if In_dec (@clock_eq_dec root) x Z then\n        if Rlt_dec 0 M then None\n        else Some {| guard_clock := x; guard_comparison := CLt;\n                     guard_bound := 0 |}\n      else Some {| guard_clock := x; guard_comparison := CLe;\n                   guard_bound := M |}\n  | None => None\n  end.\n\nDefinition inv_guard_item_w",
  'inv_item_of: invariant of a clock reset on the transition judged true iff 0 < M (instead of 0 <= M)'),
 'M10': (OPT, "  set_eqb (@clock_eq_dec root) (bt_resets t) (bt_resets t') &&\n  Nat.eqb (red p q (bt_target t)) (red p q (bt_target t')).",
         "  true &&\n  Nat.eqb (red p q (bt_target t)) (red p q (bt_target t')).",
  'sim: the subsumption test no longer compares the reset sets of the two transitions'),
 'M12': (OPT, "  | CLt => mk CGe\n", "  | CLt => mk CGt\n",
  'compl: the complement of x < c is computed as x > c instead of x >= c'),
 'M16': (EXP, "  | CLe => if Rle_dec 0 (guard_bound k) then true else false\n  | CLt => if Rlt_dec 0",
         "  | CLe => if Rlt_dec 0 (guard_bound k) then true else false\n  | CLt => if Rlt_dec 0",
  'const_true: x <= b judged true at x = 0 iff 0 < b (instead of 0 <= b)'),
 'M13': (OPT, "      | Some u, Some v => Some (Rmin u v)\n      | _, _ => None\n      end\n  end.\n\nLemma min_all_le",
         "      | Some u, Some v => Some (Rmax u v)\n      | _, _ => None\n      end\n  end.\n\nLemma min_all_le",
  'min_all: the entry lower bound is the max instead of the min over incoming transitions'),
 'M14': (EXP, "  | _ => map (fun q => map (fun p => DDiff (fst p) (fst q) (snd p - snd q)) Uk) Ul",
         "  | _ => map (fun q => map (fun p => DDiff (fst q) (fst p) (snd q - snd p)) Uk) Ul",
  'split entry condition: difference constraint d_l <= d_k reversed (the copy with the SHORTEST delay is entered)'),
 'M19': (EXP, "filter (fun t => Nat.eqb (dt_src t) (dta_init D) ||\n                                   dhas_incoming D (dt_src t))",
         "filter (fun t => false ||\n                                   dhas_incoming D (dt_src t))",
  'dprune: the initial location is no longer exempt from the incoming-transition test'),
}

M['CTRL'] = (OPT, None, None, 'control: unmutated sources')
for mid in sys.argv[1:]:
    f, old, new, desc = M[mid]
    d = os.path.join(HERE, 'mut', mid)
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(CTRL if mid == 'CTRL' else os.path.join(HERE, 'mut', 'CTRL'), d)
    p = os.path.join(d, f + '.v')
    s = open(p, encoding='utf8', newline='').read()
    crlf = '\r\n' in s
    s = s.replace('\r\n', '\n')
    if old is not None:
        assert s.count(old) == 1, (mid, s.count(old))
        s = s.replace(old, new)
    open(p, 'w', encoding='utf8', newline='').write(s.replace('\n', '\r\n') if crlf else s)
    res = {'id': mid, 'description': desc, 'file': f, 'compiled': [], 'status': None}
    i0 = CHAIN.index(f) if mid != 'CTRL' else 0
    # remove stale products of the mutated file and its dependents
    for g in CHAIN[i0:]:
        for ext in ('.vo', '.vok', '.vos', '.glob'):
            try: os.remove(os.path.join(d, g + ext))
            except FileNotFoundError: pass
    t_all = time.time()
    for g in CHAIN[i0:]:
        t0 = time.time()
        r = subprocess.run([COQC] + FLAGS + [g + '.v'], cwd=d, capture_output=True, text=True, stdin=subprocess.DEVNULL)
        out = (r.stdout + r.stderr).replace('\r', '')
        open(os.path.join(HERE, 'logs', '%s_%s.log' % (mid, g)), 'w').write(out)
        dt = time.time() - t0
        if r.returncode != 0:
            m = re.search(r'File "[^"]*?([^"/\\]+)", line (\d+).*?\n(.*)', out, re.S)
            res.update(status='rejected', failing_file=g, seconds_to_fail=round(time.time() - t_all, 1),
                       first_error=out.strip()[:1500])
            if m: res.update(err_line=int(m.group(2)))
            break
        res['compiled'].append([g, round(dt, 1)])
    else:
        res.update(status='accepted', seconds=round(time.time() - t_all, 1))
    json.dump(res, open(os.path.join(HERE, 'logs', mid + '_result.json'), 'w'), indent=1)
    print(mid, res['status'], res.get('failing_file'), res.get('err_line'), flush=True)

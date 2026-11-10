"""Seeded mutants of the EXTRACTED OCaml passes (tool/src/optim.ml, copied to ~/mut/work/<id>).
Each mutant replaces one exact substring (checked to be unique).  The Rocq sources are NOT mutated:
these are bugs a developer could plausibly write when implementing the same pass by hand.

Run inside WSL:  python3 mutants.py build [ID ...]     (builds ~/mut/exe/<ID>_{tba_opt,mtl2tba}.exe)
                 python3 mutants.py list
"""
import os, shutil, subprocess, sys, json

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')
BASE = HOME + '/mut/base'
NL = chr(10)

# (id, pass, description, why plausible, old, new)
M = [
 ('M01', 'bound propagation (invariant into guards)',
  'reset clock whose target invariant bound is 0: contradictory test 0<=m replaced by 0<m',
  'off-by-one on a closed bound when the clock was just reset',
  'then if (<=) (float_of_int 0) m', 'then if (<) (float_of_int 0) m'),
 ('M02', 'bound synthesis',
  'invariant of a location = tightest (min) instead of loosest (max) upper bound of its outgoing guards',
  'min/max confusion: the invariant must allow every outgoing branch',
  "(match max_all l' with" + NL + '         | Some v -> Some (Float.max u v)',
  "(match max_all l' with" + NL + '         | Some v -> Some (Float.min u v)'),
 ('M03', 'contradictory transitions',
  'lower bound l and upper bound u with u = l is always called contradictory (strictness ignored)',
  'x>=2 and x<=2 look empty; forgetting that both bounds must be closed',
  'else if (=) u l then (||) sl su else false', 'else if (=) u l then true else false'),
 ('M04', 'dead resets / clock merging',
  'a clock counts as "tested" only by upper-bound atoms (lower-bound tests are ignored)',
  'liveness written for the invariant case; lower-bound guards forgotten',
  'let mentions root x = function' + NL + '| Some k -> clock_eqb root k.guard_clock x',
  'let mentions root x = function' + NL + '| Some k -> clock_eqb root k.guard_clock x && is_upper k.guard_comparison'),
 ('M05', 'pass ordering',
  'the normalization that precedes dead-reset removal is omitted (order of the optimization step)',
  'seems redundant because a normalization also runs later',
  '(remove_dead_resets root' + NL + '            (normalize root' + NL + '              (remove_unreachable root',
  '(remove_dead_resets root' + NL + '            (Fun.id' + NL + '              (remove_unreachable root'),
 ('M06', 'guard normalization',
  'x > b with b < 0 test generalised to b <= 0: the guard x>0 is dropped as trivially true',
  'x>=0 is trivial, x>0 is not; strict/non-strict slip',
  '| CGt ->  ((<) k.guard_bound (float_of_int 0))', '| CGt ->  ((<=) k.guard_bound (float_of_int 0))'),
 ('M07', 'clock merging',
  'two clocks are merged without checking that they are reset by exactly the same transitions',
  'merge test only looks at the initial transitions',
  '(=) (clock_in root x t0.bt_resets) (clock_in root y t0.bt_resets)', 'true'),
 ('M08', 'clock merging',
  'the side condition "no transition enters the initial location" is dropped',
  'looks like a corner case',
  '(fun t0 -> not ((=) t0.bt_target a.tba_init))', '(fun t0 -> true)'),
 ('M09', 'location merging',
  'two locations are merged although one is accepting and the other is not',
  'the acceptance test is forgotten when the transition structure matches',
  '((=) (in_nat p a.tba_accepting) (in_nat q0 a.tba_accepting))', 'true'),
 ('M10', 'location merging',
  'simulation test between transitions ignores their reset sets',
  'resets compared on labels and guards only',
  '(set_eqb (clock_eq_dec root) t0.bt_resets t\'.bt_resets)', 'true'),
 ('M11', 'transition merging',
  'two transitions with the same ends are merged without comparing their reset sets',
  'same source and target look sufficient',
  '(beq (List.equal (clock_eq_dec root)) t0.bt_resets u.bt_resets)', 'true'),
 ('M12', 'transition merging',
  'complement of x<c computed as x>c instead of x>=c (merging x<c with x>=c)',
  'strict/non-strict confusion in the complement',
  '| CLt -> mk CGe', '| CLt -> mk CGt'),
 ('M13', 'forward propagation',
  'entry lower bound of a location = max instead of min over its incoming transitions',
  'min/max confusion, dual of M02',
  "(match min_all l' with" + NL + '         | Some v -> Some (Float.min u v)',
  "(match min_all l' with" + NL + '         | Some v -> Some (Float.max u v)'),
 ('M14', 'disjunctive split (max-delay)',
  'entry condition compares copies the wrong way round: the copy with the SHORTEST admitted delay is entered',
  'reversed difference constraint',
  'List.map (fun p -> DDiff ((fst p), (fst q0), ((-.) (snd p) (snd q0)))) uk)',
  'List.map (fun p -> DDiff ((fst q0), (fst p), ((-.) (snd q0) (snd p)))) uk)'),
 ('M15', 'disjunctive split (max-delay)',
  'entry condition evaluated on the valuation before the reset instead of after it (reset substitution omitted)',
  'the substitution of reset clocks by 0 is forgotten',
  '(subst_guard root t0.dt_resets (entry_cond root (di t0.dt_tgt) k0))',
  '(subst_guard root [] (entry_cond root (di t0.dt_tgt) k0))'),
 ('M16', 'disjunctive split (max-delay)',
  'reset substitution: a reset clock x with bound x<=b is judged true iff 0<b (instead of 0<=b)',
  'off-by-one on the closed bound',
  '| CLe -> if (<=) (float_of_int 0) k.guard_bound then true else false',
  '| CLe -> if (<) (float_of_int 0) k.guard_bound then true else false'),
 ('M17', 'export normalization',
  'in a disjunctive guard, a conjunct is dropped when an existing one IMPLIES it (should be: it implies an existing one)',
  'direction of the implication test',
  'else if List.exists (fun a -> conj_implies root c a) acc',
  'else if List.exists (fun a -> conj_implies root a c) acc'),
 ('M18', 'export location merging',
  'two exported locations with different invariants may be merged',
  'invariants forgotten in the equality test',
  '(if oinv_dec root (inv_norm root (d.dta_inv p))' + NL + '              (inv_norm root (d.dta_inv q0))' + NL + '         then true' + NL + '         else false)',
  'true'),
 ('M19', 'export pruning',
  'unreachable-location pruning forgets that the initial location has no incoming transition',
  'every location must have an incoming transition',
  '(||) ((=) t0.dt_src d.dta_init) (dhas_incoming root d t0.dt_src))',
  '(||) false (dhas_incoming root d t0.dt_src))'),
 ('M20', 'implication between guards',
  'x<=u is taken to imply x<w when u<=w (should be u<w)',
  'strict/non-strict slip in the implication table',
  '| CLe ->  ((<) u w)', '| CLe ->  ((<=) u w)'),
 ('M21', 'dead resets',
  'the safety check of the dead-reset pass (dead sources lead to dead targets and do not test the clock) is removed',
  'the check looks redundant after computing the live set',
  'if List.for_all (fun t0 ->' + NL + '       (||) (not (dead_in t0.bt_source))' + NL + '         ((&&) (dead_in t0.bt_target) (not (tests root x t0))))' + NL + '       a.tba_transitions' + NL + '  then with_transitions',
  'if true' + NL + '  then with_transitions'),
 ('M22', 'bound synthesis',
  'conjunctive guard x<=3 && x<=5 yields the upper bound 5 instead of 3 (weaker invariant)',
  'min replaced by max when collecting bounds of one guard',
  "| o :: g' -> opt_min (ub_item root x o) (ub_guard root g' x)",
  "| o :: g' -> (match ub_item root x o, ub_guard root g' x with Some u, Some v -> Some (Float.max u v) | Some u, None -> Some u | None, v -> v)"),
]


def patched_source(mid):
    src = open(BASE + '/src/optim.ml').read()
    for (i, p, d, w, old, new) in M:
        if i == mid:
            assert src.count(old) == 1, (mid, src.count(old))
            line = src[:src.index(old)].count(NL) + 1
            return src.replace(old, new), line
    raise KeyError(mid)


def build(mid):
    W = HOME + '/mut/work/' + mid
    shutil.rmtree(W, ignore_errors=True)
    os.makedirs(W)
    shutil.copytree(BASE + '/src', W + '/src', ignore=shutil.ignore_patterns('_build'))
    shutil.copy(BASE + '/dune-project', W)
    s, line = patched_source(mid)
    open(W + '/src/optim.ml', 'w').write(s)
    r = subprocess.run('eval "$(opam env 2>/dev/null)"; cd %s && dune build 2>&1 | head -20' % W, shell=True, capture_output=True, text=True, executable='/bin/bash')
    ok = os.path.exists(W + '/_build/default/src/tba_opt.exe') and os.path.exists(W + '/_build/default/src/mtl2tba.exe')
    if ok:
        for e in ('tba_opt', 'mtl2tba'):
            dst = HOME + '/mut/exe/%s_%s.exe' % (mid, e)
            if os.path.exists(dst): os.remove(dst)
            shutil.copy(W + '/_build/default/src/%s.exe' % e, dst)
    return ok, line, r.stdout


if __name__ == '__main__':
    if sys.argv[1] == 'list':
        for (i, p, d, w, old, new) in M:
            try: print(i, patched_source(i)[1], p, '|', d)
            except Exception as ex: print(i, 'PATCH FAILS', ex)
    else:
        ids = sys.argv[2:] or [m[0] for m in M]
        info = {}
        for i in ids:
            ok, line, out = build(i)
            print(i, 'built' if ok else 'BUILD FAILED', 'line', line, out[:300])
            info[i] = line
        json.dump(info, open(HERE + '/mutant_lines.json', 'w'))

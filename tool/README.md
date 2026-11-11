# mtl2tba

From an MTL(0,inf) formula to a timed automaton for UPPAAL (XML) and its
drawing (Graphviz dot).

    mtl2tba [options] 'formula'

      -o <base>    output files <base>.xml, <base>.dot, <base>.pdf (default: out)
      -init        add an initialization event _init_ fixing the time origin
      -n <n>       maximal number of optimization rounds (default: 50)
      -spot <cmd>  LTL-to-Buchi command (default: ltl2tgba)
      -nopdf       do not run Graphviz to produce <base>.pdf
      -dot <cmd>   Graphviz command (default: dot)
      -tba         also write <base>_tba.dot (after reset completion) and
                   <base>_opt.dot (after optimization)
      -norecur     keep the lower bounds under []<> and <>[]; by default
                   []<>[>=d] p becomes []<> p and <>[][>=d] p becomes <>[] p
                   (also with >), valid under time divergence (proved)
      -noweak      for measurements only: keep a strong Until in the
                   clauses of upper-bounded hatted Until instead of the
                   weak until of the translation
      -check <b>   write <b>_ltl.lbt (T(f) by a second printer) and <b>_ba.hoa
                   (the automaton built by the reader), to check the
                   interface with Spot (evaluation/run_interface_check.sh)
      -stats       print one line of measures (header: -stats-header)
      -v           print the intermediate results

Example:

    mtl2tba -o sporadic '[](e -> ^[][<=2] !e)'
    # writes sporadic.xml (UPPAAL), sporadic.dot and sporadic.pdf (Graphviz)

## Chain

| Step | Code |
|---|---|
| parsing, `-init` | prototype (`mtl.ml`, `lexer.mll`, `parser.mly`, `mtl2mtl.ml`) |
| negation normal form | extracted from Coq (`neg`, `neg_correct`) |
| derivation of the ordinary timed operators | extracted from Coq (`MUle`, ..., `MRgt`) |
| lower bounds under `[]<>` and `<>[]` removed (default) | extracted from Coq (`recur`, `recur_correct`) |
| clocked-LTL translation `T` | extracted from Coq |
| weak until in the clauses of upper-bounded hatted Until (part of the translation) | extracted from Coq (`weak`, `weak_correct`) |
| LTL to Buchi automaton | Spot, `ltl2tgba -B --<level> --hoa` (default `auto`: `low`, then `any` with `ba-simul=0` on the simplified formula after 5 s; `-spot-level` selects one level) |
| reading of the Spot automaton, HOA or LBTT (literals kept) | `lbtt_read.ml` |
| relaxation and reset completion | extracted from Coq (`compile_with`) |
| optimization, iterated to a fixed point | extracted from Coq (`optimize`) |
| export: conjunctive guards and invariants | extracted from Coq (`export`) |
| UPPAAL and dot output | `output.ml` |
| PDF drawing | Graphviz (`dot -Tpdf`) |

The extracted steps are proved in Coq: for every Buchi automaton `A` that
accepts exactly the propositional models of `T f`,
`MTL_to_TBA_correct_with` states that `compile_with A` accepts exactly the
models of `f`, and `optimize_accepts` and `export_accepts` that the later
steps preserve the language; `MTL_to_exported_correct0_recur_weak_with`
states the same for the default chain, where the formula is first rewritten
by `recur` and `A` accepts the models of its translation with the weak
until.  Every atom, including a negated event `!e`, is
passed to Spot as an independent quoted proposition, as in the hypothesis of
that theorem.

In the UPPAAL model, the template `Property` receives the events on
channels (`other` stands for every event that does not occur in the
formula) and the template `Env` can emit every event; accepting locations
are named `A<n>`.  UPPAAL does not check Buchi acceptance.

## Choosing the Spot level and `-simp`

Spot is called as `ltl2tgba -B --<level> [-x <options>] --hoa` (`-spot-format
lbtt` reads Spot's LBTT output instead).  No level is fastest everywhere:
`low` is instant on conjunctions of requirements (8 bounded responses: 0.1 s)
and slow on deeply nested ones (6 levels: 14 s); `any` on the simplified
formula (`-simp`) is the reverse (6 levels: 1.3 s, 7 responses: 12 s).  With
`-spot-x ba-simul=0` (Spot's simulation reductions off) `any` is two to
three times faster and gives the same automaton: the sizes of `low` and `any`
agree on every benchmark pattern.  A rule based on the shape of the formula was
tried and rejected (a depth-5 chain with five plain responses takes 0.3 s with
`low`, 7.7 s with `any`).

The default `-spot-level auto` therefore runs `low` and, if Spot has not
finished after `-spot-budget` seconds (default 5), stops it and runs `any` with
`ba-simul=0` on the simplified formula.  Both steps are the proved translation
and the proved simplification; only Spot is trusted, as before.  The cost of
the fallback is at most the budget; the choice is deterministic for a given
machine speed.  The automatic mode needs a POSIX shell (Linux, macOS, WSL).

### When to override the automatic mode

An explicit `-spot-level` skips the budget.  Override it when:

1. **Every conjunct of the requirement is a deeply nested chain** (nested
   bounded eventualities or invariances, depth 4 or more).  Use
   `-simp -spot-level any -spot-x ba-simul=0`: 6 nested levels take 1.3 s,
   against 6.6 s in automatic mode.
2. **You benchmark or want reproducible automata.**  The switch depends on the
   speed of the machine; fix `-spot-level` (and `-simp`, `-spot-x`).
3. **You want to experiment with Spot.**  `-spot-x` passes any option of
   `spot-x(7)`; on our inputs only the simulation reductions mattered.

For a requirement made of plain responses no override is needed: `low` finishes
before the budget.  We know of no case in the benchmark where forcing `low` is
worth it.

## Other options

* `-alloc` reuses clocks by liveness after the optimization (Coq: `alloc_pass`,
  `alloc_pass_accepts`).  The liveness analysis and the colouring (`src/alloc.ml`)
  are not verified; the extracted checker `alloc_ok` validates their result and
  the automaton is left unchanged when it fails, so the language is preserved
  in either case.  Off by default.
* `-all-copy` uses the separately verified all-copy split of disjunctive
  invariants instead of the default maximal-delay split.  The all-copy export
  adds no clock-difference (diagonal) guards, which TChecker's liveness
  algorithms (`tck-liveness`) reject ("unsupported diagonal constraints"), so use
  it for automata that a TChecker product will read, in particular for the
  positive form of a requirement used as a system or reference component.  On
  negated requirements the two policies gave the same automata on our benchmark.
* `-n <k>` limits the optimization rounds (`-n 0` disables the optimizer; the
  export still computes the location invariants).
* `-spot-format hoa|lbtt` and `-spot-x <options>`: see above.

## `tba_opt`: the optimizer and exporter on any automaton

`tba_opt` (built next to `mtl2tba`: `_build/default/src/tba_opt.exe`) runs the
same extracted optimizer, exporter and initial-value check on a timed Buchi
automaton read from a text file, without the MTL front end and without Spot.
It was written to apply the verified stages to the output of an independent
translator (CASAAL); the reader and the conversion are not part of the proofs.

    tba_opt [-n <rounds>] [-all-copy] [-stats] -o <base> automaton.tba

writes `<base>.xml` (UPPAAL/TChecker) and `<base>.dot`, and prints the sizes
before and after optimization and after export.  Input format (`#` starts a
comment):

    events p q            event names (the i-th name is event i)
    clocks 2
    init 0
    states 4
    acc 1 3               accepting locations (location acceptance)
    t SRC DST | 0+ 1- | 0<=5 1>2 | 0 1
                          label literals (<event><+|->), guard atoms
                          (<clock><op><bound>), clocks reset; fields may be empty

`../evaluation/casaal_to_tba.py` converts a CASAAL automaton (DOT, transition
acceptance with one acceptance set) to this format; the conversion to location
acceptance takes the reachable pairs (location, last transition accepting).  On
CASAAL's automata the optimizer changes nothing, and the export alone reduces
the states TChecker stores (see the evaluation in the paper).

## Build

`dune build` in this folder (requires dune and menhir); it builds `mtl2tba` and `tba_opt`.  The extracted
module `src/optim.ml` is included; `make` in `../proof` regenerates it from
the Coq development, and `make tool` there rebuilds the tool.  `examples/`
contains the output for Examples 1 and 3 of the paper and for the
sporadicity requirement.

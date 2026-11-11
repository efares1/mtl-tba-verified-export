#!/bin/bash
# Builds ~/ablate_tool, a scratch copy of the tool whose optimization round skips the pass named in
# the environment variable ABLATE (propagate, forward, contradictory, unsat, unreachable, normalize,
# dead_resets, merge_clocks, merge_trans, merge_states).  The proved sources and tool/ are not
# modified; run_pass_ablation.sh uses the copy.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
D=${1:-$HOME/ablate_tool}
rm -rf "$D" && mkdir "$D"
(cd "$HERE/../tool" && tar cf - --exclude=_build .) | (cd "$D" && tar xf -)
cd "$D"
python3 - <<'EOF'
s = open("src/optim.ml").read()
a = s.index("let optimize_step root a =")
b = s.index("(** val optimize : mtl -> int")
new = """let optimize_step root a =
  let ab = Sys.getenv_opt "ABLATE" in
  let on n f x = if ab = Some n then x else f x in
  (on "merge_states" (merge_states_all root)
    (on "merge_trans" (merge_trans root)
      (on "normalize" (normalize root)
        (on "merge_clocks" (merge_all root)
          (on "dead_resets" (remove_dead_resets root)
            (on "normalize" (normalize root)
              (on "unreachable" (remove_unreachable root)
                (on "unsat" (remove_unsat root)
                  (on "contradictory" (remove_contradictory root)
                    (on "forward" (forward_fast root)
                      (on "propagate" (propagate_fast root) a)))))))))))

"""
open("src/optim.ml", "w").write(s[:a] + new + s[b:])
EOF
dune build 2>&1 | tail -5

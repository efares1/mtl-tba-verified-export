#!/bin/bash
# Prune the freshly extracted proof/optim.ml exactly as proof/Makefile does and install it.
D=/mnt/c/Users/user/Desktop/JSS_paper
cd $D/proof
ROOTS="optimized optimize export export_all optimize_export optimize_export_all t ltl_atoms compile_with compile_with_fast init_free ltl_simp symbolic neg weak recur timed_subformulas mUle mUlt mUge mUgt mRle mRlt mRge mRgt"
cp optim.ml $HOME/optim_raw.ml
python3 tools/prune_extraction.py optim.ml $ROOTS
wc -l optim.ml
cp optim.ml $D/tool/src/optim.ml
echo "--- diff against the previous tool module (summary)"
diff $HOME/optim_previous.ml $D/tool/src/optim.ml | grep -c '^[<>]'
diff $HOME/optim_previous.ml $D/tool/src/optim.ml | grep '^[<>] *let \(rec \)\?[a-z_0-9]*' | cut -c1-90

#!/bin/bash
# Builds the supplement and the article (single-column, at most 36 pages) and regenerates the cross-reference files.
cd "$(dirname "$0")/.."
P="pdflatex -interaction=nonstopmode -halt-on-error"
for r in 1 2; do
  $P jss_supp.tex >/dev/null; bibtex jss_supp >/dev/null
  $P jss_paper.tex >/dev/null; bibtex jss_paper >/dev/null
  python make_refs.py >/dev/null
done
$P jss_supp.tex >/dev/null; $P jss_supp.tex >/dev/null
$P jss_paper.tex >/dev/null; $P jss_paper.tex >/dev/null
grep -h "Output written" jss_supp.log jss_paper.log
grep -c "undefined" jss_supp.log jss_paper.log

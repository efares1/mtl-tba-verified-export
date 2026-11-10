# Build supplement, refresh cross-reference files, build a single-spaced (non-review) copy of the article
# and report page count and undefined references. Does not touch jss_paper.pdf. Usage: powershell -File scripts/length_check.ps1
$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')
(Get-Content jss_paper.tex -Raw) -replace 'documentclass\[preprint,review,12pt\]\{elsarticle\}', 'documentclass[preprint,12pt]{elsarticle}' | Set-Content zz_len_check.tex -Encoding utf8
pdflatex -interaction=nonstopmode jss_supp.tex > "$env:TEMP\s1.txt"
pdflatex -interaction=nonstopmode zz_len_check.tex > "$env:TEMP\m1.txt"
python scripts/refresh_refs.py jss_supp.aux zz_len_check.aux
bibtex zz_len_check > "$env:TEMP\bib.txt"
pdflatex -interaction=nonstopmode zz_len_check.tex > "$env:TEMP\m2.txt"
pdflatex -interaction=nonstopmode jss_supp.tex > "$env:TEMP\s2.txt"
pdflatex -interaction=nonstopmode zz_len_check.tex > "$env:TEMP\m3.txt"
pdflatex -interaction=nonstopmode zz_len_check.tex > "$env:TEMP\m4.txt"
foreach ($f in 's2', 'm4') {
    Select-String -Path "$env:TEMP\$f.txt" -Pattern 'undefined|Output written|^!' | ForEach-Object { $_.Line.Substring(0, [Math]::Min(120, $_.Line.Length)) }
}

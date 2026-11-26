FINAL SUBMISSION FOLDER - ARRAY (Elsevier), transfer from JSS
==============================================================
Requirements checked against Array's Guide for Authors (sciencedirect.com/journal/array/publish/guide-for-authors, read 2026-11-26).

Files to upload (Editorial Manager "Attach Files" step; the transfer may pre-load the JSS files, replace them with these):
 1. Cover Letter ................. cover_letter.txt
 2. Highlights ................... array_highlights.txt (5 bullets, each <= 85 characters; name contains "highlights")
 3. Manuscript ................... array_paper.pdf (reference PDF, single column, 37 pages); editable source: source.zip
 4. LaTeX Source Files ........... source.zip (array_paper.tex, array_supp.tex, .bbl, .bib, figures, evaluation tables)
 5. Supplementary material ....... array_supplementary_material.pdf (61 pages, cited in the article)
 6. Declaration of interest ...... declaration_of_interests.docx (Word, as Array asks; "nothing to declare")
Optional, not provided: graphical abstract (encouraged, not required); no co-submission (Data in Brief / MethodsX).

Requirement -> status
 - Article type: regular paper; no page limit (technical notes only are limited to 10 pages) -> OK
 - Abstract <= 250 words: 235 -> OK
 - Keywords 1 to 7: 5 (timed automata, MTL, verified optimization, Rocq, UPPAAL) -> OK
 - Highlights 3 to 5, <= 85 characters -> OK (longest 84)
 - References numbered [1] in order of appearance (elsarticle-num); \journal{Array} set -> OK
 - Title page: names, affiliations with country, corresponding author with e-mail (Elie Fares) -> OK
 - CRediT statement, Funding statement (Elsevier standard sentence), Declaration of competing interest -> in the manuscript
 - Generative AI declaration: section "Declaration of generative AI and AI-assisted technologies in the manuscript preparation process" before the references, in Elsevier's wording -> OK
 - Research data (Option B): archived on Zenodo, DOI 10.5281/zenodo.24478303; data and artifact availability section -> OK
 - Single-anonymized review: the manuscript carries author names, no anonymization needed
 - Tables are editable text (LaTeX); figures are TikZ text graphics embedded in the source

What changed relative to the JSS version: \journal{Array}; funding sentence; generative AI section title and statement (Elsevier wording); files renamed array_*; cover letter (transfer, no JSS length claim); Word declaration of interests. The scientific content is unchanged.

To do in the form (authors):
 - Corresponding author details and ORCIDs (already in the paper); confirm the CRediT roles and the AI statement
 - Tick the APC acknowledgement. Array is open access with an article processing charge; third-party sites list about USD 1350, so check the current amount on Elsevier's page and ask whether HCT or a waiver covers it
 - Optional: post a preprint on SSRN (free option during submission; does not count as prior publication)
 - Suggested reviewers are optional
Rebuild (from source/): pdflatex array_supp; pdflatex array_paper; python make_refs.py; bibtex array_supp; bibtex array_paper; pdflatex array_supp; pdflatex array_paper (twice); python make_refs.py; repeat once. elsarticle.cls comes from the TeX distribution.

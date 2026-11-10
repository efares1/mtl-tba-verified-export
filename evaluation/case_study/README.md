# Case study: use of the UPPAAL model on system models

Two safety requirements, each with a correct and a faulty system
(Section VII, paragraph "Use on system models"):

| Model      | Requirement                  | System                          |
|------------|------------------------------|---------------------------------|
| `spor_ok`  | `[](e -> ^[][<2] !e)`        | emits `e` at least 2 apart      |
| `spor_bad` | idem                         | emits `e` at least 1 apart      |
| `resp_ok`  | `[](p -> ^<>[<=5] q)`        | answers `p` by `q` within 4     |
| `resp_bad` | idem                         | answers `p` by `q` within 6     |

- `negspor.xml`, `negresp.xml`: output of `mtl2tba` for the negations
  `<>(e & ^<>[<2] e)` and `<>(p & ^[][<=5] !q)`.
- `make_models.py`: composes them with the systems (without `Env`) into
  `models/*.xml`, with the queries `models/*.q`; the `*_alone` models contain
  the system with a receiver of every channel, for the timelock check (C4).
- `run_uppaal.sh`: runs `verifyta` on every model
  (`VERIFYTA=/path/to/verifyta bash run_uppaal.sh`).
- `explore.py`: independent cross-check by explicit exploration on a 1/4
  time grid; its output is `expected.txt`.

Results with UPPAAL 5.0.0 (`uppaal_results.txt`, diagnostic traces
`(e,1)(e,2)` for `spor_bad` and `(p,0.5)(q,6)` for `resp_bad`), equal to the
expected verdicts: `E<> P.A4` not satisfied for `*_ok`, satisfied for `*_bad`;
`A[] not deadlock` satisfied for every `*_alone` model.

---
type: feat
target: this repo
opened: 2026-08-06
closed:
---

# 030 - migrate-need-to-plcc-ng

<!--
`type` is a conventional commit type: fix, feat, refactor, perf, docs,
test, chore. Classify by user-facing impact, not by whether something was
"broken". `fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.

`target` is the repository the issue is actually about. It defaults to
this repo; set it to the upstream repository (e.g. ourPLCC/plcc-ng) when
the defect is there rather than in this repo's own src/.

`closed` stays empty until bin/issues/close.bash fills it in.
-->

## Description

Port NEED (`NAME + memoization`) to plcc-ng: one shared `src/NEED/grammar.plcc`
plus three target `spec.plcc`s (Python, Java, JavaScript). NEED is the last of
Phase 3's four languages and the only one with a **syntax delta** — a
three-line change over NAME's grammar: an `ERROR` token (added after `token
SET`, before `token SYMBOL`), an `<Prim:ErrorPrim> ::= ERROR` production
(added after `<Prim:ZeropPrim>`), and an updated header comment. Like NAME it
does no Env work — SET already ported `envRef` (shared by SET, REF, NAME, and
NEED) on NEED's behalf.

NEED's whole content is a five-hunk semantic delta over NAME, most of it
following from one fact — a thunk is forced at most once and caches its
value:

- `ThunkRef` gains memoization: a `val` field initialized to null/`None`, and
  a `deRef` that computes it on first call and returns the cached value
  thereafter. The null sentinel is kept in all three targets rather than
  replaced with a `forced` boolean, matching the Java reference shape.
  `setRef` and `__str__` are unchanged from NAME.
- `ValRORef` is a new free-standing `Ref` subclass extending `ValRef` whose
  `setRef` throws `cannot modify a read-only reference`.
- `LitExp.evalRef` and `ProcExp.evalRef` return `ValRORef` where NAME returned
  `ValRef` — the only two places NAME wrapped an eagerly computed value.
  `VarExp.evalRef` is untouched, so a bare variable operand is still
  assignable by reference.
- `ErrorPrim` is added: `__str__` returns `"error"`, `apply` raises
  `user-defined error`. Only Python needs an explicit `ErrorPrim:import`;
  Java needs none (package-less classes); JavaScript needs none either,
  since the grammar-derived class gets `LanguageError` auto-injected and an
  explicit import would redeclare it.
- Imports follow the class moves: in Python and JavaScript, `LitExp:import`
  and `ProcExp:import` each switch `ValRef` → `ValRORef`. Java needs no
  import changes.

Three targets, four value-only test cases, each measured against all three
targets before being written down (see the design doc):
`thunk-forced-once/` (a thunk forced seven times runs its side effect once,
→ `4`, NAME: `10` — this **is** NEED's existing `tests/let/`, renamed and
upgraded to the seven-use program already on disk at `Prog/test`),
`memoized-across-calls/` (an operand built once is shared across four calls,
→ `4`, NAME: `1` — `Prog/counter` copied in from `src/NAME/Prog/`),
`unused-arg-not-evaluated/` (an operand never used is never forced, so
`error()` never raises, → `11`, NAME: cannot parse — no `ERROR` token), and
`infinite-stream/` (`Prog/natno`, the infinite natural-number stream built
from `pair`/`first`/`rest`/`nth` — NEED's course centerpiece, →
`pair` `first` `rest` `nth` `seq` `natno` `0` `1` `2` `100`).

Unlike REF, NEED's `src/NEED/Prog/` needs no consolidation: all nine
programs (the existing eight plus `counter`) already run clean in all three
targets, with one already-known exception — `Prog/nn` dies in Python with a
`RecursionError`, inherited from issue #19 and unchanged by this port.

Baseline measured today with a full `bin/test.bash` run: 119 tests, 115
passing, 4 failing (NEED, OBJ, TYPE0, TYPE1 — all `plccmk: command not
found`). After this phase: 130 tests (119, minus NEED's 1 old test, plus 12
new — 4 cases × 3 targets), 127 passing, 3 failing — the same `command not
found` set minus NEED.

## Notes

See
[dev-docs/specs/2026-08-05-plcc-ng-need-design.md](../specs/2026-08-05-plcc-ng-need-design.md),
which extends
[dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)
and builds directly on
[dev-docs/specs/2026-08-05-plcc-ng-name-design.md](../specs/2026-08-05-plcc-ng-name-design.md),
whose grammar, `envRef` reuse, and semantic classes NEED inherits almost
entirely unchanged, and through NAME on
[dev-docs/specs/2026-08-04-plcc-ng-ref-design.md](../specs/2026-08-04-plcc-ng-ref-design.md)
and
[dev-docs/specs/2026-08-04-plcc-ng-set-design.md](../specs/2026-08-04-plcc-ng-set-design.md).

**The Jensen device diverges under call-by-need, by design.** NAME's
centerpiece — a `while` loop built entirely out of call-by-name thunks —
does not terminate under NEED in any of the three targets: `test?` is
forced once, caches a true value, and every later iteration reads the
cache, so the loop condition can never become false. This is correct
call-by-need semantics, not a defect, and is documented rather than fixed;
nothing is copied into `src/NEED/Prog/` and no test pins it, since it is an
error path (a different exception name per target) excluded by the
value-cases-only rule every migrated language follows. See
[The Jensen Device Diverges](../specs/2026-08-05-plcc-ng-need-design.md#the-jensen-device-diverges)
in the design doc.

Out of scope for this issue: TYPE0, TYPE1, and OBJ; error-path and
diagnostic tests, including `ValRORef`'s `cannot modify a read-only
reference` throw and `ErrorPrim`'s `user-defined error`; any test, `Prog/`
file, or workaround for the Jensen-device divergence; making `let` lazy or
any other extension of call-by-need beyond operands; issue
[#16](016-cross-target-integer-divergence.md) (cross-target integer
divergence), issue [#19](019-python-recursion-ceiling.md) (Python recursion
ceiling), and issue
[#22](022-plcc-rep-parses-each-source-independently.md) (plcc-rep parses
each SOURCE argument independently), all repo-wide and inherited; and any
unification of the Env variants or the per-language
`Val`/`IntVal`/`Prim`/`Ref` duplication.

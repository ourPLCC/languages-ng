---
type: feat
target: this repo
opened: 2026-08-05
closed: 2026-08-05
---

# 029 - migrate-name-to-plcc-ng

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

Port NAME (`REF + call-by-name semantics`) to plcc-ng: one shared
`grammar.plcc` plus three target `spec.plcc`s (Python, Java, JavaScript). NAME
is the third language of Phase 3 and the second in a row with a **zero syntax
delta** — `src/NAME/grammar.plcc` is REF's file with only its header comment
changed. Like REF it does only one job: SET already ported `envRef` (the
shared Env variant for SET, REF, NAME, and NEED) on NAME's behalf, so this
phase touches nothing under `src/Env/`.

NAME's whole content is a four-part semantic delta over REF, all following
from one fact — an operand becomes a thunk, not a value:

- `ThunkRef` is a new free-standing `Ref` subclass whose `deRef` evaluates
  the captured expression in the captured environment *every time it is
  called* — the absence of memoization is what separates NAME from NEED.
  Its `setRef` throws, since an arbitrary expression is not an assignable
  location.
- `Exp.evalRef` is rewritten to return `ThunkRef(self, env)` — this one
  method *is* call-by-name.
- `LitExp` and `ProcExp` override `evalRef` back to REF's `ValRef` form,
  since a literal or a closure is already a value with nothing to defer.
- Imports follow the class moves: `Exp:import` switches from `ValRef` to
  `ThunkRef`, `LitExp:import` gains `ValRef`, and `ProcExp` gains an
  `import` block it did not have under REF (Java needs none of this, being
  same-directory and package-less).

`Define` also changes its return value: pre-migration NAME had its
`System.out.println(id)` commented out, the only language in the repository
to suppress it. Since plcc-ng's `_run()` must return a string, "print
nothing" isn't available, and `return ""` still emits a blank line. Decision:
`return s`, matching SET, REF, NEED, and OBJ, so the defined name now prints
— logged in `dev-docs/course-material-impact.md` rather than smoothed over.

Five value-only test cases, each measured against all three targets before
being written down (see the design doc): `operand-evaluated-at-use/` (an
unused-until-later formal is forced after a `set` on another formal has
already run, → `7`, REF: `6`), `thunk-reevaluated-per-use/` (a thunk forced
seven times re-runs its side effect every time — the NAME↔NEED
discriminator, → `10`, REF: `4`), `unused-arg-not-evaluated/` (an operand
that is never used is never forced, so a division by zero in it never
happens, → `11`, REF: `attempt to divide by zero`), `jensen-device/` (a
`while` loop built entirely from call-by-name thunks re-forced each
iteration — the course centerpiece, → `while` `55`, REF: does not
terminate), and `by-name-terminates/` (a recursive third operand that is
never forced once the base case is reached, so the program terminates where
call-by-value cannot, → `p` `g` `8`, REF: does not terminate).
`operand-evaluated-at-use/` **is** NAME's existing single test,
`src/NAME/tests/let-proc/`, renamed rather than duplicated.

Unlike REF, NAME's `src/NAME/Prog/` needs no consolidation: there is no
`Stuff/` directory, no loose top-level program, and no syntax-error file to
fix. All eight existing `Prog/` programs already run clean in all three
targets.

Baseline measured today with a full `bin/test.bash` run: 105 tests, 100
passing, 5 failing (NAME, NEED, OBJ, TYPE0, TYPE1 — all `plccmk: command not
found`). After this phase: 119 tests (105, minus NAME's 1 old test, plus 15
new — 5 cases × 3 targets), 115 passing, 4 failing — the same `command not
found` set minus NAME.

## Notes

See
[dev-docs/specs/2026-08-05-plcc-ng-name-design.md](../specs/2026-08-05-plcc-ng-name-design.md),
which extends
[dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)
and builds directly on
[dev-docs/specs/2026-08-04-plcc-ng-ref-design.md](../specs/2026-08-04-plcc-ng-ref-design.md),
whose grammar, `envRef` reuse, and semantic classes NAME inherits almost
entirely unchanged, and through REF on
[dev-docs/specs/2026-08-04-plcc-ng-set-design.md](../specs/2026-08-04-plcc-ng-set-design.md).

Out of scope for this issue: NEED, TYPE0, TYPE1, and OBJ; error-path and
diagnostic tests, including the `ThunkRef.setRef` throw and the duplicate-ID
check; making `let` lazy or any other extension of call-by-name beyond
operands; issue [#16](016-cross-target-integer-divergence.md) (cross-target
integer divergence), issue [#19](019-python-recursion-ceiling.md) (Python
recursion ceiling), and issue
[#22](022-plcc-rep-parses-each-source-independently.md) (plcc-rep parses
each SOURCE argument independently), all repo-wide and inherited; and any
unification of the Env variants or the per-language
`Val`/`IntVal`/`Prim`/`Ref` duplication.

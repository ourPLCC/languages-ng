---
type: feat
target: this repo
opened: 2026-08-04
closed:
---

# 024 - migrate-ref-to-plcc-ng

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

Port REF (`SET + call-by-reference semantics`) to plcc-ng: one shared
`grammar.plcc` plus three target `spec.plcc`s (Python, Java, JavaScript). REF
is the second language of Phase 3 and the first in the entire migration with
a **zero syntax delta** — `src/REF/grammar.plcc` is SET's file with only its
header comment changed. It also does only one job, where SET did two: SET
already ported `envRef` (the shared Env variant for SET, REF, NAME, and NEED)
on REF's behalf, so this phase touches nothing under `src/Env/`.

REF's whole content is a five-method semantic delta over SET, all following
from one fact — operands evaluate to `Ref`s, not `Val`s:

- `Exp` gains a default `evalRef(env)` that wraps `eval` in a fresh `ValRef`.
- `VarExp` overrides it to return the binding's own `Ref` via
  `applyEnvRef` — this one method *is* call-by-reference.
- `Rands` gains `evalRandsRef`, alongside the untouched `evalRands` (which
  primitives still use).
- `AppExp.eval` calls `evalRandsRef` in place of `evalRands`.
- `Val.apply`/`ProcVal.apply` take a list of `Ref`s instead of `Val`s;
  `ProcVal` no longer wraps its args in fresh cells, since its caller already
  did.

Four value-only test cases, each measured against all three targets before
being written down (see the design doc): `formal-is-a-ref/` (`set` on a
formal reaches the caller's variable — REF's signature demonstration, → `4`,
the same program SET ships as `formal-is-a-copy/` with expected `3`, making
the SET→REF contrast a one-file diff), `nonvar-arg-is-a-copy/` (a
non-variable operand still gets a fresh cell — the only case exercising the
`Exp.evalRef` default, → `3`), `alias-two-formals/` (two formals aliasing one
binding, so a write through one is visible through the other — impossible
under SET, → `9`), and `captured-ref/` (a closure holding the caller's ref
through the persistent top-level environment, → `x g h 1 2 2`). REF's
existing single test, `src/REF/tests/let/`, **is**
`nonvar-arg-is-a-copy/` and is renamed rather than duplicated.

REF's example programs also consolidate into `src/REF/Prog/`: the
`Stuff/{counter1..5, factory}` directory (unique to REF among the fourteen
kept languages) folds in with `Stuff/factory` dropped as a byte-identical
duplicate of `Prog/factory`, and the loose top-level `oe` moves in with its
unbalanced-`{` syntax error fixed (the same repair V4 made to its own
`Prog/oe`). `counter1` and `counter3` are left exactly as written — both are
deliberate "here is what does not work" steps, not bit-rot.

Baseline measured today with a full `bin/test.bash` run: 84 tests, 78
passing, 6 failing (NAME, NEED, OBJ, REF, TYPE0, TYPE1 — all `plccmk:
command not found`). After this phase: 95 tests (84, minus REF's 1 old test,
plus 12 new — 4 cases × 3 targets), 90 passing, 5 failing — the same
`command not found` set minus REF.

## Notes

See
[dev-docs/specs/2026-08-04-plcc-ng-ref-design.md](../specs/2026-08-04-plcc-ng-ref-design.md),
which extends
[dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)
and builds directly on
[dev-docs/specs/2026-08-04-plcc-ng-set-design.md](../specs/2026-08-04-plcc-ng-set-design.md),
whose grammar, `envRef` port, and semantic classes REF inherits almost
entirely unchanged.

Out of scope for this issue: NAME and NEED, and the
`ThunkRef`/`ValRORef`/`ErrorPrim` work they add; TYPE0, TYPE1, and OBJ;
error-path and diagnostic tests; repairing `Prog/counter1` and
`Prog/counter3`; issue [#16](016-cross-target-integer-divergence.md)
(cross-target integer divergence), issue
[#19](019-python-recursion-ceiling.md) (Python recursion ceiling), and issue
[#22](022-plcc-rep-parses-each-source-independently.md) (plcc-rep parses each
SOURCE argument independently), all repo-wide and inherited; and any
unification of the Env variants or the per-language
`Val`/`IntVal`/`Prim`/`Ref` duplication.

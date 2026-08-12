---
type: test
target: this repo
opened: 2026-08-12
closed:
---

# 040 - OBJ test coverage gaps, and the 59-example sweep is not in the harness

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

Two related gaps in OBJ's test coverage, filed together since closing
either one touches the same seven-case suite under `src/OBJ/tests/`.

**Coverage gaps in the seven committed cases.** The seven cases
(`class/`, `objects/`, `inheritance/`, `lists/`, `strings-chars/`,
`env-ops/`, `errors/` — 47 program lines total) never exercise `/`,
`add1`, `sub1`, `zero?`, `exit`, the six comparison prims (`<? <=? >?
>=? <>? =?`), `!@`, `@@`, `letrec`, `if`, or any prim arity/type error
path. A reviewer verified these correct by hand during the final
branch review, so this is a regression-detection gap rather than a
known bug. Cheap to close: a handful more `.input`/`.expected` lines,
either extending existing cases or adding a new one.

**The 59-example cross-target sweep is not wired into the harness.**
The strongest evidence that this port is faithful to old PLCC is Task
5's byte-identity sweep across all 59 of OBJ's original example
programs, run on all three targets — but it ran from a throwaway
script in `/tmp`. Nothing in `bin/test.bash` re-runs it, so the
migration's best regression net currently exists nowhere durable.
Decide whether it becomes a committed, opt-in script (the suite's
runtime argues against making it part of the default run).

## Notes

The `.expected` files that already exist are genuinely load-bearing,
not filler — this issue is about widening coverage, not distrusting
what's there:

- `class/` pins static-vs-top-level shadowing.
- `strings-chars/` pins the output interleaving that breaks if anyone
  reverts a buffered output expression to printing (see the buffering
  entry in `dev-docs/course-material-impact.md`, `## OBJ`).
- `errors/` pins all three reserved-ID sites.

Found during the final whole-branch review of the OBJ migration
(issue #35).

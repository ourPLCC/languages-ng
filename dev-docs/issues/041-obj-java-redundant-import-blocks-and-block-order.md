---
type: refactor
target: this repo
opened: 2026-08-12
closed:
---

# 041 - OBJ Java spec carries 26 redundant :import blocks; head-of-file block order diverges

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

Two zero-behavior-impact cleanups in `src/OBJ/java/spec.plcc`, found
during the final whole-branch review and filed together since both are
about that file's readability rather than its correctness.

**26 redundant `:import` blocks.** Every prim from `AddPrim:import`
(`java:1275`) through `AppendPrim:import` (`:1717`), plus
`ErrorExp:import` (`:1145`) and `PerrorExp:import` (`:1162`), contains
only `import runtime.LanguageError;` — which plcc-ng auto-injects into
grammar-derived Java classes, making the explicit block redundant.
`src/SET/java/spec.plcc` uses `LanguageError` 13 times with zero such
blocks, confirming the auto-injection covers this case. The reviewer
verified deletion is safe by stripping all 26 in a scratch tree and
re-running a probe covering the object system, an arity error, `error`,
`perror`, `reverse`, and `puts`: identical output, 1,407 bytes lighter.
This also brings OBJ's Java spec in line with its own JavaScript spec,
which correctly omits the equivalent blocks per R9.

**The `import runtime.LanguageError;` lines inside free-standing class
bodies (`Val`, `ProcVal`, `ListNode`, `Reserved`) are required and must
stay** — auto-injection only covers grammar-derived classes, not
these.

**Head-of-file block order diverges from six predecessors.** OBJ's
Python and Java specs open with `Program`/`Eval`/`Define` and put `Val`
after (`python:53`, `java:69`); SET, TYPE1, and REF all open with the
free-standing value classes, and OBJ's own JavaScript spec follows that
convention (`Val` at `:7`). Java is additionally inconsistent with
itself: `Program:import` follows `Program` (`:19`) while `Eval:import`
precedes `Eval` (`:25`). Zero behavioral impact; matters only because
these spec files are meant to be read side by side with their six
predecessors.

## Notes

Found during the final whole-branch review of the OBJ migration
(issue #35). Both fixes are mechanical (deletion / reordering) and
carry no risk to generated output — verify with the seven-case
three-target cross-check described in that review rather than a full
`bin/test.bash` run.

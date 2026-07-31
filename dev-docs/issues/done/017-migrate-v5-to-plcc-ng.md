# 017 - migrate-v5-to-plcc-ng

**Type:** feat
**Target:** this repo
**Date:** 2026-07-31

<!--
Classify by user-facing impact, not by whether something was "broken".
`fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.
-->

## Description

Port V5's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V5 is
V4 + letrec: it adds the LETREC token, the <Exp:LetrecExp> production,
and LetDecls.addLetrecBindings, which builds a recursive scope by
extending the environment with an empty Bindings and then mutating that
node as each right-hand side is evaluated. It reuses the envVal Env
variant and every other V4 class without modification. V6 is explicitly
out of scope.

## Notes

See [dev-docs/specs/2026-07-31-plcc-ng-v5-design.md](../../specs/2026-07-31-plcc-ng-v5-design.md)
and [dev-docs/plans/2026-07-31-plcc-ng-phase2-v5.md](../../plans/2026-07-31-plcc-ng-phase2-v5.md).

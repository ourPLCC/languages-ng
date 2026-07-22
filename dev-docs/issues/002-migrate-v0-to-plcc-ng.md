# 002 - migrate-v0-to-plcc-ng

**Type:** feat
**Target:** this repo
**Date:** 2026-07-22

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

Port V0's grammar to `plcc-ng` syntax and add Python, Java, and
JavaScript semantics (today only Java exists, under old PLCC). V0 is the
migration's syntax pathfinder: it has no semantics beyond printing the
parsed expression and no `Env` dependency, so it's the cheapest place to
validate the per-language directory layout (shared `grammar.plcc` plus
`python/`, `java/`, `javascript/` subdirectories) and the `.bats` test
convention (one shared expected-output fixture per test case, asserted
against by all three targets) before they fan out to 13 more languages.

## Notes

See [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md),
including its "Addendum: Validated Syntax Facts" section, for concrete
syntax rules this migration must follow (the `_run()` print-vs-return
split between targets, and the `VAR` field-rename rule for JavaScript
compatibility).

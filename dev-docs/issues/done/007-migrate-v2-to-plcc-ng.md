# 007 - migrate-v2-to-plcc-ng

**Type:** feat
**Target:** this repo
**Date:** 2026-07-23

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

Port V2's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V2 is
V1 + IfExp: it reuses the envRN Env variant and V1's Prim/Val unchanged,
adding only the IfExp grammar production and its semantics. V3–V6 are
explicitly out of scope for this issue.

## Notes

See [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../../specs/2026-07-22-plcc-ng-migration-design.md),
[dev-docs/plans/2026-07-23-plcc-ng-phase2-v2.md](../../plans/2026-07-23-plcc-ng-phase2-v2.md),
and [issue #6](../006-multi-capture-alt-name-case-mismatch.md) (IfExp's
repeated-capture alt-names must be all-lowercase).

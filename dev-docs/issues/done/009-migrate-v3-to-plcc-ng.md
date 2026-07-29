# 009 - migrate-v3-to-plcc-ng

**Type:** feat
**Target:** this repo
**Date:** 2026-07-28

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

Port V3's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V3 is
V2 + let: it introduces the envVal Env variant (ported once here and
reused by V4-V6), keeping checkDuplicates and the two-list Bindings
constructor that envRN dropped, and adds the LetExp/LetDecls productions
and their semantics. V4-V6 are explicitly out of scope for this issue.

## Notes

See [dev-docs/specs/2026-07-28-plcc-ng-v3-design.md](../../specs/2026-07-28-plcc-ng-v3-design.md)
and [dev-docs/plans/2026-07-28-plcc-ng-phase2-v3.md](../../plans/2026-07-28-plcc-ng-phase2-v3.md).

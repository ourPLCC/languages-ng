---
type: feat
target: this repo
opened: 2026-07-22
closed: 2026-07-22
---

# 005 - migrate-v1-to-plcc-ng

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

Port V1's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V1 is the
first kept language that depends on `Env`, so this issue also ports the
`envRN` variant into the shared `src/Env/envRN/<target>/` location V2
will later reuse via `%include`. V2–V6 are explicitly out of scope for
this issue.

## Notes

See [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)
and [dev-docs/plans/2026-07-22-plcc-ng-phase2-v1.md](../plans/2026-07-22-plcc-ng-phase2-v1.md).

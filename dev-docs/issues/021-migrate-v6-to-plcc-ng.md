---
type: feat
target: this repo
opened: 2026-08-03
closed: 2026-08-03
---

# 021 - migrate-v6-to-plcc-ng

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

Port V6's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V6 is
V5 + top-level define: it adds the DEFINE token and splits <Program>
into Define and Eval alternatives. A define mutates a single Program-level
environment node that persists across every program in one plcc-rep run,
so a redefinition is visible through closures that already captured that
node. It reuses the envVal Env variant and every other V5 class without
modification.

This is the last language in Phase 2.

## Notes

See [dev-docs/specs/2026-08-03-plcc-ng-v6-design.md](../specs/2026-08-03-plcc-ng-v6-design.md)
and [dev-docs/plans/2026-08-03-plcc-ng-phase2-v6.md](../plans/2026-08-03-plcc-ng-phase2-v6.md).

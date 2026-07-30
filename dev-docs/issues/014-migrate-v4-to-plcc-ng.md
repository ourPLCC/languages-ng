# 014 - migrate-v4-to-plcc-ng

**Type:** feat
**Target:** this repo
**Date:** 2026-07-30

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

Port V4's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V4 is
V3 + procedures and the sequence operator: it adds the ProcExp/AppExp/
SeqExp productions, the Proc/Formals/SeqExps nonterminals, and the
ProcVal closure class, reusing the envVal Env variant V3 introduced
without modification. It is also the first migrated language with a
Prog/ directory of example programs, so this issue also verifies those
against all three targets. V5-V6 are explicitly out of scope.

## Notes

See [dev-docs/specs/2026-07-30-plcc-ng-v4-design.md](../specs/2026-07-30-plcc-ng-v4-design.md)
and [dev-docs/plans/2026-07-30-plcc-ng-phase2-v4.md](../plans/2026-07-30-plcc-ng-phase2-v4.md).

# 001 - remove-unused-languages

**Type:** chore
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

Remove all `src/` languages not used in current course materials, so the
repository only contains the 14 languages being migrated to `plcc-ng`
(V0–V6, SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ) plus the `Env` library.
Also removes the two `Env` variants (`envSimple`, `envRefCD`) that none
of the kept languages use.

## Notes

See [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../../specs/2026-07-22-plcc-ng-migration-design.md)
for the full migration design and phase order. Removed languages remain
recoverable from the original `ourPLCC/languages` repository's history if
ever needed.

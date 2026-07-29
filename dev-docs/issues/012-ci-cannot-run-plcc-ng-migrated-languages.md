# 012 - ci-cannot-run-plcc-ng-migrated-languages

**Type:** chore
**Target:** this repo
**Date:** 2026-07-29

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

CI's test image only installs old-PLCC (`ourPLCC/plcc` → `plccmk`/`rep`)
and has no Node.js. Any language that has been migrated to `plcc-ng`
(currently V0, V1, V2, V3) uses the `plcc-rep`/pipx-installed `plcc-ng`
tooling and, for its JavaScript target, Node.js — neither of which CI's
image provides. So in CI these languages fail with `command not found`
(`plcc-rep: command not found` and/or `node: command not found`), while
languages still on old-PLCC pass.

This is the exact opposite of local dev, where the devcontainer installs
`plcc-ng` (and Node.js) and old-PLCC languages are the ones that may not
even be runnable. This predates the V3 migration branch and is out of
scope to fix there, but it was untracked in `dev-docs/issues/` and the
roadmap despite the repo's usual issue bookkeeping discipline. That
branch makes the gap worse: it adds 9 more tests (V3's python/java/
javascript × let/nested-let/single-let cases) to the set that fails in
CI while passing locally.

## Steps to Reproduce

1. Look at `.github/workflows/test-languages.yaml` — it builds
   `.github/workflows/test-langauges.dockerfile` and runs
   `/languages/bin/test.bash` inside that image.
2. Look at `.github/workflows/test-langauges.dockerfile` — it installs
   Java, Python, Bats, and old-PLCC (via
   `https://github.com/ourPLCC/plcc/raw/main/installers/plcc/install.bash`).
   It never installs `plcc-ng`/pipx or Node.js.
3. Run `bin/test.bash` locally (with the devcontainer's `plcc-ng` +
   Node.js toolchain) versus in a container built from that Dockerfile:
   locally, V0-V3 (`plcc-ng`-migrated) pass and any still-old-PLCC
   language would need old-PLCC's `plccmk`/`rep` to be on `PATH`; in the
   Dockerfile's container, V0-V3 fail with `command not found` because
   `plcc-rep` and `node` are missing.

## Notes

Suggested fix direction: CI's image needs to install `plcc-ng` (matching
what `.devcontainer/devcontainer.json` does — pipx install/upgrade) and
Node.js, in addition to or instead of old-PLCC, so that both
already-migrated and future languages are actually exercised by CI. As
more languages migrate to `plcc-ng`, this gap only grows — currently
V0-V3; eventually all of V0-V6.

Found while doing the whole-branch review fix wave for the V3 migration
branch (issue #9, already closed). Not caused by that branch, but that
branch's 9 new tests are the first ones to make the failure count
concretely worse, which is what surfaced it.

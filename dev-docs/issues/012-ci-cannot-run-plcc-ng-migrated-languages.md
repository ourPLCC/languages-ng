---
type: chore
target: this repo
opened: 2026-07-29
closed:
---

# 012 - ci-cannot-run-plcc-ng-migrated-languages

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

**Deferred until every language has migrated to plcc-ng (decided
2026-07-30).** Do not act on the fix direction above before then — it is
written for a state the repo is leaving, and following it now would build
something half-disposable. Two reasons:

- *The failing job does not run.* `test-languages.yaml` triggers `on:
  pull_request`, and the working flow until migration completes is
  worktree → implement → merge to main → push. No PR is opened, so the
  job never fires and `bin/test.bash` run locally is the real quality
  gate. Fixing CI now buys nothing until the PR workflow exists.
- *The fix collapses once migration finishes.* Today a fix would have to
  install plcc-ng and Node.js **alongside** old-PLCC, since V0-V3 need
  the first and V4-V6 still need the second. After V4-V6 migrate,
  old-PLCC is needed nowhere and half that image is dead weight. The
  image already pinned in `.devcontainer/devcontainer.json` ships Java
  21, Python 3.12, Node 24, and plcc-ng, so the eventual fix is to base
  the CI image on that pin and add bats — not to keep extending the
  separately hand-assembled stack in `test-langauges.dockerfile`. Basing
  both on one image is also what stops the two toolchains drifting apart
  again, which is the underlying cause here.

Pick this up when the last language migrates, and rewrite the fix
direction then, together with the PR workflow that would make it
observable.

The mirror-image local gap needs no issue of its own. V4/V5/V6 fail
locally with `plccmk: command not found` only because their `.bats` files
still call old-PLCC, and migrating a language rewrites its `.bats` — the
failures delete themselves as the migration proceeds. Migrating does not
require old-PLCC to be installed: V3's migration never regenerated a
`.expected` from old-PLCC output (`let/V3.expected` predates it
unchanged; `nested-let` and `single-let` were authored new alongside the
plcc-ng tests). So do not add old-PLCC to the devcontainer to green those
three tests — it would install a toolchain the project is in the middle
of deleting the need for.

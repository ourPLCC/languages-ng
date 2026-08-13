# CI on the pinned devcontainer image, and a PR workflow

Design for issue [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md).
Date: 2026-08-12.

## Why now

Issue #12 was deferred on 2026-07-30 until every language had migrated to
plcc-ng, on the grounds that a fix written before then would have to
install plcc-ng and Node.js *alongside* old-PLCC and would be half
disposable the moment migration finished.

That condition has cleared. No `.bats` file calls `plccmk` any more —
all 55 of them drive `plcc-rep`, across V0-V6, SET, REF, NAME, NEED,
TYPE0, TYPE1, and OBJ. The only surviving mentions of old-PLCC are two
stale comments, in `bin/clean.bash` and `bin/relocate.bash`. So
old-PLCC is needed nowhere, and the disposable half of the fix simply
does not need to be written.

The issue's own text asks that the fix direction be *rewritten* when
picked up rather than followed as filed. This document is that rewrite.
It supersedes the "base the CI image on the devcontainer pin and add
bats" direction recorded in the issue.

## What is broken

`.github/workflows/test-langauges.dockerfile` hand-assembles Java 21,
Python 3, bats, and old-PLCC, and installs neither plcc-ng nor Node.js.
Every migrated language therefore fails in CI with `plcc-rep: command
not found` or `node: command not found`.

Separately, `.github/workflows/test-languages.yaml` triggers only on
`pull_request`, and the working flow has been worktree → merge to main →
push. No PR is opened, so the job never runs. Fixing the image alone
would leave the failure unobserved.

## Decisions

### CI runs inside the pinned devcontainer image, via `container:`

GitHub Actions runs every step of a job inside a named image when the
job declares `container:`. Pinning that to the same digest
`.devcontainer/devcontainer.json` already pins gives CI and local
development a bit-identical toolchain — Java 21.0.12, Python 3.12.13,
Node 24.19.0, plcc-ng 2.0.2 — with no image build anywhere in the repo.

Verified while designing this:

- The image is **anonymously pullable**. An anonymous ghcr token
  returns HTTP 200 for the `2.0.2` manifest, so CI needs no registry
  credentials. amd64 is 18 layers, 0.86 GB compressed.
- The image **ships Node 24**, which `container:` jobs require in order
  to run JavaScript-based actions such as `actions/checkout` at all.
  This is a common blocker for the approach and this image clears it.
- `plcc-rep` in the image is the `plcc-ng` PyPI package installed with
  pipx into `/usr/local/pipx/venvs/plcc-ng`; the installed version is
  2.0.2, matching the image tag.

The decisive property is that **the devcontainer already runs this
image**. Pinning CI to the same digest makes `bin/test.bash`, run in the
devcontainer, a faithful local reproduction of CI. Nothing needs to be
nested, so docker-in-docker never enters the picture.

### Rejected: a shared Dockerfile built by both consumers

The first design moved the digest and the bats install into
`.devcontainer/Dockerfile`, switched `devcontainer.json` from `"image"`
to `"build"`, and had CI build that same file and bind-mount the
checkout. It reached the same toolchain guarantee by a much longer road,
and every complication it carried came from Docker rather than from the
problem:

- **Local verification needed a Docker daemon.** There is none in the
  devcontainer, so verifying the image meant either a host terminal or
  adding docker-in-docker.
- **docker-in-docker undercuts the reason for the devcontainer.** The
  devcontainer exists to keep mistakes away from the host and from other
  projects. Docker-in-docker requires running it privileged, which
  weakens exactly that boundary; docker-outside-of-docker (mounting the
  host socket) is worse, granting effective host root. Spending
  isolation to buy fidelity is a bad trade when fidelity is available
  without it.
- **Bind mounts break inside a git worktree.** In a worktree, `.git` is
  a *file* reading `gitdir: /workspaces/languages-ng/.git/worktrees/
  <name>` — a path outside the worktree. Mounting only the worktree
  leaves that path absent in the container, so `git rev-parse --git-dir`
  fails, `relocate` reports "not in a git checkout", and all 165 `src`
  tests fail for a reason that looks like a toolchain bug and is not.
  CI is unaffected, since `actions/checkout` produces a normal clone —
  which makes this the worst kind of defect, one that breaks the gate
  rather than the thing being gated.
- **Ownership needed managing.** The image runs as `vscode` (uid 1000)
  while a runner checkout is owned by uid 1001, so git would reject the
  tree as dubious ownership without an explicit `chown`.

`container:` has none of these. It also deletes more than it adds.

### Rejected: a plain runner, following upstream's pattern

plcc-ng's own CI (`.github/workflows/ci.yml`) uses no Docker: eight
parallel `ubuntu-latest` jobs with `actions/setup-python`,
`actions/setup-java`, `actions/cache` keyed on `pdm.lock`, and
idempotent user-level installers in `bin/install/*.bash`. Its
devcontainer is an unrelated stack (`base:bullseye` plus features,
Java 17). Upstream therefore tolerates dev/CI divergence.

Their constraint is the inverse of ours. plcc-ng builds itself from
source and *cannot* consume a pinned release of itself; languages-ng
consumes plcc-ng 2.0.2, and that pin is the thing that must not drift.
Upstream's precedent is not evidence against sharing an image here.

Adopting their pattern would mean pinning Java, Python, Node, and
plcc-ng separately in the workflow — four drift vectors, of which only
the plcc-ng pin could be checked against `devcontainer.json` offline.
The runtime versions matter to this repo specifically because its
`.expected` files are byte comparisons of program output across three
targets; issues #16, #19, and #39 all record output that depends on
runtime behavior. Reintroducing drift to save roughly thirty seconds of
image pull is the wrong trade for a corpus whose entire purpose is
byte-identical cross-target output.

### The workflow gains a `push` backstop on main

`on: pull_request` alone leaves `main` unguarded: a direct push runs no
tests but does trigger `release.yaml`, which would cut a release from
unverified code. The workflow therefore triggers on both `pull_request`
and `push` to `main`.

### No `paths-ignore`

Upstream skips docs-only changes. This suite takes about two minutes,
and filtering by path would eventually collide with running
`bin/issues/check.bash` in CI — the one check that matters specifically
for a docs-only PR. Not worth the cleverness.

There is a second, harder reason, given the branch protection below: a
required status check that never reports leaves a PR permanently
unmergeable. With `paths-ignore`, a docs-only PR would skip the job,
never report `Test Languages`, and block forever. Running the suite
unconditionally is what makes the check safe to require.

### GitHub enforces the PR workflow; the repo records the settings

A convention that lives only in a document is advisory. `main` gets a
branch ruleset that makes the PR workflow the only way in, and the
intended settings are committed so they survive being changed or lost.

## Design

### `.github/workflows/test-languages.yaml`

```yaml
---
name: Test Languages

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  test:
    name: Test Languages
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.2@sha256:ebab585854e2c2dd5133db9616b398f6ede19702b514a5f4ace14757ae63dc9a
    steps:
      - uses: actions/checkout@v4
      - name: Install bats
        run: |
          bin/install/bats.bash
          echo "${HOME}/.local/bin" >> "${GITHUB_PATH}"
      - name: Test languages
        run: bin/test.bash
```

The image reference is written as `tag@sha256:…` so a reader sees which
plcc-ng release it corresponds to while the digest is what actually
resolves. This matches how `devcontainer.json` writes it.

### `bin/install/bats.bash`

A new idempotent installer, modeled on plcc-ng's
`bin/install/bats.bash`, so the two repositories share one idiom:

- Pins `BATS_VERSION` as a constant in the script.
- Exits early when `bats --version` already reports that version.
- Clones `bats-core` at the matching tag into a `mktemp -d` cleaned up
  by a trap, and installs into `${HOME}/.local`.
- Uses no `sudo`, unlike today's `postCreateCommand`.

`/home/vscode/.local/bin` is already on `PATH` in the image (confirmed;
the directory does not exist yet but the entry is present), so the
devcontainer needs no PATH handling. CI's `HOME` differs, so the
workflow appends to `GITHUB_PATH` after installing.

`devcontainer.json`'s `postCreateCommand` becomes
`bin/install/bats.bash`. Its `"image"` pin and the issue #11 warning
comment above it are left exactly as they are.

### `bin/tests/image-pin.bats`

The image reference now appears in two committed files. Unlike the
Java/Python/Node case, both values are readable offline, so this is
genuinely checkable rather than a matter of diligence.

A new bats file extracts the `ghcr.io/…@sha256:…` string from
`.devcontainer/devcontainer.json` and from
`.github/workflows/test-languages.yaml` and asserts they are identical,
failing with both values when they diverge. It must extract by pattern
rather than by parsing: `devcontainer.json` contains comments and so is
not valid JSON, and no YAML parser is guaranteed present in the image.

It rides along in the existing suite, since `bin/test.bash` already runs
`bats --recursive src bin`.

### Branch protection on `main` (applied by hand)

These are settings in GitHub's web UI, not files, so they are applied
manually by the maintainer rather than by a script in `bin/` — `gh` is
not installed in the devcontainer, and this is a one-time setup.
Because GitHub-side state is invisible to the repository and cannot be
recovered from it, `CONTRIBUTING.md` records the intended settings
verbatim, so a drifted or deleted ruleset is detectable by reading and
re-appliable by hand.

A ruleset targeting the **`main` branch**, with:

| Setting | Value | Why |
|---|---|---|
| Require a pull request before merging | on | Makes the PR the only route into `main`. |
| Required approvals | **0** | A solo maintainer cannot approve their own PR; requiring one would deadlock every merge. |
| Require status checks to pass | on, `Test Languages` | The gate this whole change exists to create. |
| Require branches to be up to date before merging | on | Catches two individually green PRs that break when combined. Cheap at this repo's volume. |
| Block force pushes | on | `main` history stays append-only. |
| Restrict deletions | on | |
| Bypass list | empty | Otherwise the rules are advisory for the only person they apply to. |

Target the branch, **not tags**. `.releaserc.yaml` runs
`@semantic-release/commit-analyzer` and `@semantic-release/github` and
has no `@semantic-release/git` plugin, so semantic-release creates a tag
and a GitHub Release and never pushes a commit to `main` — the PR
requirement cannot deadlock it. A ruleset that also targeted tags would
break tag creation.

The required check name is `Test Languages`, which is the workflow job's
`name:`. It must match exactly, and it only becomes selectable in the UI
after the workflow has reported at least once — so the ruleset is
applied *after* the first PR run, not before.

### `CONTRIBUTING.md`

New, at the repository root, following the shape of plcc-ng's: a
practical guide that links to existing convention documents rather than
duplicating them. It covers the development workflow this change adopts:

1. Create a worktree for the work.
2. Implement, committing as you go.
3. Run `bin/test.bash` locally — the same image CI uses.
4. Push the branch and open a PR.
5. Merge once CI is green.

It links to `dev-docs/issue-conventions.md`, `dev-docs/roadmap.md`, and
`dev-docs/course-material-impact.md` for the conventions they already
own, and summarizes the `bin/` commands a contributor runs.

It also reproduces the `main` ruleset table above. That table is the
repository's only durable copy of GitHub-side configuration, which is
otherwise unreadable from a checkout.

`CLAUDE.md` gains a requirement to read `CONTRIBUTING.md`, and the
worktree → merge → push flow it replaces is corrected wherever stated.

### `README.md`

`README.md` lines 13-17 document
`bin/test-using-pipeline-container.bash` — a live reference to a file
this change deletes, so it goes with it. The remaining "Run tests"
section's "Requires PLCC and bats to be installed" is also stale: the
devcontainer supplies both. It becomes a pointer to the devcontainer and
to `CONTRIBUTING.md`.

### Deletions

| Path | Why |
|---|---|
| `.github/workflows/test-langauges.dockerfile` | Old-PLCC is installed nowhere; the filename typo dies with it. |
| `.dockerignore` | Nothing builds an image any more. Issue #25's live guard is `relocate_copy_tree`'s git-driven filter, which is untouched. |
| `bin/test-using-pipeline-container.bash` | Superseded — the devcontainer *is* the pipeline container. |

Plus two stale comments asserting old-PLCC behavior: `bin/clean.bash`
line 3, and `bin/relocate.bash` line 41, which claims "OBJ, TYPE1 run
plccmk" — false since both migrated.

**Leave historical documents alone.** `dev-docs/plans/` and older
`dev-docs/specs/` files also mention the deleted paths, and
`CLAUDE.md`'s issue #25 narrative mentions `.dockerignore`. Those are
records of what was true when written, not live references. Rewriting
them is the mistake issue #18 exists to record. Only `README.md` and the
workflow are updated.

## Verification

**Step 1 — locally.** `bin/test.bash` in the devcontainer, expecting
`EXIT=0`. The suite is 186 tests today; `bin/tests/image-pin.bats` adds
its own, so the expected total is 186 plus however many that file
contains, and the banner must report every one of them passing. This is
now a faithful check of the CI environment, since CI runs the same
image.

**Step 2 — the first PR's CI run must be green.** Two `container:`
frictions are known and unconfirmed from here:

- **Workspace permissions under a non-root image.** The image runs as
  `vscode` while Actions prepares the workspace as root, which sometimes
  produces write failures. `options: --user root` is the escape hatch.
- **git ownership.** `relocate` calls `git rev-parse` and
  `git ls-files`, so git must accept the checkout. `actions/checkout`
  sets `safe.directory` for the workspace, which should cover it —
  treated as verified only after a green run.

**Step 3 — the maintainer applies the `main` ruleset by hand**, after
that first green run, since `Test Languages` only becomes selectable as
a required check once the workflow has reported at least once.

**Step 4 — a direct push to `main` is rejected**, confirming the ruleset
is live rather than merely saved.

Steps 1 and 2 gate the code; steps 3 and 4 are manual and gate the
workflow. Issue #12 stays open until step 2 is green — local evidence
cannot close an issue about CI. The branch's own merge is the first
exercise of the new flow: it goes in as a PR, not a direct push.

## Out of scope

- Adding `bin/issues/check.bash` to CI.
- plcc-ng's `e2e` job pins `ourPLCC/languages` (the predecessor repo) at
  commit `57777e0` as its Java corpus, not this repository. Worth an
  issue; not this one.
- Issue #27's `plcc-rep -s` change, which would remove `relocate`'s tree
  copy altogether.

## Course-material impact

None. No language, grammar symbol, field name, or program output
changes.

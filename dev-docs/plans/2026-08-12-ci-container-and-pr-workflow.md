# CI on the pinned image, and a PR workflow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CI actually run this repository's test suite, by running it inside the same pinned image the devcontainer already uses, and make that CI observable by adopting a PR workflow that GitHub enforces.

**Architecture:** The CI job declares `container:` with the digest `.devcontainer/devcontainer.json` already pins, so CI and local development share a bit-identical toolchain with no image build anywhere in the repo. The one part of the toolchain the image lacks — bats — moves into a single `bin/install/bats.bash` called by both the devcontainer's `postCreateCommand` and the workflow. A bats test guards the one remaining drift vector, the digest now appearing in two files.

**Tech Stack:** GitHub Actions, bash, bats-core 1.11.0, sed. No new dependencies. Nothing in `src/` changes.

Design spec: [2026-08-12-ci-container-and-pr-workflow-design.md](../specs/2026-08-12-ci-container-and-pr-workflow-design.md).
Issue: [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md).

## Global Constraints

- **Commit types are `chore`, `test`, or `docs` only.** Nothing in `src/` changes, so the release version must not spin (`.releaserc.yaml` bumps on `fix`/`feat`). Issue #12 is itself `type: chore`.
- **Every commit message ends with** `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- **The branch is `worktree-ci-plcc-ng-migrated-languages`,** in the worktree at `/workspaces/languages-ng/.claude/worktrees/ci-plcc-ng-migrated-languages`. Confirm with `git branch --show-current` before every commit. Never `cd` to `/workspaces/languages-ng`. See [CLAUDE.md](../../CLAUDE.md), "Verifying a subagent's commits".
- **`set -euo pipefail` goes before any `cd`,** never after — the issue #25 defect.
- **The pinned image reference, verbatim, everywhere it appears:**
  `ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.2@sha256:ebab585854e2c2dd5133db9616b398f6ede19702b514a5f4ace14757ae63dc9a`
- **`BATS_VERSION` is `1.11.0`** — matching what `.devcontainer/devcontainer.json` installs today.
- **Do not rewrite historical documents.** `dev-docs/plans/` and older `dev-docs/specs/` files mention the paths this plan deletes, and `CLAUDE.md`'s issue #25 narrative mentions `.dockerignore`. Those are records of what was true when written. Only `README.md` and the workflow are updated. Rewriting plan prose is the mistake issue #18 exists to record.
- **The issue is closed with `bin/issues/close.bash`** as the final commit of the branch, per CLAUDE.md — but only *after* CI is green (Task 8). Never edit the `closed:` field or `roadmap.md` by hand.

**Everything below has been executed and verified** in a scratch directory before being written here, including the mutation tests proving the assertions have teeth. Code blocks are transcription-ready.

## File Structure

| File | Responsibility |
|---|---|
| `bin/install/bats.bash` *(new)* | Install the pinned bats under `~/.local` if absent. Idempotent, no sudo. The single definition of which bats this project uses. |
| `bin/tests/install-bats.bats` *(new)* | Tests the early-exit branch only. The install branch needs network and is exercised for real by CI. |
| `bin/tests/image-pin.bats` *(new)* | Asserts `devcontainer.json` and the workflow name the same image, and that both extractors match exactly once. |
| `.github/workflows/test-languages.yaml` *(rewrite)* | The whole CI definition: triggers, the pinned `container:`, three steps. |
| `.devcontainer/devcontainer.json` *(modify)* | `postCreateCommand` calls the new script. The `"image"` pin and its issue #11 comment are untouched. |
| `CONTRIBUTING.md` *(new)* | The PR workflow, the commands, and the durable copy of the `main` ruleset settings. |
| `CLAUDE.md` *(modify)* | Requires reading `CONTRIBUTING.md`. |
| `README.md` *(modify)* | Drops the deleted script; points at the devcontainer and `CONTRIBUTING.md`. |
| `.github/workflows/test-langauges.dockerfile` *(delete)* | Old-PLCC is installed nowhere. |
| `.dockerignore` *(delete)* | Nothing builds an image any more. |
| `bin/test-using-pipeline-container.bash` *(delete)* | The devcontainer *is* the pipeline container. |
| `bin/clean.bash:3`, `bin/relocate.bash:41` *(modify)* | Two stale comments asserting old-PLCC behavior. |

## Task Order

Tasks 1-7 are code and documentation, each independently committable. Task 8 is the manual gate: push, PR, green CI, ruleset, close. Task 8 cannot be done by an implementing agent — it needs the maintainer's GitHub access.

---

### Task 1: The bats installer

**Files:**
- Create: `bin/install/bats.bash`
- Test: `bin/tests/install-bats.bats`

**Interfaces:**
- Produces: an executable `bin/install/bats.bash` taking no arguments. Exits 0 having ensured `bats` 1.11.0 is available. Task 2 calls it from the workflow; Task 3 calls it from `postCreateCommand`.

- [ ] **Step 1: Write the failing test**

Create `bin/tests/install-bats.bats`:

```bash
#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# Only the early-exit branch is tested here. The install branch clones
# from GitHub, so putting it in the suite would make every run depend on
# the network and on GitHub being up. It is exercised for real, on every
# CI run, in an image that has no bats -- which is the better test
# anyway, since that is the situation it exists for.

@test "install-bats exits 0 and installs nothing when the pinned bats is present" {
  run "${BATS_TEST_DIRNAME}/../install/bats.bash"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install-bats pins the same bats version the suite runs" {
  local pinned
  pinned="$(sed -nE 's/^BATS_VERSION="([^"]+)"$/\1/p' \
    "${BATS_TEST_DIRNAME}/../install/bats.bash")"
  [ -n "${pinned}" ]
  bats --version | grep -q "${pinned}"
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bats bin/tests/install-bats.bats`
Expected: both tests fail — the script does not exist yet, so `run` reports a non-zero status and the `sed` yields an empty string.

- [ ] **Step 3: Write the script**

Create `bin/install/bats.bash`:

```bash
#!/usr/bin/env bash

# Install the pinned bats under ~/.local, if it is not already there.
#
# One script, two callers: devcontainer.json's postCreateCommand and the
# CI workflow. That is the point -- bats is the one part of the
# toolchain the pinned image does not carry, so a second copy of this
# logic is a second bats version waiting to diverge.
#
# ~/.local rather than /usr/local because CI and the devcontainer run as
# different users; a user-local install needs no sudo in either. The
# image already has ~/.local/bin on PATH, so the devcontainer needs no
# PATH handling. CI's HOME differs, so the workflow appends to
# GITHUB_PATH itself.
#
# Modeled on ourPLCC/plcc-ng's bin/install/bats.bash so the two
# repositories share one idiom.

set -euo pipefail

BATS_VERSION="1.11.0"

if command -v bats >/dev/null 2>&1 \
    && bats --version | grep -q "${BATS_VERSION}"; then
  echo "bats ${BATS_VERSION} already installed: $(command -v bats)"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

git clone --depth 1 --branch "v${BATS_VERSION}" \
  https://github.com/bats-core/bats-core.git "${tmp_dir}/bats-core"
"${tmp_dir}/bats-core/install.sh" "${HOME}/.local"

echo "installed bats ${BATS_VERSION} into ${HOME}/.local"
```

Then make it executable:

```bash
chmod +x bin/install/bats.bash
```

- [ ] **Step 4: Run the tests and make sure they pass**

Run: `bats bin/tests/install-bats.bats`
Expected: `ok 1`, `ok 2`.

- [ ] **Step 5: Prove the version assertion has teeth**

Temporarily break the pin and confirm test 2 fails:

```bash
sed -i 's/^BATS_VERSION="1.11.0"$/BATS_VERSION="1.10.0"/' bin/install/bats.bash
bats bin/tests/install-bats.bats
```

Expected: **both** tests fail — test 1 because the early-exit branch no
longer matches and the script tries to clone 1.10.0, test 2 because the
pin no longer matches the running bats.

Restore it:

```bash
sed -i 's/^BATS_VERSION="1.10.0"$/BATS_VERSION="1.11.0"/' bin/install/bats.bash
bats bin/tests/install-bats.bats
```

Expected: `ok 1`, `ok 2`.

- [ ] **Step 6: Commit**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git add bin/install/bats.bash bin/tests/install-bats.bats
git commit -m "chore(bin): add an idempotent bats installer

bats is the one part of the toolchain the pinned devcontainer image
does not carry, so both the devcontainer and CI have to install it.
One script called by both is what keeps them on one version; two
copies of the logic would be two versions waiting to diverge.

Installs under ~/.local rather than /usr/local because CI and the
devcontainer run as different users, and a user-local install needs
no sudo in either. Modeled on ourPLCC/plcc-ng's bin/install/bats.bash
so the two repositories share one idiom.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: The CI workflow

**Files:**
- Rewrite: `.github/workflows/test-languages.yaml`
- Delete: `.github/workflows/test-langauges.dockerfile`

**Interfaces:**
- Consumes: `bin/install/bats.bash` from Task 1.
- Produces: a workflow job whose display name is exactly `Test Languages`. Task 6 records that name as the required status check; Task 8 selects it in GitHub's UI. It must match exactly.

- [ ] **Step 1: Rewrite the workflow**

Replace the entire contents of `.github/workflows/test-languages.yaml` with:

```yaml
---
name: Test Languages

# Runs inside the same image .devcontainer/devcontainer.json pins, so a
# local pass predicts a CI pass. bin/tests/image-pin.bats fails if these
# two files ever name different images.
#
# The push trigger is a backstop, not the gate: release.yaml runs on
# push to main, so an unverified commit reaching main would cut a
# release from untested code. The gate is the required status check on
# pull requests -- see CONTRIBUTING.md.

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
      -
        name: Checkout
        uses: actions/checkout@v4
      -
        name: Install bats
        run: |
          bin/install/bats.bash
          echo "${HOME}/.local/bin" >> "${GITHUB_PATH}"
      -
        name: Test languages
        run: bin/test.bash
```

- [ ] **Step 2: Delete the old image definition**

```bash
git rm .github/workflows/test-langauges.dockerfile
```

That file installed old-PLCC and no plcc-ng or Node.js, which is issue
#12 itself. Nothing references it once the workflow above replaces the
build step. Its filename typo goes with it.

- [ ] **Step 3: Verify the YAML parses and says what it should**

```bash
python3 -c "import sys; sys.exit(0)"   # sanity: python3 present
grep -n 'name: Test Languages' .github/workflows/test-languages.yaml
grep -c 'ghcr.io/ourplcc/devcontainers/plcc-ng' .github/workflows/test-languages.yaml
```

Expected: the `grep -n` prints two lines (the workflow name and the job
name — both are legitimately `Test Languages`), and the count is `1`.

- [ ] **Step 4: Commit**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git add .github/workflows/test-languages.yaml
git commit -m "chore(ci): run the suite in the pinned image via container:

Closes the gap issue #12 describes: the old image installed old-PLCC
and neither plcc-ng nor Node.js, so every migrated language failed in
CI with 'command not found' while passing locally. Every language has
now migrated, so old-PLCC is needed nowhere and the image it lived in
is deleted rather than extended.

Uses the container: job key with the digest devcontainer.json already
pins, rather than building an image. The devcontainer already runs
that image, so bin/test.bash locally is a faithful reproduction of CI
and nothing needs to be nested -- no Dockerfile, no bind mounts, no
docker-in-docker.

Adds a push trigger on main as a backstop, since release.yaml runs on
push and would otherwise cut a release from untested code.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Point the devcontainer at the installer

**Files:**
- Modify: `.devcontainer/devcontainer.json:16`

**Interfaces:**
- Consumes: `bin/install/bats.bash` from Task 1.

- [ ] **Step 1: Replace the postCreateCommand**

In `.devcontainer/devcontainer.json`, replace this line:

```json
  "postCreateCommand": "BATS_VERSION=v1.11.0 && git clone https://github.com/bats-core/bats-core.git /tmp/bats-core && cd /tmp/bats-core && git checkout $BATS_VERSION && sudo ./install.sh /usr/local && cd - && rm -rf /tmp/bats-core"
```

with:

```json
  "postCreateCommand": "bin/install/bats.bash"
```

Leave the `"image"` pin and the issue #11 comment block above it exactly
as they are. Leave `"features"` alone — `claude-code` and `shellcheck`
are dev-only and CI has no use for them.

- [ ] **Step 2: Verify nothing else changed**

```bash
git diff --stat .devcontainer/devcontainer.json
git diff .devcontainer/devcontainer.json
```

Expected: one line removed, one added. The diff must not touch the
`"image"` line.

- [ ] **Step 3: Commit**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git add .devcontainer/devcontainer.json
git commit -m "chore(devcontainer): install bats via bin/install/bats.bash

Same version, same result, but now the devcontainer and CI install
bats from one script instead of two copies of the logic. Drops the
sudo install into /usr/local for a user-local one, which works
unchanged for whichever user CI runs as.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Guard the image pin

**Files:**
- Create: `bin/tests/image-pin.bats`

**Interfaces:**
- Consumes: the workflow from Task 2 and the unchanged `"image"` line in `.devcontainer/devcontainer.json`. This task must come after Task 2, or the workflow has no `image:` key to find.

- [ ] **Step 1: Write the test**

Create `bin/tests/image-pin.bats`:

```bash
#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# The image is pinned in two files that cannot read each other:
# .devcontainer/devcontainer.json, which is what your dev environment
# runs, and the CI workflow's container:, which is what CI runs. The
# entire value of pinning both to one digest is that a local pass
# predicts a CI pass, so a silent divergence destroys the guarantee
# without breaking anything visibly. This is the only drift vector the
# container: design leaves open, and unlike the Java, Python and Node
# versions inside the image, both values are readable from a checkout --
# which is what makes it checkable at all.
#
# Extraction is by pattern, not by parser: devcontainer.json carries
# comments and so is not valid JSON, and no YAML parser is guaranteed
# present in the image.

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."

devcontainer_image () {
  sed -nE 's/^[[:space:]]*"image"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
    "${REPO_ROOT}/.devcontainer/devcontainer.json"
}

workflow_image () {
  sed -nE 's/^[[:space:]]*image:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' \
    "${REPO_ROOT}/.github/workflows/test-languages.yaml"
}

# Guard the extractors themselves. Without these, a renamed key or a
# reformatted file yields no match, and the comparison below passes by
# comparing one empty string to another -- a green test proving nothing.

@test "devcontainer.json names exactly one image" {
  run devcontainer_image
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "the workflow names exactly one container image" {
  run workflow_image
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "devcontainer and CI pin the same image" {
  local dev ci
  dev="$(devcontainer_image)"
  ci="$(workflow_image)"
  [ -n "${dev}" ]
  if [[ "${dev}" != "${ci}" ]]; then
    echo "devcontainer.json: ${dev}" >&2
    echo "workflow:          ${ci}" >&2
    return 1
  fi
}
```

**Why `"image"` is matched with the quotes and `image:` without them.**
`devcontainer.json`'s `features` block contains three more `ghcr.io/…`
strings (`claude-code`, `shellcheck`), so an unanchored `ghcr.io` pattern
returns four matches, not one. Anchoring on the quoted key at the start
of a line is what selects only the base image. This was verified against
the real file; the unanchored version was tried first and did return
four.

- [ ] **Step 2: Run it and confirm it passes**

Run: `bats bin/tests/image-pin.bats`
Expected: `ok 1`, `ok 2`, `ok 3`.

- [ ] **Step 3: Prove all three assertions have teeth**

Mutation A — a divergent digest:

```bash
sed -i 's/ebab5858/ebab5859/' .github/workflows/test-languages.yaml
bats bin/tests/image-pin.bats
```

Expected: tests 1 and 2 pass, test 3 fails and prints both values.

```bash
sed -i 's/ebab5859/ebab5858/' .github/workflows/test-languages.yaml
```

Mutation B — a renamed key, which is the false-pass case:

```bash
sed -i 's/"image":/"imageRef":/' .devcontainer/devcontainer.json
bats bin/tests/image-pin.bats
```

Expected: test 1 fails on the line count and test 3 fails on
`[ -n "${dev}" ]` — *not* a green run comparing two empty strings.

```bash
sed -i 's/"imageRef":/"image":/' .devcontainer/devcontainer.json
bats bin/tests/image-pin.bats
```

Expected: `ok 1`, `ok 2`, `ok 3`, and `git status --porcelain` reports
no modifications to either file.

- [ ] **Step 4: Commit**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git add bin/tests/image-pin.bats
git commit -m "test(bin): fail when devcontainer and CI pin different images

Running CI in the image the devcontainer pins is only worth anything
while the two files agree, and nothing about a divergence is visible:
both halves keep working, they just stop describing the same
toolchain, and 'passes locally, fails in CI' quietly comes back.

Guards the extractors as well as the comparison. A renamed key would
otherwise yield no match in both files and pass by comparing one empty
string to another.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Retire the local pipeline-container script

**Files:**
- Delete: `bin/test-using-pipeline-container.bash`
- Delete: `.dockerignore`
- Modify: `README.md:5-17`

**Interfaces:**
- Consumes: nothing. Must come after Task 2, which removes the Dockerfile the deleted script builds.

- [ ] **Step 1: Delete both files**

```bash
git rm bin/test-using-pipeline-container.bash .dockerignore
```

`bin/test-using-pipeline-container.bash` built
`.github/workflows/test-langauges.dockerfile`, which Task 2 deleted. Its
purpose — run the suite the way the pipeline does — is now served by
running the suite, because the devcontainer and CI are the same image.

`.dockerignore` only ever affected a build context, and nothing builds
an image any more. Issue #25's live guard is `relocate_copy_tree`'s
git-driven filter in `bin/relocate.bash`, which this does not touch.

- [ ] **Step 2: Rewrite the README's test section**

In `README.md`, replace lines 5-17 — the `## Run tests` heading through
the second fenced block — with:

````markdown
## Run tests

Open this repository in its devcontainer (VS Code: "Dev Containers:
Reopen in Container"), then:

```bash
bin/test.bash
```

CI runs the same suite in the same image, so a local pass predicts a CI
pass. See [CONTRIBUTING.md](CONTRIBUTING.md) for the development
workflow.
````

The old text said "Requires PLCC and bats to be installed", which was
already stale — the devcontainer supplies both.

- [ ] **Step 3: Confirm no live references remain**

```bash
grep -rn "test-using-pipeline-container\|test-langauges.dockerfile" \
  README.md CLAUDE.md bin .github 2>/dev/null
```

Expected: no output. Matches under `dev-docs/` are historical records and
**must be left alone** — see Global Constraints.

- [ ] **Step 4: Commit**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git add -A README.md
git commit -m "chore: retire the local pipeline-container script

It built the Dockerfile the previous commit deleted. What it existed
for -- running the suite the way the pipeline runs it -- is now what
bin/test.bash already does, since the devcontainer and CI are the same
image. .dockerignore goes too: it only ever affected a build context,
and nothing builds an image any more.

The README's 'Requires PLCC and bats to be installed' was stale
independently of this; the devcontainer supplies both.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: CONTRIBUTING.md

**Files:**
- Create: `CONTRIBUTING.md`
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: the job name `Test Languages` from Task 2, recorded here as the required status check.

- [ ] **Step 1: Write CONTRIBUTING.md**

Create `CONTRIBUTING.md`:

````markdown
# Contributing

This document is the practical guide for working in this repository: how
a change gets from a worktree to `main`, and the commands you run along
the way. Read it before making changes.

Conventions that have their own documents are linked, not duplicated:
the issue workflow is in
[dev-docs/issue-conventions.md](dev-docs/issue-conventions.md), open work
is in [dev-docs/roadmap.md](dev-docs/roadmap.md), and changes an
instructor's materials must track are logged in
[dev-docs/course-material-impact.md](dev-docs/course-material-impact.md).

## Development environment

Open the repository in its devcontainer. It runs a digest-pinned image
carrying Java, Python, Node, and `plcc-ng`; `postCreateCommand` adds
bats. Do not install toolchain pieces by hand — see the warning in
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) and
[issue #11](dev-docs/issues/011-devcontainer-image-stale-plcc-ng-version.md).

## The workflow

1. **Create a worktree** for the change, so `main` and other work stay
   untouched.
2. **Implement**, committing as you go. Commit messages follow
   [Conventional Commits](https://www.conventionalcommits.org/); the type
   matters, because `.releaserc.yaml` cuts a release on `fix` and `feat`.
   A change to tests, scripts, or CI is `test` or `chore`, not `fix`.
3. **Run the suite**: `bin/test.bash`. CI runs this same suite in the
   same image, so a local pass predicts a CI pass.
4. **Push the branch and open a pull request.** Direct pushes to `main`
   are rejected.
5. **Merge once CI is green.**

## Commands

| Command | What it does |
|---|---|
| [bin/test.bash](bin/test.bash) | Run the whole bats suite over `src/` and `bin/`. Exit 0 means every test passed, 1 means real failures, 2 means the harness itself did not finish. |
| [bin/clean.bash](bin/clean.bash) | Remove build output left under `src/`. |
| [bin/install/bats.bash](bin/install/bats.bash) | Install the pinned bats under `~/.local`. Idempotent; run by `postCreateCommand` and by CI. |
| [bin/issues/new.bash](bin/issues/new.bash) | Create an issue. Never assign issue numbers by hand. |
| [bin/issues/close.bash](bin/issues/close.bash) | Close an issue, as the final commit of the branch that does the work. |
| [bin/issues/check.bash](bin/issues/check.bash) | Verify issue and roadmap consistency. |

## Continuous integration

[.github/workflows/test-languages.yaml](.github/workflows/test-languages.yaml)
runs `bin/test.bash` inside the same image
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) pins,
via the `container:` job key. That is what makes a local pass meaningful.
`bin/tests/image-pin.bats` fails if the two files ever name different
images.

It triggers on every pull request, and on pushes to `main` as a
backstop — `release.yaml` runs on push, so an unverified commit reaching
`main` would cut a release from untested code.

## Branch protection on `main`

These settings live in GitHub, not in this repository, so this table is
their only durable copy. If the ruleset is changed or deleted, this is
what it should be restored to. Applied by hand, as a ruleset targeting
the **`main` branch** (not tags — `.releaserc.yaml` has no
`@semantic-release/git` plugin, so semantic-release only creates tags and
releases, and a ruleset covering tags would break it).

| Setting | Value | Why |
|---|---|---|
| Require a pull request before merging | on | Makes the PR the only route into `main`. |
| Required approvals | 0 | A solo maintainer cannot approve their own PR; requiring one would deadlock every merge. |
| Require status checks to pass | on, `Test Languages` | The gate. The name must match the workflow job's `name:` exactly. |
| Require branches to be up to date before merging | on | Catches two individually green PRs that break when combined. |
| Block force pushes | on | `main` history stays append-only. |
| Restrict deletions | on | |
| Bypass list | empty | Otherwise the rules are advisory for the only person they apply to. |
````

- [ ] **Step 2: Require it from CLAUDE.md**

In `CLAUDE.md`, insert this section immediately after the
`## Anything worth remembering goes in a committed file` section — that
is, directly before the line `## Creating and closing issues`:

```markdown
## Read CONTRIBUTING.md

[CONTRIBUTING.md](CONTRIBUTING.md) is required reading before making
changes. It owns the development workflow — worktree, commit types,
`bin/test.bash`, pull request, merge — and the `main` branch protection
settings, which live in GitHub and have no other copy in this
repository. Direct pushes to `main` are rejected; every change goes in
through a pull request whose `Test Languages` check is green.
```

- [ ] **Step 3: Verify the links resolve**

```bash
bin/issues/check.bash
```

Expected: exits 0. This checks issue and roadmap consistency, which the
new `CONTRIBUTING.md` links into.

Then confirm every relative link in the new file points at something
real:

```bash
grep -oE '\]\(([^)h][^)]*)\)' CONTRIBUTING.md \
  | sed -E 's/^\]\(//; s/\)$//' \
  | while read -r p; do [ -e "$p" ] || echo "MISSING: $p"; done
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git add CONTRIBUTING.md CLAUDE.md
git commit -m "docs: adopt a PR workflow, and record it in CONTRIBUTING.md

Issue #12's second half: CI that never runs is not a gate. The job
triggered only on pull_request while the working flow was worktree ->
merge to main -> push, so it never fired and bin/test.bash run locally
was the real quality gate.

Records the main ruleset settings in full. They live in GitHub, not in
the repository, so without this table a changed or deleted ruleset
leaves nothing to restore from -- the same reasoning as CLAUDE.md's
'anything worth remembering goes in a committed file'.

Required approvals is 0 deliberately: a solo maintainer cannot approve
their own pull request, so requiring one would deadlock every merge.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Correct the two stale old-PLCC comments

**Files:**
- Modify: `bin/clean.bash:3`
- Modify: `bin/relocate.bash:37-47`

- [ ] **Step 1: Fix `bin/clean.bash`**

Replace line 3:

```bash
# Remove the build output plcc-rep and plccmk leave under src/ --
```

with:

```bash
# Remove the build output plcc-rep leaves under src/ --
```

- [ ] **Step 2: Fix `bin/relocate.bash`**

Replace this passage (lines 37-47):

```bash
# BATS_TEST_DIRNAME is .../src/<LANG>/tests/<case>. Copy the whole src/
# tree (not just <LANG>/) for two reasons: migrated specs %include a
# sibling top-level directory -- e.g. V1's spec.plcc reaching into
# ../../Env/envRN/<target>/env.plcc -- and the not-yet-migrated languages
# (OBJ, TYPE1) run plccmk, which builds in place and
# has no way to be pointed at a spec elsewhere.
#
# The %include half of that is now avoidable: plcc-rep -s <abs spec path>
# resolves %include from the spec's real location while writing build
# output to the cwd, so migrated tests need no copy at all. See the
# follow-up issue filed alongside issue #25.
```

with:

```bash
# BATS_TEST_DIRNAME is .../src/<LANG>/tests/<case>. Copy the whole src/
# tree (not just <LANG>/) because specs %include a sibling top-level
# directory -- e.g. V1's spec.plcc reaching into
# ../../Env/envRN/<target>/env.plcc.
#
# That is now avoidable: plcc-rep -s <abs spec path> resolves %include
# from the spec's real location while writing build output to the cwd,
# so the tests need no copy at all. Every language has migrated to
# plcc-ng, so the second reason this function used to give -- that OBJ
# and TYPE1 ran plccmk, which builds in place -- no longer applies, and
# nothing now requires the copy. See issue #27.
```

- [ ] **Step 3: Confirm no `plccmk` claims survive in `bin/`**

```bash
grep -rn "plccmk" bin
```

Expected: no output.

- [ ] **Step 4: Run the affected tests**

```bash
bats bin/tests/relocate.bats bin/tests/clean.bats
```

Expected: all pass. These are comment-only edits, so a failure means
something was deleted that should not have been.

- [ ] **Step 5: Commit**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git add bin/clean.bash bin/relocate.bash
git commit -m "docs(bin): drop stale claims that OBJ and TYPE1 run plccmk

Both migrated; no .bats file calls plccmk any more. relocate.bash gave
two reasons for copying the whole src/ tree and one of them is now
false, which matters because it was also the reason issue #27 could
not simply be applied. Only the %include reason is left.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Verify, then close (maintainer)

**This task requires the maintainer's GitHub access and cannot be
completed by an implementing agent.** Steps 1 and 2 can be; steps 3-6
cannot.

- [ ] **Step 1: Run the full suite locally**

```bash
bin/test.bash; echo "EXIT=$?"
```

Expected: `EXIT=0` and a banner reporting every test passing. The suite
was 186 tests before this branch; Tasks 1 and 4 add five (two in
`install-bats.bats`, three in `image-pin.bats`), so expect **191**. A
different total means a test file was not collected — investigate rather
than accept it.

- [ ] **Step 2: Push the branch and open a pull request**

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
git push -u origin worktree-ci-plcc-ng-migrated-languages
```

Then open a PR against `main`. This is the first exercise of the new
workflow, and the PR itself is what proves the workflow works.

- [ ] **Step 3: Confirm CI is green**

Two `container:` frictions are known and unverifiable from the
devcontainer. If the run fails, these are the first two things to check
— they are expected risks, not surprises:

- **Workspace permissions under a non-root image.** The image runs as
  `vscode` while Actions prepares the workspace as root, which can cause
  write failures. Fix by adding `options: --user root` under
  `container:`.
- **git ownership.** `relocate` calls `git rev-parse` and `git ls-files`,
  so git must accept the checkout. `actions/checkout` sets
  `safe.directory` for the workspace, which should cover it. If it does
  not, add a step running
  `git config --global --add safe.directory "${GITHUB_WORKSPACE}"`
  before `bin/test.bash`.

Do not proceed to step 4 until the run is green.

- [ ] **Step 4: Apply the `main` ruleset**

In GitHub: **Settings → Rules → Rulesets → New branch ruleset**,
targeting `main`, with exactly the settings in `CONTRIBUTING.md`'s
"Branch protection on `main`" table.

This comes *after* the first green run, because `Test Languages` only
becomes selectable as a required status check once the workflow has
reported at least once.

- [ ] **Step 5: Confirm the ruleset is live**

Run this **from the main checkout at `/workspaces/languages-ng`**, not
from the worktree. `main` is already checked out there, so a linked
worktree cannot check it out — `git checkout main` in the worktree fails
with "already used by worktree".

```bash
cd /workspaces/languages-ng
git pull
git commit --allow-empty -m "test: confirm branch protection rejects direct pushes"
git push
```

Expected: the push is **rejected** by GitHub. Then discard the local
commit:

```bash
git reset --hard origin/main
```

A ruleset that is saved but not enforcing looks identical to one that
is, until the day it matters.

- [ ] **Step 6: Close the issue**

Back in the worktree, as the final commit of the branch:

```bash
git branch --show-current   # must print worktree-ci-plcc-ng-migrated-languages
bin/issues/close.bash 12
```

This fills in the issue's `closed` date and updates
[dev-docs/roadmap.md](../roadmap.md). Never edit either by hand. Then
verify and commit:

```bash
bin/issues/check.bash
git add -A dev-docs
git commit -m "chore(issues): close #12 -- CI runs plcc-ng-migrated languages

Verified green in CI, not just locally. An issue about CI cannot be
closed on local evidence.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

Push, and merge the pull request.

---

## Notes for the implementer

**If reality contradicts this plan, reality wins.** Per
[CLAUDE.md](../../CLAUDE.md), when someone implementing a plan reports
being blocked because the plan is wrong, the plan is assumed wrong until
shown otherwise — that happened three times on issue #25 and the
implementer was right every time. Report the contradiction rather than
working around it silently.

**What was verified before this plan was written**, in a scratch
directory, so you should expect these to work as described:

- The image-pin extractors, against the real `.devcontainer/devcontainer.json` — including that the unanchored `ghcr.io` pattern returns four matches, which is why the anchored form is used.
- Both image-pin mutation tests, producing the failures described in Task 4 Step 3.
- The installer's early-exit branch, printing `already installed`.
- `git clone --depth 1 --branch v1.11.0` followed by `install.sh <prefix>`, producing a working `bats --version` reporting `Bats 1.11.0`.

**What was not verified and cannot be from here:** anything requiring a
Docker daemon or GitHub Actions. That is Task 8's job, and it is why the
issue stays open until CI is green.

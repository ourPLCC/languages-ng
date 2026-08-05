# relocate: stop copying stale build artifacts — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `bin/relocate.bash` copy only the files git reports as
non-ignored, so a by-hand `plcc-rep` run can no longer contaminate the
next test suite run.

**Architecture:** Extract the copy out of `relocate` into a testable
`relocate_copy_tree <from> <to>` helper that drives `tar` from a
`git ls-files --cached --others --exclude-standard` path list. `.gitignore`
becomes the single source of truth for what counts as a build artifact.
Add a bats suite under `bin/tests/` and wire it into `bin/test.bash`.

**Tech Stack:** Bash, bats-core 1.11, git, GNU tar. No new dependencies.

**Spec:** [dev-docs/specs/2026-08-05-relocate-stale-artifacts-design.md](../specs/2026-08-05-relocate-stale-artifacts-design.md)
**Issue:** [#25](../issues/025-relocate-copies-stale-build-artifacts.md)

## Global Constraints

- No new runtime dependencies. `git` and `tar` only — **not** `rsync`,
  which is absent from the CI image (`python:3` + `git`).
- `.gitignore` is the single source of truth for artifact patterns. Do not
  duplicate `plcc-ng/` / `__pycache__/` / `*.class` into `relocate.bash`.
- `.dockerignore` must **not** exclude `.git`. `relocate_copy_tree`
  requires a real checkout, and the container test image relies on it.
- `relocate`'s public contract is unchanged: callers still end up inside
  `<lang_name>/` within `BATS_TEST_TMPDIR`. All 35 existing `.bats` files
  call it and are not modified by this plan.
- Legacy languages (NAME, NEED, OBJ, TYPE0, TYPE1) still need the
  tree-wide copy — they use `plccmk`/`rep`, which build in place. They
  currently fail with `command not found`; that is pre-existing and must
  not change.
- Commit messages follow conventional commits. This work is `test`/`chore`
  scope — **never** `fix` or `feat`, which would bump the release version
  (see `.releaserc.yaml`).
- No `dev-docs/course-material-impact.md` entry: repository tooling only.

---

### Task 1: Baseline, test wiring, and the exclusion fix

**Files:**
- Modify: `bin/relocate.bash` (whole file)
- Modify: `bin/test.bash:4-5`
- Create: `bin/tests/relocate.bats`

**Interfaces:**
- Consumes: nothing.
- Produces: `relocate_copy_tree <from_dir> <to_dir>` — copies every
  non-ignored file under `from_dir` into `to_dir`, preserving relative
  paths. Returns 0 on success. Later tasks extend it.

- [ ] **Step 1: Measure and record the baseline**

Run: `bin/test.bash 2>&1 | tail -5`

Record the three numbers it prints (total tests, passing, failing) in the
task's commit message. Do **not** trust the "84 tests / 78 passing / 6
failing" figure in issue #25 — REF landed since it was written and there
are now 95 `@test`s. Everything below asserts a *delta* against whatever
you measure here.

- [ ] **Step 2: Write the failing test**

Create `bin/tests/relocate.bats`:

```bash
#!/usr/bin/env bats

load '../relocate.bash'

# Builds a throwaway git repo that mimics src/: one language directory
# with a spec, plus the three kinds of build artifact .gitignore names.
# No commit is made -- `git ls-files --cached` reads the index, so
# `git add` is enough and no user.name/user.email config is needed.
setup() {
  FROM="${BATS_TEST_TMPDIR}/from"
  TO="${BATS_TEST_TMPDIR}/to"
  mkdir -p "${FROM}/LANG/java" "${TO}"

  cat > "${FROM}/.gitignore" <<'EOF'
*.class
plcc-ng/
__pycache__/
EOF

  echo 'spec contents' > "${FROM}/LANG/java/spec.plcc"

  mkdir -p "${FROM}/LANG/java/plcc-ng/Java" "${FROM}/LANG/java/__pycache__"
  echo 'stale' > "${FROM}/LANG/java/plcc-ng/spec.json"
  echo 'stale' > "${FROM}/LANG/java/plcc-ng/Java/Val.java"
  echo 'stale' > "${FROM}/LANG/java/__pycache__/mod.pyc"
  echo 'stale' > "${FROM}/LANG/java/Val.class"

  git -C "${FROM}" init --quiet
  git -C "${FROM}" add -A
}

@test "relocate_copy_tree omits gitignored build artifacts" {
  relocate_copy_tree "${FROM}" "${TO}"

  [ ! -e "${TO}/LANG/java/plcc-ng" ]
  [ ! -e "${TO}/LANG/java/__pycache__" ]
  [ ! -e "${TO}/LANG/java/Val.class" ]
}
```

- [ ] **Step 3: Wire `bin/tests/` into the suite**

In `bin/test.bash`, replace the last two lines:

```bash
cd "${PROJECT_ROOT}/src"
bats --recursive .
```

with:

```bash
cd "${PROJECT_ROOT}"
bats --recursive src bin
```

Nothing in the language tests depends on bats' working directory — they
use an absolute `BATS_TEST_DIRNAME` and a `load` relative to the `.bats`
file — so the language suite is unaffected. (`bats` accepting two path
arguments was verified.)

- [ ] **Step 4: Run the test to verify it fails**

Run: `bats bin/tests/relocate.bats`
Expected: FAIL with `relocate_copy_tree: command not found`.

- [ ] **Step 5: Rewrite `bin/relocate.bash`**

Replace the whole file:

```bash
# Copy every non-ignored file under $1 into $2, preserving relative
# paths. Driving the copy from git means .gitignore is the single source
# of truth for what counts as build output -- a plain `cp -R` also sweeps
# up the gitignored plcc-ng/, __pycache__/, and *.class directories a
# by-hand plcc-rep run leaves behind, which silently corrupts the next
# suite run (issue #25).
#
# --others --exclude-standard is what keeps uncommitted work visible:
# git ls-files yields a path list and tar reads those paths from the
# working tree, so uncommitted edits and never-added files are copied,
# while ignored files are not.
function relocate_copy_tree () {
  local from="$1" to="$2"
  (
    cd "${from}" || return 1
    git ls-files -z --cached --others --exclude-standard \
      | tar --null -T - -cf -
  ) | tar -xf - -C "${to}"
}

# BATS_TEST_DIRNAME is .../src/<LANG>/tests/<case>. Copy the whole src/
# tree (not just <LANG>/) for two reasons: migrated specs %include a
# sibling top-level directory -- e.g. V1's spec.plcc reaching into
# ../../Env/envRN/<target>/env.plcc -- and the not-yet-migrated languages
# (NAME, NEED, OBJ, TYPE0, TYPE1) run plccmk, which builds in place and
# has no way to be pointed at a spec elsewhere.
#
# The %include half of that is now avoidable: plcc-rep -s <abs spec path>
# resolves %include from the spec's real location while writing build
# output to the cwd, so migrated tests need no copy at all. See the
# follow-up issue filed alongside issue #25.
#
# Then cd into <LANG>, landing in the same place callers already expect
# (unchanged for languages with no cross-directory %include).
function relocate () {
  local lang_dir
  lang_dir="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  local lang_name
  lang_name="$(basename "${lang_dir}")"
  local src_dir
  src_dir="$(cd "${lang_dir}/.." && pwd)"
  cd "${BATS_TEST_TMPDIR}"
  relocate_copy_tree "${src_dir}" .
  cd "${lang_name}"
}
```

Note this is the *minimal* implementation — the deleted-file filter and
the not-a-checkout guard arrive in Tasks 3 and 4, driven by their own
failing tests.

- [ ] **Step 6: Run the test to verify it passes**

Run: `bats bin/tests/relocate.bats`
Expected: `1 test, 0 failures`.

- [ ] **Step 7: Run the full suite and check the delta**

Run: `bin/test.bash 2>&1 | tail -5`
Expected: exactly **+1 test and +1 passing** versus Step 1. The failure
count must be unchanged — if any language test changed state, stop and
investigate before committing.

- [ ] **Step 8: Commit**

```bash
git add bin/relocate.bash bin/test.bash bin/tests/relocate.bats
git commit -m "test(relocate): copy only non-ignored files into the test tmpdir

Baseline before this change: <N> tests, <P> passing, <F> failing.
After: <N+1> tests, <P+1> passing, <F> failing.

Refs #25"
```

---

### Task 2: Prove uncommitted work is still copied

**Files:**
- Modify: `bin/tests/relocate.bats` (append)

**Interfaces:**
- Consumes: `relocate_copy_tree <from_dir> <to_dir>` from Task 1; the
  `setup()` fixture, which creates `${FROM}/LANG/java/spec.plcc` (tracked,
  content `spec contents`) and `git add`s it without committing.
- Produces: nothing new.

These are characterization tests. They are expected to pass immediately
against Task 1's implementation — their job is to lock in the behavior
that makes this approach safe for day-to-day development, so a future
"optimization" to `--cached` alone cannot silently break it.

- [ ] **Step 1: Append three tests**

```bash
@test "relocate_copy_tree copies tracked source files" {
  relocate_copy_tree "${FROM}" "${TO}"

  [ -f "${TO}/LANG/java/spec.plcc" ]
  [ "$(< "${TO}/LANG/java/spec.plcc")" = 'spec contents' ]
}

@test "relocate_copy_tree copies a new file that was never git added" {
  echo 'brand new' > "${FROM}/LANG/java/newfile.plcc"

  relocate_copy_tree "${FROM}" "${TO}"

  [ "$(< "${TO}/LANG/java/newfile.plcc")" = 'brand new' ]
}

@test "relocate_copy_tree copies uncommitted edits, not indexed content" {
  echo 'edited in the working tree' > "${FROM}/LANG/java/spec.plcc"

  relocate_copy_tree "${FROM}" "${TO}"

  [ "$(< "${TO}/LANG/java/spec.plcc")" = 'edited in the working tree' ]
}
```

- [ ] **Step 2: Run them**

Run: `bats bin/tests/relocate.bats`
Expected: `4 tests, 0 failures`. If the "never git added" test fails, the
implementation is missing `--others --exclude-standard`.

- [ ] **Step 3: Commit**

```bash
git add bin/tests/relocate.bats
git commit -m "test(relocate): lock in that uncommitted work is still copied

Refs #25"
```

---

### Task 3: Survive a tracked file deleted with plain `rm`

**Files:**
- Modify: `bin/tests/relocate.bats` (append)
- Modify: `bin/relocate.bash` (`relocate_copy_tree` body)

**Interfaces:**
- Consumes: `relocate_copy_tree <from_dir> <to_dir>`, `setup()` fixture.
- Produces: `relocate_copy_tree` gains tolerance for index entries with no
  working-tree file. Signature unchanged.

`git ls-files --cached` lists a path that no longer exists on disk when a
tracked file is removed with `rm` rather than `git rm`. `tar` then aborts
with `Cannot stat: No such file or directory`, failing **every** test in
the suite. This was confirmed by experiment during design.

- [ ] **Step 1: Write the failing test**

```bash
@test "relocate_copy_tree tolerates a tracked file deleted with rm" {
  rm "${FROM}/LANG/java/spec.plcc"

  run relocate_copy_tree "${FROM}" "${TO}"

  [ "$status" -eq 0 ]
  [ ! -e "${TO}/LANG/java/spec.plcc" ]
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bats bin/tests/relocate.bats`
Expected: FAIL — tar reports `LANG/java/spec.plcc: Cannot stat: No such
file or directory` and exits non-zero.

- [ ] **Step 3: Filter the path list to entries that exist**

In `relocate_copy_tree`, replace the pipeline body:

```bash
    git ls-files -z --cached --others --exclude-standard \
      | tar --null -T - -cf -
```

with:

```bash
    git ls-files -z --cached --others --exclude-standard \
      | while IFS= read -r -d '' f; do
          [[ -e "${f}" ]] && printf '%s\0' "${f}"
        done \
      | tar --null -T - -cf -
```

Add to the function's comment block:

```bash
# The existence filter handles a tracked file deleted with plain `rm`
# rather than `git rm`: --cached still lists the path, and tar aborts the
# whole copy if it cannot stat it.
```

- [ ] **Step 4: Run to verify it passes**

Run: `bats bin/tests/relocate.bats`
Expected: `5 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/relocate.bash bin/tests/relocate.bats
git commit -m "test(relocate): skip index entries with no working-tree file

Refs #25"
```

---

### Task 4: Report a non-checkout clearly

**Files:**
- Modify: `bin/tests/relocate.bats` (append)
- Modify: `bin/relocate.bash` (`relocate_copy_tree` body)

**Interfaces:**
- Consumes: `relocate_copy_tree <from_dir> <to_dir>`.
- Produces: `relocate_copy_tree` returns 1 and writes a single-line
  diagnostic to stderr when `from_dir` is not inside a git checkout.

Without this, a non-checkout produces a wall of git errors followed by a
confusing empty-archive tar failure.

- [ ] **Step 1: Write the failing test**

```bash
@test "relocate_copy_tree fails clearly when not in a git checkout" {
  local nogit="${BATS_TEST_TMPDIR}/nogit"
  mkdir -p "${nogit}"
  echo 'orphan' > "${nogit}/spec.plcc"

  run relocate_copy_tree "${nogit}" "${TO}"

  [ "$status" -eq 1 ]
  [[ "$output" == *"not in a git checkout"* ]]
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bats bin/tests/relocate.bats`
Expected: FAIL — the status is not 1 and the message is absent.

Note: if `$TMPDIR` happens to sit inside some unrelated git checkout this
test would spuriously pass; `BATS_TEST_TMPDIR` does not, so the test is
sound as written. If it does not fail at this step, stop and check where
`BATS_TEST_TMPDIR` points before proceeding.

- [ ] **Step 3: Add the guard**

As the first line of `relocate_copy_tree`'s body, after the `local`
declaration:

```bash
  git -C "${from}" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "relocate: ${from} is not in a git checkout" >&2; return 1; }
```

- [ ] **Step 4: Run to verify it passes**

Run: `bats bin/tests/relocate.bats`
Expected: `6 tests, 0 failures`.

- [ ] **Step 5: Run the full suite**

Run: `bin/test.bash 2>&1 | tail -5`
Expected: **+6 tests and +6 passing** versus the Task 1 Step 1 baseline
(`relocate.bats` now holds 1 + 3 + 1 + 1 = 6 tests), failure count
unchanged.

- [ ] **Step 6: Commit**

```bash
git add bin/relocate.bash bin/tests/relocate.bats
git commit -m "test(relocate): fail with a clear message outside a checkout

Refs #25"
```

---

### Task 5: `bin/clean.bash`

**Files:**
- Create: `bin/clean.bash`
- Create: `bin/tests/clean.bats`

**Interfaces:**
- Consumes: nothing.
- Produces: `bin/clean.bash`, an executable script taking no arguments
  that removes ignored files under `src/` of the repository containing it.

This replaces the three ad-hoc `find` commands the REF migration ran by
hand. `git clean -X` removes **only** ignored files, so untracked work in
progress is safe.

- [ ] **Step 1: Write the failing test**

Create `bin/tests/clean.bats`:

```bash
#!/usr/bin/env bats

# Exercises bin/clean.bash against a throwaway repo laid out like this
# one, so the real src/ is never touched.
setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/bin" "${REPO}/src/LANG/java"

  cat > "${REPO}/.gitignore" <<'EOF'
*.class
plcc-ng/
__pycache__/
EOF

  echo 'spec contents' > "${REPO}/src/LANG/java/spec.plcc"
  echo 'work in progress' > "${REPO}/src/LANG/java/untracked.plcc"
  mkdir -p "${REPO}/src/LANG/java/plcc-ng" "${REPO}/src/LANG/java/__pycache__"
  echo 'stale' > "${REPO}/src/LANG/java/plcc-ng/spec.json"
  echo 'stale' > "${REPO}/src/LANG/java/__pycache__/mod.pyc"
  echo 'stale' > "${REPO}/src/LANG/java/Val.class"

  git -C "${REPO}" init --quiet
  git -C "${REPO}" add -A

  cp "${BATS_TEST_DIRNAME}/../clean.bash" "${REPO}/bin/clean.bash"
}

@test "clean.bash removes ignored build artifacts under src" {
  "${REPO}/bin/clean.bash"

  [ ! -e "${REPO}/src/LANG/java/plcc-ng" ]
  [ ! -e "${REPO}/src/LANG/java/__pycache__" ]
  [ ! -e "${REPO}/src/LANG/java/Val.class" ]
}

@test "clean.bash preserves tracked and untracked source files" {
  "${REPO}/bin/clean.bash"

  [ -f "${REPO}/src/LANG/java/spec.plcc" ]
  [ "$(< "${REPO}/src/LANG/java/untracked.plcc")" = 'work in progress' ]
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats bin/tests/clean.bats`
Expected: FAIL in `setup` — `cp: cannot stat '.../bin/clean.bash'`.

- [ ] **Step 3: Write `bin/clean.bash`**

```bash
#!/usr/bin/env bash

# Remove the build output plcc-rep and plccmk leave under src/ --
# plcc-ng/, __pycache__/, and *.class. Uses `git clean -X`, which removes
# only *ignored* files, so .gitignore stays the single source of truth and
# untracked work in progress is never touched.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

set -euo pipefail

git clean -X -d -f src
```

Then: `chmod +x bin/clean.bash`

- [ ] **Step 4: Run to verify it passes**

Run: `bats bin/tests/clean.bats`
Expected: `2 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/clean.bash bin/tests/clean.bats
git commit -m "chore: add bin/clean.bash to clear build artifacts under src

Refs #25"
```

---

### Task 6: `.dockerignore`

**Files:**
- Create: `.dockerignore`

**Interfaces:**
- Consumes: nothing. Produces: nothing other tasks depend on.

`.github/workflows/test-langauges.dockerfile` does `COPY . /languages/`
with no `.dockerignore`, so `bin/test-using-pipeline-container.bash` bakes
local stale artifacts into the image — the same root cause through a
different copy.

**Scope honesty:** now that `relocate_copy_tree` is hermetic, this file is
no longer load-bearing for correctness. It is a smaller build context and
defense in depth. **Docker is not available in the devcontainer**, so this
task is verified by inspection; the PR's CI run and any local
`bin/test-using-pipeline-container.bash` exercise it for real.

- [ ] **Step 1: Create `.dockerignore`**

```
# Build output -- see issue #25. Copying these into the image is the same
# defect as copying them into a test tmpdir.
plcc-ng/
__pycache__/
*.class

# Agent worktrees and scratch state; never needed in the test image.
.claude/
```

- [ ] **Step 2: Verify `.git` is NOT excluded**

Run: `grep -c '^\.git$' .dockerignore || true`
Expected: `0`.

This is load-bearing: `relocate_copy_tree` calls `git ls-files`, the image
installs `git`, and the build context supplies `.git`. Excluding it would
fail every test in the container with `not in a git checkout`.

- [ ] **Step 3: Confirm the suite is unaffected**

Run: `bin/test.bash 2>&1 | tail -5`
Expected: identical to the end of Task 5 — **+8 tests and +8 passing**
versus the Task 1 Step 1 baseline (6 in `relocate.bats`, 2 in
`clean.bats`).

- [ ] **Step 4: Commit**

```bash
git add .dockerignore
git commit -m "chore: add .dockerignore so build artifacts stay out of the image

Refs #25"
```

---

### Task 7: File the `plcc-rep -s` follow-up issue

**Files:**
- Create: `dev-docs/issues/0NN-use-spec-flag-instead-of-copying-tree.md` (ID assigned by the script)
- Modify: `dev-docs/issues/.next-id.txt` (by the script)
- Modify: `dev-docs/roadmap.md`

**Interfaces:**
- Consumes: nothing. Produces: nothing other tasks depend on.

- [ ] **Step 1: Create the issue file**

Run: `bin/issues/new.bash use-spec-flag-instead-of-copying-tree test`

Never assign the ID by hand — the script reads and increments
`dev-docs/issues/.next-id.txt`.

- [ ] **Step 2: Fill in the issue body**

Under `## Description`, record the finding and the evidence so it does not
have to be rediscovered:

```markdown
`plcc-rep -s <absolute path to spec>` resolves `%include` relative to the
spec's real location while still writing build output to the **current
directory**. So a test needs no copied tree at all:

    cd "$BATS_TEST_TMPDIR"
    plcc-rep -s "$REPO/src/REF/java/spec.plcc" < input

This gets isolation structurally rather than by filtering a copy: nothing
is copied, so nothing stale can be copied. It supersedes the
`git ls-files`-driven copy added for issue #25 — for migrated languages.

**Verified** during the issue #25 design across all three Env flavors and
all three targets: V1/envRN, V6/envVal, REF/envRef in python, java, and
javascript. 6 of 6 produced their expected output with nothing copied, and
`git status --ignored` confirmed `src/` was left clean afterwards.

## Scope

30 test files / 90 tests use plcc-ng and can convert. Each becomes roughly:

    @test "SET counter (java)" {
      cd "$BATS_TEST_TMPDIR"
      RESULT="$(plcc-rep -s "$BATS_TEST_DIRNAME/../../java/spec.plcc" \
                  < "$BATS_TEST_DIRNAME/SET.input")"
      expected_output=$(< "$BATS_TEST_DIRNAME/SET.expected")
      [[ "$RESULT" == "$expected_output" ]]
    }

5 test files / 5 tests (NAME, NEED, OBJ, TYPE0, TYPE1) **cannot**: they run
`plccmk -c grammar` / `rep -n`, which build in place with no `-s`
equivalent. `relocate` and `relocate_copy_tree` must stay until those five
migrate, at which point both can be deleted outright.

Best sequenced with the remaining migration work, which is actively
editing these same test files.
```

- [ ] **Step 3: Add the roadmap entry**

Add to the `### Test` section of `dev-docs/roadmap.md`, in the same commit
as the issue file. Substitute the ID the script assigned:

```markdown
- **[#NN](issues/0NN-use-spec-flag-instead-of-copying-tree.md) — use `plcc-rep -s` instead of copying `src/` into each test tmpdir**
  `plcc-rep -s <abs spec path>` resolves `%include` from the spec's real location while writing build output to the current directory, so the 30 migrated test files need no copied tree at all — isolation becomes structural rather than a filtered copy. The 5 legacy `plccmk` languages still need `relocate`, so both mechanisms coexist until they migrate.
```

- [ ] **Step 4: Verify consistency**

Run: `bin/issues/check.bash`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): file follow-up - use plcc-rep -s instead of copying src"
```

---

### Task 8: Close issue 25

**Files:**
- Modify: `dev-docs/issues/025-relocate-copies-stale-build-artifacts.md` (by the script)
- Modify: `dev-docs/roadmap.md` (by the script)

**Interfaces:**
- Consumes: nothing. Produces: nothing.

- [ ] **Step 1: Final full-suite run**

Run: `bin/test.bash 2>&1 | tail -5`
Expected: +8 tests and +8 passing versus the Task 1 Step 1 baseline,
failure count unchanged.

- [ ] **Step 2: Attempt the end-to-end reproduction (bonus check)**

```bash
mkdir -p src/SET/java/plcc-ng && echo stale > src/SET/java/plcc-ng/spec.json
bin/test.bash 2>&1 | tail -5
bin/clean.bash
```

Expected: results identical to Step 1 — the planted artifact has no effect.

**This is a bonus check, not a gate.** The mechanism by which stale
artifacts change a test's *result* was never reproduced during design (see
the spec's Testing section: `plcc-rep` keeps a `plcc-ng/.spec-hash` cache,
but a whitespace edit to `spec.plcc` left the hash unchanged, so its rules
are not understood). If planting an artifact does not perturb the suite
even before the fix, record that in the issue as new information — do not
treat it as a reason to doubt the fix, which removes the copying that
feeds the reported corruption regardless of the cache's exact semantics.

- [ ] **Step 3: Close the issue**

Run: `bin/issues/close.bash 025`

This fills in the `closed` date and updates the roadmap. Issue files never
move, so links to them keep working.

- [ ] **Step 4: Verify and commit**

```bash
bin/issues/check.bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): close issue 25 (relocate copies stale artifacts)"
```

---

## Verification Summary

| | Before | After |
| --- | --- | --- |
| Tests | baseline `N` | `N + 8` |
| Passing | baseline `P` | `P + 8` |
| Failing | baseline `F` | `F` (unchanged) |

The 8 new tests are 6 in `bin/tests/relocate.bats` (Tasks 1–4) and 2 in
`bin/tests/clean.bats` (Task 5).

The five legacy `plccmk` tests stay failing throughout — `plccmk`/`rep`
are not installed in the devcontainer. That gap is pre-existing and out of
scope.

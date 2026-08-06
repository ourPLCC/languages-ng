# Suite disk bound + run-completeness check — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound the bats suite's peak disk use at the cost of one test, and make `bin/test.bash` fail loudly when a run dies instead of blaming whichever test was running.

**Architecture:** Two independent, small bash libraries under `bin/`. `bats-tmpdir.bash` defines a `teardown()` that every `.bats` file loads, emptying each passing test's `BATS_TEST_TMPDIR`. `check-run-complete.bash` reads the TAP report bats writes via `--report-formatter` and proves the run reached the test count in its own `1..N` plan line; `bin/test.bash` calls it and exits 2 if not.

**Tech Stack:** bash, bats-core 1.11, awk, sed. No new dependencies.

Design spec: [2026-08-06-suite-disk-and-run-completeness-design.md](../specs/2026-08-06-suite-disk-and-run-completeness-design.md).
Issue: [#31](../issues/031-suite-exhausts-disk-and-reports-spurious-failure.md).

## Global Constraints

- **Commit types are `test`, `chore`, or `docs` only.** Nothing in `src/` changes, so the release version must not spin (`.releaserc.yaml` bumps on `fix`/`feat`). Issue #31 is itself `type: test`.
- **Every commit message ends with** `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- **`set -euo pipefail` goes before any `cd`,** never after — the issue #25 defect.
- **Do not run the full suite before Task 2 is complete.** This machine has ~220 MB free and today's suite needs ~312 MB; it will die partway. Run individual test files with `bats <file>` until then.
- **Every `.bats` file loads `bin/bats-tmpdir.bash`** except `bin/tests/bats-tmpdir.bats`, which cannot — the teardown would delete the fixtures it generates.
- **The issue is closed with `bin/issues/close.bash`** as the final commit of the branch, per [CLAUDE.md](../../CLAUDE.md). Never edit the `closed:` field or `roadmap.md` by hand.

## File Structure

| File | Responsibility |
|---|---|
| `bin/bats-tmpdir.bash` *(new)* | One `teardown()`. Empties a passing test's tmpdir. Nothing else. |
| `bin/tests/bats-tmpdir.bats` *(new)* | Tests that teardown by running a child `bats` on generated fixtures. |
| `bin/check-run-complete.bash` *(new)* | Pure functions over a TAP report path: plan count, last test reached, the verdict, the banner. No I/O beyond reading the report and writing stderr. |
| `bin/tests/check-run-complete.bats` *(new)* | Tests those functions against handwritten TAP files. |
| `bin/test.bash` *(modify)* | Glue: run bats with a TAP report, call the check, choose the exit code. |
| `bin/test-using-pipeline-container.bash` *(modify)* | Drive-by: `set` before `cd`. |
| 42 `src/**/*.bats` + 2 `bin/tests/*.bats` *(modify)* | One `load` line each. |
| `dev-docs/issues/027-*.md` *(modify)* | Correct stale scope numbers. |

**Everything below has been executed and verified** in a scratch directory before being written here — including the mutation tests proving the assertions have teeth. Code blocks are transcription-ready.

---

### Task 1: The teardown library and its tests

**Files:**
- Create: `bin/bats-tmpdir.bash`
- Test: `bin/tests/bats-tmpdir.bats`

**Interfaces:**
- Consumes: nothing.
- Produces: a `teardown()` function, sourced by `load`. No other file calls it directly; bats invokes it after each test.

**Background the implementer needs.** bats 1.11 creates `$BATS_RUN_TMPDIR/test/<n>` per test (`bats-exec-test:69`) and deletes none of them during the run — the only in-run `rm` is the retry path (`bats-exec-test:162`), and `BATS_RUN_TMPDIR` goes in the EXIT trap (`bats:340`). Peak disk is the sum of all tests. Two environment variables make the fix possible, both verified: `BATS_TEST_COMPLETED` is `1` after a passing test body and unset after a failing one; `BATS_TEMPDIR_CLEANUP` is exported as `1` normally and `''` under `--no-tempdir-cleanup`.

- [ ] **Step 1: Write the failing test**

Create `bin/tests/bats-tmpdir.bats`. Read the header comment carefully — the indirection is deliberate and non-obvious.

```bash
#!/usr/bin/env bats

# Exercises bin/bats-tmpdir.bash by running a *child* bats on a fixture this
# file generates at runtime.
#
# Why a child, and why the assertions live inside it: observing a child's
# tmpdirs from out here would need --no-tempdir-cleanup, which disables the
# very teardown under test. bats numbers tmpdirs $BATS_RUN_TMPDIR/test/<n>,
# so instead the child's second test inspects what its first test left behind.
#
# Why fixtures are generated rather than committed: a committed fixture named
# *.bats anywhere under bin/ would be collected as a real test by
# `bats --recursive bin`.
#
# Why this file must NOT load bin/bats-tmpdir.bash: the teardown would empty
# BATS_TEST_TMPDIR between tests and delete the fixtures written there.
#
# Why TMPDIR is exported for the child: it puts the child's whole bats-run-*
# tree inside this test's tmpdir, so it goes away with it. Without this,
# --no-tempdir-cleanup leaks a directory into /tmp on every run.

LIB="${BATS_TEST_DIRNAME}/../bats-tmpdir.bash"

@test "a passing test's tmpdir is emptied" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
source '${LIB}'
@test "fills its tmpdir" {
  cd "\$BATS_TEST_TMPDIR"
  mkdir -p a/b
  echo x > a/b/f
}
@test "sees test 1 emptied" {
  prev="\$BATS_RUN_TMPDIR/test/1"
  [ -d "\$prev" ]
  [ -z "\$(ls -A "\$prev")" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats "${BATS_TEST_TMPDIR}/child.bats"
  [ "$status" -eq 0 ]
}

# Control. Without the teardown the identical fixture must FAIL, which is what
# proves the test above is not passing vacuously.
@test "without the teardown, the same fixture fails" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
@test "fills its tmpdir" {
  cd "\$BATS_TEST_TMPDIR"
  mkdir -p a/b
  echo x > a/b/f
}
@test "sees test 1 emptied" {
  prev="\$BATS_RUN_TMPDIR/test/1"
  [ -d "\$prev" ]
  [ -z "\$(ls -A "\$prev")" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats "${BATS_TEST_TMPDIR}/child.bats"
  [ "$status" -eq 1 ]
}

@test "a failing test's tmpdir is preserved as evidence" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
source '${LIB}'
@test "fails leaving evidence" {
  cd "\$BATS_TEST_TMPDIR"
  touch evidence
  false
}
@test "sees evidence survived" {
  [ -e "\$BATS_RUN_TMPDIR/test/1/evidence" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats "${BATS_TEST_TMPDIR}/child.bats"
  # The child exits 1 because its first test fails by design. What matters is
  # that its second test passed.
  [ "$status" -eq 1 ]
  [[ "$output" == *'ok 2 sees evidence survived'* ]]
}

@test "--no-tempdir-cleanup preserves the tree" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
source '${LIB}'
@test "fills its tmpdir" {
  cd "\$BATS_TEST_TMPDIR"
  mkdir -p a/b
  echo x > a/b/f
}
@test "sees test 1 was left alone" {
  prev="\$BATS_RUN_TMPDIR/test/1"
  [ -n "\$(ls -A "\$prev")" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats --no-tempdir-cleanup "${BATS_TEST_TMPDIR}/child.bats"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the tests and confirm they fail for the right reason**

```bash
bats bin/tests/bats-tmpdir.bats
```

Expected: tests 1, 3, and 4 FAIL (the child cannot `source` a file that does not exist yet); test 2, the control, PASSES already because it sources nothing. If test 2 fails at this point, stop — the fixture itself is wrong, not the missing library.

- [ ] **Step 3: Write the implementation**

Create `bin/bats-tmpdir.bash`:

```bash
# Empty a passing test's BATS_TEST_TMPDIR as soon as that test ends.
#
# bats creates $BATS_RUN_TMPDIR/test/<n> per test and deletes none of them
# during the run: the only in-run rm is the retry path (bats-exec-test:162),
# and BATS_RUN_TMPDIR itself goes in the EXIT trap (bats:340). Peak disk is
# therefore the *sum* of every test's footprint -- ~2.4 MB x 130 = ~312 MB --
# which is what exhausts a constrained filesystem (issue #31). Emptying per
# test makes the peak the cost of one test, and keeps it there as the suite
# grows.
#
# Empty the directory rather than remove it: that same retry path runs an
# unguarded `rm -r "$BATS_TEST_TMPDIR"`, which fails if it is already gone.
teardown () {
  # --no-tempdir-cleanup means "I want to inspect the trees". Honor it.
  [[ -n "${BATS_TEMPDIR_CLEANUP:-}" ]] || return 0

  # Unset unless the test body ran to completion. A failing test's tree is
  # evidence; keep it. This is why a run with failures can still accumulate.
  [[ -n "${BATS_TEST_COMPLETED:-}" ]] || return 0

  [[ -n "${BATS_TEST_TMPDIR:-}" && -d "${BATS_TEST_TMPDIR}" ]] || return 0

  # Tests cd into subdirectories that are about to vanish. Step up to the
  # tmpdir itself, which survives because of -mindepth 1.
  cd "${BATS_TEST_TMPDIR}" || return 0

  # Loud on failure, per issue #28: a cleanup that silently no-ops just
  # restores the accumulation this file exists to prevent.
  if ! find "${BATS_TEST_TMPDIR}" -mindepth 1 -delete; then
    printf 'bats-tmpdir: could not empty %s\n' "${BATS_TEST_TMPDIR}" >&2
    printf 'bats-tmpdir: disk will accumulate from here on.\n' >&2
    return 1
  fi
}
```

Note the exit status: the trailing `if !` is the last statement, so a successful `find` leaves the function at 0. Do not "simplify" it to `[[ ... ]] && printf` — that is the issue #25 defect, and it would fail every test.

- [ ] **Step 4: Run the tests and verify all four pass**

```bash
bats bin/tests/bats-tmpdir.bats
```

Expected: `4 tests, 0 failures`.

- [ ] **Step 5: Confirm no run tree leaked**

```bash
ls -d /tmp/bats-run-* 2>/dev/null || echo "clean"
```

Expected: `clean`. If a directory appears, the `export TMPDIR` line is missing from one of the four tests.

- [ ] **Step 6: Commit**

```bash
git add bin/bats-tmpdir.bash bin/tests/bats-tmpdir.bats
git commit -F - <<'EOF'
test(harness): empty each passing test's BATS_TEST_TMPDIR

bats holds every per-test tmpdir until the whole run exits, so the
suite's peak disk is the sum of all 130 tests (~312 MB) rather than
the cost of one. That is what exhausts a constrained filesystem and
produces issue #31's spurious failure.

A teardown in a loadable library empties each tmpdir as soon as its
test passes, making peak disk the cost of the largest single test and
keeping it there as the suite grows. Failing tests keep their trees as
evidence, and --no-tempdir-cleanup is honored.

Not yet wired into any test file; that is the next commit.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 2: Wire the teardown into all 44 test files

**Files:**
- Modify: 42 files matching `src/**/*.bats`
- Modify: `bin/tests/relocate.bats`, `bin/tests/clean.bats`

**Interfaces:**
- Consumes: `bin/bats-tmpdir.bash` from Task 1.
- Produces: a suite that runs to completion on a constrained filesystem. Later tasks assume the full suite can be run.

This is the task that actually delivers the fix. Its verification is the real acceptance test from the spec.

- [ ] **Step 1: Record the baseline, so the improvement is measured rather than asserted**

```bash
df -h /tmp | tail -1
```

Write the "Avail" figure down. On the machine this plan was written for it was ~220 MB, against a suite needing ~312 MB.

- [ ] **Step 2: Apply the edit to the 42 `src` files**

All 42 share a byte-identical load line, verified. This inserts the new line directly after it:

```bash
mapfile -t files < <(grep -rl "^load '\.\./\.\./\.\./\.\./bin/relocate\.bash'$" --include='*.bats' src)
echo "matched ${#files[@]} files"
sed -i "/^load '\.\.\/\.\.\/\.\.\/\.\.\/bin\/relocate\.bash'\$/a load '..\/..\/..\/..\/bin\/bats-tmpdir.bash'" "${files[@]}"
```

Expected: `matched 42 files`. If it prints anything else, stop and investigate rather than proceeding.

- [ ] **Step 3: Apply the edit to the two `bin/tests` files**

`relocate.bats` has its own load line; `clean.bats` has none, so its line goes after the shebang:

```bash
sed -i "/^load '\.\.\/relocate\.bash'\$/a load '..\/bats-tmpdir.bash'" bin/tests/relocate.bats
sed -i "1a\\
\\
load '../bats-tmpdir.bash'" bin/tests/clean.bats
```

- [ ] **Step 4: Verify the edit landed exactly once everywhere**

These match on the **`load` line specifically**, not on the string anywhere in
the file. A looser `grep -rc 'bats-tmpdir.bash'` gives a false positive:
`bin/tests/bats-tmpdir.bats` mentions the name twice in its comments and would
be reported as a duplicate insertion.

```bash
echo "src: $(grep -rl "^load '.*bats-tmpdir\.bash'$" --include='*.bats' src | wc -l)"
echo "bin: $(grep -rl "^load '.*bats-tmpdir\.bash'$" --include='*.bats' bin | wc -l)"
grep -rc "^load '.*bats-tmpdir\.bash'$" --include='*.bats' src bin \
  | grep -v ':[01]$' || echo "no duplicate load lines"
head -5 src/V4/tests/seq/V4test.bats
head -6 bin/tests/clean.bats
```

Expected: `src: 42`, `bin: 2`, `no duplicate load lines`, and both `head`
outputs showing the new line in a sensible place.

- [ ] **Step 5: Confirm `bats-tmpdir.bats` was not accidentally wired**

```bash
grep -n "^load" bin/tests/bats-tmpdir.bats || echo "correctly has no load line"
```

Expected: `correctly has no load line`. If a load line is there, remove it — the teardown would delete that file's own fixtures.

- [ ] **Step 6: Run the full suite — the acceptance test**

This is the first time the whole suite is run in this branch. It is expected to complete now, on the same machine where it previously died.

```bash
bin/test.bash
echo "exit=$?"
```

Expected: the run reaches its final test and reports `0 failures`. The planned count is **not** 130 — Task 1 added `bin/tests/bats-tmpdir.bats`, so it is higher. Do not assert a specific number; assert that the run finished and nothing failed.

If it still dies partway, do not proceed. Free disk space or investigate; the rest of the plan assumes a completable suite.

- [ ] **Step 7: Measure the improvement**

```bash
df -h /tmp | tail -1
```

Compare against Step 1. Free space should be essentially unchanged after a full run, where before it would have been consumed.

- [ ] **Step 8: Commit**

```bash
git add src bin/tests/relocate.bats bin/tests/clean.bats
git commit -F - <<'EOF'
test(harness): load the tmpdir teardown in every test file

Wires bin/bats-tmpdir.bash into all 42 src test files and the two
bin/tests files. With this the suite's peak disk is the cost of one
test rather than the sum of all of them, and it runs to completion on
a filesystem that could not previously finish it.

bin/tests/bats-tmpdir.bats is deliberately excluded: the teardown
would delete the fixtures it generates.

Closes the footprint half of issue #31.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 3: The run-completeness library and its tests

**Files:**
- Create: `bin/check-run-complete.bash`
- Test: `bin/tests/check-run-complete.bats`

**Interfaces:**
- Consumes: `bin/bats-tmpdir.bash` (the test file loads it, per the global constraint).
- Produces, for Task 4:
  - `run_plan_count <report_path>` → prints N from `1..N`, or nothing.
  - `run_last_test_number <report_path>` → prints the highest test number reached, or `0`.
  - `run_incomplete_banner <report> <reason> <planned> <reached>` → prints the banner to **stderr**.
  - `check_run_complete <report_path>` → **0** if the run reached its last test; otherwise prints the banner and returns **1**.

- [ ] **Step 1: Write the failing test**

Create `bin/tests/check-run-complete.bats`:

```bash
#!/usr/bin/env bats

load '../bats-tmpdir.bash'
load '../check-run-complete.bash'

write_report () { printf '%s\n' "$@" > "${BATS_TEST_TMPDIR}/report.tap"; }

# A report for a run that planned $1 tests but stopped at $2, whose last line
# is "$3 $2 ..." -- pass 'ok' or 'not ok' as $3.
write_truncated_report () {
  local planned="$1" reached="$2" last_status="$3" i
  {
    printf '1..%s\n' "${planned}"
    for (( i = 1; i < reached; i++ )); do printf 'ok %d test %d\n' "$i" "$i"; done
    printf '%s %d test %d\n' "${last_status}" "${reached}" "${reached}"
  } > "${BATS_TEST_TMPDIR}/report.tap"
}

@test "a complete run passes" {
  write_report '1..3' 'ok 1 a' 'ok 2 b' 'ok 3 c'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 0 ]
}

# The check must never turn ordinary test failures into harness failures.
@test "a complete run with real test failures still passes" {
  write_report '1..3' 'ok 1 a' 'not ok 2 b' 'ok 3 c'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a run truncated after 'ok 96' is a harness failure" {
  write_truncated_report 130 96 'ok'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'HARNESS FAILURE'* ]]
  [[ "$output" == *'planned : 130 tests'* ]]
  [[ "$output" == *'reached : 96'* ]]
}

# The exact case observed in issue #31.
@test "a run truncated after 'not ok 96' is a harness failure, not a test failure" {
  write_truncated_report 130 96 'not ok'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'reached : 96'* ]]
}

@test "a missing report is a harness failure" {
  run check_run_complete "${BATS_TEST_TMPDIR}/absent.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'no report was written'* ]]
}

@test "a report with no plan line is a harness failure" {
  write_report 'ok 1 a'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'no TAP plan line'* ]]
}

@test "an empty suite is complete" {
  write_report '1..0'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 0 ]
}
```

bats's `run` merges stderr into `$output`, which is why the banner assertions work. This was verified, not assumed.

- [ ] **Step 2: Run the tests and verify they fail**

```bash
bats bin/tests/check-run-complete.bats
```

Expected: all 7 fail — `load` cannot find `../check-run-complete.bash`.

- [ ] **Step 3: Write the implementation**

Create `bin/check-run-complete.bash`:

```bash
# Decide whether a bats run actually finished, from the TAP report written by
# `bats --report-formatter tap --output <dir>`.
#
# A run that dies partway -- disk exhaustion, OOM, SIGKILL -- leaves output
# that reads like an ordinary result: the last line is often a `not ok` naming
# whatever test was running, and `grep -c '^ok '` returns a plausible number.
# Issue #31 records a run that died at test 96 having written
# `not ok 96 V4 seq (javascript)`, a test that passes whenever the run
# completes.
#
# The witness is the TAP plan. bats writes `1..N` before test 1 runs, so a
# complete run always has a line for test N. Its absence means the harness
# stopped, not that a test failed.
#
# awk throughout rather than grep/tail pipelines, deliberately: no
# "grep found nothing" exit status can leak into the result.

# Print the planned test count from a TAP report; print nothing if absent.
function run_plan_count () {
  awk '/^1\.\.[0-9]+$/ { print substr($0, 4); exit }' "$1"
}

# Print the number of the highest test the run reached; 0 if none.
# Note the field difference: "ok 12 name" vs "not ok 12 name".
function run_last_test_number () {
  awk '/^ok [0-9]+/     { n = $2 }
       /^not ok [0-9]+/ { n = $3 }
       END              { print n + 0 }' "$1"
}

# Quoted heredoc for the prose, printf for the values: nothing in the advice
# text can expand by accident.
function run_incomplete_banner () {
  local report="$1" reason="$2" planned="$3" reached="$4"
  {
    printf '\n%s\n' '================================================================'
    printf 'HARNESS FAILURE: the test run did not finish.\n\n'
    printf '  reason  : %s\n' "${reason}"
    printf '  planned : %s tests\n' "${planned}"
    printf '  reached : %s\n' "${reached}"
    printf '  report  : %s\n\n' "${report}"
    cat <<'ADVICE'
Nothing above is a trustworthy test result. A trailing 'not ok'
names the test that was running when the harness stopped, not a
test that is broken, and the pass count counts a truncated file.

The usual cause is the filesystem holding TMPDIR filling up:
  df -h "${TMPDIR:-/tmp}"

A run killed this way also leaks its whole scratch tree, since
bats only removes it in an EXIT trap. Check for stale
/tmp/bats-run-* directories and remove them.

See dev-docs/issues/031-suite-exhausts-disk-and-reports-spurious-failure.md
ADVICE
    printf '%s\n' '================================================================'
  } >&2
}

# 0 if the report shows a run that reached its last test. Otherwise print the
# banner and return 1.
function check_run_complete () {
  local report="$1" planned reached

  [[ -f "${report}" ]] \
    || { run_incomplete_banner "${report}" 'no report was written' '?' '?'; return 1; }

  planned="$(run_plan_count "${report}")"
  [[ -n "${planned}" ]] \
    || { run_incomplete_banner "${report}" 'the report has no TAP plan line' '?' '?'; return 1; }

  reached="$(run_last_test_number "${report}")"
  if (( reached < planned )); then
    run_incomplete_banner "${report}" 'the run stopped before its last test' \
      "${planned}" "${reached}"
    return 1
  fi
}
```

The final `if` has no `else`, so a complete run leaves the function at 0. `1..0` reads as complete, correctly.

- [ ] **Step 4: Run the tests and verify all seven pass**

```bash
bats bin/tests/check-run-complete.bats
```

Expected: `7 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add bin/check-run-complete.bash bin/tests/check-run-complete.bats
git commit -F - <<'EOF'
test(harness): add a check that a bats run reached its last test

A run that dies partway leaves output that reads like an ordinary
result: a trailing `not ok` naming whichever test was running, and a
pass count that counts a truncated file. Issue #31 records a run that
died at test 96 having accused `V4 seq (javascript)`, which passes
whenever the run completes.

The witness is the TAP plan line, which bats writes before test 1
runs. check_run_complete proves the report reached the test number the
run planned, and prints a harness-failure banner naming the last test
reached when it did not.

Library only; bin/test.bash calls it in the next commit.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 4: Make `bin/test.bash` use the check

**Files:**
- Modify: `bin/test.bash` (whole file, currently 6 lines)

**Interfaces:**
- Consumes: `check_run_complete` from Task 3.
- Produces: exit `0` all passed, `1` real test failures, `2` the harness did not finish.

There is no new test file here. The logic worth testing lives in Task 3's library; what remains is glue, and its verification is running it.

- [ ] **Step 1: Rewrite `bin/test.bash`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
source "${SCRIPT_DIR}/check-run-complete.bash"
cd "${PROJECT_ROOT}"

# --report-formatter writes a machine-readable TAP copy *alongside* whatever
# formatter stdout is using, so an interactive run keeps its pretty output.
# bats writes it incrementally, which is what makes it a usable witness even
# when the run dies partway.
report_dir="$(mktemp -d)" || {
  printf 'test.bash: could not create a report directory (disk full?)\n' >&2
  exit 2
}

bats_status=0
bats --recursive --report-formatter tap --output "${report_dir}" src bin \
  || bats_status=$?

# Exit 2, distinct from bats's 1, so a dead harness is never read as a test
# failure by a caller, a CI step, or a person.
check_run_complete "${report_dir}/report.tap" || exit 2

rm -rf "${report_dir}"     # kept on the failure path; the banner names it
exit "${bats_status}"
```

`set -euo pipefail` is on line 2, **before** the `cd`. Every command that can legitimately return non-zero is guarded by `||`.

- [ ] **Step 2: Run the full suite and confirm a clean pass**

```bash
bin/test.bash
echo "exit=$?"
```

> **Amended 2026-08-06, mid-execution.** This step originally expected
> `0 failures` and `exit=0`. That is unreachable on this machine, and the
> original text was written without ever having seen a completed run — the
> suite could not finish before Task 2 landed, so the "clean baseline" was an
> assumption, not an observation.
>
> Three tests fail here and always have: `OBJ class`, `TYPE0 boolean`, and
> `TYPE1 proc-types` invoke old-PLCC's `plccmk` and `rep`, which this
> devcontainer does not install (`command -v plccmk` → not found). Verified by
> running `OBJ` at the pre-wiring commit and after: identical
> `plccmk: command not found`, status 127, with only the line number shifted
> by the added `load` line. Open issue
> [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) documents
> this as the local mirror of its CI complaint.

Expected: the run reaches its final test and prints a failure count; `exit=1`;
and **exactly three** failures, all `plccmk: command not found`:

```
not ok  OBJ class
not ok  TYPE0 boolean
not ok  TYPE1 proc-types
```

A fourth failure, or any different one, is a regression — **stop and
investigate**. This is a stricter gate than `exit=0` would have been, because
it names the tests rather than trusting a count.

No banner should appear: the run completed, so `check_run_complete` stays
silent. The pretty progress output is unchanged from before — that is the
point of using `--report-formatter` rather than piping stdout.

- [ ] **Step 3: Prove the failure path fires, using a deliberately truncated report**

The full suite now completes, so exhaustion cannot be triggered on demand. Exercise the path directly instead:

```bash
tmp="$(mktemp -d)"
{ echo '1..130'; for i in $(seq 1 95); do echo "ok $i test $i"; done; \
  echo 'not ok 96 V4 seq (javascript)'; } > "$tmp/report.tap"
( source bin/check-run-complete.bash; check_run_complete "$tmp/report.tap" ); echo "exit=$?"
rm -rf "$tmp"
```

Expected: the full banner, naming `planned : 130 tests` and `reached : 96`, and `exit=1`. Read the banner text and confirm it would actually stop someone from blaming `V4 seq (javascript)`.

- [ ] **Step 4: Confirm no report directory leaked from the passing run**

A successful run removes its report directory. Look for the report file
itself rather than for `/tmp/tmp.*`, which other programs also create:

```bash
find /tmp -maxdepth 2 -name report.tap 2>/dev/null; echo "--- end ---"
```

Expected: no paths listed before `--- end ---`.

- [ ] **Step 5: Commit**

```bash
git add bin/test.bash
git commit -F - <<'EOF'
test(harness): fail loudly when a bats run does not reach its last test

bin/test.bash now writes a TAP report alongside its normal output and
checks that the run reached the test count in its own plan line. A
truncated run prints a harness-failure banner and exits 2, distinct
from bats's 1, so a dead harness is never read as a test failure.

The report formatter leaves stdout's formatter alone, so interactive
runs keep their pretty output.

Closes the silence half of issue #31.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 5: Drive-by — `set` before `cd` in the container script

**Files:**
- Modify: `bin/test-using-pipeline-container.bash:5-7`

Harmless where it stands, but it is exactly the ordering CLAUDE.md flags from issue #25, and it is two lines from work already being done.

- [ ] **Step 1: Move the `set` line above the `cd`**

The file currently reads:

```bash
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

set -euo pipefail
```

Change it to:

```bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"
```

- [ ] **Step 2: Confirm the script still parses**

```bash
bash -n bin/test-using-pipeline-container.bash && echo "syntax ok"
```

Expected: `syntax ok`. Do not run the script itself — it builds a Docker image, which is slow and needs disk this machine does not have.

- [ ] **Step 3: Commit**

```bash
git add bin/test-using-pipeline-container.bash
git commit -F - <<'EOF'
chore(bin): set -euo pipefail before cd, not after

A cd that fails before `set -e` is active leaves the script running in
the wrong directory. This is the ordering CLAUDE.md flags from issue
#25; nothing destructive follows it here, but the pattern should not
be left in place to be copied.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 6: Correct issue #27's stale scope

**Files:**
- Modify: `dev-docs/issues/027-use-spec-flag-instead-of-copying-tree.md`

Two things in #27 are now wrong, both verified against the current tree. NAME and NEED have migrated since it was written, so only OBJ, TYPE0 and TYPE1 still run `plccmk`. And `-s` removes the copied tree but not the build output, so it shrinks the footprint rather than bounding it.

- [ ] **Step 1: Re-verify the numbers before writing them down**

Do not copy these from the plan; confirm them, since more languages may have migrated:

```bash
echo "still on plccmk: $(grep -rl 'plccmk\|rep -n' --include='*.bats' src | wc -l)"
grep -rl 'plccmk\|rep -n' --include='*.bats' src
echo "convertible files: $(grep -rl 'plcc-rep' --include='*.bats' src | wc -l)"
echo "total src tests: $(bats --count --recursive src)"
```

At the time of writing: 3 non-convertible files (OBJ, TYPE0, TYPE1), 39 convertible files, 120 src tests — so 117 convertible tests.

- [ ] **Step 2: Rewrite the `## Scope` section**

Keep the existing `@test "SET counter (java)"` example code block exactly as it
is. Replace the prose around it so the section reads (adjust the figures if
Step 1 differed):

```markdown
## Scope

39 test files / 117 tests use plcc-ng and can convert. Each becomes roughly:

    @test "SET counter (java)" {
      cd "$BATS_TEST_TMPDIR"
      RESULT="$(plcc-rep -s "$BATS_TEST_DIRNAME/../../java/spec.plcc" \
                  < "$BATS_TEST_DIRNAME/SET.input")"
      expected_output=$(< "$BATS_TEST_DIRNAME/SET.expected")
      [[ "$RESULT" == "$expected_output" ]]
    }

3 test files / 3 tests (OBJ, TYPE0, TYPE1) **cannot**: they run
`plccmk -c grammar` / `rep -n`, which build in place with no `-s`
equivalent. `relocate` and `relocate_copy_tree` must stay until those three
migrate, at which point both can be deleted outright.

NAME and NEED were in that cannot-convert list when this issue was filed.
Both have since migrated to plcc-ng and are now convertible; the counts
above reflect that.

Best sequenced with the remaining migration work, which is actively
editing these same test files.
```

- [ ] **Step 3: Add the shrink-versus-bound note to `## Notes`**

Append, adjusting figures if Step 1 differed:

```markdown
**`-s` shrinks the footprint; it does not bound it.** Measured while
designing issue [#31](031-suite-exhausts-disk-and-reports-spurious-failure.md):
`-s` removes the 1.5 MB tree copy, but each test's build output still lands
in `BATS_TEST_TMPDIR` and still accumulates across the run (V4 seq: python
488K, java 588K, javascript 372K). For the suite as it stands that is a drop
from roughly 312 MB peak to roughly 65 MB — about 5x, and still growing with
every language added.

The bound comes from `bin/bats-tmpdir.bash` (issue #31), which empties each
passing test's tmpdir and holds peak at the cost of a single test regardless
of suite size. That also covers OBJ, TYPE0 and TYPE1, which can never
convert. So this issue is a speed and cleanliness win, not the disk fix it
was once thought to be.
```

- [ ] **Step 4: Verify issue consistency**

```bash
bin/issues/check.bash
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add dev-docs/issues/027-use-spec-flag-instead-of-copying-tree.md
git commit -F - <<'EOF'
docs(issues): correct issue 27 scope and clarify -s shrinks rather than bounds

NAME and NEED have migrated since #27 was written, so the
non-convertible set is 3 files (OBJ, TYPE0, TYPE1), not 5, and the
convertible set is 39 files / 117 tests, not 30 / 90.

Also records what measuring for issue #31 showed: -s removes the tree
copy but not the build output, so it shrinks peak disk roughly 5x
rather than bounding it. The bound comes from the per-test tmpdir
cleanup instead.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 7: Close issue #31

**Files:**
- Modify (via script only): `dev-docs/issues/031-*.md`, `dev-docs/roadmap.md`

- [ ] **Step 1: Final full-suite run**

```bash
bin/test.bash
echo "exit=$?"
```

> **Amended 2026-08-06, mid-execution** — same correction as Task 4, Step 2.
> `0 failures` / `exit=0` is unreachable here.

Expected: the run reaches its final test; `exit=1`; **exactly three** failures,
and they are precisely `OBJ class`, `TYPE0 boolean`, and `TYPE1 proc-types`,
all `plccmk: command not found` (issue #12). Anything else is a regression —
do not close the issue.

Do not close on a run you did not watch finish. Issue #31 is about a harness
that lies when it dies; closing it on an unwitnessed run would be its own
small version of the same mistake.

- [ ] **Step 2: Close the issue with the script**

Never edit the `closed:` field or `roadmap.md` by hand.

```bash
bin/issues/close.bash 031
bin/issues/check.bash
```

- [ ] **Step 3: Review what the script changed**

```bash
git diff
```

Expected: a `closed:` date in the issue's frontmatter and a roadmap entry moved. Nothing else.

- [ ] **Step 4: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -F - <<'EOF'
docs(issues): close issue 31

Peak suite disk is now the cost of one test rather than the sum of
all of them, and a run that dies reports a harness failure with a
distinct exit code instead of accusing whichever test was running.

Issue #27 remains open as a speed and cleanliness improvement, with
its scope numbers corrected.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

## Verification Checklist

Before calling the branch done, every one of these must have been run and its output seen — not inferred:

- [ ] `bin/test.bash` reaches its final test; `exit=1`; exactly 3 failures, and they are `OBJ class`, `TYPE0 boolean`, `TYPE1 proc-types` (issue #12, `plccmk` absent — see the amendment at Task 4, Step 2)
- [ ] `bats bin/tests/bats-tmpdir.bats` — 4 tests, 0 failures
- [ ] `bats bin/tests/check-run-complete.bats` — 7 tests, 0 failures
- [ ] The truncated-report banner was printed and read (Task 4, Step 3)
- [ ] `ls -d /tmp/bats-run-*` reports nothing after a full run
- [ ] `df -h /tmp` is essentially unchanged before and after a full run
- [ ] `bin/issues/check.bash` reports no errors
- [ ] `git log --format=%s b1d87d9..HEAD | grep -E '^(fix|feat)'` finds nothing — no commit type that would spin the release version
- [ ] every commit on the branch ends with the `Co-Authored-By` trailer

The spec's Commits section lists six. This plan splits two of them for
reviewability — the teardown library from its wiring (Tasks 1 and 2), and the
completeness library from its use in `bin/test.bash` (Tasks 3 and 4) — so that
a reviewer can accept a library and still reject how it is wired in.

> **Amended 2026-08-06, mid-execution — twice, which is the point.**
>
> This item originally asserted a commit count: **eight**, reasoning "the spec
> commit plus one per task." That was wrong — it forgot the plan commit, and it
> could not know about the acceptance-baseline amendment added during Task 2.
> Corrected to ten. Committing that correction made it eleven. The final
> review's fix wave then made it fifteen.
>
> Three corrections, each one invalidated by the act of making it. The defect
> was never the arithmetic; it was asserting a number that the assertion itself
> changes. So the item no longer counts commits — it checks the two properties
> that actually matter and that no later commit can silently falsify: no
> release-spinning commit type, and the required trailer on every commit.
>
> Worth leaving on the record. Issue #31 is about a harness that reports a
> number a reader is inclined to trust and shouldn't; a plan checklist that
> does the same thing is the documentation version of it.
>
> Caught by the Task 7 implementer, not by me. Worth recording rather than
> quietly correcting: a plan that asserts a count a reader can check, and gets
> it wrong, is a small instance of exactly what issue #31 is about.

## Out of Scope

- **Issue #27's conversion work.** See the design spec; it is a shrink, not a bound, and its own issue says to sequence it with migration work that is editing the same files.
- **`dev-docs/course-material-impact.md`.** Deliberately no entry: nothing here touches a language, grammar symbol, field name, or program output.
- **Auto-removing stale `/tmp/bats-run-*`.** A concurrent run may own one. The banner advises; it does not delete.
- **A pre-flight `df` threshold.** Guesswork once the run is bounded at a few MB.

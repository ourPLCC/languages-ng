# Bound the suite's disk use, and never report a dead run as a test failure — Design

Addresses issue [#31](../issues/031-suite-exhausts-disk-and-reports-spurious-failure.md).

## Background

On a container whose filesystem is nearly full, `bin/test.bash` dies partway
through and writes a `not ok` for whichever test happened to be running. The
named test is fine; it passes in every run that completes. A reader who trusts
the output concludes that test is broken.

Two separate defects hide behind that one symptom, and they need separate
fixes:

- **The footprint.** The suite's peak disk use is the *sum* of all 130 tests,
  not the cost of one.
- **The silence.** A run that dies for any reason — disk, OOM, a stray
  `SIGKILL` — produces output that reads like an ordinary result. This is the
  same class as issues [#25](../issues/025-relocate-copies-stale-build-artifacts.md)
  and [#28](../issues/028-relocate-filter-hides-permission-errors.md): the
  harness fails in a way that looks like a test result.

### Why the footprint is a sum, not a maximum

This was measured, not assumed. bats 1.11 creates `$BATS_RUN_TMPDIR/test/<n>`
per test (`bats-exec-test:69`) and **deletes none of them during the run**. The
only in-run `rm` is the retry path (`bats-exec-test:162`); `BATS_RUN_TMPDIR`
itself goes in the `EXIT` trap (`bats:340`). Every test's tree is therefore
held simultaneously until the run ends.

Measured with `bats --no-tempdir-cleanup` on `src/V4/tests/seq/V4test.bats`:
one `relocate` test costs **~2.4 MB** — a 1.5 MB copy of `src/` plus one
target's build output.

    130 tests x ~2.4 MB  ~=  312 MB peak

That matches the observed deaths exactly. On a devcontainer with ~230 MB free,
one run died at test 75 (~180 MB) and another at test 96 (~230 MB).

A second consequence: if bats is `SIGKILL`ed the `EXIT` trap never runs and the
entire `bats-run-*` tree leaks permanently, on the filesystem that just filled
up.

### Why issue #27 is not sufficient on its own

Issue [#27](../issues/027-use-spec-flag-instead-of-copying-tree.md) proposes
`plcc-rep -s <abs spec path>`, which needs no copied tree. Issue #31 treats
that as the structural fix. Measurement says otherwise: `-s` removes the
1.5 MB copy but **not** the build output, which still lands in
`BATS_TEST_TMPDIR` and still accumulates. Measured for V4 seq — python 488K,
java 588K, javascript 372K.

| | peak disk, 130-test suite |
|---|---|
| today | ~312 MB |
| #27 alone | ~65 MB |
| per-test cleanup alone | **~2.4 MB, constant** |
| both | ~0.6 MB, constant |

So #27 is a ~5x shrink whose benefit erodes with every language added, while
per-test cleanup is a *bound* that holds as the suite grows and covers
OBJ/TYPE0/TYPE1, which can never convert to `-s`.

#27 is therefore **out of scope here** and stays filed as a speed and
cleanliness win, sequenced with migration work as its own issue recommends —
that work is actively editing the same 39 test files.

## Decision 1: empty each passing test's tmpdir, in a teardown

A new `bin/bats-tmpdir.bash` defines a single `teardown()`, loaded by every
`.bats` file. Peak disk becomes the cost of the largest single test and stays
there however many languages are added.

```bash
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

**Empty the directory, do not remove it.** The retry path at
`bats-exec-test:162` runs an unguarded `rm -r "$BATS_TEST_TMPDIR"`, which fails
if the directory is already gone.

**Exit status was traced.** The trailing `if !` is the last statement, so a
successful `find` leaves the function at 0 — no repeat of the issue #25 defect
where a trailing `&&` left a function at status 1.

### Wiring

One `load` line added to **44 files**: the 42 under `src/`, plus
`bin/tests/relocate.bats` and `bin/tests/clean.bats`. Both bin tests build
fixtures in `BATS_TEST_TMPDIR`; they are tiny today, but a consistent rule
beats an exception nobody remembers.

```bash
load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'   # added; ../bats-tmpdir.bash in bin/tests/
```

A separate file rather than a `teardown()` inside `bin/relocate.bash`: the
cleanup has nothing to do with relocating, and #27 will delete those
`load '.../relocate.bash'` lines — taking the cleanup with them, silently.

No test file defines `teardown()` today (only two `setup()`s, in
`bin/tests/`), so this collides with nothing.

The two test files added by this work are the standing exceptions to
"every `.bats` file loads it":

- `bin/tests/check-run-complete.bats` **does** load it. It writes only small
  TAP files, but the rule is worth keeping uniform.
- `bin/tests/bats-tmpdir.bats` **does not**, and cannot — the teardown would
  wipe the fixtures it is generating. See Testing below.

### Verified behavior

Each of these was checked empirically before being written down, per
[CLAUDE.md](../../CLAUDE.md):

| Claim | Result |
|---|---|
| `teardown()` in a `load`ed library applies to every test in the file | holds |
| `find "$BATS_TEST_TMPDIR" -mindepth 1 -delete` in teardown — bats does not complain | holds |
| `BATS_TEST_COMPLETED` is `1` on pass, unset on fail | holds |
| `BATS_TEMPDIR_CLEANUP` is exported: `1` by default, `''` under `--no-tempdir-cleanup` | holds |

## Decision 2: prove the run reached its last test

The witness is the TAP plan. bats writes `1..N` **before test 1 runs**, so a
complete run always ends with a line for test N. Its absence means the harness
stopped — not that a test failed.

`--report-formatter tap --output <dir>` writes a machine-readable copy
*alongside* whatever formatter stdout is using, so an interactive run keeps its
pretty output. Verified under a pty: stdout kept its ANSI progress display and
`2 tests, 0 failures` summary while a complete `report.tap` was written
separately. Verified incremental, too — the file held `1..4 / ok 1 / ok 2`
while test 3 was still running, which is what makes it a usable witness when
the run dies.

### `bin/check-run-complete.bash`

Pure functions over a report path, so the tests need no disk exhaustion to
exercise them.

```bash
# Print the planned test count from a TAP report; print nothing if absent.
function run_plan_count () {
  awk '/^1\.\.[0-9]+$/ { print substr($0, 4); exit }' "$1"
}

# Print the number of the highest test the run reached; 0 if none.
function run_last_test_number () {
  awk '/^ok [0-9]+/     { n = $2 }
       /^not ok [0-9]+/ { n = $3 }
       END              { print n + 0 }' "$1"
}

# 0 if the report shows a run that reached its last test. Otherwise print a
# harness-failure banner and return 1.
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

awk rather than `grep`/`tail` pipelines, deliberately: no "grep found nothing"
exit status can leak into the result. The final `if` has no `else`, so a
complete run leaves the function at 0. `1..0` reads as complete, correctly.

`run_incomplete_banner` builds its output from a **quoted** heredoc for the
prose plus `printf` for the values, so no `${...}` in the advice text can
expand by accident:

```
================================================================
HARNESS FAILURE: the test run did not finish.

  reason  : the run stopped before its last test
  planned : 130 tests
  reached : 96
  report  : /tmp/tmp.Xy9kQ2/report.tap

Nothing above is a trustworthy test result. A trailing 'not ok'
names the test that was running when the harness stopped, not a
test that is broken, and the pass count counts a truncated file.

The usual cause is the filesystem holding TMPDIR filling up:
  df -h "${TMPDIR:-/tmp}"

A run killed this way also leaks its whole scratch tree, since
bats only removes it in an EXIT trap. Check for stale
/tmp/bats-run-* directories and remove them.

See dev-docs/issues/031-suite-exhausts-disk-and-reports-spurious-failure.md
================================================================
```

### `bin/test.bash`

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

`set -euo pipefail` is on line 2, **before** the `cd` — the issue #25 ordering
defect, avoided. Every command that can legitimately return non-zero is guarded
by `||`.

### Considered and rejected

- **A pre-flight `df` check.** Once cleanup bounds the run at a few MB, a
  free-space threshold is guesswork that would either never fire or fire
  wrongly. The completeness check catches exhaustion if it happens anyway, and
  describes it accurately.
- **Auto-removing stale `/tmp/bats-run-*`.** A real leak, but a concurrent run
  owns one of those directories. The banner advises; it does not delete.

## Testing

### `bin/tests/check-run-complete.bats`

Every case is a handwritten TAP file — no disk exhaustion needed to test the
disk-exhaustion detector.

| Case | Report | Expect |
|---|---|---|
| complete run, all pass | `1..3` + `ok 1..3` | 0, no banner |
| complete run with real failures | `1..3`, `ok 1`, `not ok 2`, `ok 3` | **0** — must not turn honest failures into harness failures |
| truncated, ends `ok 96` | `1..130`, up to `ok 96` | 1; banner names planned 130, reached 96 |
| truncated, ends `not ok 96` | the exact case observed in issue #31 | 1 |
| report file missing | — | 1, reason `no report was written` |
| no plan line | `ok 1` only | 1, reason `no TAP plan line` |
| empty suite | `1..0` | 0 |

The two `not ok` rows also pin `run_last_test_number`'s field handling: `$3`
for `not ok N`, `$2` for `ok N`.

### `bin/tests/bats-tmpdir.bats`

Testing the teardown from outside is awkward: inspecting a child run's tmpdirs
needs `--no-tempdir-cleanup`, which disables the very teardown under test. So
the assertions go **inside** the child, exploiting the fact that tmpdirs are
numbered `$BATS_RUN_TMPDIR/test/<n>` — test 2 can inspect test 1's:

```bash
@test "1 fills its tmpdir"                 { cd "$BATS_TEST_TMPDIR"; mkdir -p a/b; echo x > a/b/f; }
@test "2 sees test 1's tmpdir was emptied" {
  prev="${BATS_RUN_TMPDIR}/test/1"
  [ -d "$prev" ] && [ -z "$(ls -A "$prev")" ]
}
```

The parent generates each fixture into its own `$BATS_TEST_TMPDIR` at runtime
and runs `bats` on it, so no fixture files sit in the repo where
`bats --recursive bin` would collect them as real tests. Three fixtures:

1. a passing test's tmpdir is emptied;
2. a failing test's evidence survives;
3. `--no-tempdir-cleanup` preserves everything.

This file must **not** load `bin/bats-tmpdir.bash`, or the teardown would wipe
its own fixtures.

**Open risk, to settle before writing assertions.** Nested `bats` inherits the
parent's `BATS_*` environment and may need those unset. The plan's first task
on this file verifies nested invocation empirically in a scratch directory
rather than asserting it works.

## Also in scope

- **`bin/test-using-pipeline-container.bash`** — move `set -euo pipefail` above
  its `cd`. Harmless where it stands, but it is exactly the ordering CLAUDE.md
  flags from issue #25, and it is two lines away from work already being done.
- **`dev-docs/issues/027`** — correct the stale scope and record the
  shrink-versus-bound distinction. NAME and NEED have since migrated, so the
  non-convertible set is 3 files (OBJ, TYPE0, TYPE1), not 5, and the
  convertible set is 39 files / 117 tests, not 30 / 90.

## Not in scope

- **Issue #27 itself.** See Background.
- **The course material impact log.** Considered and deliberately skipped:
  nothing here touches a language, a grammar symbol, a field name, or program
  output. It is all test harness, invisible to slides and handouts.
- **CI.** Unaffected today for the reason in issue
  [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) — the job is
  `on: pull_request` and no PRs are open — and unaffected afterwards, since a
  fresh runner has room either way. The exit-2 distinction is what will matter
  there once CI does run.

## Acceptance

The suite cannot currently run to completion on the machine this was written on
— 221 MB free against ~312 MB needed. That makes the acceptance test a real one
rather than a simulated one: after the cleanup lands, `bin/test.bash` runs to
completion on this machine and reports every test it planned.

Note that the planned count is no longer 130 once this work lands — the two new
test files in `bin/tests/` add to it. "130 of 130" is the wrong thing to assert;
"reached the number in the `1..N` plan line" is the right one, which is exactly
what `check_run_complete` checks.

## Commits

Tests first within each commit.

1. `docs(specs): design for bounding suite disk use and detecting truncated runs`
2. `test(harness): empty each passing test's BATS_TEST_TMPDIR`
3. `test(harness): fail loudly when a bats run does not reach its last test`
4. `chore(bin): set -euo pipefail before cd in test-using-pipeline-container`
5. `docs(issues): correct issue 27 scope and clarify -s shrinks rather than bounds`
6. `bin/issues/close.bash` for 031 — final commit of the branch, per CLAUDE.md

All `test`, `chore`, or `docs`. Nothing in `src/` changes, so the release
version does not spin — matching the issue template's rule and issue #31's own
`type: test`.

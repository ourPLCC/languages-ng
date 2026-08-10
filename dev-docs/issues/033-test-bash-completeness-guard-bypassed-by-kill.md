---
type: test
target: this repo
opened: 2026-08-10
closed:
---

# 033 - test.bash's completeness guard is bypassed when test.bash itself is killed

## Description

Issue [#31](031-suite-exhausts-disk-and-reports-spurious-failure.md) gave
`bin/test.bash` a guard against the truncated-run lie: `check_run_complete`
reads the TAP plan line, notices the run never reached test N, prints a
banner, and exits 2. That guard works — but it only runs **if `test.bash`
reaches the line that calls it.**

When `test.bash` itself is killed outright — SIGKILL, or its process group
torn down by whatever launched it — nothing runs. Not the guard, not the
`EXIT` trap. What survives is exactly what #31 set out to eliminate:

- the caller's redirected stdout file, truncated mid-suite, with **no
  banner** anywhere in it;
- a pass count that is plausible and wrong (`grep -c '^ok '` on the
  fragment returns a real number);
- and, because the trap never fires, a leaked `mktemp -d` report directory
  that nothing will ever clean up.

The exit-status contract (`0` all passed, `1` real failures, `2` harness
died) is only meaningful to a caller that reads an exit status. A caller
that redirects to a file and counts it later — which is how every long run
in this repo is actually invoked, since the suite takes 6-9 minutes — gets
no signal at all. The file is the only artifact, and the file lies.

The comment in `bin/test.bash` shows the case was considered one level
down and stopped there:

> Any other value below is bats's own exit status passed through untouched
> -- e.g. 130 if bats was SIGINT'd, or 137 for an OOM kill that lands after
> the last `ok N` is written, so check_run_complete sees a complete report
> and this branch is never taken.

That reasoning is correct for **bats** being killed: `test.bash` survives,
reaches `check_run_complete`, and reports honestly. SIGINT is handled for
the same reason — bash runs the `EXIT` trap, `bats_status` becomes 130, and
the guard still executes. The gap is one level up, where `test.bash` is the
process that dies.

## Steps to Reproduce

1. Start a run, redirecting as any long run in this repo does:

       bin/test.bash > /tmp/out.txt 2>&1

2. From another shell, kill it uncatchably partway through:

       pkill -KILL -f bin/test.bash

3. Inspect `/tmp/out.txt`. It stops at whatever test was running. There is
   no `HARNESS FAILURE` banner. `grep -c '^ok '` and `grep -c '^not ok '`
   both return plausible numbers, and `tail -1` is an ordinary-looking test
   line.

4. `ls -d /tmp/tmp.*` — the report directory `mktemp -d` created is still
   there, because the `EXIT` trap never ran.

## Notes

**Observed during the TYPE0 migration** (issue
[#32](032-migrate-type0-to-plcc-ng.md)), not hypothetically. An agent
subtask backgrounded `bin/test.bash > /tmp/type0-task3.txt 2>&1` and then
ended its turn; the harness reaped the process group. The run died at test
58 of 148. The output file's final line was `ok 58 TYPE0
declared-type-not-checked (python)` and it counted as **57 ok / 1 not ok** —
numbers a reader would have no reason to doubt. Nothing announced the
death. It was caught only by noticing that the file's mtime had stopped
advancing while no `bats` process was alive.

A leaked report directory from a second such kill was still present
afterwards and is direct evidence the trap does not run:

    /tmp/tmp.505vtnhkqD/report.tap   plan=152  reached=5

The report itself is intact and unambiguous — the TAP plan line is right
there — but no one reads it, because the process that would have is gone.

**This is the same silent-corruption class as #31, #25, and #28**, one
layer up: the failure is shaped like an ordinary result. #31 moved the
detection from "the reader notices" to "the harness announces". This issue
is that the announcement has a precondition — the harness being alive to
make it — and that precondition is exactly what fails in the case worth
detecting.

**Directions, roughly in order of how much they buy.**

1. *Make the artifact self-describing.* The truncated file is the thing
   people and agents actually read, and nothing in it says whether it is
   whole. Having `test.bash` write a terminal marker line on the way out —
   or having the caller check for the TAP plan's test N in the stdout copy
   the way `check_run_complete` checks the report — turns "did this finish"
   into a property of the file rather than of the process. A wrapper that
   verifies the marker before anyone counts would close this for every
   caller, not just careful ones.

2. *Do not let the report directory be the only honest witness and also be
   deleted on success.* Today the report is removed on the normal path and
   leaked on the killed path — precisely backwards from what an
   investigator wants. Keeping it (or its plan/reached summary) somewhere
   predictable would make post-mortem a lookup rather than an archaeology
   exercise.

3. *Document the contract's precondition.* Whatever else changes, the
   three-value exit contract should say plainly that it binds only when
   `test.bash` exits, and that a caller reading a file rather than a status
   must verify completeness itself. The current comment reads as though the
   contract is total.

**Not a defect in `check_run_complete`.** That function is correct, and
its `awk`-only implementation is deliberately careful about exit statuses
leaking. The problem is entirely in when it gets the chance to run.

**Practical note for agent-driven work,** since that is how this surfaced:
a backgrounded suite run does not survive the agent turn that started it.
Runs of this length should be foregrounded, or driven by something that
outlives the turn. That is a workaround for the calling pattern, not a fix
for the harness.

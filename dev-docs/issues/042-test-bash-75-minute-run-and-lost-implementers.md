---
type: chore
target: this repo
opened: 2026-08-12
closed:
---

# 042 - test.bash's 75-minute run, and two implementers lost mid-task

<!--
`type` is a conventional commit type: fix, feat, refactor, perf, docs,
test, chore. Classify by user-facing impact, not by whether something was
"broken". `fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.

`target` is the repository the issue is actually about. It defaults to
this repo; set it to the upstream repository (e.g. ourPLCC/plcc-ng) when
the defect is there rather than in this repo's own src/.

`closed` stays empty until bin/issues/close.bash fills it in.
-->

## Description

**This is an observation, not a diagnosis.** Filed so the record
survives the OBJ-migration worktree being deleted (that ledger is
git-ignored), in case the slow-suite behavior recurs.

`bin/test.bash` ran to a correct, complete `EXIT=0, 186/186, ok 186`
but took **~75 minutes**, where every prior run of the same suite in
the same worktree took roughly two minutes. Observed 2026-08-12.
During the slow run it was progressing normally but slowly through
tests in alphabetical order; a single `plcc-rep` invocation timed at
1.4s, disk was 87% full with 7.8G free, load average was ~1.3, memory
4.2G/7.7G used, and no stray or runaway processes were found. **No
root cause was established. Ruled out: nothing conclusively.**

Separately, two of the OBJ-migration plan's six implementer subagents
were killed by infrastructure mid-task after committing but before
reporting: Task 3 by an API spend limit, Task 6 by a 600s stall
watchdog waiting on that slow suite run. Both were verified after the
fact by the controller and both landed clean, so this is not a finding
against the code — but it means two tasks have no independent
implementer attestation.

## Notes

Found during the final whole-branch review of the OBJ migration
(issue #35). If this recurs on a future language's suite run, this
issue is where to add the next data point. If it never recurs, close
it.

---
type: chore
target: ourPLCC/plcc-ng
opened: 2026-08-11
closed:
---

# 037 - plcc-rep lacks output and clean-exit records

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

Semantic actions have no supported way to emit user-visible output, nor
to end the session cleanly. Both are missing record kinds in `plcc-rep`'s
protocol.

`plcc/cmd/rep.py::_render_record` already dispatches on `record['kind']`
(`result` / `error` / `specification_error`, else a hard error), so the
shape of the fix is a new record kind handled there, plus a hook in each
target runtime that lets `_run()` emit it. Two concrete gaps this would
close:

1. **Output.** There is no record kind for "the program printed this."
   OBJ works around it by buffering everything a semantic action would
   have printed into a `Program.out` list and folding it into `_run()`'s
   returned string, because writing directly to stdout collides with
   `plcc-rep`'s use of stdout as its own JSON channel (see issue
   [#036](036-plcc-rep-deadlocks-on-partial-stdout-line.md)). A `output`
   record kind, emitted as each write happens rather than buffered and
   flushed at the end, would let output interleave with results the way
   old PLCC's `rep` did, and would remove the need for the buffering
   workaround entirely.
2. **Clean exit.** There is no record kind for "the program is
   intentionally done." OBJ's `exit` expression calls the target
   language's process-exit function, which — because `plcc-rep` runs the
   generated program as a subprocess — closes the pipe mid-protocol.
   Measured:

   ```
   $ printf 'display 1\nexit\ndisplay 2\n' | plcc-rep
   1nil                                          # stdout
   plcc-rep: interpreter exited unexpectedly     # stderr
   $ echo $?
   1
   ```

   Under old PLCC, `rep` *was* the process, so this was a clean quit with
   status 0. Under plcc-ng, a deliberate quit now reads as a crash: wrong
   stderr message, wrong exit status, for want of a `session-end` (or
   similar) record kind the subprocess could emit before exiting.

## Notes

Cross-links issue [#036](036-plcc-rep-deadlocks-on-partial-stdout-line.md),
the partial-line deadlock this same record-kind addition would also
close off, since output would travel through a typed record instead of
raw stdout.

Found while designing OBJ's port
([dev-docs/specs/2026-08-11-plcc-ng-obj-design.md](../specs/2026-08-11-plcc-ng-obj-design.md),
"The stdout Protocol Finding" and "`exit` Ships With A Documented
Divergence"). OBJ does not block on this: the buffered-output workaround
ships, and `exit`'s status-code divergence ships as-is with a comment in
each spec explaining it, since `exit` is used by zero example programs
and zero tests. The pattern issue
[#006](006-multi-capture-alt-name-case-mismatch.md) set is the model here
— workaround ships, upstream fixes the root cause, workaround gets
reverted with a course-material-impact note.

Per issue-conventions.md, upstream-targeted issues stay in this repo and
are reported upstream manually, with explicit go-ahead. Nothing has been
filed externally.

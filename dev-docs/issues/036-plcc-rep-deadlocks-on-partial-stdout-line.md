---
type: chore
target: ourPLCC/plcc-ng
opened: 2026-08-11
closed:
---

# 036 - plcc-rep deadlocks on a partial stdout line

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

A semantic action that writes a partial line (no trailing newline) to
stdout deadlocks `plcc-rep` with no diagnostic.

Mechanism, from reading the installed package's
`plcc/cmd/rep.py::_read_response`: `plcc-rep` runs the generated program
as a subprocess and treats its stdout as a private, line-oriented JSON
channel. A line that fails to parse as JSON is printed verbatim and the
read loop continues. That works for a line ending in a newline — the
result record arrives on the next `readline()` intact. It does not work
for a partial line: the unterminated text merges with the following JSON
result line into one unparseable line, which is printed (destroying the
result record), and `readline()` then blocks forever waiting for a result
that will never come.

Measured in both Python and JavaScript targets, via stdin and via a
SOURCE file: `timeout` reports exit 124, with no stdout and no stderr —
the worst available failure mode, since nothing tells the caller what
happened.

A newline-terminated write survives, but only via the unparseable-line
fallback, which is an accident of the implementation rather than a
supported output channel: it happens to print the raw line before the
real result, faking the interleaving a language's `display` would want.

## Steps to Reproduce

1. A spec whose semantic action for some expression writes a partial
   line, e.g. `sys.stdout.write("7")` with no trailing `\n`.
2. `echo '<partial-write expression>' | timeout 5 plcc-rep`
3. Actual: exit 124, no output. Expected: either the partial write is
   surfaced, or `plcc-rep` reports the malformed channel rather than
   hanging silently.

## Notes

Impact: a student who puts a `print` (or the target-language equivalent)
in a semantic action, without remembering to add a trailing newline, gets
a hang with no message — nothing distinguishes it from an infinite loop
in their own program.

Found while designing OBJ's port
([dev-docs/specs/2026-08-11-plcc-ng-obj-design.md](../specs/2026-08-11-plcc-ng-obj-design.md),
"The stdout Protocol Finding"), where OBJ's `display`, `display#`,
`putc`, `puts`, and `newline` are partial-line writers by design — a
trailing newline is what the separate `newline` expression is for. OBJ
works around this by buffering all output into `Program.out` and
returning it as part of `_run()`'s result rather than writing it
directly; that workaround is not the fix, and it is why this issue stays
open independently.

Related: issue [#037](037-plcc-rep-lacks-output-and-clean-exit-records.md)
sketches the missing-record-kind fix that would let a semantic action emit
output through a supported channel instead of raw stdout.

Per issue-conventions.md, upstream-targeted issues stay in this repo and
are reported upstream manually, with explicit go-ahead.

**Filed upstream 2026-08-11** as `ourPLCC/plcc-ng` issue #186
(`dev-docs/issues/186-rep-deadlocks-on-partial-stdout-line.md`), typed
`fix`. The mechanism above was re-verified against plcc-ng's current
`src/plcc/cmd/rep.py` rather than the installed CLI, and holds. Upstream
splits the work: `_read_response` must stop treating an unbounded
`readline()` as acceptable regardless, since user code can always write to
stdout directly, while the wider fix is upstream #187's output record kind.
This issue stays open while OBJ's `Program.out` buffering workaround lives
in `src/`.

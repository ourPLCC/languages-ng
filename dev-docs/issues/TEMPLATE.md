---
type: TYPE
target: this repo
opened: YYYY-MM-DD
closed:
---

# NNN - Short descriptive title

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

`## Summary` is one paragraph: what is wrong and why it matters, for
someone triaging the backlog without opening the file. It is required
while the issue is open — bin/issues/check.bash fails until you write
it — and it is deliberately blank here so that filing an issue and
leaving it unsummarized is not a silent state. The full account belongs
in `## Description`.
-->

## Summary

## Description

What you observed, or what you want changed.

## Steps to Reproduce

(For bugs — omit if not applicable)

1. ...

## Notes

Any ideas, hunches, or related context.

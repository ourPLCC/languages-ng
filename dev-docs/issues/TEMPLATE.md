# NNN - Short descriptive title

**Type:** (conventional commit type: fix, feat, refactor, perf, docs, test, …)
**Target:** (this repo by default; set to the upstream repo, e.g. ourPLCC/plcc-ng, if this issue is actually about a defect found there)
**Date:** YYYY-MM-DD

<!--
Classify by user-facing impact, not by whether something was "broken".
`fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.
-->

## Description

What you observed, or what you want changed.

## Steps to Reproduce

(For bugs — omit if not applicable)

1. ...

## Notes

Any ideas, hunches, or related context.

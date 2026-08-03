---
type: docs
target: ourPLCC/plcc-ng
opened: 2026-08-03
closed:
---

# 022 - plcc-rep-parses-each-source-independently

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

plcc-rep parses each SOURCE argument as an independent token stream, so
a program split across two files no longer parses. Old PLCC's `rep`
joined its file arguments into one stream. V6's Prog/p1 (`+(3`) and
Prog/p2 (`,4)`) are a course example that relies on the old behavior.

Not a defect in this repo's src/ — per-source parsing is arguably the
more sensible design — but it is a migration hazard worth documenting
upstream, and it silently changes what a course demonstration does.

## Steps to Reproduce

1. From `src/V6/python/`, with p1 containing `+(3` and p2 containing `,4)`:

   ```
   $ plcc-rep ../Prog/p1 ../Prog/p2
   plcc-parser-table: -:1:3: error: expected 'RPAREN', got end of file
   plcc-parser-table: -:1:1: error: unexpected 'COMMA', no production for 'Program'
   ```

2. Concatenating first works as expected:

   ```
   $ cat ../Prog/p1 ../Prog/p2 | plcc-rep
   7
   ```

## Notes

Found while porting V6. See
[dev-docs/specs/2026-08-03-plcc-ng-v6-design.md](../specs/2026-08-03-plcc-ng-v6-design.md).

Per issue-conventions.md, upstream-targeted issues stay in this repo and
are reported upstream manually, with explicit go-ahead. Nothing has been
filed externally.

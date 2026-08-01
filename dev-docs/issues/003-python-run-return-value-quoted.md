---
type: docs
target: ourPLCC/plcc-ng
opened: 2026-07-22
closed: 2026-07-28
---

# 003 - python-run-return-value-quoted

## Description

The Python quick-start example (`docs/quick-start.md`) shows `_run()`
returning a plain string via `'\n'.join(...)`, and the language guide
(`docs/language-guide/languages/python.md`) documents: "The return value
is converted to a string and printed by `plcc-rep`." In practice,
returning a plain `str` from `_run()` prints it wrapped in quotes (e.g.
`'hello'` instead of `hello`) instead of the plain string the docs show.

## Steps to Reproduce

1. `spec.plcc`:
   ```
   skip WHITESPACE '\s+'
   token NUM '\d+'
   %
   <Prog> **= <NUM>
   %
   Python

   Prog
   %%%
   def _run(self):
       return "hello"
   %%%
   ```
2. `echo "1 2 3" | plcc-rep`
3. Actual: `'hello'`. Expected per docs: `hello`.

Using `print(...)` instead of `return` inside `_run()` avoids the issue
entirely (confirmed) and is what this repo now uses everywhere for the
Python target.

## Notes

Found while validating [dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md](../plans/2026-07-22-plcc-ng-phase0-phase1.md).
Not filed upstream yet — needs the repo owner's go-ahead first.

**Resolved in plcc-ng 2.0.0:** `_run()` now returns its output and the
runtime prints a plain string unquoted. Repo switched from `print()` back
to returning. Upstream shipped the fix, so filing upstream is moot.

---
type: test
target: this repo
opened: 2026-08-14
closed:
---

# 051 - close.bash's argument-resolution paths have no test coverage

## Summary

[#49](049-retire-roadmap-open-issues-section.md) gave `bin/issues/close.bash`
its first tests, but the five cases cover the happy path and two early-exit
guards only. Three argument-resolution paths are still unexercised: the
unpadded legacy-id fallback, the multiple-match guard, and the
frontmatter-scoped fill's refusal to be fooled by a `closed:` line in an
issue's body. All three were hand-traced correct during #49's review, so
this is a regression-detection gap rather than a known bug — but they are
exactly the paths a future change to the id-matching logic would break
silently, and [#20](020-close-bash-roadmap-awk-edge-cases.md) proposes
changes to that very code.

## Description

`bin/tests/issues-close.bats` covers: closing an issue, that the output
never mentions the roadmap, that exactly one file is staged, refusing an
already-closed issue, and refusing an id with no file.

Three paths in the script have no test:

1. **The unpadded legacy-id fallback.** `close.bash` first globs
   `${ISSUES_DIR}/${padded}-*.md`, and if that matches nothing, retries
   with the unpadded id — for issues filed before `new.bash` zero-padded.
   `nullglob` is off, so an unmatched glob stays literal and the `[[ ! -e ]]`
   test catches it. Nothing verifies that, and nothing verifies the
   fallback actually finds a legacy file.
2. **The multiple-match guard.** If two files share an id prefix,
   `close.bash` errors rather than guessing. Untested.
3. **A `closed:` line in the body.** The fill `awk` is scoped to the first
   frontmatter block via an `n == 1` guard, so a `closed:` line appearing
   in an issue's prose must not be rewritten. Untested — and this one has
   real teeth, since an issue *about* the closing convention would
   naturally quote that field.

## Steps to Reproduce

Not a defect to reproduce. To see the gap:

1. `grep -c '^@test' bin/tests/issues-close.bats` — five.
2. Compare against the branches in `bin/issues/close.bash` between the
   argument guard and the `git add`.

## Notes

The fixture helpers to write these already exist in
`bin/tests/issues-close.bats`: `setup()` builds a throwaway git repo with
the script copied in, and `make_issue` writes a well-formed issue. Case 3
needs a fixture whose body contains a `closed:` line, which `make_issue`
cannot express today — either extend it or write the file inline, the way
`bin/tests/issues-check.bats` does for its whitespace-only case.

Worth doing **before** [#20](020-close-bash-roadmap-awk-edge-cases.md),
not after: #20 changes the argument guard and the id arithmetic, and these
tests are what would prove that change safe. Filed separately rather than
folded into #20 because #20 is about defects in that code and this is about
the absence of tests around it — the two are fixed by different work.

Raised in the whole-branch review of #49 and deferred there by explicit
decision, since #49's own scope was the roadmap retirement.

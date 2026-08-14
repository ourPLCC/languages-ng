---
type: chore
target: this repo
opened: 2026-08-01
closed:
---

# 020 - close.bash's argument handling and staging order

## Summary

`bin/issues/close.bash` has three dormant defects around its argument and
its staging order: `[[ $# -ne 1 ]] && usage` in place of an explicit `if`,
a raw bash arithmetic error rather than `usage()` when the id is not a
number, and `git add` running before `check.bash`, so a failed check
leaves a half-applied close staged with no recovery hint. None can
corrupt an issue file; all three are diagnostics quality.

## Description

This issue originally reported two defects in the roadmap-editing `awk` in
[close.bash](../../bin/issues/close.bash) — blank-line collapsing that was
file-wide rather than entry-scoped, and a skip state that a blank line
ended prematurely — plus four lower-severity observations swept up from the
whole-branch review of [#18](018-close-bash-rewrites-plan-prose.md).

[#49](049-retire-roadmap-open-issues-section.md) deleted `dev-docs/roadmap.md`
and every line of `close.bash` that edited it. Both numbered defects went
with that `awk`, and so did one of the four sweep-up items: the unescaped
`${basename}` interpolated into a BRE `sed` pattern was the
milestone-checkbox pass, which no longer exists. Three remain:

1. **`[[ $# -ne 1 ]] && usage` instead of `if ...; then ...; fi`.** The
   script runs under `set -euo pipefail`, and this form survives only
   because `set -e` exempts every command in an AND-list except the last:
   the failing `[[ ]]` is not that command, so the shell does not exit. It
   is a well-known footgun that happens to be standing on the exemption.
   `list.bash` already uses the explicit `if` form.
2. **A non-numeric id produces a raw bash arithmetic error** rather than
   the `usage()` message, though it fails before touching any file.
3. **Staging precedes verification.** `close.bash` stages the issue file
   and then runs `check.bash`. A failed check leaves the filled-in
   `closed:` date staged, with nothing printed about how to undo it.

## Notes

All three were raised in the whole-branch review of #18 and deferred by
explicit decision. Item 3 is the only one with a real cost: recovery is
`git restore --staged --worktree <file>`, which the script could simply
print.

A correction to what this issue used to claim: it cited
[issue-conventions.md](../issue-conventions.md) as prescribing
`if ...; then ...; fi` over `[[ ... ]] && ...`. That document contains no
shell style rule and appears never to have. Item 1 stands on the `set -e`
reasoning above, not on a convention.

`bin/issues/new.bash` uses the same `[[ $# -lt 1 ]] && usage` form, on the
same exemption. Fixing item 1 should fix both.

Retitled and re-scoped by #49. The filename keeps its original
`close-bash-roadmap-awk-edge-cases` slug: issue files never move, so links
to this issue never break.

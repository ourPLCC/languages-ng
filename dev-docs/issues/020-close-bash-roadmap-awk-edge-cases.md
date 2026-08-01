---
type: chore
target: this repo
opened: 2026-08-01
closed:
---

# 020 - close.bash's roadmap awk has two dormant edge cases

## Description

The roadmap-editing `awk` in [bin/issues/close.bash](../../bin/issues/close.bash)
carries two defects. Both predate [#18](018-close-bash-rewrites-plan-prose.md) —
they were inherited verbatim when that issue rewrote the script around the
`closed:` frontmatter field, and #18 deliberately left them alone as out of
scope. Neither can fire against the roadmap as it stands today, which is why
they were deferred rather than fixed.

1. **Blank-line collapsing is file-wide, not entry-scoped.** The `END` block
   rebuilds the whole file through a `blank`/`printed` filter that emits at
   most one blank line between any two kept lines. Any pre-existing run of two
   or more consecutive blank lines *anywhere* in `dev-docs/roadmap.md` — between
   unrelated sections, or inside a fenced code block — is silently collapsed on
   every close. The removal logic itself is carefully scoped to the entry being
   deleted; this normalization pass is not.

2. **A blank line ends the bullet-removal skip state.** The state machine
   continues skipping only while lines match `/^[ \t]/`. A blank line does not,
   so it resets `skip` to 0, and any further indented lines belonging to the
   same entry are kept — leaving an orphaned fragment of the deleted entry
   behind, along with the stray blank line.

## Steps to Reproduce

Neither reproduces against the current roadmap. To see (2):

1. Give an Open Issues entry a multi-paragraph continuation — a bullet, an
   indented line, a blank line, then another indented line.
2. Close that issue with `bin/issues/close.bash <id>`.
3. The bullet and its first continuation line are removed; the blank line and
   the second continuation line remain.

For (1), add a second consecutive blank line anywhere in the roadmap, close any
issue, and observe that it is gone.

## Notes

Why they are dormant today: every Open Issues entry is a bullet plus exactly one
indented continuation line, and the roadmap contains no fenced blocks and no
double-blank runs. `bin/issues/check.bash` does not police either property, so
nothing prevents a future entry from tripping (2).

Fix directions:

1. Scope the blank-line normalization to the span the removal actually touched,
   rather than re-normalizing the entire file.
2. Track the skip state by indentation depth instead of treating any
   non-indented line — including a blank one — as the end of the entry.

Both were raised in the whole-branch review of #18 and deferred by explicit
decision. Related lower-severity observations from that same review, all
similarly dormant, if this issue is a convenient place to sweep them up:

- `close.bash` interpolates `${basename}` unescaped into a BRE `sed` pattern, so
  the `.` before `md` is a wildcard rather than a literal.
- `close.bash` uses `[[ $# -ne 1 ]] && usage`, the form
  [dev-docs/issue-conventions.md](../issue-conventions.md) tells us to avoid in
  favor of `if ...; then ...; fi`.
- A non-numeric id produces a raw bash arithmetic error rather than the
  `usage()` message, though it fails before touching any file.
- `close.bash` stages both files before running `check.bash`, so a failed check
  leaves a half-applied close staged with no recovery hint printed.

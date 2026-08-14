---
type: chore
target: this repo
opened: 2026-08-14
closed:
---

# 050 - the `head -n N` idiom is coupled to TEMPLATE.md's comment block

## Summary

Four places document `bin/issues/list.bash | xargs head -n 50` and promise
it shows an issue's frontmatter, title, and summary. That number is only
correct for as long as `dev-docs/issues/TEMPLATE.md`'s HTML comment block
stays its current length: the comment sits between the `#` title and
`## Summary`, so growing it pushes every new issue's summary further down
and silently starts truncating the thing the documents promise. The number
already drifted twice during [#49](049-retire-roadmap-open-issues-section.md)
— 20, then 40, then 50 — and nothing detects the next drift.

## Description

`dev-docs/issues/TEMPLATE.md` currently lays out as:

- lines 1-6: frontmatter
- line 8: the `#` title
- lines 10-32: an HTML comment block explaining the fields
- line 34: `## Summary`
- line 36: `## Description`

So a freshly filed issue puts `## Description` at line **37 + N**, where N
is the summary's line count. The longest summary in the repo today is 8
lines, landing at line 45. `head -n 50` covers that with headroom for a
13-line summary.

The coupling is the problem, not the current value. Any edit to that
comment block — one more paragraph about a new frontmatter key, say —
moves the boundary, and the four documents keep asserting the old number:

- `CLAUDE.md`, in the paragraph about `list.bash`
- `CONTRIBUTING.md`, the `list.bash` row of the command table
- `dev-docs/issue-conventions.md`, under "Listing open issues"
- `bin/issues/list.bash`, its own usage text

Nothing checks any of them. `bin/issues/check.bash` validates issue files,
not the documentation's arithmetic about them.

## Steps to Reproduce

1. Add a paragraph to the HTML comment block in
   `dev-docs/issues/TEMPLATE.md`.
2. `bin/issues/new.bash some-slug chore`, and write a summary of 8 or more
   lines.
3. `bin/issues/list.bash | xargs head -n 50` — the new issue's summary is
   cut off, while all four documents still claim 50 shows it.

## Notes

Two fix directions, from the whole-branch review of #49:

1. **Break the coupling structurally.** Move `## Summary` above the HTML
   comment block, or move the comment to the end of the template. Either
   makes the summary's position independent of the comment's length, and
   the number then depends only on the frontmatter, which is fixed at four
   keys. This is the durable fix, but it needs the four documents
   re-measured once more when it lands.
2. **Make the drift detectable.** Have `check.bash` verify that the
   documented number actually reaches past `## Description` in the deepest
   open issue. That turns a silent falsehood into a failed check, at the
   cost of teaching the issue checker about prose in three other files.

Direction 1 is preferred; direction 2 is what would have caught this
during #49 rather than during its review.

Related: this is the same class of defect as
[#47](047-issue-conventions-claims-generated-changelog.md) — a document
stating something about the tooling that quietly stopped being true. #47
was a claim that was never true; this is a claim with an expiry date.

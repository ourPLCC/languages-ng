---
type: chore
target: this repo
opened: 2026-08-13
closed:
---

# 049 - retire the roadmap's Open Issues section

## Description

Every open issue is recorded twice: once as a file in
[dev-docs/issues/](../issues/) whose `closed:` field is empty, and again as a
two-line entry in the **Open Issues** section of
[dev-docs/roadmap.md](../roadmap.md). The issue file is the source of truth —
`closed:` *is* the status — so the roadmap section is a derived copy that is
maintained by hand.

The duplication costs three things:

1. **Merge conflicts between parallel branches.** Filing or closing an issue
   edits one shared region of one shared file. Two branches that each open or
   close an issue collide in `roadmap.md` even when they touch nothing else in
   common. Nothing about the underlying work conflicts; only the index does.
2. **Links that can break.** Each entry hard-codes `(issues/NNN-slug.md)`.
   `bin/issues/check.bash` has a dedicated pass to catch entries pointing at
   files that do not exist, which exists only because the duplication does.
3. **Machinery to keep the copy in sync.** `bin/issues/close.bash` removes the
   entry and its `###` group when empty; `check.bash` enforces that every open
   issue has an entry and no closed one does. Both are pure consequences of
   storing the list twice.

[bin/issues/list.bash](../../bin/issues/list.bash) now derives the same list
from the issue files directly, which is what makes retiring the section
possible: the question the section answers has a script that answers it from
the source of truth.

Note the scope boundary. This issue is about the **Open Issues** section only.
The roadmap's **milestone sections** are ordered task lists carrying
hand-written rationale prose and completion state — genuinely authored
content, not a derived index — and they stay, along with `check.bash`'s pass
that reconciles their checkboxes against each issue's `closed:` field.

## Steps to Reproduce

For the conflict cost:

1. From `main`, create two worktrees.
2. In each, run `bin/issues/new.bash <slug>` and add the roadmap entry the
   conventions require.
3. Merge the first. The second now conflicts in `dev-docs/roadmap.md`, though
   the two issues are unrelated and no other file overlaps.

## Notes

The open design question is the **one-line summaries**. Each Open Issues entry
carries a hand-written summary — often the single most useful triage sentence
about that issue — and that prose exists nowhere else. Deleting the section
discards it unless it moves. Options considered so far:

- Add a `summary:` frontmatter key. Flat scalar like the other four, so
  `check.bash`'s existing `fm_value` reader handles it and can require it
  non-empty. Costs a template change and a one-time migration of the open
  issues.
- Drop the summaries and let the `#` heading carry the meaning. Free, but
  loses real information — and many headings are still the raw slug, since
  `new.bash` substitutes the slug for the placeholder title.

This wants brainstorming before implementation; it is not a mechanical
deletion.

Work implied, roughly:

- Remove the Open Issues section from `dev-docs/roadmap.md`.
- Delete `close.bash`'s roadmap-entry removal, keeping the `closed:` fill-in
  and the milestone checkbox update.
- Delete `check.bash`'s two entry-presence passes, keeping the milestone
  reconciliation and the link-resolution pass for whatever links remain.
- Update `dev-docs/issue-conventions.md`, `CLAUDE.md`, and `CONTRIBUTING.md`,
  all of which instruct the reader to add a roadmap entry when filing.

This partly overlaps [#20](020-close-bash-roadmap-awk-edge-cases.md), whose
two numbered defects are both in the roadmap-editing `awk` that this issue
deletes. It does **not** obsolete #20 entirely: the four sweep-up items in
that issue's Notes — the unescaped `sed` BRE, the `[[ ... ]] && usage` form,
the raw arithmetic error on a non-numeric id, and staging before `check.bash`
runs — are about argument handling and staging, and survive this change
untouched. Whoever does this work should re-scope #20 rather than close it.

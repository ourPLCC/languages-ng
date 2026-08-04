---
type: docs
target: this repo
opened: 2026-07-30
closed: 2026-08-04
---

# 013 - dev-docs-link-checker-not-fence-aware

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

The ad-hoc link checker used in the issue-#11 plan (the Python snippet in
Task 3 Step 4 of
[dev-docs/plans/2026-07-30-devcontainer-cache-diagnosis.md](../plans/2026-07-30-devcontainer-cache-diagnosis.md))
reports **19 broken relative `.md` links** across `dev-docs/`. Two
separate problems are tangled together in that number:

1. **The checker does not understand fenced code blocks.** It regex-scans
   whole files, so every Markdown link appearing *inside* a fence is
   checked as though it were a live link. Our plans quote large verbatim
   excerpts of `roadmap.md`, `CLAUDE.md` and issue files inside
   ` ```markdown ` fences, and `issue-conventions.md` documents the
   required roadmap entry format using an `issues/NNN-slug.md`
   placeholder. None of these render as links or can ever resolve.
2. **Four genuinely broken links** exist in `dev-docs/issues/done/`.

Until the checker skips fenced blocks, its gate line
`OK: all dev-docs links resolve` is not merely unmet but
**unsatisfiable** — the placeholder in `issue-conventions.md` is
deliberately unresolvable, so no amount of link repair will silence it.
The #11 plan's Task 3 Step 4 was written expecting that output, so that
step's gate could never have been met as written.

## Steps to Reproduce

Run the Task 3 Step 4 snippet from the repository root. Current output,
verbatim:

```
BROKEN:
dev-docs/issue-conventions.md -> issues/NNN-slug.md
dev-docs/issue-conventions.md -> issues/NNN-slug.md
dev-docs/plans/2026-07-28-plcc-ng-phase2-v3.md -> issues/done/009-migrate-v3-to-plcc-ng.md
dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md -> ../CLAUDE.md
dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md -> dev-docs/course-material-impact.md
dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md -> issues/done/001-remove-unused-languages.md
dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md -> issues/done/002-migrate-v0-to-plcc-ng.md
dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md -> issues/done/003-python-run-return-value-quoted.md
dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md -> issues/done/004-js-var-field-reserved-word.md
dev-docs/plans/2026-07-23-plcc-ng-phase2-v2.md -> 006-multi-capture-alt-name-case-mismatch.md
dev-docs/plans/2026-07-23-plcc-ng-phase2-v2.md -> issues/done/007-migrate-v2-to-plcc-ng.md
dev-docs/plans/2026-07-30-devcontainer-cache-diagnosis.md -> done/010-plcc-ng-arbno-drops-mid-body-terminal.md
dev-docs/plans/2026-07-22-plcc-ng-phase2-v1.md -> issues/005-migrate-v1-to-plcc-ng.md
dev-docs/plans/2026-07-22-plcc-ng-phase2-v1.md -> issues/done/003-python-run-return-value-quoted.md
dev-docs/plans/2026-07-22-plcc-ng-phase2-v1.md -> issues/done/004-js-var-field-reserved-word.md
dev-docs/issues/done/007-migrate-v2-to-plcc-ng.md -> ../006-multi-capture-alt-name-case-mismatch.md
dev-docs/issues/done/008-update-plcc-ng-2.0.0.md -> ../003-python-run-return-value-quoted.md
dev-docs/issues/done/008-update-plcc-ng-2.0.0.md -> ../006-multi-capture-alt-name-case-mismatch.md
dev-docs/issues/done/008-update-plcc-ng-2.0.0.md -> ../004-js-var-field-reserved-word.md
TOTAL: 19
```

Re-running the same scan with a fence toggle (skipping lines between
fence markers) splits the 19 into **15 fenced false positives** and
**4 real breaks**.

### The 4 real breaks

All four are in closed issue files, and all four are the same bug:

| File | Line | Link |
| --- | --- | --- |
| `dev-docs/issues/done/007-migrate-v2-to-plcc-ng.md` | 29 | `../006-multi-capture-alt-name-case-mismatch.md` |
| `dev-docs/issues/done/008-update-plcc-ng-2.0.0.md` | 31 | `../003-python-run-return-value-quoted.md` |
| `dev-docs/issues/done/008-update-plcc-ng-2.0.0.md` | 35 | `../006-multi-capture-alt-name-case-mismatch.md` |
| `dev-docs/issues/done/008-update-plcc-ng-2.0.0.md` | 40 | `../004-js-var-field-reserved-word.md` |

Each climbs one level out of `done/` to reach an issue that has since
been closed and therefore now lives *in* `done/`, alongside the linking
file. The correct target in every case is the bare sibling name.

### The 15 fenced false positives

`dev-docs/issue-conventions.md` lines 18 and 58 are the documented
`issues/NNN-slug.md` entry-format placeholder — once for Open Issues, once
for milestone lists. The other 13 are verbatim quotations of other files
inside ` ```markdown ` fences:
`2026-07-22-plcc-ng-phase0-phase1.md` (lines 138, 153, 252, 404, 1202,
1204), `2026-07-22-plcc-ng-phase2-v1.md` (72, 77, 79),
`2026-07-23-plcc-ng-phase2-v2.md` (54, 67),
`2026-07-28-plcc-ng-phase2-v3.md` (75), and
`2026-07-30-devcontainer-cache-diagnosis.md` (202). Every one is correct
as written: a plan showing what a file should contain has to reproduce
that file's links literally.

## Notes

None of this was introduced by the #11 branch. Its single authored entry
in the list (`2026-07-30-devcontainer-cache-diagnosis.md:202`) is a fenced
quotation of issue #11's pre-close body, showing the link text as it stood
before `close.bash` re-depthed it — a false positive.

Suggested fix direction, in order:

1. **Make the checker fence-aware**, and promote it out of a plan step into
   a real script under `bin/` (`bin/check-links.bash` or similar) so it is
   reusable and can gate CI. This is the prerequisite: without it the
   `OK: all dev-docs links resolve` gate can never pass. Track fence state
   while scanning and skip lines inside fences; mind indented fences and
   the varying fence lengths Markdown permits.
2. ~~**Repair the 4 real breaks**~~ — done under
   [#18](018-close-bash-rewrites-plan-prose.md): all four were links from
   one closed issue to another, and they were repaired when issues stopped
   moving into `done/`.
3. ~~**Consider the root cause in `bin/issues/close.bash`.**~~ — moot under
   [#18](018-close-bash-rewrites-plan-prose.md). There is no pass 3 or pass
   4 any more: an issue's status is a `closed:` frontmatter date, its file
   never moves, and no link to it is ever rewritten.

Found during the whole-branch review of the #11 branch, which surfaced the
checker but caused none of the breaks.

## Resolution

**Closed without building the checker.** Fix direction 1 was the only
remaining scope, and it is not worth the code it would take to keep
correct.

Measured across all 50 Markdown files on 2026-08-04: of 166 relative
links, 154 point into `dev-docs/`, 7 into `bin/`, and 5 at `CLAUDE.md`.
**None point into `src/`** — the only part of the repo with real file
churn, where whole `src/V*/code|grammar|prim|val|envVal` trees are deleted
each migration (`489323e`, `37fe117`, `5fbadab`). The entire linked
surface is files that, since
[#18](018-close-bash-rewrites-plan-prose.md), never move.

That also accounts for the checker's whole historical yield. The 4 real
breaks above were `done/`-relative links between closed issues, produced
by a mechanism `b60e8ce` removed when it flattened `issues/`. A fence- and
inline-code-aware scan of the tree on 2026-08-04 reports **0** broken
links. What is left is authoring typos and the 7 `bin/` links — cheap to
notice, and cheaper to fix than a checker is to maintain.

Two findings worth keeping if this is ever revisited:

- **Fence-awareness alone is not enough.** Three reports survive fence
  skipping because they are links inside *inline code spans* — prose in
  [2026-07-31-issue-status-frontmatter.md](../plans/2026-07-31-issue-status-frontmatter.md)
  that quotes a line of Markdown between backticks to say what to replace
  it with. Any checker must skip both fences and inline spans.
- **Don't hand-roll it.** Off-the-shelf checkers parse Markdown into an
  AST, so text inside fences and code spans is never a link — the bug in
  this issue is an artifact of regex-scanning raw text. `lychee` with
  `--offline` (via `lycheeverse/lychee-action`) is the best fit: a ~15
  line workflow, no repo manifest required. The npm options
  (`remark-validate-links`, `markdown-link-check`) would mean introducing
  node packaging to a repo that has none.

Reopen if docs start linking into `src/` paths, where a break would be
silent.

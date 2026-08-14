# Retire the roadmap — design

Date: 2026-08-14
Issue: [#49](../issues/049-retire-roadmap-open-issues-section.md)

## Problem

Every open issue is recorded twice: as a file in `dev-docs/issues/` whose
`closed:` field is empty, and as a hand-maintained entry in the **Open
Issues** section of `dev-docs/roadmap.md`. The issue file is the source of
truth — `closed:` *is* the status — so the roadmap section is a derived
copy kept in sync by hand and by script.

The duplication costs merge conflicts between otherwise unrelated
branches, hard-coded links that can break, and machinery in
`bin/issues/close.bash` and `bin/issues/check.bash` whose only purpose is
keeping the copy honest. `bin/issues/list.bash` now derives the same list
from the issue files, which is what makes retiring the section possible.

## What this design decides

Issue #49 left one question open — where the entries' one-line summaries
go — and assumed the roadmap's milestone sections would remain. Reading
the file settled the second point differently, which widened the change.

### The roadmap is deleted, not trimmed

`dev-docs/roadmap.md` is 52 lines and **all of them are the Open Issues
section**: a `# Roadmap` heading and five `###` type groups. There are no
milestone sections. `check.bash`'s milestone-checkbox reconciliation and
`close.bash`'s checkbox `sed` both match zero lines today; the milestone
convention in `issue-conventions.md` describes content that does not
exist.

So retiring the section empties the file, and the decision is to delete
it. The milestone apparatus goes with it — the conventions section, the
two script passes, and the roadmap-link-resolution pass. Nothing in the
tree stops being checked, because none of it governs any current content.
What is lost is a convention, recoverable later by writing the document
again.

After this change the backlog has exactly one representation: the issue
files. `closed:` is the status, `list.bash` enumerates, `check.bash`
validates. There is no index, so there is no index to conflict in — two
branches filing issues touch only their own new file and `.next-id.txt`.

### Summaries move into a `## Summary` section

Each Open Issues entry carries 40–70 words of hand-written triage prose
that exists nowhere else. It moves into the issue file, between the `#`
title and `## Description`:

```markdown
# 044 - relocate swallows git's reason for refusing a checkout

## Summary

`relocate_copy_tree`'s opening guard sends git's stderr to `/dev/null`
and replaces it with "is not in a git checkout", which is the least
likely of the reasons `rev-parse --git-dir` can fail under `src/`.

## Description
```

A body section rather than a `summary:` frontmatter key: the prose stays
normally wrapped, with readable diffs, instead of becoming one unwrapped
60-word scalar that strains the frontmatter's "flat scalars, one key per
line" shape. It also falls inside `head -n 20`, so the documented
`list.bash | xargs head` idiom surfaces it with no new tooling.

**The requirement applies while the issue is open.** `check.bash` requires
a non-empty `## Summary` when `closed:` is empty and says nothing about
closed issues. The section exists to triage open work; closed work needs
no triage. Migration is therefore exactly the 17 roadmap entries into the
17 open files — a lossless move — and closing an issue never has to touch
the section.

### `list.bash` does not change

It keeps its single contract: one path per line, in id order, no flags
beyond `-h`/`--help`. The documented idiom moves from `head -n 15` to
`head -n 20` so a full Summary always fits. A `--summary` digest mode was
considered and rejected as unneeded surface on the one script other
tooling composes with — issue #43 is what a loose argument guard costs.

## Changes

### `bin/issues/check.bash`

Keeps every issue-file invariant: the `done/` directory guard, the
frontmatter block being opened and closed, the four required keys, the
`opened`/`closed` date formats, the open/closed counts, and
`.next-id.txt` being ahead of every id.

Removes the `ROADMAP` variable and all four roadmap passes — the
open-issue-has-an-entry check, the closed-issue-has-no-entry check, the
roadmap-link-resolution loop, and the milestone-checkbox reconciliation
loop.

Adds one check, for open issues only: the file must contain a `## Summary`
heading followed by a non-blank line before the next `##` heading. The
`awk` reads:

```awk
$0 ~ /^## Summary[[:space:]]*$/ { in_s = 1; next }
in_s && /^## /                  { exit }
in_s && NF                      { found = 1; exit }
END                             { exit !found }
```

Entering the section sets the state; the next `##` heading ends it; the
first non-blank line inside it succeeds. A whitespace-only line has
`NF == 0`, so it does not count as content. `/^## /` requires the space,
so a `### ` subheading does not end the section. `exit` runs `END`, and
`found` is unset until proven, so a file with no `## Summary` at all
reaches `exit !found` and fails.

Known limitation, accepted: the match is line-based, so a literal
`## Summary` line inside a fenced code block elsewhere in the file would
satisfy the check. Reaching that requires an issue with no real Summary
that also quotes the heading verbatim in a fence. Not worth a fence-aware
parser in a checker this size.

The success line drops "roadmap consistent":

```
OK: 17 open, 32 closed, next id 50
```

### `bin/issues/close.bash`

Removes the `ROADMAP` variable, the milestone-checkbox `sed -i` (pass 1),
and the entry-removal `awk` (pass 2). Stages only the issue file. Drops
the "Review the roadmap (milestone rationale text is not auto-edited)"
line from its output and the roadmap sentences from its usage text.

What remains: resolve the id (padded, then unpadded), refuse an
already-closed issue, fill `closed:` via the frontmatter-scoped `awk`,
verify the fill, run `check.bash`, print the commit message — now
`docs(issues): close issue N (<short title>)`, without ", update roadmap".

### `dev-docs/issues/TEMPLATE.md`

Gains `## Summary` between the title and `## Description`, with an
**empty** body. Guidance goes in the existing HTML comment block: the
Summary is the triage condensation — what is wrong and why it matters —
not the full account, which is `## Description`'s job.

An empty body means a freshly filed issue fails `check.bash` until someone
writes a summary. `new.bash` does not run the checker, so this costs
nothing at file time; it makes the summary a precondition for the commit,
which is already where the conventions put `check.bash`. Shipping
placeholder text instead would let a placeholder pass the check.

`bin/issues/new.bash` is unchanged.

### Documentation

- **`dev-docs/issue-conventions.md`** — delete the "The roadmap" section.
  Change the opening "indexed by [roadmap.md]" to name `list.bash`. In
  "Filing an issue", replace the roadmap-entry paragraph with the Summary
  requirement. Add a short section documenting what a Summary is. Reword
  "Closing an issue" and "Consistency check" to the new script behavior,
  including the shortened commit message. Change `head -n 15` to
  `head -n 20`.
- **`CLAUDE.md`** — drop "Add a roadmap entry in the same commit" and the
  `close.bash` roadmap mention; change `head -n 15` to `head -n 20`.
- **`CONTRIBUTING.md`** — "open work is in dev-docs/roadmap.md" becomes
  the `bin/issues/list.bash` pointer; the command-table row for
  `check.bash` drops "and roadmap".
- **`dev-docs/index.md`** — remove the `[Roadmap](roadmap.md)` bullet.

Four archived plans in `dev-docs/plans/` carry markdown links to
`roadmap.md` that will dangle. They are left alone: those documents are
dated snapshots of what was true when written, and editing them falsifies
the record. `dev-docs/index.md`'s link is live navigation, so it goes.

## Migration

One commit moves all 17 summaries into their issue files and retitles the
five open issues whose `#` heading is still the raw slug — 16, 19, 27, 28,
and 44 — using the titles their roadmap entries already carry.

Sixteen summaries move verbatim. **#20's must be rewritten**: its summary
describes the roadmap-editing `awk` that this change deletes.

## Consequences for other issues

### #47 is fixed by this change

Deleting `issue-conventions.md`'s "The roadmap" section deletes the exact
passage [#47](../issues/047-issue-conventions-claims-generated-changelog.md)
is about — the claim that shipped history is owned by "`CHANGELOG.md`
(generated by semantic-release)", when no such file exists. That is #47's
option 1, "correct the sentence to name only what exists", taken to its
limit: the sentence disappears with its section.

By the close-in-the-same-PR convention this branch closes #47, adding a
line to its file recording that the passage was removed rather than
reworded. Its option-2 analysis — that a committed changelog would make
semantic-release push to `main` and force branch-protection changes —
survives in the closed file, which is what closed issues are for.

### #20 re-scopes to three items, not four

Issue #49's Notes say four of #20's sweep-up items survive this change.
Only three do.

#20's two numbered defects are both in the entry-removal `awk` that this
change deletes. So is the first sweep-up item: the unescaped
`${basename}` interpolated into a BRE `sed` pattern is the
milestone-checkbox pass, deleted here too.

What survives is about argument handling and staging:

- `close.bash` uses `[[ $# -ne 1 ]] && usage` rather than the
  `if ...; then ...; fi` form the conventions prescribe.
- A non-numeric id produces a raw bash arithmetic error instead of
  `usage()`.
- `close.bash` stages before running `check.bash`, so a failed check
  leaves a half-applied close staged with no recovery hint.

#20 is retitled and rewritten in place to those three. The file keeps its
now-stale `close-bash-roadmap-awk-edge-cases` slug: issue files never
move, so links to it never break.

## Verification

- `bin/issues/check.bash` exits 0 and reports the expected counts.
- `check.bash` fails as designed on an open issue with a missing, empty,
  or whitespace-only `## Summary`, and passes a closed issue without one.
- A real `bin/issues/close.bash` run against a scratch issue fills the
  date, stages one file, and prints the shortened commit message.
- `grep -rn roadmap` over the tree matches only `dev-docs/plans/`,
  `dev-docs/specs/`, and issue files — no live script, doc, or navigation
  link.

`bin/test.bash` is not run: nothing here touches `src/` or the test
harness.

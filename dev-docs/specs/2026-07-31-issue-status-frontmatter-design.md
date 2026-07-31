# Issue status as frontmatter, not location

**Issue:** [#18](../issues/018-close-bash-rewrites-plan-prose.md)
**Date:** 2026-07-31

## Problem

`bin/issues/close.bash` moves a closed issue from `dev-docs/issues/` to
`dev-docs/issues/done/`. Because every link to that issue names its path,
the move forces a link rewrite, and pass 3 does that rewrite with a blind
global `sed`:

```bash
sed -i "s|issues/${basename}|issues/done/${basename}|g" "${f}"
```

It matches the raw string anywhere — prose, code spans, fenced blocks —
so closing an issue silently edits the plan that described how to file
it. Issue #18 records the damage: V4's plan was corrupted this way, V5's
plan inherited the wrong path from it, and the same four lines were
re-corrupted when #17 closed.

The same substitution also matches **too little**: it only knows the
`issues/NNN-slug.md` spelling, never the `../NNN-slug.md` form used by
files already inside `done/`, so each close dangles the links pointing at
it from previously-closed issues. That is fix direction 3 of
[#13](../issues/013-dev-docs-link-checker-not-fence-aware.md), and the
source of the four genuinely broken links that issue inventories.

Both defects are the same root cause: **the file's location encodes the
issue's state.** Location is also what every link depends on, so a state
change forces a link change, and rewriting links across documents whose
prose *discusses* those paths is a problem no regex solves safely. A plan
is written before its own close step runs, so the correctness of a link
it contains depends on *when* it was written — which is why plans are the
documents that keep breaking.

## Solution

Issues never move. `dev-docs/issues/done/` is eliminated; every issue
lives at `dev-docs/issues/NNN-slug.md` for its whole life, and status
becomes a metadata field. No link to an issue ever needs rewriting again,
so `close.bash` loses its link-rewriting apparatus entirely rather than
gaining a more careful version of it.

### Frontmatter

Each issue file opens with YAML frontmatter, replacing today's bolded
`**Type:** / **Target:** / **Date:**` block:

```yaml
---
type: chore
target: this repo
opened: 2026-07-31
closed:
---

# 018 - close.bash rewrites plan prose
```

- `type`, `target` — unchanged in meaning, relocated out of prose.
- `opened` — replaces `**Date:**`.
- `closed` — empty while open, `YYYY-MM-DD` once closed. **This is the
  state.** There is no separate `status` field: it would duplicate what
  the date already says and create a way to be wrong (`status: open`
  beside a `closed` date). The one thing a status enum could carry that a
  date cannot is a non-"fixed" resolution (`wontfix`, `duplicate`,
  `superseded`); none of the 14 closed issues is anything but fixed, and
  adding a `resolution:` key later is a one-line change.
- `closed` is **always present, empty while open**, never omitted. The
  template then guarantees the key exists in every file, so `check.bash`
  can require it — if absence meant "open", a misspelled `cloesd:` would
  read as an open issue forever.

The id and slug stay in the filename and the title stays in the H1; they
are not duplicated into the frontmatter, so nothing can drift out of
sync.

**Contract: frontmatter is flat scalars, one key per line — no nesting,
no lists, no multi-line values.** This lets `check.bash` and any future
`list.bash` read it with `grep`/`awk` and no `yq` dependency, while
remaining real YAML for anything that later wants a proper parser. The
day a field genuinely needs structure is the day to add a parser.

Queries stay trivial:

```bash
grep -l '^closed: [0-9]' dev-docs/issues/*.md   # closed
grep -L '^closed: [0-9]' dev-docs/issues/*.md   # open
```

Reopening also stops being a special case: clear `closed`, restore the
roadmap entry. No link churn in either direction.

### `new.bash`

Unchanged logic, new template. It fills `type`, `target: this repo`, and
`opened: <today>`, and leaves `closed:` empty.

One adjustment: today's template carries its guidance inside the
placeholder values (`**Type:** (conventional commit type: fix, feat,
…)`). In frontmatter that would leave a bogus value in any hand-created
file, so the guidance moves into the HTML comment already present in the
body, and an omitted type argument leaves `type:` empty.

### `close.bash`

1. Resolve the id to the single matching file in `dev-docs/issues/`
   (zero-padded and legacy-unpadded forms, as today); error on no match
   or multiple matches.
2. Refuse if `closed:` already holds a date — the same guard as today's
   "already closed" error, reading the field instead of probing `done/`.
3. Set `closed: <today>` **within the frontmatter block only** — an awk
   pass that stops at the closing `---`, so a `closed:` line occurring in
   the body cannot be hit.
4. Roadmap: check the issue's box in any milestone task list. The link is
   left alone; it was always `issues/NNN-slug.md` and stays that way.
5. Roadmap: remove the Open Issues entry, plus its indented continuation
   lines and any `###` heading left empty. That awk program is unchanged.
6. Stage the two touched files, run `check.bash`, print the commit hint.

No `git mv`. Passes 3 and 4 — the inbound-link rewrite, the moved file's
own depth adjustment, and the ordering commentary guarding those three
chained `sed`s — are deleted.

### `check.bash`

Same invariants, new source of truth:

- Every `dev-docs/issues/[0-9]*.md` opens with frontmatter at line 1,
  closes it, and carries all four keys; `closed` is empty or a
  `YYYY-MM-DD` date. A missing or misspelled key is a hard failure.
- Every open issue has exactly one Open Issues entry in the roadmap;
  every closed issue has none.
- Every roadmap `(issues/…)` link resolves to an existing file.
- Milestone task lists: unchecked items link issues whose `closed` is
  empty, checked items link issues whose `closed` is set — read from the
  file, not inferred from the path.
- `.next-id.txt` is ahead of every id ever assigned (one directory to
  scan now).
- `dev-docs/issues/done/` does not exist, so the old model cannot creep
  back.

The invariant that disappears: "roadmap links agree with the file's
location." There is no location to agree with anymore.

## Migration

One time, reviewed by hand.

1. `git mv dev-docs/issues/done/*.md dev-docs/issues/` (14 files); the
   directory is removed.
2. Convert all 19 issue files and `TEMPLATE.md` to frontmatter. `opened`
   takes the existing `**Date:**` value. `closed` comes from git: the
   commit that *added* each file at its `done/` path is exactly its
   closing commit, so
   `git log --diff-filter=A --format=%as -- dev-docs/issues/done/NNN-*.md`
   yields a real date rather than a guess, spot-checked against the
   `docs(issues): close issue N` commit subjects.
3. Repoint links — **link targets only, prose untouched**:
   - `](issues/done/X)` → `](issues/X)` (roadmap and other `dev-docs/*.md`)
   - `](../issues/done/X)` → `](../issues/X)` (plans, specs, reviews)
   - `](../NNN-slug.md)` → `](NNN-slug.md)` inside formerly-closed issues
     — these are #13's four real breaks, fixed by construction.

   About 25 sites, reviewed hunk by hunk. Some `](issues/done/…)`
   occurrences are **fenced quotations of the roadmap as it stood** and
   must stay exactly as written; #13 inventories which lines those are,
   so the review has a checklist. Likewise, prose that describes the old
   workflow (for example the V5 plan's record of `close.bash` printing a
   `done/` path) is history and is left alone. Doing this once by hand,
   with eyes on the diff, is the point — it is the judgment #18 shows a
   permanent script cannot be trusted with.
4. Update the docs that describe the move: [CLAUDE.md](../../CLAUDE.md)
   ("It moves the file to `done/`"), and
   [issue-conventions.md](../issue-conventions.md) — the opening
   paragraph, the roadmap section's reference to `issues/done/` as an
   owner of the past, the milestone rule about repointing checked links,
   and the `close.bash` description. Add a short subsection documenting
   the frontmatter contract and the flat-scalar rule.
5. Update #13's body: its four broken links are fixed here, and its fix
   direction 3 is moot because there is no pass 3. Its remaining scope is
   the fence-aware link checker.

No `course-material-impact.md` entry: this is repo-internal tooling, and
nothing an instructor's slides or handouts reference.

## Verification

- `bin/issues/check.bash` passes with its new frontmatter invariants.
- `grep -rn 'issues/done' dev-docs CLAUDE.md` returns only fenced
  historical quotations in `dev-docs/plans/` — zero link targets, zero
  live documentation.
- Every relative `.md` link target in `dev-docs/` resolves. (Checked
  ad hoc; the reusable fence-aware checker remains #13's scope.)
- **The dogfood.** Closing #18 with the new `close.bash`, as the branch's
  final commit, must touch exactly two files: the issue's `closed:` line
  and `dev-docs/roadmap.md`. A `git diff --stat` showing `dev-docs/plans/`
  untouched is the direct refutation of the original bug.

No new test harness. The risky logic is being deleted rather than
rewritten, and what remains is small bash whose invariants `check.bash`
enforces on every close.

## Out of scope

- **The fence-aware link checker** (#13 fix direction 1). It is a
  validator with its own design questions — fence lengths, indented
  fences, CI gating, what counts as a link — and #13 stays open for it.
- **A `list.bash`.** The frontmatter is designed so that listing open
  issues is a `grep`, but nothing needs the script today.
- **A `reopen.bash`.** Reopening is now a two-line hand edit; if it
  becomes common, it is easy to add.

# Issue Conventions

Issues are tracked as files in [issues/](issues/), listed by [bin/issues/list.bash](../bin/issues/list.bash). Issues never move: an issue is closed when its `closed` frontmatter field holds a date. There is no external tracker; the repository is the source of truth.

## Filing an issue

Always use [bin/issues/new.bash](../bin/issues/new.bash):

```bash
bin/issues/new.bash <slug> [type]
```

It reads the next ID from `issues/.next-id.txt`, creates the file from `issues/TEMPLATE.md`, and increments the counter. Never assign IDs by hand or by scanning the directory.

In the same commit, write the issue's `## Summary` — the template ships the
heading with an empty body, and `check.bash` fails while it stays empty.

Commit message: `docs(issues): file NNN - <short title>`.

## Frontmatter

Every issue file opens with a YAML frontmatter block:

```yaml
---
type: chore
target: this repo
opened: 2026-07-31
closed:
---
```

`closed` is the issue's status: empty while open, `YYYY-MM-DD` once closed.
It is **always present** — never omit the key — so that a misspelling is a
hard failure in `check.bash` rather than an issue that silently reads as
open forever. There is no separate `status` field; the date is the state.

The block is **flat scalars, one key per line** — no nesting, no lists, no
multi-line values. That is what lets the scripts read it with `grep` and
`awk` and no YAML dependency:

```bash
grep -l '^closed: [0-9]' dev-docs/issues/[0-9]*.md   # closed issues
grep -L '^closed: [0-9]' dev-docs/issues/[0-9]*.md   # open issues
```

The id and slug live in the filename and the title in the `#` heading;
they are deliberately not duplicated into the frontmatter.

## The summary

Every open issue carries a `## Summary` between its `#` title and its
`## Description`: one paragraph saying what is wrong and why it matters,
written for someone triaging the backlog without opening the file.

It is required while the issue is open and not required once it closes —
the section exists to triage open work, and closed work needs no triage.
`bin/issues/check.bash` enforces exactly that.

This is where the roadmap's Open Issues entries went. That section listed
every open issue a second time, in a single shared file, so two branches
that each filed an issue conflicted over an index neither had really
changed. The list now derives from the issue files themselves.

## Listing open issues

[bin/issues/list.bash](../bin/issues/list.bash) prints the path of every
open issue, one per line, in id order — the second `grep` above, with the
guards that make it safe to build on:

```bash
$ bin/issues/list.bash
dev-docs/issues/016-cross-target-integer-divergence.md
dev-docs/issues/019-python-recursion-ceiling.md
...
```

Paths only, so the output composes with anything that takes file
arguments. `head` supplies its own `==> path <==` banner, which is why
the script has no verbose mode of its own:

```bash
bin/issues/list.bash | xargs head -n 50      # frontmatter, title, and summary
bin/issues/list.bash | xargs grep -l readline
```

Paths are relative to the root of the tree the script lives in, which is
also where it runs. To list a worktree's open issues, run that worktree's
copy from that worktree — the answer differs per worktree, since a branch
can open or close issues.

## Upstream defects

Every issue's frontmatter names a `target` — the repository the **defect**
is in. It defaults to this repo; set it to the upstream repository (e.g.
`ourPLCC/plcc-ng`) when the defect is there rather than in this repo's own
`src/`.

An issue in `issues/` tracks work in **this** repository. Whether upstream
has fixed something is a fact about upstream: read it when you pick the
issue up, never record it here. A cached copy of another repo's status is
wrong by default and nothing detects the drift.

So open/closed answers **"is there local work?"**, and that question is
answerable without leaving this repo. An upstream defect is in exactly one
of three states:

- **Found, not yet reported.** The local work is to get the go-ahead and
  file it upstream. The issue is open with `upstream:` empty, and closes
  when the report is filed.
- **Reported, nothing here waits on it.** Close it, with `upstream:`
  naming the ref. The closed file keeps its reproduction detail
  permanently — issues never move, so links to it never break.
- **Reported, and a workaround lives in shipped `src/`.** The issue stays
  open and its subject is *the revert*. It closes when the workaround is
  gone, not when upstream ships.

A defect that straddles both repositories is **split by repository**: the
local half is an ordinary issue with `target: this repo`, and the upstream
half follows the three states above. There is no third "blocked on
upstream" issue.

Upstream-targeted issues still live in this repo's `issues/` like any
other issue — nothing is filed externally automatically. They get reported
upstream manually, with the reporter's explicit go-ahead, since that's a
public action outside this repo.

### The `upstream:` field

```yaml
upstream: ourPLCC/plcc-ng 187-rep-lacks-output-and-clean-exit-records.md
```

Two space-separated tokens — the repository, then the issue's filename in
that repository's `dev-docs/issues/`. Separate multiple refs with commas.
Empty or absent means not reported; the ref *is* the evidence of
reporting, which is why there's no separate `reported:` date.

Deliberately **not** `owner/repo#187`. Upstream numbers issues and pull
requests in one sequence, so that form names a pull request rather than
the issue meant. Deliberately not a URL either: upstream closes an issue
by moving the file into `dev-docs/issues/done/`, so a URL naming the open
path returns 404 exactly when the state changes. Repository-plus-filename
names the issue, not its location.

[bin/issues/check.bash](../bin/issues/check.bash) validates the shape when
the key is non-empty and never requires it.

## Closing an issue

Close in the same PR that completes the work — as the branch's final commit — so the work and its bookkeeping merge atomically. Use [bin/issues/close.bash](../bin/issues/close.bash):

```bash
bin/issues/close.bash <id>
```

It fills in the issue's `closed` date and stages the file. Nothing moves and no links are rewritten.

Commit message: `docs(issues): close issue N (<short title>)`.

**Exception — close on verification.** Some fixes can only be proven by events after the merge (e.g. release-pipeline changes that a real release run must exercise). For those, merge the fix without closing, and close in a follow-up commit once verified. That is a deliberate state, not drift.

## Consistency check

[bin/issues/check.bash](../bin/issues/check.bash) verifies the invariants: the `dev-docs/issues/done` directory does not exist, the frontmatter block is well formed and carries all four keys, the `opened` and `closed` dates parse, every open issue has a non-empty `## Summary`, and `.next-id.txt` is ahead of every ID ever used. `close.bash` runs it automatically; run it directly after filing an issue or during periodic sweeps. It exits non-zero on any drift.

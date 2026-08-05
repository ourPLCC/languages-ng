# CLAUDE.md

## Anything worth remembering goes in a committed file

Assistant memory does not survive this devcontainer. It lives under
`~/.claude/` on the container's `overlay` filesystem, which is discarded
when the container is rebuilt or a new one is created; only
`/workspaces/languages-ng` is a host mount that persists, and
`.devcontainer/devcontainer.json` declares no volume for `~/.claude`.
Nothing written to memory reaches a teammate either, since it is per-user
and per-machine.

So a fact only matters as long as it is committed to this repository.
Recording something in assistant memory alone means losing it at the next
rebuild — and losing it silently, since nothing reports the gap. The same
applies to scratch space inside a git worktree: `.superpowers/` and
`.claude/worktrees/` are gitignored, so notes kept there vanish when the
worktree is removed.

This is why the conventions below are all file-based. When something is
worth carrying forward, put it where it belongs and commit it: an issue in
[dev-docs/issues/](dev-docs/issues/), a design decision in a
`dev-docs/specs/` document, a course-material consequence in
[dev-docs/course-material-impact.md](dev-docs/course-material-impact.md),
or a working convention in this file.

## Creating and closing issues

Issue workflow conventions live in [dev-docs/issue-conventions.md](dev-docs/issue-conventions.md). The short version:

To add a new issue to [dev-docs/issues/](dev-docs/issues/), always use [bin/issues/new.bash](bin/issues/new.bash):

```bash
bin/issues/new.bash <slug> [type]
```

This reads [dev-docs/issues/.next-id.txt](dev-docs/issues/.next-id.txt) for the next ID, creates the file from the template with the date filled in, and increments the ID. Never assign issue numbers by hand or by scanning the directory. Add a roadmap entry in the same commit.

To close an issue, always use [bin/issues/close.bash](bin/issues/close.bash) — as the final commit of the branch that does the work. It fills in the issue's `closed` date and updates [dev-docs/roadmap.md](dev-docs/roadmap.md). Issue files never move, so links to them never break. Verify consistency any time with [bin/issues/check.bash](bin/issues/check.bash).

## Design specs and implementation plans

This project keeps design specs and implementation plans under [dev-docs/](dev-docs/), not the tool-default `docs/superpowers/`:

- Specs (from brainstorming) go in `dev-docs/specs/`, named `YYYY-MM-DD-<topic>-design.md`.
- Plans (from writing-plans) go in `dev-docs/plans/`.

### Shell and config embedded in a plan

Review snippets inside a plan as rigorously as code going into the repo.
They read as prose and get transcribed as-is, so a defect in one survives
into `bin/` unless someone catches it first.

Issue [#25](dev-docs/issues/025-relocate-copies-stale-build-artifacts.md)
is the cautionary case: five defects were found across its eight tasks,
and **every one originated in the plan's own snippets** rather than in the
implementation — a false claim about when `tar` aborts, an
`[[ -e ]] && printf` inside a `while` loop that left the loop at exit
status 1 and broke a newly added `set -o pipefail`, `set -euo pipefail`
placed after the `cd` in a destructive script, `.dockerignore` patterns
written with `.gitignore` semantics, and a commit message that ignored
this repo's own issue conventions. The plan's `Amended`/`Corrected` blocks
record each one.

Two habits catch these: mentally execute a snippet for exit-status
propagation, subshell boundaries, and pattern semantics before dispatching
it; and when a snippet asserts a factual claim about tool behavior
("`tar` aborts", "this pattern matches"), verify it in a scratch directory
rather than asserting it. If someone implementing the plan reports being
blocked because reality contradicts it, assume they are right until shown
otherwise — that happened three times on issue #25 and they were correct
every time.

## Course-material impact log

Some changes made while porting a language don't just change internals —
they change something an instructor's slides, handouts, or lecture notes
would need to match (a renamed field referenced in a semantics
walkthrough, a changed output format, a renamed grammar symbol). Log
these in [dev-docs/course-material-impact.md](dev-docs/course-material-impact.md),
one entry per change, filed under that language's heading, **in the same
commit that makes the change** — not batched up for later, since the
reasoning is freshest right when the change is made. This is distinct
from `CHANGELOG.md`/issue history: it's curated specifically to answer
"what do I need to update in my course materials," not "what happened in
the repo."

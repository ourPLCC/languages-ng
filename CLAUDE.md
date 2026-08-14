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

## Read CONTRIBUTING.md

[CONTRIBUTING.md](CONTRIBUTING.md) is required reading before making
changes. It owns the development workflow — worktree, commit types,
`bin/test.bash`, pull request, merge — and the `main` branch protection
settings, which live in GitHub and have no other copy in this
repository. Direct pushes to `main` are rejected; every change goes in
through a pull request whose `Test Languages` check is green.

## Creating and closing issues

Issue workflow conventions live in [dev-docs/issue-conventions.md](dev-docs/issue-conventions.md). The short version:

To add a new issue to [dev-docs/issues/](dev-docs/issues/), always use [bin/issues/new.bash](bin/issues/new.bash):

```bash
bin/issues/new.bash <slug> [type]
```

This reads [dev-docs/issues/.next-id.txt](dev-docs/issues/.next-id.txt) for the next ID, creates the file from the template with the date filled in, and increments the ID. Never assign issue numbers by hand or by scanning the directory. Write the issue's `## Summary` in the same commit — `check.bash` fails until you do.

To close an issue, always use [bin/issues/close.bash](bin/issues/close.bash) — as the final commit of the branch that does the work. It fills in the issue's `closed` date and stages the file. Issue files never move, so links to them never break. Verify consistency any time with [bin/issues/check.bash](bin/issues/check.bash).

To see what is open, use [bin/issues/list.bash](bin/issues/list.bash). It prints one path per open issue, in id order, and nothing else — pipe it into `xargs head -n 50` for each issue's frontmatter, title, and summary. Run it from the tree whose issues you want, since a worktree's branch may open or close issues the others do not have.

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

### Verifying a subagent's commits

A subagent's reported SHA is not evidence of which branch the commit is
on. When dispatching implementation agents while working in a git
worktree, check that each commit actually landed on the intended branch
before accepting a DONE report — `git branch --contains <sha>`, or
`git log --oneline -1` in the worktree, not the SHA the agent hands back.

On issue [#31](dev-docs/issues/031-suite-exhausts-disk-and-reports-spurious-failure.md)
(2026-08-06), a subagent told "do NOT cd to the parent repo" did exactly
that and committed to `main` in `/workspaces/languages-ng`. Its return
looked completely normal — status DONE, a real SHA, a plausible summary.
The commit was real; it was just on the wrong branch, and the worktree's
HEAD had not moved. Nothing in the report could reveal this, since the SHA
exists and resolves either way. Left undetected it would have merged a
phantom commit into `main` and left the branch's history incomplete.

Put the branch name in the dispatch prompt and require the agent to
confirm `git branch --show-current` before committing, then verify it
yourself afterward. Recovery is cheap when caught early: cherry-pick onto
the correct branch, then `git reset --hard` the parent back to its prior
commit — safe while unpushed, and it stays in the reflog — but confirm
before resetting anyone's checkout.

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

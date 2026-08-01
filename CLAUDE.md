# CLAUDE.md

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

# Contributing to languages-ng

This builds on the [ourPLCC developer guide](https://github.com/ourPLCC/dev/blob/main/CONTRIBUTING.md); read that first. Below is what's specific to this repo, and where it differs.

## Where this repo differs from the org guide

Nowhere at present. One leftover from before the org guide is history, not
a deviation: [dev-docs/plans/](dev-docs/plans/) holds kept plans. Merged
plans are frozen, so they stay; add no new ones.

## Development environment

Open the repository in its devcontainer. It runs a digest-pinned image
carrying Java, Python, Node, and `plcc-ng`; `postCreateCommand` adds
bats. Do not install toolchain pieces by hand — see the warning in
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) and
CR-511.

Before the container is created, it clones the
[ourPLCC/dev](https://github.com/ourPLCC/dev) repo beside this one, as
`../dev`, unless that folder already exists. The container mounts it at
`/workspaces/dev`, points the `backlog` CLI at it through `BACKLOG_CWD`,
and installs the pinned `backlog` version. In the tracker, this repo's
`project` value is `languages-ng`. Old languages-ng issue numbers still
resolve at +500: `#12` is `CR-512`.

[AGENTS.md](AGENTS.md) imports files from `../dev`. Claude Code loads
imports from outside the repo only once they are approved, and until then
skips them without an error, so agents never load the org guide. It does
not reliably ask for that approval, and the approval lives in
`~/.claude.json`, which a rebuild discards. So the container approves them
when it is created, by running
[bin/install/claude-imports.bash](bin/install/claude-imports.bash). To
check, run `/memory` in a session and confirm it lists `ORG-AGENTS.md` and
both `CONTRIBUTING.md` files. If they are missing, quit every Claude Code
session, since a running one can overwrite `~/.claude.json`, then run the
script and start a new session.

Keep each import in `AGENTS.md` on its own line with nothing after the
path: Claude Code reads an import up to the next whitespace, so
`@file.md,` looks for a file named `file.md,` and silently skips it.

## The workflow

1. **Create a worktree** for the change, so `main` and other work stay
   untouched.
2. **Implement**, committing as you go. Commit messages follow
   [Conventional Commits](https://www.conventionalcommits.org/); the type
   matters, because `.releaserc.yaml` cuts a release on `fix` and `feat`.
   A change to tests, scripts, or CI is `test` or `chore`, not `fix`.
3. **Run the suite**: `bin/test.bash`. CI runs this same suite in the
   same image, so a local pass predicts a CI pass.
4. **Push the branch and open a pull request.** Direct pushes to `main`
   are rejected.
5. **Merge once CI is green.**

## Commands

| Command | What it does |
|---|---|
| [bin/test.bash](bin/test.bash) | Run the whole bats suite over `src/` and `bin/`. Exit 0 means every test passed, 1 means real failures, 2 means the harness itself did not finish. |
| [bin/clean.bash](bin/clean.bash) | Remove build output left under `src/`. |
| [bin/install/bats.bash](bin/install/bats.bash) | Install the pinned bats under `~/.local`. Idempotent; run by `postCreateCommand` and by CI. |
| [bin/install/claude-imports.bash](bin/install/claude-imports.bash) | Approve [AGENTS.md](AGENTS.md)'s imports from `../dev` in `~/.claude.json`. Run by the devcontainer on creation. Idempotent. |

## Course-material impact log

Some changes made while porting a language don't just change internals —
they change something an instructor's slides, handouts, or lecture notes
would need to match (a renamed field referenced in a semantics
walkthrough, a changed output format, a renamed grammar symbol). Log
these in [dev-docs/course-material-impact.md](dev-docs/course-material-impact.md),
one entry per change, filed under that language's heading, **in the same
commit that makes the change** — not batched up for later, since the
reasoning is freshest right when the change is made. This is distinct
from the CR history: it's curated specifically to answer "what do I need
to update in my course materials," not "what happened in the repo."

## Continuous integration

[.github/workflows/test-languages.yaml](.github/workflows/test-languages.yaml)
runs `bin/test.bash` inside the same image
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) pins,
via the `container:` job key. That is what makes a local pass meaningful.
`bin/tests/image-pin.bats` fails if the two files ever name different
images.

It triggers on every pull request, and on pushes to `main` as a
backstop — `release.yaml` runs on push, so an unverified commit reaching
`main` would cut a release from untested code.

## Branch protection on `main`

These settings live in GitHub, not in this repository, so this table is
their only durable copy. If the ruleset is changed or deleted, this is
what it should be restored to. Applied by hand, as a ruleset targeting
the **`main` branch** (not tags — `.releaserc.yaml` has no
`@semantic-release/git` plugin, so semantic-release only creates tags and
releases, and a ruleset covering tags would break it).

| Setting | Value | Why |
|---|---|---|
| Require a pull request before merging | on | Makes the PR the only route into `main`. |
| Required approvals | 0 | A solo maintainer cannot approve their own PR; requiring one would deadlock every merge. |
| Require status checks to pass | on, `Test Languages` | The gate. The name must match the workflow job's `name:` exactly. |
| Require branches to be up to date before merging | on | Catches two individually green PRs that break when combined. |
| Block force pushes | on | `main` history stays append-only. |
| Restrict deletions | on | |
| Bypass list | empty | Otherwise the rules are advisory for the only person they apply to. |

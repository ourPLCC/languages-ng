# Contributing

This document is the practical guide for working in this repository: how
a change gets from a worktree to `main`, and the commands you run along
the way. Read it before making changes.

Conventions that have their own documents are linked, not duplicated:
the issue workflow is in
[dev-docs/issue-conventions.md](dev-docs/issue-conventions.md), open work
is listed by [bin/issues/list.bash](bin/issues/list.bash), and changes an
instructor's materials must track are logged in
[dev-docs/course-material-impact.md](dev-docs/course-material-impact.md).

## Development environment

Open the repository in its devcontainer. It runs a digest-pinned image
carrying Java, Python, Node, and `plcc-ng`; `postCreateCommand` adds
bats. Do not install toolchain pieces by hand — see the warning in
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) and
[issue #11](dev-docs/issues/011-devcontainer-image-stale-plcc-ng-version.md).

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
| [bin/issues/new.bash](bin/issues/new.bash) | Create an issue. Never assign issue numbers by hand. |
| [bin/issues/close.bash](bin/issues/close.bash) | Close an issue, as the final commit of the branch that does the work. |
| [bin/issues/check.bash](bin/issues/check.bash) | Verify issue-file consistency. |
| [bin/issues/list.bash](bin/issues/list.bash) | Print the path of every open issue, one per line. Pipe it: `\| xargs head -n 50`. |

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

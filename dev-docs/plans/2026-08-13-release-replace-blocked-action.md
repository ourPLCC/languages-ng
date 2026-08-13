# Plan — Replace the TOS-blocked release action

Issue: [#045](../issues/045-release-workflow-uses-blocked-action.md) — that
issue is the spec this plan argues from. Read it for the diagnosis; this
plan covers only the change.

## Context

`.github/workflows/release.yaml` references
`codfish/semantic-release-action@v3`. GitHub suspended that repository on
2026-06-25 (`{"message":"Repository access blocked","block":{"reason":"tos"}}`),
so the runner fails during *Prepare all required actions* and no step runs.

The fix invokes semantic-release directly through `npx`, deleting the
third-party-action dependency rather than substituting another one.
`.releaserc.yaml` already holds the full configuration and does not change.

## Global Constraints

- **`.releaserc.yaml` is not modified.** Its two plugins
  (`@semantic-release/commit-analyzer` with the `conventionalcommits`
  preset, `@semantic-release/github`) already express everything the
  action's `branches` and `additional-packages` inputs restated.
- **Commit type is `chore`.** Per
  [CONTRIBUTING.md](../../CONTRIBUTING.md), a CI change is `chore`, never
  `fix`/`feat` — those bump the released version.
- **Do not close issue #045.** It is a "close on verification" case per
  [issue-conventions.md](../issue-conventions.md#closing-an-issue): only a
  real `Release` run on `main` after merge can prove the fix. It closes in
  a follow-up commit.
- **Only `.github/workflows/release.yaml` changes.** No other file.

## Verified facts

Checked before writing this plan, not assumed:

- `npx --yes -p A -p B <cmd>` installs both packages and runs `<cmd>` —
  confirmed locally with `npx --yes -p cowsay -p left-pad cowsay`.
- `semantic-release@25.0.9` declares `engines.node = "^22.14.0 || >= 24.10.0"`.
  The `ubuntu-latest` image's ambient Node version is not guaranteed to
  satisfy that, which is why the task adds `actions/setup-node`. The
  devcontainer runs Node v24.19.0, so pinning `24` keeps local and CI on
  the same major.
- `codfish` appears in exactly one tracked file, `release.yaml`. No
  documentation references it, so no doc updates ride along.

## Task 1 — Rewrite `release.yaml`

Replace the entire contents of `.github/workflows/release.yaml` with:

```yaml
---
# yamllint disable line-length
name: Release

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    name: Release
    runs-on: ubuntu-latest
    steps:
      -
        name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      -
        name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: '24'
      -
        name: Tag
        run: >
          npx --yes
          -p semantic-release@25
          -p conventional-changelog-conventionalcommits
          semantic-release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Why each part

- **`workflow_dispatch:`** — a failed release could previously only be
  retried by pushing another commit to `main`. Re-running semantic-release
  with no new commits is a no-op, so a manual trigger is safe.
- **`permissions:`** — the workflow previously declared none and inherited
  the repository's default `GITHUB_TOKEN` scope. `contents: write` creates
  the tag and Release. `issues: write` and `pull-requests: write` are
  needed because `@semantic-release/github` comments on the issues and PRs
  a release resolves; without them those calls fail. Declaring the set
  explicitly preserves today's behaviour instead of resting on an org
  default that can change.
- **`actions/setup-node@v4`, `node-version: '24'`** — pins the Node major
  against `semantic-release@25`'s engines range rather than trusting the
  runner image.
- **`-p semantic-release@25`** — a floating version would let a future
  major land unreviewed in the release path.
- **`-p conventional-changelog-conventionalcommits`** — required by the
  `conventionalcommits` preset that `.releaserc.yaml` names. This is what
  the action's `additional-packages` input supplied.
- **`fetch-depth: 0` is retained** — semantic-release reads full history
  and tags to compute the next version.
- **`id: semantic` is dropped** — nothing consumed the action's outputs.

### Verification

`.github/workflows/` has no automated coverage, so verify by inspection:

1. `grep -rn codfish .github/` returns nothing.
2. `grep -c 'uses:' .github/workflows/release.yaml` is 2, and both are
   `actions/`-owned.
3. `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yaml'))"`
   parses without error.
4. `bin/test.bash` still exits 0. The suite does not cover
   `.github/workflows/`, so this is a no-regression check, not proof of
   the fix.

The change itself can only be proven by a real `Release` run on `main`
after merge — hence the "close on verification" constraint above.

## Out of scope

- A regression test asserting workflows reference no third-party actions.
  Defensible, but neither the issue nor the approved approach called for
  it, and it would be this repository's first test over `.github/`.
- Migrating to `python-semantic-release` for consistency with
  `ourPLCC/plcc-ng` — rejected in issue #045's Notes.

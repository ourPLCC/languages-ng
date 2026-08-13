---
type: chore
target: this repo
opened: 2026-08-13
closed:
---

# 045 - Release workflow depends on a TOS-blocked action

## Description

Every push to `main` fails the `Release` workflow before a single step
runs. The job dies during *Prepare all required actions* with:

```
Error: Repository access blocked
```

[.github/workflows/release.yaml](../../.github/workflows/release.yaml)
references `codfish/semantic-release-action@v3`. GitHub has suspended
that repository:

```json
{
  "message": "Repository access blocked",
  "block": { "reason": "tos", "created_at": "2026-06-25T15:04:22Z" }
}
```

The runner cannot download the action, so the job never reaches
`Checkout`. `actions/checkout@v4` on the same workflow resolves normally
(HTTP 200), so the blocked action is the sole cause.

A `tos` block is a GitHub-side suspension of that account. There is no
setting on our side that unblocks it, and it may never be lifted.

Nothing in this repository changed to cause it. `release.yaml` has not
been touched since 2024-02-20 (`15cbd91`). Releases have simply been
failing silently since 2026-06-25.

## Steps to Reproduce

1. Push any commit to `main`.
2. Open the `Release` workflow run.
3. The job fails in *Prepare all required actions* with
   `Error: Repository access blocked`; no step output follows.

Or, without a push:

```bash
curl -s https://api.github.com/repos/codfish/semantic-release-action
```

## Notes

### The fix

Drop the third-party action and invoke semantic-release directly:

```yaml
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

This removes the entire failure class rather than swapping in another
third-party repository that can be blocked the same way.
[.releaserc.yaml](../../.releaserc.yaml) already holds the whole
configuration — the action's `branches` and `additional-packages` inputs
merely restated it — so no config change is needed. The version pin moves
from the action's semantic-release v22 era to v25; our config uses only
`commit-analyzer` and `@semantic-release/github`, both stable across that
range.

Two adjacent gaps to close in the same change:

- **`permissions:`** is absent from `release.yaml`, so the job depends on
  the repository's default `GITHUB_TOKEN` scope.
  `@semantic-release/github` needs `contents: write`; declare it
  explicitly.
- **No `workflow_dispatch`.** A failed release can currently only be
  retried by pushing another commit to `main`.

### Why not the alternatives

**`docker://ghcr.io/codfish/semantic-release-action`** works today — the
container images survived the block, because a `docker://` reference
pulls from GHCR and never touches the repository-download path that is
returning 403. Verified: the `v3` manifest returns HTTP 200 at digest
`sha256:4c0955361cf42e5ab9bb05df3a1e2a781c443f9760b63a68957689445051a2fb`.
This repo's sibling `ourPLCC/plcc-ng` used exactly that form, digest-pinned,
from 2023-02-08 (`324c210c`) until 2025-02-06 (`e487714d`).

It is a one-line change and a legitimate emergency lever, but it leaves us
depending on artifacts owned by a suspended account, which GitHub may purge
at any time — with less warning than this outage gave.

**`python-semantic-release`**, which `ourPLCC/plcc-ng` adopted on
2026-05-02, is a poor fit here. It configures via `pyproject.toml`, and
this repository has no Python packaging; adopting it would mean adding a
`pyproject.toml` solely to hold release configuration, and rewriting a
`.releaserc.yaml` that already works. plcc-ng's release pipeline also
exists mostly to publish a wheel to PyPI — work this repository has no
equivalent of. It avoided this outage by coincidence of timing, not by
a design choice we should copy.

### Closing this issue

This is a "close on verification" case (see
[issue-conventions.md](../issue-conventions.md)): the fix can only be
proven by a real release run on `main` after the merge. Merge without
closing, then close in a follow-up commit once a `Release` run is green.

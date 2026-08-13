---
type: chore
target: this repo
opened: 2026-08-13
closed: 2026-08-13
---

# 048 - Release fails in `success`: `#NNN` in commits means a file, not a GitHub issue

## Description

The 2026-08-13 `Release` run published `v1.0.0` and then failed:

```
✔  Created tag v1.0.0
ℹ  Published GitHub release: .../releases/tag/v1.0.0
✔  Completed step "publish" of plugin "@semantic-release/github"
✘  Failed step "success" of plugin "@semantic-release/github"
✘  Error: Could not resolve to an issue or pull request with the number of 170.
   type: 'NOT_FOUND', path: [ 'repository', 'issue170' ]
```

with the same error for #26, #24, #19, #18, #17, #14, #13, and #12.

The release itself is fine. The tag and the GitHub Release both exist;
only the post-publish `success` step failed, and the workflow reports red
because of it.

`@semantic-release/github`'s `success` step scans the released commits
for issue references and comments on each one in this repository. But
this repository's issues are **files** in [issues/](.), and commit
messages refer to them by the same `#NNN` syntax GitHub uses for its own
issues:

```
Closes #26.
Closes #13 without building the fence-aware link checker.
Fixes #18.
```

Those mean `dev-docs/issues/026-*.md`, `013-*.md`, `018-*.md`. GitHub
reads them as GitHub issue numbers. This repository's GitHub numbering
currently tops out at PR #11, so everything from #12 up resolves to
nothing.

Some references are not even about this repository. `#170` comes from a
commit body reading "distinguished from upstream's already-fixed #170" —
an issue number in `ourPLCC/plcc-ng`. Another commit closes an issue by
full URL in a third repository entirely
(`https://github.com/ourPLCC/course/issues/6`).

So the collision is structural: our issue-numbering convention and
GitHub's occupy the same syntax, in a repository where the two numbering
spaces are unrelated.

### Why it surfaced on this run

The remote had no tags. `git ls-remote --tags origin` returned nothing
before this run — the `v1.0.0`/`v1.0.1`/`v1.0.2` tags that existed in old
local clones were residue from the original `languages` repository and
were never on this remote.

With no previous release to bound the range, semantic-release analyzed all
367 commits and treated the entire history as one release, harvesting every
`#NNN` ever written in a commit body. A normal incremental release would
only scan commits since the last tag and would hit this far less often —
but it would still hit it, because the convention guarantees a collision
whenever a released commit closes a file-tracked issue numbered above
GitHub's highest.

## Steps to Reproduce

1. Merge to `main` any commit whose message contains `Closes #NNN` where
   `NNN` exceeds the repository's highest GitHub issue or PR number.
2. The `Release` workflow publishes the release, then fails in `success`
   with `NOT_FOUND` for that number.

## Notes

### The fix

Turn off every issue and pull-request write in
[.releaserc.yaml](../../.releaserc.yaml):

```yaml
    - - "@semantic-release/github"
      - successCommentCondition: false
        failCommentCondition: false
```

`successCommentCondition: false` takes an early branch in the plugin's
`success.js` that logs "Skip commenting on issues and pull requests" and
never enters the block containing the GraphQL lookups — so the queries
that raise `NOT_FOUND` are not issued at all, rather than issued and
tolerated.

`failCommentCondition: false` suppresses the companion behaviour: on a
failed release the plugin opens a GitHub issue titled "The automated
release is failing", and closes it on the next success. That issue tracker
is not the one this project uses.

Use the `*Condition` options, not `successComment: false` /
`failComment: false` / `failTitle: false`. Those also work, but the plugin
logs `DEPRECATION: 'false' for 'successComment' is deprecated and will be
removed in a future major version` and they will stop working in a future
major — the exact silent-breakage pattern
[#45](045-release-workflow-uses-blocked-action.md) was opened to eliminate.

`releasedLabels: false` is **not** needed: labels are only applied inside
the block that `successCommentCondition: false` already skips. `addReleases`
already defaults to `false`.

Verified against `@semantic-release/github@12.0.9`, the version
`semantic-release@25` bundles.

### Consequence

No comments on issues or PRs, and no `released` labels. Nothing is lost
that this project was using: the file-based tracker is the source of
truth, and [issue-conventions.md](../issue-conventions.md) already says
closed issue files are what record shipped work.

With those writes gone, [release.yaml](../../.github/workflows/release.yaml)
no longer needs `issues: write` or `pull-requests: write` — `contents:
write` alone covers the tag and the Release.

### Alternative considered

Changing the commit convention to avoid bare `#NNN` — writing `issue 026`
or `dev-docs/issues/026` — was rejected. It cannot fix the 367 commits
already written, it asks every contributor to remember a rule that only
matters to a plugin, and `git log` would no longer read naturally.
Configuring the plugin fixes it once, at the boundary where the two
numbering spaces actually meet.

### Verified

Closed on verification (see
[issue-conventions.md](../issue-conventions.md)), since only a real
release run could prove it.

The `Release` run for `f8640dd` — the merge of PR #12, which carried the
fix — completed with conclusion `success`
([run 31724349715](https://github.com/ourPLCC/languages-ng/actions/runs/31724349715)).
No `NOT_FOUND` errors, and the workflow finished green for the first time
in its recent history:

```
17:10 UTC  f8640dd  success   <- the fix
14:42 UTC  9e4dc6a  failure   <- this issue's defect
01:04 UTC  75482e8  failure   <- #45's defect
```

That run cut no new version, correctly: PR #12 carried only `chore` and
`docs` commits, which do not bump under conventionalcommits. So the run
exercised the `success` step without a release to comment about.

That is weaker evidence than a release run would be, and worth being
precise about. What it proves is that nothing in the changed
configuration breaks the workflow. What closes this issue is the
mechanism rather than the observation:
`successCommentCondition: false` takes a branch in the plugin's
`success.js` that logs "Skip commenting on issues and pull requests" and
returns before any GraphQL query is built, so there is no path left on
which the `NOT_FOUND` errors can be raised — with or without commits in
the release.

[#46](046-release-notes-generator-not-loaded.md) stays open: it needs a
`feat` or `fix` to reach `main` and actually cut a version before its
release body can be inspected.

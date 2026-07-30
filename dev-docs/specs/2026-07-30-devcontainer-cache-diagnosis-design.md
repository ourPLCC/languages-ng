# Devcontainer stale-toolchain diagnosis (issue #11)

**Date:** 2026-07-30
**Issue:** [#11](../issues/011-devcontainer-image-stale-plcc-ng-version.md)
**Type:** chore

## Problem

Issue #11 claims the published image
`ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:a50898f…` is built from
plcc-ng 2.0.0 despite its 2.0.1 tag, and blames the upstream
build/publish pipeline (`Target: ourPLCC/devcontainers`). Commit
`1831a79` acted on that claim, appending a `pipx upgrade plcc-ng` to
`postCreateCommand` so every container create force-upgrades from PyPI.

That diagnosis is wrong. The image does ship 2.0.1. The container that
reported 2.0.0 was a locally cached derived image built on the earlier
2.0.0 base, produced by a rebuild that reused Docker's cache across a
base-digest bump. A subsequent rebuild without cache produced a container
reporting the correct version.

## Evidence

Collected inside the current container, which was rebuilt without cache
on 2026-07-30 at 00:24 UTC:

| Path | mtime | Origin |
| --- | --- | --- |
| `site-packages/plcc_ng-2.0.1.dist-info/` (`METADATA` → `Version: 2.0.1`) | `2026-07-29 20:05:50.000000000` | image layer |
| `site-packages/plcc/` tree (`predictive_parser.py`, `ll1/spec_json_decoder.py`) | `2026-07-29 20:05:50.000000000` | image layer |
| `/usr/local/bin/bats` | `2026-07-30 00:24:17` | `postCreateCommand` |
| `pipx_metadata.json` | `2026-07-30 00:24:28` | `postCreateCommand` |

Two facts follow. First, the 2.0.1 distribution carries an image-layer
timestamp — whole-second precision, characteristic of layer extraction —
so it came from the image, not from the upgrade. Second, the `pipx
upgrade` ran 11 seconds after the bats install and touched only
`pipx_metadata.json`, leaving every installed file untouched: it found
plcc-ng already at the latest version and did nothing. The fixed
`_handle_arbno` / `_parse_arbno` code from issue #10 is present in the
image-dated files.

The workaround has therefore never had any effect, and the arbno fix that
motivated it was already in the image.

## Why the workaround must go

Beyond being inert, `pipx upgrade plcc-ng` installs whatever version is
newest on PyPI. That silently defeats the digest pin: when plcc-ng 2.1.0
ships, every container create drifts off the pinned 2.0.1, reintroducing
exactly the non-reproducibility the pin exists to prevent. It also adds a
network dependency and latency to every create.

[dev-docs/issue-conventions.md](../issue-conventions.md) makes removal a
precondition of closing, not an optional tidy-up: an issue whose
workaround lives in the tree "stays open for as long as that workaround
lives in the code… removing the workaround is [the fix]."

## Mechanism worth documenting

The image has been pinned by digest since `bcd8b6e`, so a stale *base
tag* does not explain the reuse — a digest pin resolves unambiguously.
What got reused is the **derived** image the Dev Containers extension
builds by layering the configured features (`claude-code`, `shellcheck`)
and `postCreateCommand` onto the base. Its cache key did not pick up the
base digest change, so a plain rebuild after `b5e6308` → `bcd8b6e`
(2.0.0 → 2.0.1) kept the old toolchain.

The actionable rule: **after bumping the image digest, rebuild without
cache.** That is the one thing a future maintainer needs, and it belongs
where the digest is edited.

## Changes

### 1. `.devcontainer/devcontainer.json`

Revert `postCreateCommand` to its exact pre-`1831a79` value (bats install
only), and add a jsonc comment above the `image` line:

```jsonc
{
  "name": "languages-ng",
  // Pinned by digest for reproducibility. When you bump this, rebuild
  // WITHOUT cache ("Dev Containers: Rebuild Container Without Cache") —
  // the derived feature image is cached independently of the base
  // digest, so a plain rebuild silently reuses the old toolchain.
  // Do not "fix" a stale container with `pipx upgrade plcc-ng`; that
  // defeats this pin. See
  // dev-docs/issues/done/011-devcontainer-image-stale-plcc-ng-version.md
  "image": "ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:a50898f…",
```

`devcontainer.json` is jsonc, so comments are valid. The `image` value
itself is untouched — the digest is abbreviated above for readability
only. No other key changes; `devcontainer-lock.json` is unaffected.

### 2. Issue #11 file

Rewrite the Description to state the real diagnosis and carry the
evidence table, and correct `Target:` from `ourPLCC/devcontainers` to
this repo. Record that nothing is to be reported upstream. This file,
once in `done/`, is the durable record the jsonc comment points at.

### 3. Close

`bin/issues/close.bash 11` as the branch's final commit — moves the file
to `issues/done/`, removes the Open Issues entry, and rewrites links.

### Not changed

[dev-docs/issues/done/010-*.md](../issues/done/010-plcc-ng-arbno-drops-mid-body-terminal.md)
is accurate as written: the fix did land in plcc-ng 2.0.1, no local
workaround was committed for it, and it closed once the devcontainer ran
2.0.1. No `src/` change, so no
[course-material-impact](../course-material-impact.md) entry. `1831a79`'s
commit message is immutable; the revert's message carries the correction.

## Commits

1. `chore(devcontainer): drop pipx upgrade workaround, document cache gotcha`
2. `docs(issues): correct issue 11 diagnosis - local cache, not upstream image`
3. `docs(issues): close issue 11 (devcontainer image stale plcc-ng version), update roadmap`

## Verification

- `bin/issues/check.bash` exits zero.
- `.devcontainer/devcontainer.json` parses as JSON once `//` comments are
  stripped, and `postCreateCommand` matches its pre-workaround value byte
  for byte (`git show '1831a79^:.devcontainer/devcontainer.json'`).
- `bin/test.bash` matches the branch baseline: 34 tests, 31 pass, 3 fail
  (V4 `proc`, V5 `letrec`, V6 `define` — all `plccmk: command not found`,
  pre-existing and tracked by [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md)).
  This suite already exercises the image's plcc-ng 2.0.1 across V0–V3.

### Accepted limitation

A rebuild-without-cache on the reverted config cannot be run from this
session: this worktree lives under `.claude/worktrees/`, so a rebuild uses
the root `.devcontainer`, not the branch's. Per the maintainer's decision,
#11 closes in this branch anyway — the evidence above already establishes
that the removed command was inert, so a rebuild could only confirm a
known result. The "close on verification" exception in
[issue-conventions.md](../issue-conventions.md) was considered and
declined for this reason.

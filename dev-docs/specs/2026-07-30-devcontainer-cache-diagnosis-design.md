# Devcontainer stale-toolchain diagnosis (issue #11)

**Date:** 2026-07-30
**Issue:** [#11](../issues/done/011-devcontainer-image-stale-plcc-ng-version.md)
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

That is the entire case for removal, and it stands on its own.
[dev-docs/issue-conventions.md](../issue-conventions.md) does have a rule
making workaround-removal a precondition of closing, but it does not
apply here: it is scoped to "when an **upstream defect** forces a local
workaround in shipped **`src/`**," and this branch's own conclusion is
that there is no upstream defect, while the workaround lived in
`.devcontainer/` rather than `src/`. Removing it is in that rule's spirit,
not under its letter.

## Mechanism worth documenting

The image has been pinned by digest since `bcd8b6e`, so a stale *base
tag* does not explain the reading — a digest pin resolves unambiguously.
The likeliest remaining candidate is reuse of the **derived** image the
Dev Containers extension builds by layering the configured features
(`claude-code`, `shellcheck`) and `postCreateCommand` onto the base: a
plain rebuild after `b5e6308` → `bcd8b6e` (2.0.0 → 2.0.1) would then have
kept the old toolchain.

That is inference, not measurement, and it should not be recorded as
though it were the latter. The evidence above proves a *negative* — the
image is correct, the workaround was inert — and is silent on which local
mechanism was at work. No Docker-side evidence was gathered or could be:
there is no `docker` CLI and no `/var/run/docker.sock` in this container.
The specific mechanism is questionable even on its face: the Dev
Containers CLI generates a Dockerfile whose base is a build arg
(`ARG _DEV_CONTAINERS_BASE_IMAGE` / `FROM $_DEV_CONTAINERS_BASE_IMAGE`),
and BuildKit resolves that before `FROM`, so a changed digest normally
*does* invalidate the chain. Simpler explanations fit the same evidence:
a Reopen-in-Container or restart that never rebuilt, an existing container
reattached, or a rebuild that predated the digest bump landing in the
working tree.

A branch whose purpose is correcting a confidently-stated wrong cause
should not deposit a second confidently-stated cause of comparable
standing. What is permanently defensible is narrower and sufficient: the
staleness was local, because the pinned digest is content-addressed and
the published image demonstrably ships 2.0.1.

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
  // WITHOUT cache ("Dev Containers: Rebuild Container Without Cache") --
  // the derived feature image can be reused across a base-digest change
  // (exact cache-key behavior unconfirmed), so a plain rebuild may
  // silently keep the old toolchain.
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
- `bin/test.bash` matches the branch baseline: 34 tests, 24 pass, 10 fail
  — V4, V5, V6, NAME, NEED, OBJ, REF, SET, TYPE0 and TYPE1, every one of
  them `plccmk: command not found`. Those are exactly the ten suites that
  still drive old PLCC (`grep -rl plccmk src/` returns precisely that
  set), and the plcc-ng image does not ship `plccmk`. They are
  pre-existing and unrelated to this work. They are also the *inverse* of
  the gap tracked by [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md),
  which is about CI lacking plcc-ng so migrated languages fail *there*;
  here it is the local container lacking old PLCC. This suite already
  exercises the image's plcc-ng 2.0.1 across V0–V3.

### Accepted limitation

A rebuild-without-cache on the reverted config cannot be run from this
session: this worktree lives under `.claude/worktrees/`, so a rebuild uses
the root `.devcontainer`, not the branch's. Per the maintainer's decision,
#11 closes in this branch anyway — the evidence above already establishes
that the removed command was inert, so a rebuild could only confirm a
known result. The "close on verification" exception in
[issue-conventions.md](../issue-conventions.md) was considered and
declined for this reason.

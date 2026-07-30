# 011 - devcontainer-image-stale-plcc-ng-version

**Type:** chore
**Target:** this repo
**Date:** 2026-07-29

<!--
Classify by user-facing impact, not by whether something was "broken".
`fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.
-->

## Description

**Filed on a false premise; see the resolution in Notes.** As originally
reported: the devcontainer image pinned in `.devcontainer/devcontainer.json`
as
`ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:a50898fdf863e9792d8a62d79d0f5f664a1e89634397f1498a7ccc0c29fc2d24`
appeared not to contain plcc-ng 2.0.1. A container built from that pin
reported `plcc-ng 2.0.0` from `plcc-version`, and its
`plcc/ll1/spec_json_decoder.py` and `plcc/parser/predictive_parser.py`
held the pre-2.0.1 arbno code — so anyone rebuilding still hit the arbno
mid-body-terminal bug of issue
[#10](done/010-plcc-ng-arbno-drops-mid-body-terminal.md). This was blamed
on the upstream image build/publish pipeline being out of sync with its
own version tag.

**The actual cause was local Docker cache reuse.** The container that
reported 2.0.0 was a cached *derived* image — the one the Dev Containers
extension builds by layering the configured features and
`postCreateCommand` onto the base — carried over from before the base pin
moved from `2.0.0@sha256:8e0123b…` to `2.0.1@sha256:a50898f…` (commits
`b5e6308` → `bcd8b6e`). That derived image's cache key did not account for
the base digest change, so a plain rebuild silently kept the old
toolchain. A rebuild *without* cache produced a container reporting the
correct 2.0.1. The published image was correct all along.

## Steps to Reproduce

The original steps no longer reproduce, which is the point: rebuilding
from the pin now yields plcc-ng 2.0.1. The stale reading required a plain
(cache-reusing) rebuild carried across the `b5e6308` → `bcd8b6e` digest
bump, starting from a container built on the 2.0.0 base.

Evidence gathered inside a container rebuilt without cache on 2026-07-30
at 00:24 UTC:

| Path | mtime | Origin |
| --- | --- | --- |
| `site-packages/plcc_ng-2.0.1.dist-info/` (`METADATA` → `Version: 2.0.1`) | `2026-07-29 20:05:50.000000000` | image layer |
| `site-packages/plcc/` tree | `2026-07-29 20:05:50.000000000` | image layer |
| `/usr/local/bin/bats` | `2026-07-30 00:24:17` | `postCreateCommand` |
| `pipx_metadata.json` | `2026-07-30 00:24:28` | `postCreateCommand` |

The 2.0.1 distribution carries an image-layer mtime — whole-second
precision, characteristic of layer extraction — so it came from the image,
not from any upgrade at create time. The `pipx upgrade plcc-ng` added by
commit `1831a79` ran 11 seconds after the bats install and modified only
`pipx_metadata.json`, leaving every installed file untouched: it found
plcc-ng already current and did nothing. The fixed `_handle_arbno` /
`_parse_arbno` code from issue #10 is present in the image-dated files.

## Notes

**Resolved as invalid, with the workaround reverted.** Nothing is to be
reported to `ourPLCC/devcontainers` — there is no upstream defect, and the
`Target` field (originally a guess inferred from the image path, as the
first version of this file acknowledged) is corrected to this repo.

Commit `1831a79` had appended `pipx upgrade plcc-ng` to
`postCreateCommand` as a workaround. It is reverted, because it was both
inert and harmful: `pipx upgrade` installs whatever is newest on PyPI, so
once plcc-ng 2.1.0 ships it would pull every container create off the
pinned digest, defeating the reproducibility the pin exists to provide.
Per [dev-docs/issue-conventions.md](../issue-conventions.md), removing the
workaround — not merely diagnosing it — is what allows this issue to
close. The durable lesson lives as a comment at the pin in
`.devcontainer/devcontainer.json`: after bumping the digest, rebuild
without cache.

Issue #10 needs no correction. It accurately records that the arbno bug
was fixed upstream in plcc-ng 2.0.1, that no local workaround was
committed for it, and that it closed once the devcontainer ran 2.0.1 —
all true. `1831a79`'s commit message repeats the false premise and is left
as-is; git history is immutable, and the revert's message carries the
correction.

Design spec:
[dev-docs/specs/2026-07-30-devcontainer-cache-diagnosis-design.md](../specs/2026-07-30-devcontainer-cache-diagnosis-design.md).

---
type: chore
target: this repo
opened: 2026-07-29
closed: 2026-07-30
---

# 011 - devcontainer-image-stale-plcc-ng-version

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
[#10](010-plcc-ng-arbno-drops-mid-body-terminal.md). This was blamed
on the upstream image build/publish pipeline being out of sync with its
own version tag.

**The staleness was local, not upstream.** The published image was correct
all along: the pin is content-addressed, and a container built from it
demonstrably ships plcc-ng 2.0.1 (evidence below). Whatever produced the
2.0.0 reading therefore happened on this machine, and a rebuild *without*
cache produced a container reporting the correct 2.0.1.

Which local mechanism it was remains an inference. The leading candidate
is reuse of a cached *derived* image — the one the Dev Containers
extension builds by layering the configured features and
`postCreateCommand` onto the base — carried over from before the base pin
moved from `2.0.0@sha256:8e0123b…` to `2.0.1@sha256:a50898f…` (commits
`b5e6308` → `bcd8b6e`). But that was not measured: no Docker-side evidence
was gathered or could be, since this container has no `docker` CLI and no
`/var/run/docker.sock`. It is also not the only fit. The Dev Containers
CLI generates a Dockerfile whose base is a build arg
(`ARG _DEV_CONTAINERS_BASE_IMAGE` / `FROM $_DEV_CONTAINERS_BASE_IMAGE`),
which BuildKit resolves before `FROM`, so a changed digest normally *does*
invalidate the chain. A Reopen-in-Container or restart that never rebuilt,
an existing container reattached, or a rebuild predating the digest bump's
arrival in the working tree all fit the same facts at least as well.

None of that weakens the conclusion. The negative — image correct,
workaround inert, nothing to report upstream — is what this issue turns
on, and it is established independently of the mechanism.

## Steps to Reproduce

The original steps no longer reproduce, which is the point: rebuilding
from the pin now yields plcc-ng 2.0.1. The stale reading is consistent
with a plain (cache-reusing) rebuild that reused a derived image built on
the 2.0.0 base, carried across the `b5e6308` → `bcd8b6e` digest bump; the
precise cache mechanism was not confirmed — only that the staleness was
local, since the pinned digest is content-addressed and the published
image demonstrably ships 2.0.1.

Evidence gathered inside a container rebuilt without cache on 2026-07-30
at 00:24 UTC:

| Path | mtime | Origin |
| --- | --- | --- |
| `site-packages/plcc_ng-2.0.1.dist-info/` (`METADATA` → `Version: 2.0.1`) | `2026-07-29 20:05:50.000000000` | image layer |
| `site-packages/plcc/` tree | `2026-07-29 20:05:50.000000000` | image layer |
| `/usr/local/bin/plcc-version` (pipx app shim) | `2026-07-29 20:05:50.000000000` | image layer |
| `/usr/local/bin/bats` | `2026-07-30 00:24:17.556336439` | `postCreateCommand` |
| `pipx_metadata.json` | `2026-07-30 00:24:28.682337665` | `postCreateCommand` |

The two populations partition cleanly, with no ambiguous case: every
image-layer mtime has whole-second precision (`.000000000`, characteristic
of tar/layer extraction) while every create-time file carries real
nanoseconds. So the 2.0.1 distribution came from the image, not from any
upgrade at create time.

The `pipx upgrade plcc-ng` added by commit `1831a79` ran 11 seconds after
the bats install and modified only `pipx_metadata.json`, leaving every
installed file untouched: it found plcc-ng already current and did
nothing. Independently confirming that, `plcc-version` — a pipx-generated
app shim, which a genuine `pipx upgrade` would recreate — still carries
the image-layer mtime. The venv holds exactly one plcc-ng dist-info
(`plcc_ng-2.0.1.dist-info`), with no `plcc_ng-2.0.0.dist-info` residue.
The fixed `_handle_arbno` / `_parse_arbno` code from issue #10 is present
in the image-dated files.

Consistent with all of this, commit `bcd8b6e` ("pin plcc-ng 2.0.1 image by
digest") was authored `2026-07-29 20:22:13` — seventeen minutes after the
`20:05:50` layer timestamp, about what you would expect if the image was
built shortly before someone pinned its digest.

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
That merit is the whole justification. The workaround-removal rule in
[dev-docs/issue-conventions.md](../issue-conventions.md) is not on
point — it is scoped to an *upstream defect* forcing a workaround in
shipped `src/`, and neither condition holds here: there is no upstream
defect, and the workaround lived in `.devcontainer/`. Removing it in that
rule's spirit was still plainly right. The durable lesson lives as a
comment at the pin in
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

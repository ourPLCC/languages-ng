# 011 - devcontainer-image-stale-plcc-ng-version

**Type:** chore
**Target:** ourPLCC/devcontainers
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

The devcontainer image tagged/pinned as `plcc-ng:2.0.1` (digest currently
pinned in `.devcontainer/devcontainer.json` as
`ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:a50898fdf863e9792d8a62d79d0f5f664a1e89634397f1498a7ccc0c29fc2d24`)
does **not** actually contain plcc-ng 2.0.1. After rebuilding the
devcontainer from this exact pin, the pipx-installed CLI inside the fresh
container still reports version 2.0.0 (`plcc-version` prints
`plcc-ng 2.0.0`), and its `plcc/ll1/spec_json_decoder.py` and
`plcc/parser/predictive_parser.py` still contain the pre-2.0.1 (buggy)
arbno code — confirmed by direct inspection of those files inside the
freshly rebuilt container.

This means anyone who rebuilds the devcontainer from this pin still hits
the arbno mid-body-terminal bug tracked in issue #10
([010-plcc-ng-arbno-drops-mid-body-terminal.md](010-plcc-ng-arbno-drops-mid-body-terminal.md)),
despite the image's own tag claiming to be the fixed 2.0.1.

This is a distinct problem from issue #10: #10 was about the bug in
`plcc-ng`'s own source (now fixed upstream, verified against the real
`plcc-ng==2.0.1` published on PyPI). This issue is about the
devcontainer **image** build/publish pipeline being out of sync with its
own version tag — the image labeled 2.0.1 was built with (or still
caches) 2.0.0.

**Workaround used so far:** manually running, inside a running container:

```bash
sudo env PIPX_HOME=/usr/local/pipx PIPX_BIN_DIR=/usr/local/bin \
  /usr/local/py-utils/bin/pipx upgrade plcc-ng
```

upgrades the live install from 2.0.0 to the real 2.0.1 (confirmed via
`plcc-version` and by re-inspecting the upgraded venv's source, which now
has the fixed code). This is **live-container-only** — it does not persist
across rebuilds and must be redone (or the image itself must be fixed)
every time the devcontainer is rebuilt.

**Suggested fix:** whoever builds/publishes the
`ghcr.io/ourplcc/devcontainers/plcc-ng` image needs to verify their
Dockerfile/build pipeline actually installs `plcc-ng==2.0.1` pinned (not
an unpinned or cached `2.0.0` layer) and republish the `2.0.1` tag/digest.
Once republished, this repo's `.devcontainer/devcontainer.json` digest pin
should be re-verified (and re-pinned to the corrected digest if it
changes) against the corrected image.

## Steps to Reproduce

1. Rebuild the devcontainer from the current pin in
   `.devcontainer/devcontainer.json`
   (`ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:a50898fdf863e9792d8a62d79d0f5f664a1e89634397f1498a7ccc0c29fc2d24`).
2. Run `plcc-version`.
3. Observe it prints `plcc-ng 2.0.0` instead of the expected
   `plcc-ng 2.0.1`.

## Notes

`Target` above (`ourPLCC/devcontainers`) is a guess inferred from the image
path `ghcr.io/ourplcc/devcontainers/plcc-ng`, not a confirmed repo name —
no doc in this repo's `dev-docs/` states the devcontainer-image source
repo explicitly. Confirm the real repo name before reporting this
upstream.

Found while resuming the V3 migration (issue #9) after issue #10's fix
landed upstream. The upstream `plcc-ng` source fix itself was verified
independently by installing the real `plcc-ng==2.0.1` from PyPI into a
scratch venv and confirming the fixed `_handle_arbno`/`_parse_arbno` code
and plcc-ng's own bundled
`test_arbno_keeps_mid_body_noncapturing_terminal_with_null_field` test —
so the gap is specifically in this devcontainer image, not in plcc-ng
itself. This issue is separate from and does not block work tracked by
issue #10 (closed once the local devcontainer's live pipx install was
manually upgraded to real 2.0.1); it exists so the image pipeline gets
fixed and a future rebuild doesn't silently regress everyone back to the
2.0.0 bug.

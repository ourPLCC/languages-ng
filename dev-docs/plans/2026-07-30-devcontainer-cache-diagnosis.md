# Devcontainer Cache Diagnosis (issue #11) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct issue #11's false diagnosis, remove the inert `pipx upgrade` workaround it caused, and document the real cause (Docker cache reuse across a base-digest bump) where the digest is edited.

**Architecture:** Three sequential, independently reviewable commits touching three files. No `src/` code changes, so no language tests change behavior. Task 1 restores `.devcontainer/devcontainer.json` to a pure digest pin plus a warning comment; Task 2 rewrites the issue file's content; Task 3 runs the repo's close script. Order matters only in that Task 3's script moves the file Task 2 edits.

**Tech Stack:** jsonc (`devcontainer.json`), Markdown, bash (`bin/issues/*.bash`), bats (existing language test suite), git.

## Global Constraints

- Spec of record: [dev-docs/specs/2026-07-30-devcontainer-cache-diagnosis-design.md](../specs/2026-07-30-devcontainer-cache-diagnosis-design.md). Do not re-litigate its conclusions.
- The `image` value in `.devcontainer/devcontainer.json` must not change. It stays exactly `ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:a50898fdf863e9792d8a62d79d0f5f664a1e89634397f1498a7ccc0c29fc2d24`.
- Never edit `dev-docs/roadmap.md` by hand for this work; `bin/issues/close.bash` does it (per [dev-docs/issue-conventions.md](../issue-conventions.md)).
- Never assign or renumber issue IDs by hand.
- Commit message types: `chore` for the devcontainer change, `docs(issues)` for both issue-file commits. `fix`/`feat` are reserved for `src/` changes because they bump the release version (see `.releaserc.yaml`) — do not use them here.
- End every commit message with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- No [course-material-impact.md](../course-material-impact.md) entry: nothing in `src/` changes.
- Expected `bin/test.bash` result throughout: **34 tests, 31 pass, 3 fail** — V4 `proc`, V5 `letrec`, V6 `define`, all failing with `plccmk: command not found`. These are pre-existing, tracked by issue #12, and unrelated to this work. Do not attempt to fix them.

---

### Task 1: Restore the pure digest pin and document the cache gotcha

Reverts commit `1831a79`'s addition to `postCreateCommand` and adds the warning comment. `devcontainer.json` is jsonc, so `//` comments are valid there.

**Files:**
- Modify: `.devcontainer/devcontainer.json` (whole file, 9 lines)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the exact issue-file path `dev-docs/issues/done/011-devcontainer-image-stale-plcc-ng-version.md`, referenced by the comment. Task 3's `close.bash` run is what creates that path — the comment points forward to it deliberately.

- [ ] **Step 1: Capture the pre-workaround value to compare against**

Run:

```bash
git show '1831a79^:.devcontainer/devcontainer.json' > /tmp/claude-1000/-workspaces-languages-ng/49a6520f-af20-44ad-832d-99c0e99acf8a/scratchpad/devcontainer-before.json
grep -o '"postCreateCommand".*' /tmp/claude-1000/-workspaces-languages-ng/49a6520f-af20-44ad-832d-99c0e99acf8a/scratchpad/devcontainer-before.json
```

Expected output — one line, ending at `rm -rf /tmp/bats-core"` with no `pipx` and no `#` comment:

```
"postCreateCommand": "BATS_VERSION=v1.11.0 && git clone https://github.com/bats-core/bats-core.git /tmp/bats-core && cd /tmp/bats-core && git checkout $BATS_VERSION && sudo ./install.sh /usr/local && cd - && rm -rf /tmp/bats-core"
```

- [ ] **Step 2: Write the new file**

Replace the entire contents of `.devcontainer/devcontainer.json` with exactly this:

```jsonc
{
  "name": "languages-ng",
  // Pinned by digest for reproducibility. When you bump this, rebuild
  // WITHOUT cache ("Dev Containers: Rebuild Container Without Cache") --
  // the derived feature image is cached independently of the base digest,
  // so a plain rebuild silently reuses the old toolchain.
  // Do not "fix" a stale container with `pipx upgrade plcc-ng`; that
  // defeats this pin. See
  // dev-docs/issues/done/011-devcontainer-image-stale-plcc-ng-version.md
  "image": "ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:a50898fdf863e9792d8a62d79d0f5f664a1e89634397f1498a7ccc0c29fc2d24",
  "features": {
    "ghcr.io/anthropics/devcontainer-features/claude-code:1.0": {},
    "ghcr.io/devcontainers-extra/features/shellcheck:1": {}
  },
  "postCreateCommand": "BATS_VERSION=v1.11.0 && git clone https://github.com/bats-core/bats-core.git /tmp/bats-core && cd /tmp/bats-core && git checkout $BATS_VERSION && sudo ./install.sh /usr/local && cd - && rm -rf /tmp/bats-core"
}
```

- [ ] **Step 3: Verify `postCreateCommand` matches the pre-workaround value byte for byte**

Run:

```bash
diff <(grep -o '"postCreateCommand".*' /tmp/claude-1000/-workspaces-languages-ng/49a6520f-af20-44ad-832d-99c0e99acf8a/scratchpad/devcontainer-before.json) \
     <(grep -o '"postCreateCommand".*' .devcontainer/devcontainer.json) \
  && echo "MATCH: postCreateCommand reverted exactly"
```

Expected: `MATCH: postCreateCommand reverted exactly`, no diff output.

If `diff` prints anything, the revert is wrong — fix Step 2 before continuing.

- [ ] **Step 4: Verify the file still parses and the digest is untouched**

Run:

```bash
python3 - <<'PY'
import json, pathlib
src = pathlib.Path('.devcontainer/devcontainer.json').read_text()
stripped = '\n'.join(l for l in src.splitlines() if not l.lstrip().startswith('//'))
cfg = json.loads(stripped)
assert cfg['image'] == ('ghcr.io/ourplcc/devcontainers/plcc-ng:2.0.1@sha256:'
                        'a50898fdf863e9792d8a62d79d0f5f664a1e89634397f1498a7ccc0c29fc2d24'), cfg['image']
assert 'pipx' not in cfg['postCreateCommand'], 'workaround still present'
assert set(cfg) == {'name', 'image', 'features', 'postCreateCommand'}, set(cfg)
print('OK: parses, digest unchanged, workaround gone')
PY
```

Expected: `OK: parses, digest unchanged, workaround gone`

(The comments added in Step 2 are all whole-line `//`, which is why the naive strip above is sound. Keep them whole-line.)

- [ ] **Step 5: Sanity-check the language suite**

Run: `bin/test.bash`

Expected: 34 tests, 31 pass, 3 fail (V4/V5/V6, `plccmk: command not found`).

Note what this does and does not prove: the suite runs in the **already-running** container and does not read `devcontainer.json`, so it cannot validate the revert. It confirms the image's plcc-ng 2.0.1 drives V0–V3 correctly — which is the substance of why the workaround is unnecessary. The revert itself is verified by Steps 3–4 and by the spec's evidence table.

- [ ] **Step 6: Commit**

```bash
git add .devcontainer/devcontainer.json
git commit -F - <<'EOF'
chore(devcontainer): drop pipx upgrade workaround, document cache gotcha

Commit 1831a79 appended `pipx upgrade plcc-ng` to postCreateCommand on the
belief that the pinned image ships plcc-ng 2.0.0 under a 2.0.1 tag. That
belief was wrong, and the command never did anything: in a container
rebuilt without cache, plcc_ng-2.0.1.dist-info and the entire plcc/ tree
carry image-layer mtimes (2026-07-29 20:05:50), while the upgrade touched
only pipx_metadata.json -- it found plcc-ng already current and exited.
The image does ship 2.0.1. The 2.0.0 sighting came from a cached derived
image reused across the 2.0.0 -> 2.0.1 base-digest bump.

Keeping the command is actively harmful: `pipx upgrade` installs whatever
is newest on PyPI, so the moment plcc-ng 2.1.0 ships, every container
create drifts off the pinned digest -- reintroducing exactly the
non-reproducibility the pin exists to prevent.

Revert postCreateCommand to its pre-1831a79 value and add a comment at the
pin recording the real rule: bumping the digest requires a rebuild without
cache, because the derived feature image is cached independently of the
base digest.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 2: Correct issue #11's diagnosis

Rewrites the issue file so the record reflects what actually happened. The file keeps its `# NNN - slug` / `**Type:**` / `**Target:**` / `**Date:**` header and its `## Description` / `## Steps to Reproduce` / `## Notes` headings, matching `dev-docs/issues/TEMPLATE.md` and the other issues. Per convention (see `dev-docs/issues/done/010-*.md`), the resolution is a bold-led paragraph in `## Notes`, not a new `## Resolution` heading.

**Files:**
- Modify: `dev-docs/issues/011-devcontainer-image-stale-plcc-ng-version.md` (replace entire body below the header comment)

**Interfaces:**
- Consumes: Task 1's committed `.devcontainer/devcontainer.json` (the Notes text asserts the workaround is gone, which is only true after Task 1).
- Produces: the file content that Task 3 moves to `dev-docs/issues/done/`. Path and filename must not change here — `close.bash` owns the move.

- [ ] **Step 1: Confirm the starting state**

Run:

```bash
grep -n '^\*\*Target:\*\*' dev-docs/issues/011-devcontainer-image-stale-plcc-ng-version.md
```

Expected: `4:**Target:** ourPLCC/devcontainers`

- [ ] **Step 2: Change the Target field**

Change line 4 from:

```markdown
**Target:** ourPLCC/devcontainers
```

to:

```markdown
**Target:** this repo
```

Rationale: there is no upstream defect. The workaround that needed removing lived in this repo, so this repo is the target.

- [ ] **Step 3: Replace everything from `## Description` to end of file**

Keep lines 1–15 (title, `**Type:**`, the corrected `**Target:**`, `**Date:**`, and the `<!-- ... -->` classification comment) exactly as they are. Replace from the `## Description` heading through the end of the file with:

```markdown
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
```

- [ ] **Step 4: Verify the file's structure survived and links resolve**

Run:

```bash
grep -n '^#\|^\*\*Type\|^\*\*Target\|^\*\*Date' dev-docs/issues/011-devcontainer-image-stale-plcc-ng-version.md
```

Expected — headings in this order, and `**Target:** this repo`:

```
1:# 011 - devcontainer-image-stale-plcc-ng-version
3:**Type:** chore
4:**Target:** this repo
5:**Date:** 2026-07-29
17:## Description
...:## Steps to Reproduce
...:## Notes
```

Then confirm every relative link in the file points at a real file:

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('dev-docs/issues/011-devcontainer-image-stale-plcc-ng-version.md')
bad = [t for t in re.findall(r'\]\(([^)#]+\.md)\)', p.read_text())
       if not (p.parent / t).resolve().exists()]
print('BROKEN:', bad) if bad else print('OK: all links resolve')
PY
```

Expected: `OK: all links resolve`

- [ ] **Step 5: Verify issue bookkeeping is still consistent**

Run: `bin/issues/check.bash`

Expected: exit 0, reporting 2 open issues and a consistent roadmap. The issue is still open at this point — that is correct; Task 3 closes it.

- [ ] **Step 6: Commit**

```bash
git add dev-docs/issues/011-devcontainer-image-stale-plcc-ng-version.md
git commit -F - <<'EOF'
docs(issues): correct issue 11 diagnosis - local cache, not upstream image

Issue #11 blamed ourPLCC/devcontainers for publishing an image tagged
2.0.1 that shipped plcc-ng 2.0.0. The image was correct; the 2.0.0
sighting came from a cached derived image reused across the 2.0.0 ->
2.0.1 base-digest bump (b5e6308 -> bcd8b6e). A rebuild without cache
reports 2.0.1.

Rewrite the Description around the real cause, replace the no-longer-
reproducing steps with the mtime evidence that distinguishes image
content from postCreate side effects, and record in Notes that the
1831a79 workaround is reverted and nothing goes upstream. Correct Target
from ourPLCC/devcontainers -- always a guess inferred from the image
path -- to this repo.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

### Task 3: Close issue #11

Runs the repo's close script as the branch's final commit, so the work and its bookkeeping merge atomically ([dev-docs/issue-conventions.md](../issue-conventions.md)).

**Files:**
- Move (by script): `dev-docs/issues/011-…md` → `dev-docs/issues/done/011-…md`
- Modify (by script): `dev-docs/roadmap.md`

**Interfaces:**
- Consumes: Tasks 1 and 2, both committed. Closing before the workaround is reverted would violate the convention that an issue stays open while its workaround lives in the tree.
- Produces: `dev-docs/issues/done/011-devcontainer-image-stale-plcc-ng-version.md`, the path Task 1's comment references.

- [ ] **Step 1: Confirm Tasks 1 and 2 are committed and the tree is clean**

Run: `git status --porcelain` and `git log --oneline -3`

Expected: empty status output; the two most recent commits are Task 2's then Task 1's.

Do not proceed with uncommitted changes — `close.bash` stages files, and unrelated staged work would be swept into the close commit.

- [ ] **Step 2: Run the close script**

Run: `bin/issues/close.bash 11`

Expected: the script moves the file to `dev-docs/issues/done/`, removes the `#11` entry from the roadmap's Open Issues (removing the `###` type group if it is now empty), rewrites `dev-docs/` links that pointed at the old path, adjusts the moved file's own relative links for its new depth, stages everything, and runs `check.bash` — which must pass.

- [ ] **Step 3: Review what the script changed**

Run: `git diff --cached`

Check specifically:
- `dev-docs/roadmap.md` no longer lists `#11`, and still lists `#12`.
- The moved file's links were re-depthed correctly: `../issue-conventions.md` became `../../issue-conventions.md`, `../specs/…` became `../../specs/…`, and the link to issue #10 changed from `done/010-…` to `010-…` (they are now siblings).
- Any link to `issues/011-…` elsewhere in `dev-docs/` now points at `issues/done/011-…`. The spec written in this session links to it and should have been rewritten.

The conventions note that milestone rationale prose is not auto-edited. Read the roadmap's milestone section and confirm no sentence now refers to #11 as pending. If one does, fix it by hand in this commit.

- [ ] **Step 4: Verify links still resolve after the move**

Run:

```bash
python3 - <<'PY'
import re, pathlib
bad = []
for p in pathlib.Path('dev-docs').rglob('*.md'):
    for t in re.findall(r'\]\(([^)#:]+\.md)\)', p.read_text()):
        if not (p.parent / t).resolve().exists():
            bad.append(f'{p} -> {t}')
print('BROKEN:\n' + '\n'.join(bad)) if bad else print('OK: all dev-docs links resolve')
PY
```

Expected: `OK: all dev-docs links resolve`

- [ ] **Step 5: Verify the comment in devcontainer.json now points at a real file**

Run:

```bash
test -f dev-docs/issues/done/011-devcontainer-image-stale-plcc-ng-version.md \
  && grep -q 'issues/done/011-devcontainer-image-stale-plcc-ng-version.md' .devcontainer/devcontainer.json \
  && echo "OK: devcontainer.json comment resolves"
```

Expected: `OK: devcontainer.json comment resolves`

- [ ] **Step 6: Final consistency and test run**

Run: `bin/issues/check.bash` — expected: exit 0, **1** open issue (#12), roadmap consistent.

Run: `bin/test.bash` — expected: 34 tests, 31 pass, 3 fail (V4/V5/V6, `plccmk: command not found`), unchanged from the baseline.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -F - <<'EOF'
docs(issues): close issue 11 (devcontainer image stale plcc-ng version), update roadmap

The image was never stale. A cached derived image reused across the
2.0.0 -> 2.0.1 base-digest bump produced the 2.0.0 reading; a rebuild
without cache reports 2.0.1. The 1831a79 workaround is reverted and the
real rule -- rebuild without cache after bumping the digest -- is
documented at the pin.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

---

## Out of scope

- The three failing V4/V5/V6 tests (`plccmk: command not found`) — tracked by [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md).
- Any upstream report to `ourPLCC/devcontainers` — there is no defect to report.
- Rewriting `1831a79`'s commit message.
- Bumping the image digest or plcc-ng version.

## Accepted limitation

A rebuild-without-cache against the reverted config cannot be run from this session: this worktree lives under `.claude/worktrees/`, so a rebuild reads the root `.devcontainer`, not the branch's. The maintainer decided to close #11 in this branch regardless, since the mtime evidence already establishes the removed command was inert — a rebuild could only confirm a known result. The "close on verification" exception in [dev-docs/issue-conventions.md](../issue-conventions.md) was considered and declined.

After this branch merges, a no-cache rebuild on `main` is still the natural confirmation: `plcc-version` should report `plcc-ng 2.0.1` with no `pipx upgrade` in `postCreateCommand`.

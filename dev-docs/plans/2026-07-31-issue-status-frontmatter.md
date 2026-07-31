# Issue Status as Frontmatter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate `dev-docs/issues/done/` and track issue status with a `closed:` frontmatter date, so closing an issue never rewrites links and `close.bash`'s blind `sed` passes can be deleted.

**Architecture:** Issue files stay at `dev-docs/issues/NNN-slug.md` for life. Each opens with YAML frontmatter (`type`, `target`, `opened`, `closed`); an empty `closed` means open. `close.bash` fills that date and updates the roadmap — nothing else. `check.bash` reads the field as the source of truth and verifies the roadmap agrees.

**Tech Stack:** Bash 5 (`set -euo pipefail`), awk, sed, git. Python 3 is used only for throwaway migration and verification snippets that are never committed.

**Design spec:** [dev-docs/specs/2026-07-31-issue-status-frontmatter-design.md](../specs/2026-07-31-issue-status-frontmatter-design.md)
**Issue:** [#18](../issues/018-close-bash-rewrites-plan-prose.md)

## Global Constraints

- **Frontmatter is flat scalars, one key per line.** No nesting, no lists, no multi-line values. Keys, in order: `type`, `target`, `opened`, `closed`.
- **`closed` is always present.** Empty while open, `YYYY-MM-DD` once closed. Never omitted.
- **Never rewrite prose or fenced content when fixing links.** Only Markdown link targets — the text inside `](...)` — change. Every fenced quotation listed in Task 1 must survive byte-identical. This is the defect being fixed; reintroducing it fails the task.
- **Scripts keep their existing preamble**: `#!/usr/bin/env bash`, `set -euo pipefail`, the `SCRIPT_DIR`/`PROJECT_ROOT` block, and `cd "${PROJECT_ROOT}"`.
- **Prefer `if grep -q X; then fail "..."; fi` over `grep -q X && fail "..."`.** Bash's `set -e` tolerates a failing left side of an `&&` list, so both forms run, but the `if` form says what it means and cannot become the accidental non-zero return value of a function.
- **All commands run from the repository root** (this worktree), not from `dev-docs/`.
- Commit types: `chore(issues):` for `bin/` changes, `docs(issues):` for documentation and issue-file content.

## File Structure

| File | Change | Responsibility after the change |
| --- | --- | --- |
| `dev-docs/issues/*.md` (19) | Move + rewrite header | Every issue, open or closed, in one directory with frontmatter |
| `dev-docs/issues/done/` | Delete | — |
| `dev-docs/issues/TEMPLATE.md` | Rewrite header | Frontmatter skeleton with `TYPE` / `YYYY-MM-DD` placeholders |
| `bin/issues/new.bash` | Modify | Fill `type` / `opened`, leave `closed` empty |
| `bin/issues/close.bash` | Rewrite | Set `closed`, update roadmap, stage. No moves, no link rewriting |
| `bin/issues/check.bash` | Rewrite | Frontmatter validity + roadmap agreement, keyed on `closed` |
| `dev-docs/issue-conventions.md`, `CLAUDE.md` | Modify | Document the new model |
| `dev-docs/plans/*.md`, `dev-docs/specs/*.md` | Link targets only | Unchanged prose; live links repointed |

---

### Task 1: Move issues out of `done/` and repoint every live link

**Files:**
- Move: all 14 of `dev-docs/issues/done/*.md` → `dev-docs/issues/`
- Modify (link targets only): the 14 moved files, `dev-docs/issues/018-close-bash-rewrites-plan-prose.md`, 4 files under `dev-docs/plans/`, 2 files under `dev-docs/specs/`

**Interfaces:**
- Consumes: nothing.
- Produces: a flat `dev-docs/issues/` directory. Every later task assumes `dev-docs/issues/done/` does not exist and that no `.md` file under `dev-docs/` contains a live link target mentioning `done/`.

- [ ] **Step 1: Move the files and remove the directory**

```bash
git mv dev-docs/issues/done/*.md dev-docs/issues/
rmdir dev-docs/issues/done
ls dev-docs/issues/
```

Expected: 19 numbered `.md` files — ids 001 through 019, every one present — plus `TEMPLATE.md` and `index.md`. No `done` entry.

- [ ] **Step 2: Fix the moved files' outbound links (`../../` → `../`)**

Each moved file was re-depthed by the old pass 4 when it was closed, so its links to `dev-docs/plans/`, `dev-docs/specs/`, and `dev-docs/issue-conventions.md` climb two levels. Back in `dev-docs/issues/` they must climb one. There are exactly 19 such targets, none inside a fence:

```bash
sed -i 's|](\.\./\.\./|](../|g' dev-docs/issues/[0-9]*.md
grep -rn --include='*.md' -c '](\.\./\.\./' dev-docs/issues/ || echo "none left"
```

Expected: `none left`.

- [ ] **Step 3: Fix the four `../NNN-slug.md` links**

These are the four genuinely broken links inventoried in issue #13 — each climbs out of `done/` to reach an issue that has since become a sibling:

```bash
sed -i -E 's|\]\(\.\./([0-9]{3}-)|](\1|g' dev-docs/issues/[0-9]*.md
grep -rn --include='*.md' -E '\]\(\.\./[0-9]{3}-' dev-docs/issues/ || echo "none left"
```

Expected: `none left`. The four sites were `007-migrate-v2-to-plcc-ng.md:29`, and `008-update-plcc-ng-2.0.0.md` lines 31, 35, 40.

- [ ] **Step 4: Fix the one `done/`-prefixed link inside an issue file**

[dev-docs/issues/018-close-bash-rewrites-plan-prose.md:97](../issues/018-close-bash-rewrites-plan-prose.md#L97) links `](done/017-migrate-v5-to-plcc-ng.md)`, which is now a sibling:

```bash
sed -i 's|](done/017-migrate-v5-to-plcc-ng.md)|](017-migrate-v5-to-plcc-ng.md)|' \
    dev-docs/issues/018-close-bash-rewrites-plan-prose.md
grep -n '017-migrate-v5' dev-docs/issues/018-close-bash-rewrites-plan-prose.md
```

Expected: one line, line 97, with target `(017-migrate-v5-to-plcc-ng.md)`.

- [ ] **Step 5: Fix the 12 inbound links in plans and specs — by hand, one at a time**

Do **not** run a global `sed` over `dev-docs/plans/` or `dev-docs/specs/`. Those files also contain fenced quotations with the same text, and rewriting those is exactly the bug this branch exists to remove. Edit these 14 targets, and only these, changing `../issues/done/` to `../issues/`:

| File | Line | Target |
| --- | --- | --- |
| `dev-docs/plans/2026-07-23-plcc-ng-phase2-v2.md` | 22 | `../issues/done/006-multi-capture-alt-name-case-mismatch.md` |
| `dev-docs/plans/2026-07-27-plcc-ng-2.0.0-update.md` | 23 | `../issues/done/003-python-run-return-value-quoted.md` |
| `dev-docs/plans/2026-07-27-plcc-ng-2.0.0-update.md` | 23 | `../issues/done/004-js-var-field-reserved-word.md` |
| `dev-docs/plans/2026-07-27-plcc-ng-2.0.0-update.md` | 23 | `../issues/done/006-multi-capture-alt-name-case-mismatch.md` |
| `dev-docs/plans/2026-07-28-plcc-ng-phase2-v3.md` | 3 | `../issues/done/010-plcc-ng-arbno-drops-mid-body-terminal.md` |
| `dev-docs/plans/2026-07-30-plcc-ng-phase2-v4.md` | 190 | `../issues/done/010-plcc-ng-arbno-drops-mid-body-terminal.md` |
| `dev-docs/specs/2026-07-27-plcc-ng-2.0.0-update-design.md` | 3 | `../issues/done/008-update-plcc-ng-2.0.0.md` |
| `dev-docs/specs/2026-07-27-plcc-ng-2.0.0-update-design.md` | 9 | `../issues/done/003-python-run-return-value-quoted.md` |
| `dev-docs/specs/2026-07-27-plcc-ng-2.0.0-update-design.md` | 11 | `../issues/done/004-js-var-field-reserved-word.md` |
| `dev-docs/specs/2026-07-27-plcc-ng-2.0.0-update-design.md` | 13 | `../issues/done/006-multi-capture-alt-name-case-mismatch.md` |
| `dev-docs/specs/2026-07-30-devcontainer-cache-diagnosis-design.md` | 4 | `../issues/done/011-devcontainer-image-stale-plcc-ng-version.md` |
| `dev-docs/specs/2026-07-30-devcontainer-cache-diagnosis-design.md` | 136 | `../issues/done/010-plcc-ng-arbno-drops-mid-body-terminal.md` |

Note that line 23 of `2026-07-27-plcc-ng-2.0.0-update.md` holds three of these targets on the one line; the table lists each separately.

- [ ] **Step 6: Confirm the fenced quotations were NOT touched**

These 11 sites are historical quotations of other files and must still read `done/`:

```bash
git diff -- dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md \
             dev-docs/plans/2026-07-22-plcc-ng-phase2-v1.md \
             dev-docs/plans/2026-07-30-devcontainer-cache-diagnosis.md
```

Expected: **no output.** Those three files contain only fenced `done/` references (phase0-phase1 lines 252, 404, 1202, 1204; phase2-v1 lines 77, 79; devcontainer-cache-diagnosis line 202) and must be untouched. Then:

```bash
grep -rn --include='*.md' 'issues/done/\|(done/' dev-docs
```

Every surviving hit must fall into one of three groups — check each one against this list, and treat anything else as a link Step 5 missed:

1. **Fenced quotations** of another file's contents, which record history and must not change: `2026-07-22-plcc-ng-phase0-phase1.md` (252, 404, 1202, 1204), `2026-07-22-plcc-ng-phase2-v1.md` (77, 79), `2026-07-23-plcc-ng-phase2-v2.md` (67), `2026-07-28-plcc-ng-phase2-v3.md` (75), `2026-07-30-plcc-ng-phase2-v4.md` (74), `2026-07-30-devcontainer-cache-diagnosis.md` (202).
2. **Prose and code spans** describing the old workflow or the bug itself — in `dev-docs/issues/013-*.md`, `dev-docs/issues/018-*.md`, the design spec, this plan, and `dev-docs/plans/2026-07-31-plcc-ng-phase2-v5.md:953`. These are historical records; leave them.
3. **`dev-docs/issue-conventions.md` lines 3 and 50**, the only two live links left pointing at the directory. Task 6 rewrites those sentences.

The distinguishing test is simple: a hit is fine if it is not a live Markdown link target. Step 7 checks that mechanically.

- [ ] **Step 7: Verify every link in `dev-docs/` resolves**

Save this as a throwaway checker (it is deliberately not committed — the reusable, fence-aware checker is issue #13's scope):

```bash
mkdir -p /tmp/issue-018
cat > /tmp/issue-018/check-links.py <<'PY'
import re, pathlib
fence = re.compile(r'^\s{0,3}(`{3,}|~{3,})')
link = re.compile(r'\]\(([^)]+)\)')
broken = 0
for p in sorted(pathlib.Path('dev-docs').rglob('*.md')):
    inf = None
    for i, line in enumerate(p.read_text().splitlines(), 1):
        m = fence.match(line)
        if m:
            tok = m.group(1)
            if inf is None:
                inf = tok
            elif tok[0] == inf[0] and len(tok) >= len(inf):
                inf = None
            continue
        if inf:
            continue
        for t in link.findall(line):
            t = t.split('#')[0].strip()
            if not t or '://' in t or t.startswith('/'):
                continue
            if not (p.parent / t).exists():
                print(f'BROKEN {p}:{i} -> {t}')
                broken += 1
print(f'TOTAL {broken}')
PY
python3 /tmp/issue-018/check-links.py
```

Expected: exactly two `BROKEN` lines, both `dev-docs/issue-conventions.md -> issues/done/` (lines 3 and 50), and `TOTAL 2`. Those are the prose links Task 6 rewrites. Any other broken link means a link in Step 5 was missed or over-applied — fix it before committing.

- [ ] **Step 8: Commit**

```bash
git add -A dev-docs
git commit -m "$(cat <<'EOF'
docs(issues): flatten dev-docs/issues, drop the done/ split

Closed issues move back beside open ones; status becomes a frontmatter
field in the next commit. Repoints every live link target and fixes the
four dangling ../NNN-*.md links inventoried in issue #13. Fenced
quotations of the old paths are left as the history they record.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Convert the 19 issue files to frontmatter

**Files:**
- Modify: all 19 of `dev-docs/issues/[0-9]*.md`

**Interfaces:**
- Consumes: the flat `dev-docs/issues/` directory from Task 1.
- Produces: every issue file begins with a four-key frontmatter block. `check.bash` (Task 4) and `close.bash` (Task 5) parse exactly this shape:

```yaml
---
type: chore
target: this repo
opened: 2026-07-31
closed:
---
```

- [ ] **Step 1: Confirm every file has the uniform header this conversion assumes**

```bash
for f in dev-docs/issues/[0-9]*.md; do sed -n '3,5p' "$f" | tr '\n' '|'; echo " <- $f"; done
```

Expected: every line begins `**Type:** … |**Target:** … |**Date:** …`. If any file differs, convert that one by hand rather than adjusting the script below.

- [ ] **Step 2: Write the conversion script**

The `closed` dates come from each issue's closing commit — the commit that added the file at its old `done/` path — and were verified against the `docs(issues): close issue N` commit subjects.

```bash
cat > /tmp/issue-018/frontmatter.py <<'PY'
import pathlib, re

CLOSED = {
    '001-remove-unused-languages.md': '2026-07-22',
    '002-migrate-v0-to-plcc-ng.md': '2026-07-22',
    '003-python-run-return-value-quoted.md': '2026-07-28',
    '004-js-var-field-reserved-word.md': '2026-07-28',
    '005-migrate-v1-to-plcc-ng.md': '2026-07-22',
    '006-multi-capture-alt-name-case-mismatch.md': '2026-07-28',
    '007-migrate-v2-to-plcc-ng.md': '2026-07-23',
    '008-update-plcc-ng-2.0.0.md': '2026-07-29',
    '009-migrate-v3-to-plcc-ng.md': '2026-07-29',
    '010-plcc-ng-arbno-drops-mid-body-terminal.md': '2026-07-29',
    '011-devcontainer-image-stale-plcc-ng-version.md': '2026-07-30',
    '014-migrate-v4-to-plcc-ng.md': '2026-07-30',
    '015-gitignore-java-pattern-shadows-source-dirs.md': '2026-07-31',
    '017-migrate-v5-to-plcc-ng.md': '2026-07-31',
}

FIELD = re.compile(r'^\*\*(Type|Target|Date):\*\*\s*(.*)$')

for p in sorted(pathlib.Path('dev-docs/issues').glob('[0-9]*.md')):
    lines = p.read_text().split('\n')
    assert lines[0].startswith('# '), p
    assert lines[1] == '', p
    vals = {}
    for i in (2, 3, 4):
        m = FIELD.match(lines[i])
        assert m, (p, i, lines[i])
        vals[m.group(1)] = m.group(2).strip()
    body = lines[5:]
    fm = [
        '---',
        f"type: {vals['Type']}",
        f"target: {vals['Target']}",
        f"opened: {vals['Date']}",
        f"closed: {CLOSED.get(p.name, '')}".rstrip(),
        '---',
        '',
        lines[0],
    ]
    p.write_text('\n'.join(fm + body))
    print(f"converted {p.name} (closed: {CLOSED.get(p.name, '-')})")
PY
python3 /tmp/issue-018/frontmatter.py
```

Expected: 19 `converted …` lines, 14 of them with a date.

- [ ] **Step 3: Inspect two files — one open, one closed**

```bash
head -9 dev-docs/issues/018-close-bash-rewrites-plan-prose.md
head -9 dev-docs/issues/017-migrate-v5-to-plcc-ng.md
```

Expected, respectively:

```
---
type: chore
target: this repo
opened: 2026-07-31
closed:
---

# 018 - close-bash-rewrites-plan-prose

```

```
---
type: feat
target: this repo
opened: 2026-07-31
closed: 2026-07-31
---

# 017 - migrate-v5-to-plcc-ng

```

- [ ] **Step 4: Verify no old-style header survives and the counts are right**

```bash
grep -rn --include='*.md' '^\*\*\(Type\|Target\|Date\):\*\*' dev-docs/issues/[0-9]*.md || echo "no old headers"
ls dev-docs/issues/[0-9]*.md | wc -l
grep -l '^closed: [0-9]' dev-docs/issues/[0-9]*.md | wc -l
grep -L '^closed: [0-9]' dev-docs/issues/[0-9]*.md | wc -l
git diff --stat -- dev-docs/issues | tail -1
```

Expected: `no old headers`; `19`; `14` closed; `5` open; and a diffstat naming 19 files. (`TEMPLATE.md` still has the old header — Task 3 handles it.)

- [ ] **Step 5: Commit**

```bash
git add dev-docs/issues
git commit -m "$(cat <<'EOF'
docs(issues): convert issue headers to YAML frontmatter

type/target/opened/closed as flat scalars, one key per line, so scripts
read status with grep instead of parsing prose. An empty `closed` means
open; the 14 closed dates come from each issue's closing commit.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Update `TEMPLATE.md` and `new.bash`

**Files:**
- Modify: `dev-docs/issues/TEMPLATE.md`
- Modify: `bin/issues/new.bash:25-38`

**Interfaces:**
- Consumes: the frontmatter shape from Task 2.
- Produces: `bin/issues/new.bash <slug> [type]` still prints the created path on stdout and still increments `.next-id.txt`. New files carry `closed:` empty.

- [ ] **Step 1: Rewrite `dev-docs/issues/TEMPLATE.md`**

The guidance that used to live inside the `**Type:**` and `**Target:**` placeholder values moves into the HTML comment, because a value-position parenthetical would be a bogus YAML value in any hand-created file.

```markdown
---
type: TYPE
target: this repo
opened: YYYY-MM-DD
closed:
---

# NNN - Short descriptive title

<!--
`type` is a conventional commit type: fix, feat, refactor, perf, docs,
test, chore. Classify by user-facing impact, not by whether something was
"broken". `fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.

`target` is the repository the issue is actually about. It defaults to
this repo; set it to the upstream repository (e.g. ourPLCC/plcc-ng) when
the defect is there rather than in this repo's own src/.

`closed` stays empty until bin/issues/close.bash fills it in.
-->

## Description

What you observed, or what you want changed.

## Steps to Reproduce

(For bugs — omit if not applicable)

1. ...

## Notes

Any ideas, hunches, or related context.
```

- [ ] **Step 2: Update the `sed` block in `bin/issues/new.bash`**

Replace the existing `sed \ … > "${filename}"` invocation (currently lines 30-37) with:

```bash
if [[ -n "${TYPE}" ]]; then
    type_line="type: ${TYPE}"
else
    type_line="type:"
fi

sed \
    -e "s/^type: TYPE$/${type_line}/" \
    -e "s/^opened: YYYY-MM-DD$/opened: ${DATE}/" \
    -e "s/NNN/${padded}/" \
    -e "s/Short descriptive title/${SLUG}/" \
    "${TEMPLATE}" > "${filename}"
```

- [ ] **Step 3: Run it against a scratch issue**

```bash
bin/issues/new.bash scratch-delete-me chore
head -9 dev-docs/issues/020-scratch-delete-me.md
```

Expected:

```
---
type: chore
target: this repo
opened: <today's date>
closed:
---

# 020 - scratch-delete-me

```

- [ ] **Step 4: Run it once with no type argument**

```bash
rm dev-docs/issues/020-scratch-delete-me.md
git checkout dev-docs/issues/.next-id.txt
bin/issues/new.bash scratch-delete-me
sed -n '2p' dev-docs/issues/020-scratch-delete-me.md
```

Expected: exactly `type:` — no trailing space, no leftover `TYPE`.

- [ ] **Step 5: Clean up the scratch issue**

```bash
rm dev-docs/issues/020-scratch-delete-me.md
git checkout dev-docs/issues/.next-id.txt
cat dev-docs/issues/.next-id.txt
git status --short
```

Expected: `.next-id.txt` reads `20`, and `git status` shows only `TEMPLATE.md` and `new.bash` as modified.

- [ ] **Step 6: Commit**

```bash
git add dev-docs/issues/TEMPLATE.md bin/issues/new.bash
git commit -m "$(cat <<'EOF'
chore(issues): file new issues with frontmatter

TEMPLATE.md gains the four-key block and moves its type/target guidance
into the HTML comment, where a placeholder can't be mistaken for a value.
new.bash fills type and opened, and leaves closed empty.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Rewrite `check.bash` around the `closed` field

**Files:**
- Modify: `bin/issues/check.bash` (full rewrite of the body below the preamble)

**Interfaces:**
- Consumes: the frontmatter shape from Task 2; the flat directory from Task 1.
- Produces: `bin/issues/check.bash` exits 0 with `OK: <n> open, <m> closed, roadmap consistent, next id <k>` or non-zero with `FAIL:` lines. Task 5's `close.bash` calls it as its last step.

This task comes **before** `close.bash` deliberately: `close.bash` runs `check.bash`, and the current `check.bash` would fail an issue closed by field rather than by move.

- [ ] **Step 1: Write the new `bin/issues/check.bash`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"
ROADMAP="dev-docs/roadmap.md"
NEXT_ID_FILE="${ISSUES_DIR}/.next-id.txt"

failures=0
fail() {
    echo "FAIL: $*" >&2
    failures=$(( failures + 1 ))
}

# Frontmatter is flat scalars, one key per line: the leading block between
# the first "---" and the next one. These two helpers are the only readers.
fm_keys() {
    awk 'NR == 1 { next } /^---$/ { exit } /^[a-z_]+:/ { sub(/:.*/, ""); print }' "$1"
}
fm_value() {
    awk -v key="$2" '
        NR == 1 { next }
        /^---$/ { exit }
        index($0, key ":") == 1 { line = $0; sub(/^[^:]*:[[:space:]]*/, "", line); print line; exit }
    ' "$1"
}

# The open/closed directory split must not creep back.
if [[ -d "${ISSUES_DIR}/done" ]]; then
    fail "${ISSUES_DIR}/done exists; status is a 'closed:' date, not a directory"
fi

open_count=0
closed_count=0
max_id=0

for f in "${ISSUES_DIR}"/[0-9]*.md; do
    [[ -e "${f}" ]] || break
    basename="${f##*/}"
    id=$(( 10#${basename%%-*} ))
    (( id > max_id )) && max_id=${id}

    if [[ "$(head -n 1 "${f}")" != "---" ]]; then
        fail "${basename} does not open with a '---' frontmatter block"
        continue
    fi
    if ! awk 'NR > 1 && /^---$/ { found = 1; exit } END { exit !found }' "${f}"; then
        fail "${basename} frontmatter block is never closed"
        continue
    fi

    keys="$(fm_keys "${f}")"
    missing=0
    for key in type target opened closed; do
        if ! grep -qx -- "${key}" <<< "${keys}"; then
            fail "${basename} frontmatter has no '${key}:' key"
            missing=1
        fi
    done
    if (( missing )); then continue; fi

    opened="$(fm_value "${f}" opened)"
    closed="$(fm_value "${f}" closed)"
    [[ "${opened}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
        || fail "${basename} has a malformed opened date: '${opened}'"
    if [[ -n "${closed}" ]]; then
        [[ "${closed}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
            || fail "${basename} has a malformed closed date: '${closed}'"
        closed_count=$(( closed_count + 1 ))
    else
        open_count=$(( open_count + 1 ))
    fi

    # Open issues are listed in the roadmap; closed ones are not.
    if [[ -z "${closed}" ]]; then
        grep -q "^- \*\*\[#${id}\](issues/${basename})" "${ROADMAP}" \
            || fail "open issue ${basename} has no Open Issues entry in ${ROADMAP}"
    else
        if grep -q "^- \*\*\[#${id}\](issues/${basename})" "${ROADMAP}"; then
            fail "closed issue ${basename} still has an Open Issues entry in ${ROADMAP}"
        fi
    fi
done

# Every roadmap issue link resolves.
while IFS= read -r target; do
    [[ -e "${ISSUES_DIR}/${target}" ]] \
        || fail "roadmap links issues/${target} but that file does not exist"
done < <(grep -o '(issues/[^)]*\.md)' "${ROADMAP}" | tr -d '()' | sed 's|^issues/||' | sort -u)

# Milestone task lists: the checkbox agrees with the issue's closed field.
while IFS= read -r line; do
    box="$(sed -n 's|^[0-9]*\. \[\([ x]\)\].*|\1|p' <<< "${line}")"
    target="$(sed -n 's|.*(issues/\([^)]*\.md\)).*|\1|p' <<< "${line}")"
    if [[ -z "${target}" ]]; then
        fail "milestone item links no issue: ${line}"
        continue
    fi
    if [[ ! -e "${ISSUES_DIR}/${target}" ]]; then
        fail "milestone item links a nonexistent issue: ${line}"
        continue
    fi
    milestone_closed="$(fm_value "${ISSUES_DIR}/${target}" closed)"
    if [[ "${box}" == " " && -n "${milestone_closed}" ]]; then
        fail "unchecked milestone item links a closed issue: ${line}"
    fi
    if [[ "${box}" == "x" && -z "${milestone_closed}" ]]; then
        fail "checked milestone item links an open issue: ${line}"
    fi
done < <(grep '^[0-9]*\. \[[ x]\] ' "${ROADMAP}" || true)

# The ID counter is ahead of every issue ever filed.
next_id=$(( 10#$(cat "${NEXT_ID_FILE}") ))
(( next_id > max_id )) \
    || fail "${NEXT_ID_FILE} is ${next_id} but issue ${max_id} already exists"

if (( failures > 0 )); then
    echo "${failures} check(s) failed" >&2
    exit 1
fi
echo "OK: ${open_count} open, ${closed_count} closed, roadmap consistent, next id ${next_id}"
```

- [ ] **Step 2: Run it against the real tree**

```bash
bin/issues/check.bash
```

Expected: `OK: 5 open, 14 closed, roadmap consistent, next id 20`

- [ ] **Step 3: Prove it catches a typo'd key**

```bash
sed -i 's/^closed:/cloesd:/' dev-docs/issues/016-cross-target-integer-divergence.md
bin/issues/check.bash; echo "exit: $?"
git checkout dev-docs/issues/016-cross-target-integer-divergence.md
```

Expected: `FAIL: 016-cross-target-integer-divergence.md frontmatter has no 'closed:' key`, `1 check(s) failed`, and `exit: 1`. This is the invariant that makes "always present, empty while open" safe.

- [ ] **Step 4: Prove it catches a closed issue still listed as open**

```bash
sed -i 's/^closed:$/closed: 2026-07-31/' dev-docs/issues/016-cross-target-integer-divergence.md
bin/issues/check.bash; echo "exit: $?"
git checkout dev-docs/issues/016-cross-target-integer-divergence.md
bin/issues/check.bash
```

Expected: first run fails with `FAIL: closed issue 016-cross-target-integer-divergence.md still has an Open Issues entry in dev-docs/roadmap.md` and `exit: 1`; after the checkout, `OK: 5 open, 14 closed, …` again.

- [ ] **Step 5: Commit**

```bash
git add bin/issues/check.bash
git commit -m "$(cat <<'EOF'
chore(issues): check status from frontmatter, not file location

The 'closed:' date is now the source of truth: check.bash validates the
frontmatter block itself, requires open issues to be listed in the roadmap
and closed ones not to be, matches milestone checkboxes against the field,
and fails if dev-docs/issues/done/ ever reappears.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Rewrite `close.bash` — delete the link-rewriting passes

**Files:**
- Modify: `bin/issues/close.bash` (full rewrite of the body below the preamble)

**Interfaces:**
- Consumes: `check.bash` from Task 4; the frontmatter shape from Task 2.
- Produces: `bin/issues/close.bash <id>` sets `closed: <today>`, updates the roadmap, stages exactly two files, and runs `check.bash`. It touches no other file — that is the property Task 7 verifies.

- [ ] **Step 1: Write the new `bin/issues/close.bash`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"
ROADMAP="dev-docs/roadmap.md"

usage() {
    echo "Usage: $(basename "$0") <id>"
    echo "  id  issue number, e.g. 135"
    echo
    echo "Fills in the issue's 'closed' date, removes its entry from the"
    echo "Open Issues section of ${ROADMAP}, and checks its box in any"
    echo "milestone task list. Stages the changes; you review and commit."
    echo
    echo "Issue files never move: status is the 'closed' frontmatter field,"
    echo "so no link to an issue ever needs rewriting."
    exit 1
}

[[ $# -ne 1 ]] && usage

padded=$(printf '%03d' "$(( 10#$1 ))")

matches=( "${ISSUES_DIR}/${padded}"-*.md )
if [[ ! -e "${matches[0]}" ]]; then
    # Unpadded IDs (e.g. 112) predate zero-padding in new.bash.
    matches=( "${ISSUES_DIR}/$(( 10#$1 ))"-*.md )
fi
if [[ ! -e "${matches[0]}" ]]; then
    echo "error: no issue matching '${ISSUES_DIR}/${padded}-*.md'" >&2
    exit 1
fi
if [[ ${#matches[@]} -gt 1 ]]; then
    echo "error: multiple files match issue $1: ${matches[*]}" >&2
    exit 1
fi

issue_file="${matches[0]}"
basename="${issue_file##*/}"

# Already closed? The frontmatter says so.
existing=$(awk '
    NR == 1 { next }
    /^---$/ { exit }
    index($0, "closed:") == 1 { line = $0; sub(/^[^:]*:[[:space:]]*/, "", line); print line; exit }
' "${issue_file}")
if [[ -n "${existing}" ]]; then
    echo "error: issue $1 is already closed (${existing}): ${issue_file}" >&2
    exit 1
fi

today="$(date +%Y-%m-%d)"

# Fill in the closed date, inside the frontmatter block only: a "closed:"
# line in the body must never be touched.
awk -v today="${today}" '
    /^---$/ { n++ }
    n == 1 && !filled && index($0, "closed:") == 1 { print "closed: " today; filled = 1; next }
    { print }
' "${issue_file}" > "${issue_file}.tmp"
mv "${issue_file}.tmp" "${issue_file}"

if ! grep -qx "closed: ${today}" "${issue_file}"; then
    echo "error: ${issue_file} has no 'closed:' key in its frontmatter" >&2
    exit 1
fi

# Roadmap, pass 1: in milestone task lists, check the box. The link is not
# touched — it has always been issues/${basename} and stays that way.
sed -i -e "s|\[ \] \(\[#[0-9]*\](issues/${basename})\)|[x] \1|" "${ROADMAP}"

# Roadmap, pass 2: drop the issue's Open Issues entry — the bullet line plus
# its indented continuation lines, so back-to-back neighbors are untouched —
# then drop any "###" heading whose section is now empty.
awk -v link="(issues/${basename})" '
    skip { if ($0 ~ /^[ \t]/) next; skip = 0 }
    /^- / && index($0, link) { skip = 1; next }
    { lines[n++] = $0 }
    END {
        for (i = 0; i < n; i++) {
            if (lines[i] ~ /^### /) {
                j = i + 1
                while (j < n && lines[j] == "") j++
                if (j >= n || lines[j] ~ /^##/) { i = j - 1; continue }
            }
            keep[m++] = lines[i]
        }
        for (k = 0; k < m; k++) {
            if (keep[k] == "") { blank = 1; continue }
            if (printed && blank) print ""
            print keep[k]
            blank = 0; printed = 1
        }
    }
' "${ROADMAP}" > "${ROADMAP}.tmp"
mv "${ROADMAP}.tmp" "${ROADMAP}"

git add "${issue_file}" "${ROADMAP}"

bin/issues/check.bash

echo "closed ${issue_file} (closed: ${today})"
echo "Review ${ROADMAP} (milestone rationale text is not auto-edited), then commit:"
echo "  docs(issues): close issue $(( 10#$1 )) (<short title>), update roadmap"
```

- [ ] **Step 2: Close a scratch issue end to end**

```bash
bin/issues/new.bash scratch-close-me chore
```

Then add its Open Issues entry to `dev-docs/roadmap.md` under the existing `### Chore` heading, in the required two-line format:

```markdown
- **[#20](issues/020-scratch-close-me.md) — scratch, delete me**
  Temporary issue used to exercise close.bash.
```

Then:

```bash
bin/issues/check.bash
bin/issues/close.bash 20
```

Expected: `check.bash` reports `OK: 6 open, 14 closed, …`; `close.bash` prints `closed dev-docs/issues/020-scratch-close-me.md (closed: <today>)`, then `OK: 5 open, 15 closed, roadmap consistent, next id 21`, then the commit hint.

- [ ] **Step 3: Verify exactly two files changed, and the issue kept its links**

```bash
git status --short
sed -n '1,7p' dev-docs/issues/020-scratch-close-me.md
```

Expected: `git status` lists only `dev-docs/issues/020-scratch-close-me.md`, `dev-docs/issues/.next-id.txt`, `dev-docs/roadmap.md`, and the modified `bin/issues/close.bash` — no plans, no specs, no other issues. The frontmatter shows `closed: <today>` with `type`, `target`, `opened` unchanged.

- [ ] **Step 4: Verify the already-closed guard**

```bash
bin/issues/close.bash 20; echo "exit: $?"
```

Expected: `error: issue 20 is already closed (<today>): dev-docs/issues/020-scratch-close-me.md` and `exit: 1`.

- [ ] **Step 5: Clean up the scratch issue**

```bash
git rm -q --cached dev-docs/issues/020-scratch-close-me.md
rm dev-docs/issues/020-scratch-close-me.md
git checkout dev-docs/roadmap.md dev-docs/issues/.next-id.txt
bin/issues/check.bash
git status --short
```

Expected: `OK: 5 open, 14 closed, roadmap consistent, next id 20`, and `git status` showing only `bin/issues/close.bash` modified.

- [ ] **Step 6: Commit**

```bash
git add bin/issues/close.bash
git commit -m "$(cat <<'EOF'
chore(issues): close issues by field, not by moving the file

Closing now fills in the 'closed:' frontmatter date and updates the
roadmap. The git mv is gone, and with it pass 3 (a global sed that
rewrote prose, code spans and fenced blocks across every dev-docs file)
and pass 4 (three order-dependent seds re-depthing the moved file).

Fixes #18.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Update the documentation and issue #13

**Files:**
- Modify: `CLAUDE.md:15`
- Modify: `dev-docs/issue-conventions.md` lines 3, 50, 61, 71, plus a new subsection
- Modify: `dev-docs/issues/013-dev-docs-link-checker-not-fence-aware.md`

**Interfaces:**
- Consumes: the finished behavior of all three scripts.
- Produces: no code interface; this is the last content change before the dogfood close.

- [ ] **Step 1: Update `CLAUDE.md`**

Replace, on line 15, `It moves the file to \`done/\` and updates [dev-docs/roadmap.md](dev-docs/roadmap.md).` with:

```markdown
It fills in the issue's `closed` date and updates [dev-docs/roadmap.md](dev-docs/roadmap.md). Issue files never move, so links to them never break.
```

- [ ] **Step 2: Update `dev-docs/issue-conventions.md` line 3**

Replace `Closed issues move to [issues/done/](issues/done/).` with:

```markdown
Issues never move: an issue is closed when its `closed` frontmatter field holds a date.
```

- [ ] **Step 3: Add a frontmatter subsection after the "Filing an issue" section**

```markdown
## Frontmatter

Every issue file opens with a YAML frontmatter block:

```yaml
---
type: chore
target: this repo
opened: 2026-07-31
closed:
---
```

`closed` is the issue's status: empty while open, `YYYY-MM-DD` once closed.
It is **always present** — never omit the key — so that a misspelling is a
hard failure in `check.bash` rather than an issue that silently reads as
open forever. There is no separate `status` field; the date is the state.

The block is **flat scalars, one key per line** — no nesting, no lists, no
multi-line values. That is what lets the scripts read it with `grep` and
`awk` and no YAML dependency:

```bash
grep -l '^closed: [0-9]' dev-docs/issues/*.md   # closed issues
grep -L '^closed: [0-9]' dev-docs/issues/*.md   # open issues
```

The id and slug live in the filename and the title in the `#` heading;
they are deliberately not duplicated into the frontmatter.
```

- [ ] **Step 4: Update the two remaining `issues/done/` references**

On line 50 (the roadmap section), replace `and [issues/done/](issues/done/)` with `and the closed issues themselves`. In the milestone rules a few lines below, replace `Completed items are **checked off, not removed** (with the link repointed at \`issues/done/\`), so the list shows progress.` with:

```markdown
  Completed items are **checked off, not removed**, so the list shows progress. The link never changes — it points at the same file whether the issue is open or closed.
```

- [ ] **Step 5: Update the "Closing an issue" paragraph**

Replace the sentence beginning `It moves the issue file to \`issues/done/\`…` with:

```markdown
It fills in the issue's `closed` date, removes the Open Issues entry (and its group heading if now empty), checks the issue's box in any milestone list, and stages the two changed files. Nothing moves and no links are rewritten. Review the roadmap before committing — milestone rationale text is prose and is not auto-edited.
```

Also update the "Consistency check" paragraph's description to match the new checks: `every open issue file has an Open Issues entry and every closed one does not, every roadmap link resolves, milestone checkboxes agree with each issue's `closed` field, the frontmatter block is well formed, and `.next-id.txt` is ahead of every ID ever used.`

- [ ] **Step 6: Update issue #13's Notes section**

In `dev-docs/issues/013-dev-docs-link-checker-not-fence-aware.md`, replace fix directions 2 and 3 with a single note recording what issue #18 settled:

```markdown
2. ~~**Repair the 4 real breaks**~~ — done under
   [#18](018-close-bash-rewrites-plan-prose.md): all four were links from
   one closed issue to another, and they were repaired when issues stopped
   moving into `done/`.
3. ~~**Consider the root cause in `bin/issues/close.bash`.**~~ — moot under
   [#18](018-close-bash-rewrites-plan-prose.md). There is no pass 3 or pass
   4 any more: an issue's status is a `closed:` frontmatter date, its file
   never moves, and no link to it is ever rewritten.

Remaining scope for this issue: fix direction 1 only — a fence-aware link
checker promoted out of a plan step into `bin/`.
```

- [ ] **Step 7: Verify no stale references remain and all links resolve**

```bash
grep -rn 'issues/done\|(done/' CLAUDE.md dev-docs/issue-conventions.md dev-docs/roadmap.md bin/ || echo "no stale references"
python3 /tmp/issue-018/check-links.py
bin/issues/check.bash
```

Expected: `no stale references`; `TOTAL 0`; `OK: 5 open, 14 closed, roadmap consistent, next id 20`.

`dev-docs/issues/` is deliberately not searched here: issues #13 and #18 describe the old `done/` layout in their prose and tables, and that text is the historical record of the bug being fixed. Only the live documentation had to change.

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md dev-docs/issue-conventions.md dev-docs/issues/013-dev-docs-link-checker-not-fence-aware.md
git commit -m "$(cat <<'EOF'
docs(issues): document status-as-frontmatter, retire the done/ split

Records the frontmatter contract and the flat-scalar rule in
issue-conventions.md, updates CLAUDE.md's description of close.bash, and
marks issue #13's fix directions 2 and 3 resolved — its remaining scope is
the fence-aware link checker.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Dogfood — close #18 with the new `close.bash`

**Files:**
- Modify: `dev-docs/issues/018-close-bash-rewrites-plan-prose.md` (its `closed:` line)
- Modify: `dev-docs/roadmap.md`

**Interfaces:**
- Consumes: everything above.
- Produces: the branch's final commit, per [CLAUDE.md](../../CLAUDE.md).

This is the acceptance test for the whole branch: the original bug was `close.bash` editing plans. If any file under `dev-docs/plans/` appears in this diff, the branch has failed.

- [ ] **Step 1: Record the pre-close state of the plans**

```bash
git status --short
md5sum dev-docs/plans/*.md > /tmp/issue-018/plans-before.txt
wc -l < /tmp/issue-018/plans-before.txt
```

Expected: a clean working tree, and 9 checksummed plan files (the eight existing plans plus this one).

- [ ] **Step 2: Close the issue**

```bash
bin/issues/close.bash 18
```

Expected: `closed dev-docs/issues/018-close-bash-rewrites-plan-prose.md (closed: <today>)`, then `OK: 4 open, 15 closed, roadmap consistent, next id 20`, then the commit hint.

- [ ] **Step 3: Prove no plan was touched**

```bash
md5sum -c /tmp/issue-018/plans-before.txt
git diff --cached --stat
```

Expected: every plan reports `OK`, and the staged diffstat names exactly two files — `dev-docs/issues/018-close-bash-rewrites-plan-prose.md` (1 insertion, 1 deletion) and `dev-docs/roadmap.md`. Under the old script this same command rewrote four lines of `dev-docs/plans/2026-07-31-plcc-ng-phase2-v5.md`.

- [ ] **Step 4: Confirm the issue file's own text is intact**

```bash
git diff --cached -- dev-docs/issues/018-close-bash-rewrites-plan-prose.md
```

Expected: a single hunk changing `closed:` to `closed: <today>`. The body — including the quoted `sed` command and every `dev-docs/issues/...` path in its prose — is unchanged.

- [ ] **Step 5: Final verification sweep**

```bash
bin/issues/check.bash
python3 /tmp/issue-018/check-links.py
grep -rn 'issues/done' bin/ CLAUDE.md dev-docs/issue-conventions.md || echo "no stale references"
```

Expected: `OK: 4 open, 15 closed, roadmap consistent, next id 20`; `TOTAL 0`; `no stale references`.

- [ ] **Step 6: Commit**

```bash
git commit -m "$(cat <<'EOF'
docs(issues): close issue 18 (close.bash rewrites plan prose), update roadmap

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Review the whole branch**

```bash
git log --oneline main..HEAD
git diff --stat main..HEAD
```

Expected: 9 commits — the design spec, this plan, and one per task. In the diffstat, `dev-docs/plans/` appears only for this plan file and for the four plans whose *live* link targets were repointed in Task 1 (`2026-07-23-plcc-ng-phase2-v2.md`, `2026-07-27-plcc-ng-2.0.0-update.md`, `2026-07-28-plcc-ng-phase2-v3.md`, `2026-07-30-plcc-ng-phase2-v4.md`), each with a handful of changed lines. It must never list `2026-07-22-plcc-ng-phase0-phase1.md`, `2026-07-22-plcc-ng-phase2-v1.md`, `2026-07-30-devcontainer-cache-diagnosis.md`, or `2026-07-31-plcc-ng-phase2-v5.md` — the V5 plan in particular is the file the old `close.bash` corrupted, and it must come through this branch untouched.

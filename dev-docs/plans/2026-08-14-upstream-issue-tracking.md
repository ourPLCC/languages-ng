# Upstream Issue Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make an issue in `dev-docs/issues/` track work in *this*
repository only, so open/closed answers "is there local work?" without
caching another repository's state.

**Architecture:** One optional frontmatter key, `upstream:`, pointing at
the upstream tracker entry. `check.bash` validates its shape when present
and never requires it, so no existing issue needs backfilling. The
convention document carries the rules; no script queries upstream.

**Tech Stack:** Bash 5 (`set -euo pipefail` throughout), bats 1.11,
plcc-ng spec files. No new dependencies.

**Spec:** [dev-docs/specs/2026-08-14-upstream-issue-tracking-design.md](../specs/2026-08-14-upstream-issue-tracking-design.md)

## Global Constraints

- **Run every command from the worktree root**, not the parent checkout.
  Confirm with `git branch --show-current` before each commit; it must
  print `worktree-issue-management`.
- **Commit types:** `docs` for documentation and for comment-only edits
  under `src/`; `chore` for `bin/` scripts and their tests. **Never `fix`
  or `feat`** — those bump the release version via `.releaserc.yaml`, and
  nothing here changes shipped language behavior.
- **Frontmatter is flat scalars, one key per line.** No nesting, no YAML
  lists, no multi-line values. This is what lets `grep` and `awk` read it
  with no YAML dependency.
- **`upstream:` is never required.** Absent and empty must both pass, or
  the 44 local issues need backfilling.
- **Ref format:** `owner/repo` + whitespace + issue filename. Never the
  GitHub `owner/repo#N` form — in `ourPLCC/plcc-ng` that numbering
  resolves to pull requests, and `#187` is a closed PR titled "069 improve
  parse trace".
- **`bin/test.bash` exit codes:** 0 = every test passed, 1 = real
  failures, 2 = the harness did not finish. Never read a 2 as a pass.
- **TEMPLATE.md's comment block is length-coupled.** Four documents
  promise `bin/issues/list.bash | xargs head -n 50` shows frontmatter,
  title, and summary. `## Summary` sits at template line 34; keep it well
  under 50. See [#50](../issues/050-head-idiom-coupled-to-template-comment.md).

**Out of scope, pending a decision:** [#19](../issues/019-python-recursion-ceiling.md)'s
upstream half (the "Specification error: RecursionError" wording belongs
to plcc-ng). Reporting it upstream is a public action needing explicit
go-ahead, so no task here touches #19.

---

### Task 1: Validate `upstream:` in check.bash

**Files:**
- Modify: `bin/issues/check.bash` (add constant near line 9; add block before the `done` at the end of the issue loop)
- Test: `bin/tests/issues-check.bats`

**Interfaces:**
- Consumes: `fm_value "${f}" <key>` and `fail "<message>"`, both already defined in `check.bash`.
- Produces: the `upstream:` ref format that Tasks 2, 4, and 5 write into documentation and issue files — `owner/repo` + whitespace + `NNN-slug.md`, comma-separated for multiple refs.

- [ ] **Step 1: Add the test helper**

Append to `bin/tests/issues-check.bats`, immediately after the existing
`make_issue()` function (which ends with `}` before the first `@test`):

```bash
# Write an open issue carrying an upstream: ref. An empty ref value leaves
# the key present but blank, which must still pass.
make_upstream_issue() {
  local name="$1" ref="$2"
  cat > "${REPO}/dev-docs/issues/${name}" <<EOF
---
type: chore
target: ourPLCC/plcc-ng
upstream:${ref:+ ${ref}}
opened: 2026-01-01
closed:
---

# ${name%%-*} - ${name}

## Summary

A one-paragraph triage summary.

## Description

The full account.
EOF
}
```

- [ ] **Step 2: Write the failing tests**

Append these seven tests to the end of `bin/tests/issues-check.bats`:

```bash
@test "check.bash accepts an issue with no upstream key" {
  make_issue "001-no-upstream.md" ""

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}

@test "check.bash accepts an empty upstream key" {
  make_upstream_issue "001-empty-upstream.md" ""

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}

@test "check.bash accepts a well-formed upstream ref" {
  make_upstream_issue "001-good-ref.md" "ourPLCC/plcc-ng 187-rep-lacks-output.md"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}

@test "check.bash accepts two comma-separated upstream refs" {
  make_upstream_issue "001-two-refs.md" \
    "ourPLCC/plcc-ng 186-rep-deadlocks.md, ourPLCC/plcc-ng 187-rep-lacks-output.md"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}

@test "check.bash rejects the GitHub owner/repo#N ref form" {
  make_upstream_issue "001-hash-form.md" "ourPLCC/plcc-ng#187"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"malformed upstream ref"* ]]
  [[ "${output}" == *"ourPLCC/plcc-ng#187"* ]]
}

@test "check.bash rejects an upstream ref with no repository" {
  make_upstream_issue "001-no-repo.md" "187-rep-lacks-output.md"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"malformed upstream ref"* ]]
}

@test "check.bash rejects a stray trailing comma in upstream" {
  make_upstream_issue "001-trailing-comma.md" "ourPLCC/plcc-ng 187-rep-lacks-output.md,"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"malformed upstream ref"* ]]
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bats bin/tests/issues-check.bats`

Expected: the first four pass (nothing validates `upstream:` yet, so
anything is accepted), and the last three **fail** — each expects status
1, but `check.bash` currently exits 0. If any of the first four fails,
stop: something other than this change is broken.

- [ ] **Step 4: Add the ref pattern constant**

In `bin/issues/check.bash`, insert after line 9 (`NEXT_ID_FILE=...`) and
before the blank line preceding `failures=0`:

```bash

# An upstream ref is "owner/repo" plus the issue's filename in that repo's
# dev-docs/issues/. Deliberately not GitHub's owner/repo#N form: upstream
# numbers issues and pull requests in one sequence, so #N there names a
# pull request, not the issue meant.
UPSTREAM_RE='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+[[:space:]]+[0-9]+-[A-Za-z0-9._-]+\.md$'
```

- [ ] **Step 5: Add the validation block**

In `bin/issues/check.bash`, inside the `for f in "${ISSUES_DIR}"/[0-9]*.md`
loop, insert immediately **before** the loop's closing `done` — that is,
after the `if [[ -z "${closed}" ]]; then ... fi` block that checks
`## Summary`:

```bash

    # `upstream:` is optional: absent and empty both mean "not reported".
    # When present, every comma-separated ref must be well formed. An empty
    # segment fails the pattern, which is what catches a stray comma.
    upstream="$(fm_value "${f}" upstream)"
    if [[ -n "${upstream}" ]]; then
        while IFS= read -r ref; do
            if [[ ! "${ref}" =~ ${UPSTREAM_RE} ]]; then
                fail "${basename} has a malformed upstream ref: '${ref}'"
            fi
        done < <(tr ',' '\n' <<< "${upstream}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    fi
```

Three things this shape is deliberate about, all verified in a scratch
run before this plan was written:

- `${UPSTREAM_RE}` is **unquoted** on the right of `=~`. Quoting it would
  match the pattern as a literal string and every ref would fail.
- The `while` loop's `read` is the loop *condition*, so its non-zero
  status at EOF does not trip `set -e`.
- The block ends in an `if`, which returns 0 when `upstream` is empty. It
  is the last statement in the loop body, so a bare `[[ ... ]] && ...`
  here would leave the body at status 1 and abort the run under `set -e`
  — the defect class recorded in
  [#25](../issues/025-relocate-copies-stale-build-artifacts.md).

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bats bin/tests/issues-check.bats`

Expected: all tests pass, including the seven added.

- [ ] **Step 7: Verify the real issue tree still checks out**

Run: `bin/issues/check.bash`

Expected: `OK: 18 open, 34 closed, next id 53`. No issue carries an
`upstream:` key yet, so this exercises the absent-key path against real
data.

- [ ] **Step 8: Commit**

```bash
git add bin/issues/check.bash bin/tests/issues-check.bats
git commit -m "chore(issues): validate the optional upstream: frontmatter ref

Accepts an absent or empty upstream: key so no existing issue needs
backfilling, and rejects a malformed ref. Rejects GitHub's owner/repo#N
form specifically: upstream numbers issues and pull requests in one
sequence, so ourPLCC/plcc-ng#187 resolves to a closed pull request rather
than the issue meant.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Document the field and the three cases

**Files:**
- Modify: `dev-docs/issue-conventions.md` (replace the whole `## The \`target\` field` section, line 92 through the line before `## Closing an issue`)
- Modify: `dev-docs/issues/TEMPLATE.md` (frontmatter block; one line in the comment block)

**Interfaces:**
- Consumes: the ref format from Task 1.
- Produces: the §"Upstream defects" heading that Task 2's TEMPLATE.md pointer and the issue edits in Tasks 4–6 refer to by name.

- [ ] **Step 1: Replace the conventions section**

In `dev-docs/issue-conventions.md`, replace the entire `## The \`target\`
field` section (everything from that heading up to but not including
`## Closing an issue`) with:

```markdown
## Upstream defects

Every issue's frontmatter names a `target` — the repository the **defect**
is in. It defaults to this repo; set it to the upstream repository (e.g.
`ourPLCC/plcc-ng`) when the defect is there rather than in this repo's own
`src/`.

An issue in `issues/` tracks work in **this** repository. Whether upstream
has fixed something is a fact about upstream: read it when you pick the
issue up, never record it here. A cached copy of another repo's status is
wrong by default and nothing detects the drift.

So open/closed answers **"is there local work?"**, and that question is
answerable without leaving this repo. An upstream defect is in exactly one
of three states:

- **Found, not yet reported.** The local work is to get the go-ahead and
  file it upstream. The issue is open with `upstream:` empty, and closes
  when the report is filed.
- **Reported, nothing here waits on it.** Close it, with `upstream:`
  naming the ref. The closed file keeps its reproduction detail
  permanently — issues never move, so links to it never break.
- **Reported, and a workaround lives in shipped `src/`.** The issue stays
  open and its subject is *the revert*. It closes when the workaround is
  gone, not when upstream ships.

A defect that straddles both repositories is **split by repository**: the
local half is an ordinary issue with `target: this repo`, and the upstream
half follows the three states above. There is no third "blocked on
upstream" issue.

Upstream-targeted issues still live in this repo's `issues/` like any
other issue — nothing is filed externally automatically. They get reported
upstream manually, with the reporter's explicit go-ahead, since that's a
public action outside this repo.

### The `upstream:` field

```yaml
upstream: ourPLCC/plcc-ng 187-rep-lacks-output-and-clean-exit-records.md
```

Two space-separated tokens — the repository, then the issue's filename in
that repository's `dev-docs/issues/`. Separate multiple refs with commas.
Empty or absent means not reported; the ref *is* the evidence of
reporting, which is why there's no separate `reported:` date.

Deliberately **not** `owner/repo#187`. Upstream numbers issues and pull
requests in one sequence, so that form names a pull request rather than
the issue meant. Deliberately not a URL either: upstream closes an issue
by moving the file into `dev-docs/issues/done/`, so a URL naming the open
path returns 404 exactly when the state changes. Repository-plus-filename
names the issue, not its location.

`bin/issues/check.bash` validates the shape when the key is non-empty and
never requires it.
```

- [ ] **Step 2: Add the key to the template frontmatter**

In `dev-docs/issues/TEMPLATE.md`, change the frontmatter block from:

```yaml
---
type: TYPE
target: this repo
opened: YYYY-MM-DD
closed:
---
```

to:

```yaml
---
type: TYPE
target: this repo
upstream:
opened: YYYY-MM-DD
closed:
---
```

- [ ] **Step 3: Add the one-line pointer to the comment block**

In the same file, in the HTML comment block, insert this single line
immediately after the `target` paragraph (the one ending "the defect is
there rather than in this repo's own src/.") and before the blank line
preceding the `closed` paragraph:

```

`upstream:` points at the upstream tracker entry — see "Upstream defects"
in dev-docs/issue-conventions.md. Leave it empty otherwise.
```

Keep it to these two lines. A full explanation here would push
`## Summary` past the `head -n 50` the documents promise; see
[#50](../issues/050-head-idiom-coupled-to-template-comment.md).

- [ ] **Step 4: Verify the template did not outgrow the head idiom**

Run: `grep -n "^## Summary" dev-docs/issues/TEMPLATE.md`

Expected: **38** — 34 before this change, plus one frontmatter line, two
comment lines, and the blank line separating the comment paragraphs. The
constraint that matters is 50: if it exceeds that, the documented
`head -n 50` idiom is broken and the comment addition must shrink.

- [ ] **Step 5: Verify a newly filed issue still passes**

```bash
bin/issues/new.bash probe-delete-me chore
bin/issues/check.bash
```

Expected: `check.bash` reports **one failure** — the new issue has no
`## Summary`. That is correct behavior and proves the template's blank
summary is still detected. The `upstream:` key must **not** be reported as
malformed.

- [ ] **Step 6: Remove the probe**

```bash
rm dev-docs/issues/053-probe-delete-me.md
printf '53\n' > dev-docs/issues/.next-id.txt
bin/issues/check.bash
```

Expected: `OK: 18 open, 34 closed, next id 53`.

- [ ] **Step 7: Commit**

```bash
git add dev-docs/issue-conventions.md dev-docs/issues/TEMPLATE.md
git commit -m "docs(issues): an issue tracks local work, not upstream status

Replaces the target-field section with an Upstream defects section stating
the rule and the three states an upstream defect can be in, and documents
the optional upstream: ref that points at the upstream tracker entry.

The template gets the key plus a one-line pointer rather than a full
explanation, because its comment block is length-coupled to the documented
head -n 50 idiom (issue 50).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Reattribute the OBJ buffering comments

**Files:**
- Modify: `src/OBJ/python/spec.plcc:15-19`
- Modify: `src/OBJ/java/spec.plcc:11-15`
- Modify: `src/OBJ/javascript/spec.plcc:615-619`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing later tasks depend on.

All three carry the same prose, differing only in comment marker (`#` for
Python, `//` for Java and JavaScript). The comment credits issue 36, but
only issue 37's upstream fix can remove the buffering — #36's fix alone
would turn the deadlock into a diagnostic without giving OBJ anywhere to
emit output.

- [ ] **Step 1: Rewrite the Python comment**

In `src/OBJ/python/spec.plcc`, replace:

```python
# Output is buffered rather than printed. plcc-rep uses this program's
# stdout as a private line-oriented JSON channel, so a partial line
# written here merges with the result record and deadlocks the tool with
# no diagnostic. See issue 36. Every output expression appends to `out`;
# only _run() emits it, as part of its return value.
```

with:

```python
# Output is buffered rather than printed. plcc-rep uses this program's
# stdout as a private line-oriented JSON channel, so a partial line
# written here merges with the result record and deadlocks the tool with
# no diagnostic (issue 36). Removing the buffering needs an output record
# kind from plcc-rep, which is issue 37 -- fixing issue 36 alone would
# only turn the deadlock into a diagnostic, with still nowhere to emit.
# Every output expression appends to `out`; only _run() emits it, as part
# of its return value.
```

- [ ] **Step 2: Rewrite the Java comment**

In `src/OBJ/java/spec.plcc`, make the identical change with `//` markers:

```java
// Output is buffered rather than printed. plcc-rep uses this program's
// stdout as a private line-oriented JSON channel, so a partial line
// written here merges with the result record and deadlocks the tool with
// no diagnostic (issue 36). Removing the buffering needs an output record
// kind from plcc-rep, which is issue 37 -- fixing issue 36 alone would
// only turn the deadlock into a diagnostic, with still nowhere to emit.
// Every output expression appends to `out`; only _run() emits it, as part
// of its return value.
```

- [ ] **Step 3: Rewrite the JavaScript comment**

In `src/OBJ/javascript/spec.plcc`, make the identical change with `//`
markers — the same eight lines as Step 2.

- [ ] **Step 4: Verify no stale attribution remains**

Run: `grep -rn "See issue 36" src/OBJ/`

Expected: **no output**. If any line matches, a spec was missed.

- [ ] **Step 5: Run the full suite**

Run: `bin/test.bash`

Expected: exit 0. These are comments, but `spec.plcc` files are compiled
by plcc-ng, so a mangled comment marker would break the build for that
target. Exit 2 means the harness did not finish — investigate rather than
re-run.

- [ ] **Step 6: Commit**

```bash
git add src/OBJ/python/spec.plcc src/OBJ/java/spec.plcc src/OBJ/javascript/spec.plcc
git commit -m "docs(obj): attribute the output buffering to issue 37, not 36

All three OBJ specs credited the Program.out buffering to issue 36, but
issue 36's upstream fix cannot remove it: a bounded read turns the
deadlock into a diagnostic while leaving OBJ with nowhere to emit output.
Only issue 37's output record kind releases the workaround. Keeps issue 36
named as the hazard that makes raw stdout unsafe.

Comment-only, so no version bump and no course-material impact.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Backfill `upstream:` refs

**Files:**
- Modify: `dev-docs/issues/037-plcc-rep-lacks-output-and-clean-exit-records.md` (frontmatter, and the status paragraph at line 137)
- Modify: `dev-docs/issues/036-plcc-rep-deadlocks-on-partial-stdout-line.md` (frontmatter)
- Modify: `dev-docs/issues/022-plcc-rep-parses-each-source-independently.md` (frontmatter)
- Modify: `dev-docs/issues/039-putc-puts-diverge-across-targets.md` (`## Notes`)

**Interfaces:**
- Consumes: the ref format validated in Task 1.
- Produces: the `upstream:` value on #36 that Task 5 relies on being present before closing it.

- [ ] **Step 1: Add the ref to #37**

In `dev-docs/issues/037-plcc-rep-lacks-output-and-clean-exit-records.md`,
change the frontmatter from:

```yaml
---
type: chore
target: ourPLCC/plcc-ng
opened: 2026-08-11
closed:
---
```

to:

```yaml
---
type: chore
target: ourPLCC/plcc-ng
upstream: ourPLCC/plcc-ng 187-rep-lacks-output-and-clean-exit-records.md
opened: 2026-08-11
closed:
---
```

- [ ] **Step 2: Add the ref to #36**

In `dev-docs/issues/036-plcc-rep-deadlocks-on-partial-stdout-line.md`, add
this line to the frontmatter, after `target:` and before `opened:`:

```yaml
upstream: ourPLCC/plcc-ng 186-rep-deadlocks-on-partial-stdout-line.md
```

- [ ] **Step 3: Add the ref to #22**

In `dev-docs/issues/022-plcc-rep-parses-each-source-independently.md`, add
this line to the frontmatter, after `target:` and before `opened:`:

```yaml
upstream: ourPLCC/plcc-ng 185-rep-parses-each-source-independently.md
```

- [ ] **Step 4: Remove #37's cached upstream status**

#37 is open, so its dated status note is a live cache and must go — that
is the whole point of the `upstream:` ref. Keep the consequences it
records, which are real and local.

In `dev-docs/issues/037-plcc-rep-lacks-output-and-clean-exit-records.md`,
replace:

```markdown
**Upstream status, checked 2026-08-13** against `ourPLCC/plcc-ng` at
`48fb1a5` (v2.0.2): #187 is still open — in `dev-docs/issues/`, not
`done/` — and no branch is working it. This is the one whose arrival
unblocks local work: the revert of OBJ's `Program.out` buffering, the
restoration of `exit`'s clean exit status, and the removal of both
caveats from [course-material-impact.md](../course-material-impact.md)
under `## OBJ`. Issue [#006](006-multi-capture-alt-name-case-mismatch.md)
is the model — workaround ships, upstream fixes the root cause, workaround
is reverted with an impact-log note.
```

with:

```markdown
**What upstream's fix unblocks here:** the revert of OBJ's `Program.out`
buffering, the restoration of `exit`'s clean exit status, and the removal
of both caveats from [course-material-impact.md](../course-material-impact.md)
under `## OBJ`. Issue [#006](006-multi-capture-alt-name-case-mismatch.md)
is the model — workaround ships, upstream fixes the root cause, workaround
is reverted with an impact-log note.

Check the upstream entry named in `upstream:` when picking this up. Its
state is deliberately not recorded here: a recorded copy is wrong by
default and nothing detects the drift.
```

**Do not make this edit to #22 or #36.** Both are closed (or become closed
in Task 5), and on a closed issue a dated status note is history rather
than a cache — it records what was true at close time and stays.

- [ ] **Step 5: Record #39's upstream half**

In `dev-docs/issues/039-putc-puts-diverge-across-targets.md`, append to the
`## Notes` section:

```markdown
**This defect straddles two repositories.** The 16-bit truncation in Java
and JavaScript is this repo's — it is the `(char)` cast and
`String.fromCharCode` in the specs above, and the fix is local. But
Python's `ValueError` escaping as a session-fatal "Specification error" is
plcc-ng's error handling: the string appears nowhere in `src/**/*.plcc`.
Per "Upstream defects" in [issue-conventions.md](../issue-conventions.md),
the local half stays here and the upstream half is reported separately;
this issue keeps `target: this repo` because its fix is local.
```

- [ ] **Step 6: Verify the refs validate**

Run: `bin/issues/check.bash`

Expected: `OK: 18 open, 34 closed, next id 53`. A typo in any ref
surfaces here as "malformed upstream ref".

- [ ] **Step 7: Commit**

```bash
git add dev-docs/issues/037-plcc-rep-lacks-output-and-clean-exit-records.md \
        dev-docs/issues/036-plcc-rep-deadlocks-on-partial-stdout-line.md \
        dev-docs/issues/022-plcc-rep-parses-each-source-independently.md \
        dev-docs/issues/039-putc-puts-diverge-across-targets.md
git commit -m "docs(issues): point 22, 36, and 37 at their upstream entries

Adds a frontmatter ref naming the file in ourPLCC/plcc-ng's
dev-docs/issues/, so a reader can check the live state instead of trusting
a copy. Drops 37's dated status paragraph, which was exactly such a copy
and began going stale the moment it was committed, while keeping the local
consequences it recorded. Leaves the equivalent paragraphs on 22 and 36
alone: those issues are closed, so the note is history rather than a cache.

Records on 39 that it straddles both repos: the truncation is this repo's,
the session-fatal Specification error is plcc-ng's.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Close #36 as reported-with-no-local-consequence

**Files:**
- Modify: `dev-docs/issues/036-plcc-rep-deadlocks-on-partial-stdout-line.md`

**Interfaces:**
- Consumes: the `upstream:` ref added to #36 in Task 4.
- Produces: nothing later tasks depend on.

This is the substantive judgment in the plan, separated so it can be
reviewed on its own. #36 is real and reported, but nothing in `src/` waits
on it: the buffering it is credited with is released by #37 alone
(Task 3). That makes it the "reported, nothing here waits on it" state.

- [ ] **Step 1: Replace #36's stays-open condition**

In `dev-docs/issues/036-plcc-rep-deadlocks-on-partial-stdout-line.md`,
replace this paragraph near the end:

```markdown
This issue stays open while OBJ's `Program.out` buffering workaround lives
in `src/`.
```

with:

```markdown
**Closed 2026-08-14 with upstream still open.** This issue was recorded as
staying open while OBJ's `Program.out` buffering lives in `src/`, but that
condition belongs to [#37](037-plcc-rep-lacks-output-and-clean-exit-records.md),
not here. Removing the buffering needs an output record kind, which is
upstream #187; a bounded read fixing *this* defect would turn the deadlock
into a diagnostic and leave OBJ with nowhere to emit output. So nothing in
`src/` waits on this issue.

The defect is real and is reported upstream — see `upstream:` above. Per
"Upstream defects" in [issue-conventions.md](../issue-conventions.md), an
upstream defect with no local consequence closes here rather than tracking
someone else's tracker. If a fix arrives and OBJ later wants to emit
output directly, that is #37's revert, not a reopening of this issue.
```

- [ ] **Step 2: Close it**

```bash
bin/issues/close.bash 36
```

This fills in the `closed:` date and stages the file. It runs
`check.bash` itself.

- [ ] **Step 3: Verify the count moved**

Run: `bin/issues/check.bash`

Expected: `OK: 17 open, 35 closed, next id 53`.

- [ ] **Step 4: Commit**

```bash
git commit -m "docs(issues): close issue 36 (plcc-rep deadlocks on a partial stdout line)

The defect is real and reported upstream, but nothing in src/ waits on it.
Issue 36 was credited with OBJ's Program.out buffering, and all three specs
cited it, but only issue 37's output record kind can remove that buffering:
a bounded read here would turn the deadlock into a diagnostic and still
leave OBJ nowhere to emit. With no local consequence, tracking it open here
overstates what is outstanding.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Close #52

**Files:**
- Modify: `dev-docs/issues/052-upstream-issues-track-local-work-only.md`

**Interfaces:**
- Consumes: every preceding task.
- Produces: nothing.

- [ ] **Step 1: Run the full suite one final time**

Run: `bin/test.bash`

Expected: exit 0. Do not proceed on exit 1 or 2.

- [ ] **Step 2: Confirm the branch**

Run: `git branch --show-current`

Expected: `worktree-issue-management`. If it prints anything else, stop —
commits have been landing somewhere unintended.

- [ ] **Step 3: Close the issue**

```bash
bin/issues/close.bash 52
```

- [ ] **Step 4: Verify**

Run: `bin/issues/check.bash`

Expected: `OK: 16 open, 36 closed, next id 53`.

- [ ] **Step 5: Commit**

```bash
git commit -m "docs(issues): close issue 52 (upstream issues track local work)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Verification summary

After Task 6 the branch should show:

- `bin/test.bash` exit 0
- `bin/issues/check.bash` → `OK: 16 open, 36 closed, next id 53`
- `grep -rn "See issue 36" src/OBJ/` → no output
- `grep -n "^## Summary" dev-docs/issues/TEMPLATE.md` → 37 or lower
- Three issues carrying an `upstream:` ref (#22, #36, #37), and no other
  issue carrying the key

# Retire the roadmap — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete `dev-docs/roadmap.md` and every script pass that maintained
it, after moving each open issue's one-paragraph summary into a required
`## Summary` section in the issue file itself.

**Architecture:** The backlog stops having two representations. Issue files
become the only record: `closed:` is the status, `bin/issues/list.bash`
enumerates, `bin/issues/check.bash` validates. Work proceeds in an order that
leaves the tree green at every commit — summaries migrate while the roadmap
still exists, then the scripts stop reading it, then the file is deleted.

**Tech Stack:** Bash (`set -euo pipefail`), `awk`, `grep`, `sed`, bats for
tests. No YAML parser — frontmatter is flat scalars read with `awk`/`grep`.

**Spec:** [dev-docs/specs/2026-08-14-retire-roadmap-design.md](../specs/2026-08-14-retire-roadmap-design.md)

## Global Constraints

- **Branch:** all work lands on `worktree-issue-049-retire-roadmap-open-issues`
  in the worktree `/workspaces/languages-ng/.claude/worktrees/issue-049-retire-roadmap-open-issues`.
  Confirm with `git branch --show-current` before every commit. Never `cd` to
  `/workspaces/languages-ng`.
- **Every commit leaves `bin/issues/check.bash` exiting 0.** It is the gate;
  no task ends with it red.
- **Do not run `bin/test.bash`.** It is the ~75-minute language suite and
  touches nothing here. Run the specific bats file each task names.
- **Issue files never move.** Filenames and slugs are permanent even when a
  title changes; links to them must never be rewritten.
- **Frontmatter is flat scalars, one key per line.** No key is added by this
  work — the summary is a body section.
- **Commit types** follow [CONTRIBUTING.md](../../CONTRIBUTING.md): `docs` for
  documentation and issue bookkeeping, `chore` for scripts under `bin/` and
  `test` for files under `bin/tests/`. Nothing here is `fix` or `feat` —
  nothing ships in `src/`, and the version must not bump.
- **Commit message trailer** on every commit:
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- **The Summary invariant is open-only:** `check.bash` requires a non-empty
  `## Summary` when `closed:` is empty, and says nothing about closed issues.

---

### Task 1: Move the 17 summaries into their issue files

The roadmap's Open Issues entries are the only copy of this prose. Move it
before anything deletes it. No script changes here, so `check.bash` keeps
passing throughout.

**Files:**
- Modify: all 17 files listed by `bin/issues/list.bash`
- Read (not modified): `dev-docs/roadmap.md`

**Interfaces:**
- Consumes: nothing.
- Produces: every open issue file contains, between its `#` title and its
  `## Description` heading, a `## Summary` heading followed by a blank line
  and one paragraph of prose. Tasks 3 and 7 depend on this shape.

**The transformation.** Each roadmap entry is exactly two lines:

```markdown
- **[#44](issues/044-relocate-swallows-git-failure-reason.md) — relocate swallows git's reason for refusing a checkout**
  `relocate_copy_tree`'s opening guard sends git's stderr to `/dev/null` and replaces it with "is not in a git checkout", which is the least likely of the reasons `rev-parse --git-dir` can fail under `src/`. It cost a CI round-trip on issue #12: all 165 language tests failed against a perfectly good checkout that git was refusing as dubious ownership, and git's own message naming the `safe.directory` remedy had been discarded. Same shape as #28.
```

The bolded text after `— ` is the title. The indented second line is the
summary. For `044-relocate-swallows-git-failure-reason.md`, whose `#` heading
is still the raw slug, the result is:

```markdown
# 044 - relocate swallows git's reason for refusing a checkout

## Summary

`relocate_copy_tree`'s opening guard sends git's stderr to `/dev/null` and
replaces it with "is not in a git checkout", which is the least likely of
the reasons `rev-parse --git-dir` can fail under `src/`. It cost a CI
round-trip on issue #12: all 165 language tests failed against a perfectly
good checkout that git was refusing as dubious ownership, and git's own
message naming the `safe.directory` remedy had been discarded. Same shape
as #28.

## Description
```

Rewrap the summary to the file's prose width (~76 columns). Change no words,
add none, drop none — including the `#NN` cross-references, which stay as
plain text exactly as written.

**Titles.** Twelve issues already have a real `#` heading; leave those
headings alone even where the roadmap's bold title is worded differently.
Five still carry the raw slug and get the roadmap's title:

The five new headings, written exactly as they must appear (the backticks
are literal — the roadmap entries carry them):

```markdown
# 016 - cross-target integer divergence
# 019 - Python recursion ceiling far below Java/JavaScript
# 027 - use `plcc-rep -s` instead of copying `src/` into each test tmpdir
# 028 - relocate's `[[ -e ]]` filter hides permission errors
# 044 - relocate swallows git's reason for refusing a checkout
```

Those go into `016-cross-target-integer-divergence.md`,
`019-python-recursion-ceiling.md`,
`027-use-spec-flag-instead-of-copying-tree.md`,
`028-relocate-filter-hides-permission-errors.md`, and
`044-relocate-swallows-git-failure-reason.md` respectively, replacing each
file's existing slug heading. The filenames do not change.

- [ ] **Step 1: Confirm the branch**

```bash
git branch --show-current
```

Expected: `worktree-issue-049-retire-roadmap-open-issues`

- [ ] **Step 2: List the work**

```bash
bin/issues/list.bash
```

Expected: 17 paths — issues 016, 019, 020, 027, 028, 033, 036, 037, 039, 040,
041, 042, 043, 044, 046, 047, 049.

- [ ] **Step 3: Edit all 17 files**

For each, insert the `## Summary` section between the `#` title and
`## Description`, per the transformation above, and retitle the five in the
table. Issue 020's summary moves verbatim like the rest — Task 7 rewrites it
once the roadmap is actually gone.

- [ ] **Step 4: Verify every summary matches its roadmap entry**

This compares each file's Summary against the roadmap entry it came from,
ignoring only line wrapping.

```bash
norm() { tr '\n\t' '  ' | tr -s ' ' | sed -e 's/^ *//' -e 's/ *$//'; }
while IFS= read -r f; do
    base="${f##*/}"
    entry=$(awk -v link="(issues/${base})" '
        found { if ($0 ~ /^[ \t]/) { sub(/^[ \t]+/, ""); print; next } else exit }
        /^- / && index($0, link) { found = 1 }
    ' dev-docs/roadmap.md | norm)
    summary=$(awk '
        /^## Summary[[:space:]]*$/ { in_s = 1; next }
        in_s && /^## / { exit }
        in_s { print }
    ' "${f}" | norm)
    if [[ "${entry}" != "${summary}" ]]; then
        echo "MISMATCH: ${base}"
        echo "  roadmap: ${entry}"
        echo "  file:    ${summary}"
    fi
done < <(bin/issues/list.bash)
echo "comparison done"
```

Expected: no `MISMATCH` lines at all, then `comparison done`. Any mismatch is
a transcription error — fix the file, do not adjust the check.

- [ ] **Step 5: Verify the five retitles**

```bash
bin/issues/list.bash | xargs grep -h '^# '
```

Expected: 17 headings, none of which is a bare hyphenated slug. Compare
against the table above.

- [ ] **Step 6: Confirm nothing else broke**

```bash
bin/issues/check.bash
```

Expected: `OK: 17 open, 32 closed, roadmap consistent, next id 50`

- [ ] **Step 7: Commit**

```bash
git add dev-docs/issues
git commit -m "docs(issues): move roadmap summaries into the issue files

Each open issue gains a '## Summary' section holding its Open Issues
entry verbatim, and the five issues still headed by their raw slug take
the entry's title. The roadmap is unchanged; this only stops its prose
from being the only copy.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Stop `check.bash` reading the roadmap

**Files:**
- Create: `bin/tests/issues-check.bats`
- Modify: `bin/issues/check.bash` — delete line 9 (`ROADMAP=`), lines 77-85
  (both entry passes), lines 88-92 (link resolution), lines 94-113 (milestone
  reconciliation), and the success message on line 124

**Interfaces:**
- Consumes: the `## Summary` shape from Task 1 (the test helper writes it, so
  the fixtures stay valid once Task 3 lands).
- Produces: `bin/tests/issues-check.bats` with `setup()` and a `make_issue`
  helper that Task 3 extends. `check.bash` prints
  `OK: <n> open, <m> closed, next id <k>`.

- [ ] **Step 1: Write the failing test**

Create `bin/tests/issues-check.bats`:

```bash
#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# Exercises bin/issues/check.bash against a throwaway repo laid out like
# this one, so the real dev-docs/issues/ is never read.
setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/bin/issues" "${REPO}/dev-docs/issues"

  cp "${BATS_TEST_DIRNAME}/../issues/check.bash" "${REPO}/bin/issues/check.bash"
  echo 900 > "${REPO}/dev-docs/issues/.next-id.txt"
}

# Write a well-formed issue file. A blank closed value means open.
make_issue() {
  local name="$1" closed="$2"
  cat > "${REPO}/dev-docs/issues/${name}" <<EOF
---
type: chore
target: this repo
opened: 2026-01-01
closed:${closed:+ ${closed}}
---

# ${name%%-*} - ${name}

## Summary

A one-paragraph triage summary.

## Description

The full account.
EOF
}

@test "check.bash passes an open issue with no roadmap.md present" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1 open, 0 closed"* ]]
}

@test "check.bash passes a closed issue with no roadmap.md present" {
  make_issue "001-closed-one.md" "2026-01-02"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"0 open, 1 closed"* ]]
}

@test "check.bash never mentions the roadmap" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/check.bash"

  [[ "${output}" != *"roadmap"* ]]
}

@test "check.bash still rejects a malformed opened date" {
  make_issue "001-open-one.md" ""
  sed -i 's/^opened: .*/opened: January 1st/' "${REPO}/dev-docs/issues/001-open-one.md"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"malformed opened date"* ]]
}

@test "check.bash still rejects an id at or above .next-id.txt" {
  make_issue "901-too-new.md" ""

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"already exists"* ]]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
bats bin/tests/issues-check.bats
```

Expected: the first three fail. The first two report
`open issue 001-open-one.md has no Open Issues entry in dev-docs/roadmap.md`
(or the closed-issue equivalent) because `grep` is reading a file that does
not exist in the fixture. The last two pass already — they guard behavior
this task must not break.

- [ ] **Step 3: Delete the four roadmap passes**

In `bin/issues/check.bash`, delete the `ROADMAP="dev-docs/roadmap.md"`
assignment. Replace the entry-presence block, currently:

```bash
    # Open issues are listed in the roadmap; closed ones are not.
    if [[ -z "${closed}" ]]; then
        grep -q "^- \*\*\[#${id}\](issues/${basename})" "${ROADMAP}" \
            || fail "open issue ${basename} has no Open Issues entry in ${ROADMAP}"
    else
        if grep -q "^- \*\*\[#${id}\](issues/${basename})" "${ROADMAP}"; then
            fail "closed issue ${basename} still has an Open Issues entry in ${ROADMAP}"
        fi
    fi
```

with nothing — Task 3 puts the Summary check in its place. Then delete both
`while IFS= read -r` loops that follow the file loop: the link-resolution one
introduced by `# Every roadmap issue link resolves.` and the milestone one
introduced by `# Milestone task lists: ...`. Keep the `.next-id.txt` check.
Change the final line to:

```bash
echo "OK: ${open_count} open, ${closed_count} closed, next id ${next_id}"
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
bats bin/tests/issues-check.bats
```

Expected: 5 tests, 0 failures.

- [ ] **Step 5: Verify against the real tree**

```bash
bin/issues/check.bash
```

Expected: `OK: 17 open, 32 closed, next id 50` — the roadmap still exists and
is simply no longer consulted.

- [ ] **Step 6: Commit**

```bash
git add bin/issues/check.bash bin/tests/issues-check.bats
git commit -m "chore(issues): stop check.bash reading the roadmap

Deletes the two Open Issues entry-presence passes, the roadmap link
resolution pass, and the milestone checkbox reconciliation pass, none of
which govern any content: the roadmap holds no milestone lines. Adds
bin/tests/issues-check.bats, the script's first tests.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Require a `## Summary` on open issues

**Files:**
- Modify: `bin/issues/check.bash` — add the check where Task 2 removed the
  entry-presence block
- Modify: `bin/tests/issues-check.bats` — add a helper and five tests
- Modify: `dev-docs/issues/TEMPLATE.md`

**Interfaces:**
- Consumes: `make_issue` and `setup()` from Task 2's bats file.
- Produces: `check.bash` fails an open issue whose Summary is missing or
  blank, with the message
  `open issue <name> has no non-empty '## Summary' section`.

- [ ] **Step 1: Write the failing tests**

Append to `bin/tests/issues-check.bats`, after `make_issue`:

```bash
# Write an issue whose body is exactly the given lines: for Summary shapes
# that make_issue's well-formed body cannot express.
make_issue_body() {
  local name="$1" closed="$2" body="$3"
  cat > "${REPO}/dev-docs/issues/${name}" <<EOF
---
type: chore
target: this repo
opened: 2026-01-01
closed:${closed:+ ${closed}}
---

# ${name%%-*} - ${name}

${body}
EOF
}
```

and these tests at the end of the file:

```bash
@test "check.bash rejects an open issue with no Summary section" {
  make_issue_body "001-no-summary.md" "" "## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"001-no-summary.md has no non-empty '## Summary' section"* ]]
}

@test "check.bash rejects an open issue whose Summary is empty" {
  make_issue_body "001-empty-summary.md" "" "## Summary

## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"has no non-empty '## Summary' section"* ]]
}

@test "check.bash rejects a Summary holding only whitespace" {
  printf '%s\n' '---' 'type: chore' 'target: this repo' 'opened: 2026-01-01' \
      'closed:' '---' '' '# 001 - ws' '' '## Summary' '   ' '	' \
      '## Description' '' 'x' > "${REPO}/dev-docs/issues/001-ws-summary.md"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"has no non-empty '## Summary' section"* ]]
}

@test "check.bash does not require a Summary on a closed issue" {
  make_issue_body "001-closed-no-summary.md" "2026-01-02" "## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}

@test "check.bash accepts a Summary containing a ### subheading" {
  make_issue_body "001-sub.md" "" "## Summary

Prose.

### An aside

More prose.

## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
bats bin/tests/issues-check.bats
```

Expected: the three rejection tests fail (status 0, no message — nothing
checks Summaries yet). The two acceptance tests pass already.

- [ ] **Step 3: Add the check**

In `bin/issues/check.bash`, in the per-file loop where Task 2 removed the
entry-presence block, add:

```bash
    # An open issue carries the triage summary that used to live in the
    # roadmap's Open Issues entry. Closed issues are not required to.
    if [[ -z "${closed}" ]]; then
        awk '
            $0 ~ /^## Summary[[:space:]]*$/ { in_s = 1; next }
            in_s && /^## /                  { exit }
            in_s && NF                      { found = 1; exit }
            END                             { exit !found }
        ' "${f}" || fail "open issue ${basename} has no non-empty '## Summary' section"
    fi
```

Entering the section sets the state, the next `## ` heading ends it, and the
first non-blank line inside it succeeds. `awk`'s `exit` runs `END`, where
`found` is unset unless proven — so a file with no Summary at all fails.
`/^## /` requires the space, so a `### ` subheading does not end the section.
A whitespace-only line has `NF == 0` and does not count as content.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
bats bin/tests/issues-check.bats
```

Expected: 10 tests, 0 failures.

- [ ] **Step 5: Verify against the real tree**

```bash
bin/issues/check.bash
```

Expected: `OK: 17 open, 32 closed, next id 50`. This is the payoff from Task
1 — every open issue already has its Summary.

- [ ] **Step 6: Add the section to the template**

In `dev-docs/issues/TEMPLATE.md`, insert between the `# NNN - Short
descriptive title` heading's comment block and `## Description`:

```markdown
## Summary

```

Leave the body empty. Then add this paragraph to the existing HTML comment
block, after the `closed` sentence:

```
`## Summary` is one paragraph: what is wrong and why it matters, for
someone triaging the backlog without opening the file. It is required
while the issue is open — bin/issues/check.bash fails until you write
it — and it is deliberately blank here so that filing an issue and
leaving it unsummarized is not a silent state. The full account belongs
in `## Description`.
```

- [ ] **Step 7: Verify the template produces a check-failing issue**

```bash
bin/issues/new.bash scratch-template-probe chore
bin/issues/check.bash || echo "expected failure"
```

Expected: `check.bash` fails naming the new file's missing Summary, then
`expected failure`. That is the forcing function working.

- [ ] **Step 8: Undo the probe**

```bash
rm dev-docs/issues/050-scratch-template-probe.md
echo 50 > dev-docs/issues/.next-id.txt
bin/issues/check.bash
```

Expected: `OK: 17 open, 32 closed, next id 50`. Confirm `git status` shows no
change to `.next-id.txt` before committing.

- [ ] **Step 9: Commit**

```bash
git add bin/issues/check.bash bin/tests/issues-check.bats dev-docs/issues/TEMPLATE.md
git commit -m "chore(issues): require a '## Summary' on every open issue

The triage prose the roadmap's Open Issues entries carried now lives in
the issue file, so check.bash enforces it there: a non-empty '## Summary'
while 'closed:' is empty, and nothing once the issue closes. TEMPLATE.md
ships the heading with an empty body, so filing without a summary fails
the check rather than passing with a placeholder.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Stop `close.bash` editing the roadmap

**Files:**
- Create: `bin/tests/issues-close.bats`
- Modify: `bin/issues/close.bash` — delete line 9 (`ROADMAP=`), lines 72-74
  (checkbox `sed`), lines 76-100 (entry-removal `awk`), and adjust the
  `git add`, usage text, and closing output

**Interfaces:**
- Consumes: `check.bash` as modified by Tasks 2 and 3 — `close.bash` invokes
  it, so the test fixture must contain both scripts and every fixture issue
  must have a Summary.
- Produces: `close.bash` stages exactly one file and prints
  `docs(issues): close issue N (<short title>)`.

- [ ] **Step 1: Write the failing test**

Create `bin/tests/issues-close.bats`:

```bash
#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# Exercises bin/issues/close.bash against a throwaway git repo laid out
# like this one. close.bash stages its work, so the fixture must be a git
# repo; it also runs check.bash, so that script is copied in too.
setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/bin/issues" "${REPO}/dev-docs/issues"

  cp "${BATS_TEST_DIRNAME}/../issues/close.bash" "${REPO}/bin/issues/close.bash"
  cp "${BATS_TEST_DIRNAME}/../issues/check.bash" "${REPO}/bin/issues/check.bash"
  echo 900 > "${REPO}/dev-docs/issues/.next-id.txt"

  git init -q "${REPO}"
}

make_issue() {
  local name="$1" closed="$2"
  cat > "${REPO}/dev-docs/issues/${name}" <<EOF
---
type: chore
target: this repo
opened: 2026-01-01
closed:${closed:+ ${closed}}
---

# ${name%%-*} - ${name}

## Summary

A one-paragraph triage summary.

## Description

The full account.
EOF
}

@test "close.bash closes an issue with no roadmap.md present" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -eq 0 ]
  grep -q "^closed: 20" "${REPO}/dev-docs/issues/001-open-one.md"
}

@test "close.bash never mentions the roadmap" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -eq 0 ]
  [[ "${output}" != *"roadmap"* ]]
  [[ "${output}" != *"Roadmap"* ]]
}

@test "close.bash stages only the issue file" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -eq 0 ]
  run git -C "${REPO}" diff --cached --name-only
  [ "${output}" = "dev-docs/issues/001-open-one.md" ]
}

@test "close.bash refuses an already-closed issue" {
  make_issue "001-closed-one.md" "2026-01-02"

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"already closed"* ]]
}

@test "close.bash refuses an id with no issue file" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 2

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"no issue matching"* ]]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
bats bin/tests/issues-close.bats
```

Expected: the first three fail. `sed -i` on the nonexistent
`dev-docs/roadmap.md` errors under `set -e`, so `close.bash` dies before it
prints anything. The last two pass — they guard the argument handling this
task must not disturb.

- [ ] **Step 3: Delete both roadmap passes**

In `bin/issues/close.bash`:

- Delete the `ROADMAP="dev-docs/roadmap.md"` assignment.
- Delete the `# Roadmap, pass 1` comment and its `sed -i` line.
- Delete the `# Roadmap, pass 2` comment and the whole `awk ... > "${ROADMAP}.tmp"`
  block through `mv "${ROADMAP}.tmp" "${ROADMAP}"`.
- Change `git add "${issue_file}" "${ROADMAP}"` to `git add "${issue_file}"`.
- In `usage()`, replace the two sentences naming the roadmap so the block reads:

```bash
    echo "Fills in the issue's 'closed' date and stages the file."
    echo
    echo "Issue files never move: status is the 'closed' frontmatter field,"
    echo "so no link to an issue ever needs rewriting."
```

- Replace the final two `echo` lines with:

```bash
echo "closed ${issue_file} (closed: ${today})"
echo "Commit:"
echo "  docs(issues): close issue $(( 10#$1 )) (<short title>)"
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
bats bin/tests/issues-close.bats
```

Expected: 5 tests, 0 failures.

- [ ] **Step 5: Confirm the real tree is untouched**

```bash
bin/issues/check.bash
git status --short
```

Expected: `OK: 17 open, 32 closed, next id 50`, and `git status` shows only
the two files this task edits. The bats runs happen in throwaway repos and
must never have staged anything here.

- [ ] **Step 6: Commit**

```bash
git add bin/issues/close.bash bin/tests/issues-close.bats
git commit -m "chore(issues): stop close.bash editing the roadmap

Deletes the milestone-checkbox sed and the entry-removal awk, so closing
an issue now fills in its date, stages one file, and runs check.bash.
Adds bin/tests/issues-close.bats, the script's first tests.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Delete the roadmap

Nothing reads it now.

**Files:**
- Delete: `dev-docs/roadmap.md`
- Modify: `dev-docs/index.md:5`

**Interfaces:**
- Consumes: Tasks 2 and 4 — both scripts must already ignore the file.
- Produces: no live reference to `dev-docs/roadmap.md` outside `dev-docs/plans/`,
  `dev-docs/specs/`, and issue files.

- [ ] **Step 1: Confirm no script reads it**

```bash
grep -rn "roadmap" bin/
```

Expected: no output.

- [ ] **Step 2: Delete the file and its navigation link**

```bash
git rm dev-docs/roadmap.md
```

Then remove the `- [Roadmap](roadmap.md)` bullet from `dev-docs/index.md`,
leaving Architecture and Issue Conventions.

- [ ] **Step 3: Verify what still mentions it**

```bash
grep -rln "roadmap" --exclude-dir=.git --exclude-dir=.claude .
```

Expected: only paths under `dev-docs/plans/`, `dev-docs/specs/`, and
`dev-docs/issues/`. The four archived plans that link to it keep their now-dangling
links on purpose — they are dated snapshots, and editing them falsifies the
record. `CLAUDE.md`, `CONTRIBUTING.md`, and `dev-docs/issue-conventions.md`
still appear here; Task 6 clears them.

- [ ] **Step 4: Confirm the checker is green**

```bash
bin/issues/check.bash
bats bin/tests/issues-check.bats bin/tests/issues-close.bats
```

Expected: `OK: 17 open, 32 closed, next id 50`, then 10 tests and 5 tests,
0 failures.

- [ ] **Step 5: Commit**

```bash
git add -A dev-docs/roadmap.md dev-docs/index.md
git commit -m "docs: delete dev-docs/roadmap.md

Every line of the file was the Open Issues section, whose prose now lives
in the issue files and whose list bin/issues/list.bash derives from them.
No milestone section was ever written, so the milestone convention retires
with the file rather than losing any content.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Update the conventions and the two instruction files

**Files:**
- Modify: `dev-docs/issue-conventions.md` — lines 3, 15-22, 72, 105-118,
  128-130, 136
- Modify: `CLAUDE.md` — lines 46, 48, 50
- Modify: `CONTRIBUTING.md` — lines 8-12, 45, 46

**Interfaces:**
- Consumes: the final behavior of both scripts (Tasks 2-4).
- Produces: nothing downstream.

- [ ] **Step 1: Rewrite `dev-docs/issue-conventions.md`**

Line 3 — replace `indexed by [roadmap.md](roadmap.md)` so the sentence reads:

```markdown
Issues are tracked as files in [issues/](issues/), listed by [bin/issues/list.bash](../bin/issues/list.bash). Issues never move: an issue is closed when its `closed` frontmatter field holds a date. There is no external tracker; the repository is the source of truth.
```

In **Filing an issue**, replace the roadmap-entry paragraph and its code
block (lines 15-20) with:

```markdown
In the same commit, write the issue's `## Summary` — the template ships the
heading with an empty body, and `check.bash` fails while it stays empty.
```

Line 72 — change `head -n 15` to `head -n 20` in the code block, and the
trailing comment to `# frontmatter, title, and summary`.

Delete the entire **## The roadmap** section (lines 105-118). In its place,
after the **Frontmatter** section, add:

```markdown
## The summary

Every open issue carries a `## Summary` between its `#` title and its
`## Description`: one paragraph saying what is wrong and why it matters,
written for someone triaging the backlog without opening the file.

It is required while the issue is open and not required once it closes —
the section exists to triage open work, and closed work needs no triage.
`bin/issues/check.bash` enforces exactly that.

This is where the roadmap's Open Issues entries went. That section listed
every open issue a second time, in a single shared file, so two branches
that each filed an issue conflicted over an index neither had really
changed. The list now derives from the issue files themselves.
```

Line 128 — replace the `close.bash` description with:

```markdown
It fills in the issue's `closed` date and stages the file. Nothing moves and no links are rewritten.
```

Line 130 — the commit message becomes:

```markdown
Commit message: `docs(issues): close issue N (<short title>)`.
```

Line 136 — replace the invariant list:

```markdown
[bin/issues/check.bash](../bin/issues/check.bash) verifies the invariants: the frontmatter block is well formed and carries all four keys, the `opened` and `closed` dates parse, every open issue has a non-empty `## Summary`, and `.next-id.txt` is ahead of every ID ever used. `close.bash` runs it automatically; run it directly after filing an issue or during periodic sweeps. It exits non-zero on any drift.
```

- [ ] **Step 2: Rewrite the three `CLAUDE.md` lines**

Line 46 — replace the final sentence, `Add a roadmap entry in the same
commit.`, with:

```markdown
Write the issue's `## Summary` in the same commit — `check.bash` fails until you do.
```

Line 48 — replace the sentence that reads "It fills in the issue's `closed`
date and updates [dev-docs/roadmap.md](dev-docs/roadmap.md)." with:

```markdown
It fills in the issue's `closed` date and stages the file.
```

Line 50 — change `xargs head -n 15` to `xargs head -n 20`, and
`for each issue's frontmatter and title` to `for each issue's frontmatter,
title, and summary`.

- [ ] **Step 3: Rewrite the three `CONTRIBUTING.md` places**

Lines 8-12 — the sentence currently reading `open work is in
[dev-docs/roadmap.md](dev-docs/roadmap.md)` becomes `open work is listed by
[bin/issues/list.bash](bin/issues/list.bash)`. Keep the surrounding clauses
and the line wrapping.

Line 45 — the table cell becomes `Verify issue-file consistency.`

Line 46 — the table cell's pipe example becomes `` `\| xargs head -n 20` ``.

- [ ] **Step 4: Verify no live roadmap reference survives**

```bash
grep -rn "roadmap" CLAUDE.md CONTRIBUTING.md dev-docs/index.md dev-docs/issue-conventions.md
```

Expected: no output.

```bash
grep -rn "head -n 15" --exclude-dir=.git --exclude-dir=.claude .
```

Expected: matches only under `dev-docs/plans/` and `dev-docs/specs/`.

- [ ] **Step 5: Verify the documented commands actually work**

Run each command the edited docs now instruct a reader to run:

```bash
bin/issues/check.bash
bin/issues/list.bash | xargs head -n 20 | head -n 25
```

Expected: the checker green, and the `head` output showing a complete
`## Summary` for the first issue — not one cut off mid-paragraph. If any
summary truncates, raise the number in all three documents rather than
leaving the idiom broken.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md CONTRIBUTING.md dev-docs/issue-conventions.md dev-docs/index.md
git commit -m "docs: point the conventions at the issue files, not the roadmap

Replaces the roadmap-entry filing step with the '## Summary' requirement,
documents the summary and why the Open Issues section retired, and
updates close.bash's and check.bash's described behavior and the
head -n 20 idiom.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Re-scope issue #20

Its two numbered defects, and one of its four sweep-up items, were in code
Tasks 2 and 4 deleted. Three survive.

**Files:**
- Modify: `dev-docs/issues/020-close-bash-roadmap-awk-edge-cases.md`

**Interfaces:**
- Consumes: Task 4's final `close.bash`.
- Produces: nothing downstream.

- [ ] **Step 1: Confirm what actually survived**

```bash
grep -n 'ne 1\|10#\$1\|git add' bin/issues/close.bash
```

Expected: the `[[ $# -ne 1 ]] && usage` line, the `padded=` and final `echo`
lines using `10#$1`, and a single-file `git add` that still precedes the
`bin/issues/check.bash` call. All three surviving defects are present.

- [ ] **Step 2: Replace the file's body**

Keep the frontmatter exactly as it is — `opened: 2026-08-01` and an empty
`closed:` — and replace everything from the `#` heading down with:

```markdown
# 020 - close.bash's argument handling and staging order

## Summary

`bin/issues/close.bash` has three dormant defects around its argument and
its staging order: `[[ $# -ne 1 ]] && usage` in place of an explicit `if`,
a raw bash arithmetic error rather than `usage()` when the id is not a
number, and `git add` running before `check.bash`, so a failed check
leaves a half-applied close staged with no recovery hint. None can
corrupt an issue file; all three are diagnostics quality.

## Description

This issue originally reported two defects in the roadmap-editing `awk` in
[close.bash](../../bin/issues/close.bash) — blank-line collapsing that was
file-wide rather than entry-scoped, and a skip state that a blank line
ended prematurely — plus four lower-severity observations swept up from the
whole-branch review of [#18](018-close-bash-rewrites-plan-prose.md).

[#49](049-retire-roadmap-open-issues-section.md) deleted `dev-docs/roadmap.md`
and every line of `close.bash` that edited it. Both numbered defects went
with that `awk`, and so did one of the four sweep-up items: the unescaped
`${basename}` interpolated into a BRE `sed` pattern was the
milestone-checkbox pass, which no longer exists. Three remain:

1. **`[[ $# -ne 1 ]] && usage` instead of `if ...; then ...; fi`.** The
   script runs under `set -euo pipefail`, and this form survives only
   because `set -e` exempts every command in an AND-list except the last:
   the failing `[[ ]]` is not that command, so the shell does not exit. It
   is a well-known footgun that happens to be standing on the exemption.
   `list.bash` already uses the explicit `if` form.
2. **A non-numeric id produces a raw bash arithmetic error** rather than
   the `usage()` message, though it fails before touching any file.
3. **Staging precedes verification.** `close.bash` stages the issue file
   and then runs `check.bash`. A failed check leaves the filled-in
   `closed:` date staged, with nothing printed about how to undo it.

## Notes

All three were raised in the whole-branch review of #18 and deferred by
explicit decision. Item 3 is the only one with a real cost: recovery is
`git restore --staged --worktree <file>`, which the script could simply
print.

A correction to what this issue used to claim: it cited
[issue-conventions.md](../issue-conventions.md) as prescribing
`if ...; then ...; fi` over `[[ ... ]] && ...`. That document contains no
shell style rule and appears never to have. Item 1 stands on the `set -e`
reasoning above, not on a convention.

`bin/issues/new.bash` uses the same `[[ $# -lt 1 ]] && usage` form, on the
same exemption. Fixing item 1 should fix both.

Retitled and re-scoped by #49. The filename keeps its original
`close-bash-roadmap-awk-edge-cases` slug: issue files never move, so links
to this issue never break.
```

- [ ] **Step 3: Verify**

```bash
bin/issues/check.bash
head -n 20 dev-docs/issues/020-close-bash-roadmap-awk-edge-cases.md
```

Expected: the checker green, and the file opening with intact frontmatter,
the new title, and the new Summary.

- [ ] **Step 4: Commit**

```bash
git add dev-docs/issues/020-close-bash-roadmap-awk-edge-cases.md
git commit -m "docs(issues): re-scope issue 20 to close.bash's surviving defects

Both numbered defects and one of the four sweep-up items lived in the
roadmap-editing code #49 deleted. Three remain, all about argument
handling and staging. Also drops the issue's citation of a shell style
rule issue-conventions.md does not contain.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Close #47 and #49

**Files:**
- Modify: `dev-docs/issues/047-issue-conventions-claims-generated-changelog.md`
- Modify: `dev-docs/issues/049-retire-roadmap-open-issues-section.md`

**Interfaces:**
- Consumes: Task 6, which deleted the passage #47 reports.
- Produces: the branch's final state — 15 open issues.

- [ ] **Step 1: Confirm the false claim is gone**

```bash
grep -rn "CHANGELOG" dev-docs/issue-conventions.md
```

Expected: no output. The sentence crediting a generated `CHANGELOG.md`
disappeared with the section that held it.

- [ ] **Step 2: Record how #47 was resolved**

Append to `## Notes` in
`dev-docs/issues/047-issue-conventions-claims-generated-changelog.md`:

```markdown
**Resolved by [#49](049-retire-roadmap-open-issues-section.md).** That
change deleted `issue-conventions.md`'s "The roadmap" section outright,
and the false sentence with it — option 1 above, taken to its limit: the
claim was not corrected, it was removed along with the rule it justified.
The roadmap itself no longer exists, so "do not duplicate shipped history
in the roadmap" has no subject left to govern.

Option 2 was not taken. Its cost analysis stands as written, should a
committed changelog ever be proposed again: `@semantic-release/changelog`
needs `@semantic-release/git`, which makes semantic-release push commits
to `main` and forces the branch ruleset to be revisited.
```

- [ ] **Step 3: Record how #49 was resolved**

Append to `## Notes` in
`dev-docs/issues/049-retire-roadmap-open-issues-section.md`:

```markdown
**Resolved.** Design in
[dev-docs/specs/2026-08-14-retire-roadmap-design.md](../specs/2026-08-14-retire-roadmap-design.md),
plan in [dev-docs/plans/2026-08-14-retire-roadmap.md](../plans/2026-08-14-retire-roadmap.md).

Two things turned out differently than this issue assumed. `roadmap.md`
had no milestone sections at all — all 52 lines were the Open Issues
section — so the file was deleted outright and the milestone convention
retired with it, rather than the section being trimmed out of a surviving
document. And of the four #20 sweep-up items named above, only three
survive: the unescaped `sed` BRE was in the milestone-checkbox pass, which
this change also deleted.

The summaries went to a required `## Summary` body section on every open
issue, not to a `summary:` frontmatter key — the prose runs 40-70 words,
which as a flat scalar would be one unwrapped line with whole-line diffs.
```

- [ ] **Step 4: Close both issues**

```bash
bin/issues/close.bash 47
bin/issues/close.bash 49
```

Expected: each prints `closed dev-docs/issues/...` and the commit message,
neither mentions the roadmap, and the `check.bash` each one runs is green.

- [ ] **Step 5: Verify the final state**

```bash
bin/issues/check.bash
bin/issues/list.bash | wc -l
git status --short
```

Expected: `OK: 15 open, 34 closed, next id 50`, a count of `15`, and both
issue files staged.

- [ ] **Step 6: Commit**

```bash
git add dev-docs/issues
git commit -m "docs(issues): close issues 47 and 49 (retire the roadmap)

47's false CHANGELOG.md claim was deleted with the conventions section
that held it. 49's own notes record where its two assumptions turned out
wrong: the roadmap had no milestone content to preserve, and only three
of #20's sweep-up items survive.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Final whole-branch verification**

```bash
git branch --show-current
bin/issues/check.bash
bats bin/tests/issues-check.bats bin/tests/issues-close.bats bin/tests/issues-list.bats
grep -rln "roadmap" --exclude-dir=.git --exclude-dir=.claude .
git log --oneline main..HEAD
```

Expected: the worktree branch; the checker green at 15 open; all three bats
files passing; `roadmap` matching only under `dev-docs/plans/`,
`dev-docs/specs/`, and `dev-docs/issues/`; and ten commits — the design
spec, this plan, and one per task.

Then open the pull request per [CONTRIBUTING.md](../../CONTRIBUTING.md) and
let the `Test Languages` check run — it exercises `bin/tests/` alongside the
language suite, which is where the two new bats files get their CI run.

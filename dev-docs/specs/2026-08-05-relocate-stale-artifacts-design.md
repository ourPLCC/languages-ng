# relocate: stop copying stale build artifacts — Design

Addresses issue [#25](../issues/025-relocate-copies-stale-build-artifacts.md).

## Background

`bin/relocate.bash` gives each bats test a private directory to build in.
This matters because `plcc-rep` writes its build output — `plcc-ng/`,
generated sources, `*.class`, `__pycache__/` — into the **current
directory**. Without relocation, tests would litter the working tree and
each test would inherit the previous one's build.

Isolation is the purpose; the whole-tree copy is a second-order
consequence. Once the build has moved elsewhere, the spec's dependencies
have to come along, and every migrated spec `%include`s a sibling
top-level directory (`../../Env/env{RN,Val,Ref}/<target>/env.plcc`). So
relocate copies all of `src/`:

```bash
cp -R "${src_dir}/"* .
```

That glob also sweeps up the gitignored build directories a previous
by-hand `plcc-rep` run left behind. The result is issue #25: running
`plcc-rep` by hand inside any `src/<lang>/<target>/` silently corrupts the
next suite run, while `git status` stays clean throughout. It accuses the
wrong language, it looks like flakiness, and it corrupts the measured
baseline that migration plans depend on.

CI is unaffected — `.github/workflows/test-languages.yaml` builds from a
fresh `actions/checkout`. This is a local-development defect.

## Decision: copy what git says isn't ignored

`relocate` copies exactly the files git reports as tracked-or-untracked
but **not** ignored, instead of globbing the tree:

```bash
git ls-files -z --cached --others --exclude-standard
```

`.gitignore` stays the single source of truth. Add an artifact pattern
there and relocate follows it automatically, with no second list to keep
in sync.

The obvious worry — "does this mean my work has to be committed?" — does
not apply, and this was verified rather than assumed. `git ls-files`
produces a *path list*; `tar` then reads those paths from the working
tree, not from the object database. Measured behavior:

| Development state | Copied into the tmpdir? |
| --- | --- |
| Uncommitted edit to a tracked file | **Yes** — tar reads working-tree bytes |
| Brand-new file, never `git add`ed | **Yes** — that is what `--others --exclude-standard` means |
| `plcc-ng/`, `__pycache__/`, `*.class` | **No** — `--exclude-standard` honors `.gitignore` |

Nothing needs to be committed or even staged. The only files hidden are
the ones `.gitignore` names, which is precisely the bug being fixed.

### Alternatives considered

- **`cp -R`, then delete artifacts from the tmpdir.** No new
  dependencies and works without git, but the artifact pattern list would
  then live in both `.gitignore` and `relocate`.
- **`tar --exclude` / `rsync --exclude`.** Same duplicated-list cost.
  `rsync` additionally is not present in the CI image (`python:3` plus
  `git`), so it would drag in a dockerfile change.
- **A guard in `bin/test.bash`** that refuses to run when artifacts exist
  under `src/`. Redundant once relocate is hermetic, and it does not help
  anyone invoking `bats` directly. Rejected.

## Design

### 1. `bin/relocate.bash`

Keep `relocate`'s existing responsibility (derive `lang_dir`,
`lang_name`, `src_dir`; cd into the tmpdir; cd into the language) and
extract the copy into a new `relocate_copy_tree <from> <to>`:

```bash
relocate_copy_tree () {
  local from="$1" to="$2" to_abs
  git -C "${from}" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "relocate: ${from} is not in a git checkout" >&2; return 1; }
  to_abs="$(cd "${to}" && pwd)" || return 1
  (
    set -o pipefail
    cd "${from}" || exit 1
    git ls-files -z --cached --others --exclude-standard \
      | while IFS= read -r -d '' f; do
          if [[ -e "${f}" ]]; then printf '%s\0' "${f}"; fi
        done \
      | tar --null -T - -cf - \
      | ( cd "${to_abs}" && tar -xf - )
  )
}
```

Four details earn their place:

- `--others --exclude-standard` is what keeps uncommitted work visible
  while honoring `.gitignore`.
- The `[[ -e ]]` filter handles a tracked file deleted with plain `rm`
  rather than `git rm`: `--cached` still lists that path, and tar skips
  it with a `Cannot stat` warning on stderr rather than aborting the
  archive. The filter suppresses that warning for the one case where it
  is expected.
- The `rev-parse` guard turns "not a git checkout" into one clear line
  instead of a wall of git errors.
- The `pipefail` subshell and the `to_abs` resolution are what actually
  fix issue #25's failure mode — see below. `to` is resolved to an
  absolute path *before* the subshell changes directory, since the `cd
  "${to_abs}"` on the extract side would otherwise resolve a relative
  `to` against the wrong directory.

> **Corrected 2026-08-05, during implementation.** This section originally
> claimed, as established fact, that a tracked file deleted with plain
> `rm` makes `tar` abort so that "**every** test fails with `Cannot stat:
> No such file or directory`," and called this "confirmed by experiment;
> the filter is not speculative." That premise is false. Measured with
> GNU tar 1.35:
>
> ```
> tar: LANG/java/spec.plcc: Cannot stat: No such file or directory
> PIPESTATUS=2 0   overall $?=0
> to/.gitignore   to/LANG/java/other.plcc     <- everything else copied
> ```
>
> tar skips the unstattable path, copies everything else, and exits 2 —
> but that 2 is the *create* side of the pipe, and (before this fix) the
> pipeline's reported status was the *extract* side's 0. Nothing "failed
> every test"; the `rm`-deleted case was already silently tolerated by
> the unfixed code.
>
> The defect that measurement actually uncovered — and what the design
> above and the shipped code fix — is that `relocate_copy_tree` returned
> 0 even when the copy failed. A failed `git ls-files` or a dead
> archiving `tar` produced a silently incomplete tree that tests then ran
> against: the same silent-corruption class as issue #25 itself,
> reintroduced one layer down. The `set -o pipefail` subshell and the
> `to_abs` absolute-path resolution close that gap; the `[[ -e ]]` filter
> stays so the legitimate `rm`-deleted case doesn't trip the new failure
> propagation. See the plan's Task 3 "Amended 2026-08-05, mid-execution"
> block for the full record.

The file's existing comment explaining the tree-wide copy is updated. It
currently justifies the width purely in terms of `%include`, which is now
only half the story — see §8.

### 2. Testability

Extracting the helper is what makes this testable. `relocate` itself is
welded to `BATS_TEST_DIRNAME`; `relocate_copy_tree` takes two paths and
can be aimed at a synthetic tree.

### 3. `bin/tests/relocate.bats`

Each test builds a throwaway repo in `BATS_TEST_TMPDIR` (`git init`, a
`.gitignore`, `git add`), calls `relocate_copy_tree`, and asserts. No
commits are needed, since `--cached` reads the index — so no git identity
configuration is required in CI. Eight cases, one per property established
above:

1. Ignored `plcc-ng/`, `__pycache__/`, and `*.class` are absent from the copy.
2. Tracked source files are present.
3. An untracked, non-ignored file is present. *(Protects the development
   workflow: new files work before `git add`.)*
4. An uncommitted edit's content arrives, not the committed content.
5. A tracked file deleted with plain `rm` does not break the copy.
6. The copy fails if the destination directory does not exist.
7. The copy fails if any listed file cannot be read.
8. An error message to stderr when the source is not in a git checkout,
   replacing a wall of git noise. *(The `rev-parse` guard provides this.)*

### 4. `bin/test.bash`

Change `cd src; bats --recursive .` to `cd "${PROJECT_ROOT}"; bats
--recursive src bin` so the new tests actually run. Nothing in the
language tests depends on bats' working directory — they use an absolute
`BATS_TEST_DIRNAME` and a relative `load` — so the language suite is
unaffected.

**Baseline:** measure it as the first step of implementation rather than
quoting a number. Issue #25 records 84 tests, but 95 `@test`s are present
today (REF landed since the issue was filed). Assert the *delta*: +5 from
the new relocate tests, with no change in language-test results.

### 5. `.dockerignore`

`plcc-ng/`, `__pycache__/`, `*.class`, `.claude/`. The dockerfile does
`COPY . /languages/` with no `.dockerignore` today, so
`bin/test-using-pipeline-container.bash` bakes local stale artifacts into
the image — the same root cause through a different copy.

Deliberately **not** `.git`: relocate needs a real checkout, the
container copies `.git` today, and the image installs `git`. Excluding it
would break every test in the container.

Honest scoping note: once relocate is hermetic this file is no longer
load-bearing for correctness. It is a smaller build context and defense
in depth.

### 6. `bin/clean.bash`

`git clean -Xdf src`, which removes exactly the ignored files under
`src/` — the same single-source-of-truth property as the fix. This
replaces the three ad-hoc `find` commands the REF migration ran by hand.
`-X` removes only ignored files, so untracked work in progress is safe.
`git clean` prints each removal itself.

### 7. Closing

Final commit is `bin/issues/close.bash 025`, per
[issue-conventions.md](../issue-conventions.md).

No `dev-docs/course-material-impact.md` entry: this is repository
tooling, and nothing an instructor's slides or handouts reference. The
old `find` workaround appears only in already-completed plan files, which
are historical record and stay as they are.

### 8. Follow-up issue: drop the copy for plcc-ng tests

File via `bin/issues/new.bash use-spec-flag-instead-of-copying-tree test`,
with a roadmap entry in the same commit.

While investigating relocate's purpose, a simpler mechanism surfaced that
the issue's "possible directions" list did not consider. `plcc-rep -s
<absolute path to spec>` resolves `%include` relative to **the spec's
real location** while still writing build output to **the current
directory**:

```bash
cd "$BATS_TEST_TMPDIR"
plcc-rep -s "$REPO/src/REF/java/spec.plcc" < input   # includes resolve; output lands here
```

This obtains isolation structurally rather than by filtering a copy:
nothing is copied, so nothing stale can be copied. No git dependency, no
exclusion list.

Verified across all three Env flavors × all three targets — `V1`/envRN,
`V6`/envVal, `REF`/envRef in python, java, and javascript. **6 of 6
produced their expected output with nothing copied**, and `git status
--ignored` confirmed `src/` was left clean afterward. Recording this here
so it need not be rediscovered.

**Why it is not part of this issue.** Five languages — NAME, NEED, OBJ,
TYPE0, TYPE1 — are not yet migrated. They call the old `plccmk -c
grammar` / `rep -n`, which builds in place and has no `-s` equivalent, so
they genuinely need a copied tree:

| | test files | tests |
| --- | --- | --- |
| plcc-ng (`-s` works) | 30 | 90 |
| legacy `plccmk` (needs the copy) | 5 | 5 |

`relocate` therefore cannot be deleted; it must survive for the legacy
five until the migration finishes, and those five copy the whole tree.
The `-s` change does not *replace* this fix — it is this fix plus a
mechanical rewrite of 30 test files that the migration is actively
editing. Bundling the two would make both harder to review.

(The legacy five are already failing: `plccmk`/`rep` are not installed in
the devcontainer, a pre-existing gap noted in the migration design.)

## Testing

`bin/test.bash`, comparing against the baseline measured in §4.

The five unit tests verify the property this fix actually controls: that
ignored files are not copied. That is directly and reliably testable.

Additionally, attempt an end-to-end reproduction — plant a `plcc-ng/`
directory under a migrated language, run the suite before and after the
fix — but treat it as a bonus check, not a gate.

**Known unknown:** the mechanism by which stale artifacts change a test's
*result* was not reproduced during design. `plcc-rep` keeps a
`plcc-ng/.spec-hash` cache, which is the plausible culprit, but a
whitespace edit to `spec.plcc` left that hash unchanged, so it is not a
plain content hash and the caching rules are not understood well enough
to assert anything. Issue #25 reports the corruption from two live
occurrences; this fix removes the copying that feeds it regardless of the
exact cache semantics. If the end-to-end reproduction does not fail
pre-fix, that is information worth recording in the issue, not a reason
to doubt the fix.

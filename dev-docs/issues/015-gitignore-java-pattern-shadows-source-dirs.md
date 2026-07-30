# 015 - gitignore-java-pattern-shadows-source-dirs

**Type:** chore
**Target:** this repo
**Date:** 2026-07-30

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

`.gitignore` line 1 is `Java/`, intended to ignore old PLCC's generated
build directory. This checkout has `core.ignorecase=true` (a
case-insensitive filesystem), so the pattern **also matches every
`src/*/java/` source directory** — plcc-ng's per-target spec directory,
not a build artifact.

**It is environment-dependent, which is what makes it dangerous.** On a
case-sensitive filesystem (a typical Linux CI runner) `Java/` does not
match `java/`, so the problem is invisible in CI and appears only on some
developers' machines — exactly the shape that produces a commit silently
missing a file, which then fails elsewhere once someone without the
matching filesystem quirk tries to reproduce it.

**No gitignore pattern can fix it in place.** Under case-insensitive
matching, `Java/` and `java/` are indistinguishable to the ignore
matcher, so a negation like `!src/*/java/` re-includes the sibling build
directory `src/*/Java/` right along with it. Verified: adding
`!src/V4/java/` to a scratch `.gitignore` un-ignores both a probe file
under `src/V4/java/` and one under `src/V4/Java/` in the same repo.

**What `Java/` actually protects is now close to nothing.** `plcc-rep`
writes only `plcc-ng/` (already ignored on line 3) as its build output in
every target, including Java (see
[dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md),
"`plcc-rep` writes build artifacts to a `plcc-ng/` subdirectory"). `Java/`
exists solely for old PLCC's `plccmk`, which is not installed in this
devcontainer.

**Recommended resolution:** drop the `Java/` line, narrowing it to a
specific path (e.g. a literal generated directory name, if one
resurfaces) if the still-unmigrated languages turn out to need it. A
blanket `*.java` is a worse substitute, not a fallback: `src/TYPE1/J/EO.java`
is a tracked source file, and `*.java` would silently ignore it (and any
future `.java` source file) too.

**Impact:** affects every remaining migration phase — V5, V6, SET, REF,
NAME, NEED, TYPE0, TYPE1, OBJ — each of which must add a `java/spec.plcc`
and will hit the same `git add -f` workaround this pattern already forced
on V3 and V4.

## Steps to Reproduce

1. Confirm the filesystem is case-insensitive: `git config
   --get core.ignorecase` prints `true`.
2. Try to stage a new file under a `java/` source directory, e.g.
   `git add src/V4/java/spec.plcc` on a fresh copy of that file — it is
   refused.
3. Run `git check-ignore -v src/V4/java/spec.plcc` — it names
   `.gitignore:1:Java/` as the matching rule.
4. Note that both `src/V3/java/spec.plcc` and `src/V4/java/spec.plcc`
   needed `git add -f` to be committed in the first place (both are
   tracked today, so nothing has been lost yet — but only because
   someone noticed and forced the add).

## Notes

Found during the whole-branch review of the V4 migration (issue #14,
already closed). Not caused by that branch — the pattern has been in
`.gitignore` since before V0's migration — but V4 is the second language
in a row (after V3) to trip over it, which is what surfaced it as worth
tracking.

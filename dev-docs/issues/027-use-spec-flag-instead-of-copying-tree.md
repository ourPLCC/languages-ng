---
type: test
target: this repo
opened: 2026-08-05
closed:
---

# 027 - use-spec-flag-instead-of-copying-tree

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

`plcc-rep -s <absolute path to spec>` resolves `%include` relative to the
spec's real location while still writing build output to the **current
directory**. So a test needs no copied tree at all:

    cd "$BATS_TEST_TMPDIR"
    plcc-rep -s "$REPO/src/REF/java/spec.plcc" < input

This gets isolation structurally rather than by filtering a copy: nothing
is copied, so nothing stale can be copied. It supersedes the
`git ls-files`-driven copy added for issue #25 — for migrated languages.

**Verified** during the issue #25 design across all three Env flavors and
all three targets: V1/envRN, V6/envVal, REF/envRef in python, java, and
javascript. 6 of 6 produced their expected output with nothing copied, and
`git status --ignored` confirmed `src/` was left clean afterwards.

## Scope

30 test files / 90 tests use plcc-ng and can convert. Each becomes roughly:

    @test "SET counter (java)" {
      cd "$BATS_TEST_TMPDIR"
      RESULT="$(plcc-rep -s "$BATS_TEST_DIRNAME/../../java/spec.plcc" \
                  < "$BATS_TEST_DIRNAME/SET.input")"
      expected_output=$(< "$BATS_TEST_DIRNAME/SET.expected")
      [[ "$RESULT" == "$expected_output" ]]
    }

5 test files / 5 tests (NAME, NEED, OBJ, TYPE0, TYPE1) **cannot**: they run
`plccmk -c grammar` / `rep -n`, which build in place with no `-s`
equivalent. `relocate` and `relocate_copy_tree` must stay until those five
migrate, at which point both can be deleted outright.

Best sequenced with the remaining migration work, which is actively
editing these same test files.

## Notes

Any ideas, hunches, or related context.

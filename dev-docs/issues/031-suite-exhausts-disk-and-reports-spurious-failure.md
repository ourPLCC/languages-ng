---
type: test
target: this repo
opened: 2026-08-06
closed: 2026-08-06
---

# 031 - suite-exhausts-disk-and-reports-spurious-failure

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

On a container whose filesystem is nearly full, `bin/test.bash` does not
finish. It runs out of disk partway through, dies, and — this is the part
that matters — **reports a `not ok` for whatever test happened to be
running when the disk ran out.** The failure names an innocent test. A
reader who trusts the output concludes that test is broken.

`relocate` copies the whole `src/` tree into `BATS_TEST_TMPDIR` for every
test, and each of the three targets then builds into a `plcc-ng/`
directory inside that copy. With 130 tests that is 130 whole-tree copies
plus their build output, all under `TMPDIR`. Nothing is wrong with any
single test's footprint; it is the accumulation against a constrained
filesystem.

This is the same silent-corruption class as issues
[#25](025-relocate-copies-stale-build-artifacts.md) and
[#28](028-relocate-filter-hides-permission-errors.md): the harness fails
in a way that looks like an ordinary result rather than like a harness
failure. A truncated run also passes a naive count — `grep -c '^ok '` on a
half-written file returns a plausible number with no indication the run
never reached the end.

Observed while migrating NEED (issue [#30](030-migrate-need-to-plcc-ng.md)),
on a devcontainer with `/` at 100% and ~230 MB free:

- one run died at test 75 of 130, leaving the output file frozen with no
  bats process alive;
- a second died at test 96 having written `not ok 96 V4 seq (javascript)`.
  `V4 seq (javascript)` is not broken — it passes in every run that
  completes.

## Steps to Reproduce

1. Work in a container where the filesystem holding `TMPDIR` has only a
   few hundred MB free (`df -h /tmp`).
2. Run `bin/test.bash > out.txt 2>&1`.
3. Observe that `out.txt` stops partway through, no `bats` process
   remains, and the last line is often a `not ok` for a test that passes
   when run on its own.

## Notes

**Workaround used during the NEED migration.** Split the run the way
`bin/test.bash` already splits it internally (`bats --recursive src bin`),
putting only the heavy half on a filesystem with room:

    TMPDIR=<dir on a roomy filesystem> bats --recursive src
    bats --recursive bin          # must keep the default TMPDIR

Pass 2 has to keep the default: `relocate_copy_tree fails clearly when not
in a git checkout` builds its fixture under `BATS_TEST_TMPDIR` and needs
that path to be **outside** a git checkout. Pointing `TMPDIR` into the
repo breaks that test by construction — it is asserting on a real
property of its own fixture, not misbehaving.

Counts must then be summed across the two passes, and each pass checked
for its final test line before its numbers are trusted.

**Two things worth fixing, and they are independent.**

1. *The footprint.* Issue [#27](027-use-spec-flag-instead-of-copying-tree.md)
   already proposes what removes it: `plcc-rep -s <abs spec path>` resolves
   `%include` from the spec's real location while writing build output to
   the current directory, so a migrated language's test needs no copied
   tree at all. Every test converted to `-s` stops contributing to this
   problem. That makes #27 the structural fix, and this issue mostly a
   record of what the current design costs on a constrained machine.

2. *The silence.* Even with #27 done, a run that dies for any reason still
   reports a misleading `not ok` and a truncated file that counts cleanly.
   Worth considering independently of #27: have `bin/test.bash` check that
   the run reached its final test line and fail loudly if it did not, so a
   dead run is never mistaken for a test result. A harness that cannot
   finish should say so, not accuse a test.

Not caused by the NEED migration; the migration only made the suite large
enough to hit it. CI is unaffected today for the reason in issue
[#12](012-ci-cannot-run-plcc-ng-migrated-languages.md) — the job is
`on: pull_request` and no PRs are opened yet — so this bites local
development first.

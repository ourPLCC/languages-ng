# Empty a passing test's BATS_TEST_TMPDIR as soon as that test ends.
#
# bats creates $BATS_RUN_TMPDIR/test/<n> per test and deletes none of them
# during the run: the only in-run rm is the retry path (bats-exec-test:162),
# and BATS_RUN_TMPDIR itself goes in the EXIT trap (bats:340). Peak disk is
# therefore the *sum* of every test's footprint -- ~2.4 MB x 130 = ~312 MB --
# which is what exhausts a constrained filesystem (issue #31). Emptying per
# test makes the peak the cost of one test, and keeps it there as the suite
# grows.
#
# Empty the directory rather than remove it: that same retry path runs an
# unguarded `rm -r "$BATS_TEST_TMPDIR"`, which fails if it is already gone.
teardown () {
  # --no-tempdir-cleanup means "I want to inspect the trees". Honor it.
  [[ -n "${BATS_TEMPDIR_CLEANUP:-}" ]] || return 0

  # Unset unless the test body ran to completion. A failing test's tree is
  # evidence; keep it. This is why a run with failures can still accumulate.
  [[ -n "${BATS_TEST_COMPLETED:-}" ]] || return 0

  [[ -n "${BATS_TEST_TMPDIR:-}" && -d "${BATS_TEST_TMPDIR}" ]] || return 0

  # Tests cd into subdirectories that are about to vanish. Step up to the
  # tmpdir itself, which survives because of -mindepth 1.
  cd "${BATS_TEST_TMPDIR}" || return 0

  # Loud on failure, per issue #28: a cleanup that silently no-ops just
  # restores the accumulation this file exists to prevent.
  if ! find "${BATS_TEST_TMPDIR}" -mindepth 1 -delete; then
    printf 'bats-tmpdir: could not empty %s\n' "${BATS_TEST_TMPDIR}" >&2
    printf 'bats-tmpdir: disk will accumulate from here on.\n' >&2
    return 1
  fi
}

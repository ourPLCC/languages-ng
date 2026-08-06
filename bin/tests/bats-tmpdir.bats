#!/usr/bin/env bats

# Exercises bin/bats-tmpdir.bash by running a *child* bats on a fixture this
# file generates at runtime.
#
# Why a child, and why the assertions live inside it: observing a child's
# tmpdirs from out here would need --no-tempdir-cleanup, which disables the
# very teardown under test. bats numbers tmpdirs $BATS_RUN_TMPDIR/test/<n>,
# so instead the child's second test inspects what its first test left behind.
#
# Why fixtures are generated rather than committed: a committed fixture named
# *.bats anywhere under bin/ would be collected as a real test by
# `bats --recursive bin`.
#
# Why this file must NOT load bin/bats-tmpdir.bash: the teardown would empty
# BATS_TEST_TMPDIR between tests and delete the fixtures written there.
#
# Why TMPDIR is exported for the child: it puts the child's whole bats-run-*
# tree inside this test's tmpdir, so it goes away with it. Without this,
# --no-tempdir-cleanup leaks a directory into /tmp on every run.

LIB="${BATS_TEST_DIRNAME}/../bats-tmpdir.bash"

@test "a passing test's tmpdir is emptied" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
source '${LIB}'
@test "fills its tmpdir" {
  cd "\$BATS_TEST_TMPDIR"
  mkdir -p a/b
  echo x > a/b/f
}
@test "sees test 1 emptied" {
  prev="\$BATS_RUN_TMPDIR/test/1"
  [ -d "\$prev" ]
  [ -z "\$(ls -A "\$prev")" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats "${BATS_TEST_TMPDIR}/child.bats"
  [ "$status" -eq 0 ]
}

# Control. Without the teardown the identical fixture must FAIL, which is what
# proves the test above is not passing vacuously.
@test "without the teardown, the same fixture fails" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
@test "fills its tmpdir" {
  cd "\$BATS_TEST_TMPDIR"
  mkdir -p a/b
  echo x > a/b/f
}
@test "sees test 1 emptied" {
  prev="\$BATS_RUN_TMPDIR/test/1"
  [ -d "\$prev" ]
  [ -z "\$(ls -A "\$prev")" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats "${BATS_TEST_TMPDIR}/child.bats"
  [ "$status" -eq 1 ]
}

@test "a failing test's tmpdir is preserved as evidence" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
source '${LIB}'
@test "fails leaving evidence" {
  cd "\$BATS_TEST_TMPDIR"
  touch evidence
  false
}
@test "sees evidence survived" {
  [ -e "\$BATS_RUN_TMPDIR/test/1/evidence" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats "${BATS_TEST_TMPDIR}/child.bats"
  # The child exits 1 because its first test fails by design. What matters is
  # that its second test passed.
  [ "$status" -eq 1 ]
  [[ "$output" == *'ok 2 sees evidence survived'* ]]
}

@test "--no-tempdir-cleanup preserves the tree" {
  cat > "${BATS_TEST_TMPDIR}/child.bats" <<EOF
source '${LIB}'
@test "fills its tmpdir" {
  cd "\$BATS_TEST_TMPDIR"
  mkdir -p a/b
  echo x > a/b/f
}
@test "sees test 1 was left alone" {
  prev="\$BATS_RUN_TMPDIR/test/1"
  [ -n "\$(ls -A "\$prev")" ]
}
EOF
  export TMPDIR="${BATS_TEST_TMPDIR}"
  run bats --no-tempdir-cleanup "${BATS_TEST_TMPDIR}/child.bats"
  [ "$status" -eq 0 ]
}

#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# Only the early-exit branch is tested here. The install branch clones
# from GitHub, so putting it in the suite would make every run depend on
# the network and on GitHub being up. It is exercised for real, on every
# CI run, in an image that has no bats -- which is the better test
# anyway, since that is the situation it exists for.

@test "install-bats exits 0 and installs nothing when the pinned bats is present" {
  run "${BATS_TEST_DIRNAME}/../install/bats.bash"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install-bats pins the same bats version the suite runs" {
  local pinned
  pinned="$(sed -nE 's/^BATS_VERSION="([^"]+)"$/\1/p' \
    "${BATS_TEST_DIRNAME}/../install/bats.bash")"
  [ -n "${pinned}" ]
  bats --version | grep -q "${pinned}"
}

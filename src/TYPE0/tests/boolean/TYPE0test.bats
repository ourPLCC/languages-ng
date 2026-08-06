#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 boolean" {
  relocate
  plccmk -c grammar > /dev/null
  RESULT="$(rep -n < ./tests/boolean/TYPE0.input)"

  expected_output=$(< "./tests/boolean/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]

}

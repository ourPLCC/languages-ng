#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 proc-types" {
  relocate
  plccmk -c grammar > /dev/null
  RESULT="$(rep -n < ./tests/proc-types/TYPE1.input)"

  expected_output=$(< "./tests/proc-types/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]


}

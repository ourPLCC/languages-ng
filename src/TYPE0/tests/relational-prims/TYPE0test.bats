#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 relational-prims (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/relational-prims/TYPE0.input)"
  expected_output=$(< "../tests/relational-prims/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

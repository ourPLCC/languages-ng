#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ errors (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/errors/OBJ.input)"
  expected_output=$(< "../tests/errors/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ objects (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/objects/OBJ.input)"
  expected_output=$(< "../tests/objects/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ lists (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/lists/OBJ.input)"
  expected_output=$(< "../tests/lists/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

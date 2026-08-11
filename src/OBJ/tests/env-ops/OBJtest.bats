#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ env-ops (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/env-ops/OBJ.input)"
  expected_output=$(< "../tests/env-ops/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

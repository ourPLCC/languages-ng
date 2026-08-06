#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NEED infinite-stream (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/infinite-stream/NEED.input)"
  expected_output=$(< "../tests/infinite-stream/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

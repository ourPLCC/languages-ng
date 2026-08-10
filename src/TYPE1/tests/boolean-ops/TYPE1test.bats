#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 boolean-ops (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/boolean-ops/TYPE1.input)"
  expected_output=$(< "../tests/boolean-ops/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 boolean-ops (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/boolean-ops/TYPE1.input)"
  expected_output=$(< "../tests/boolean-ops/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

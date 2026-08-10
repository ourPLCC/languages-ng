#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 boolean-literals (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/boolean-literals/TYPE0.input)"
  expected_output=$(< "../tests/boolean-literals/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE0 boolean-literals (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/boolean-literals/TYPE0.input)"
  expected_output=$(< "../tests/boolean-literals/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

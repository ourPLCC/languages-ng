#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 declared-type-not-checked (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/declared-type-not-checked/TYPE0.input)"
  expected_output=$(< "../tests/declared-type-not-checked/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE0 declared-type-not-checked (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/declared-type-not-checked/TYPE0.input)"
  expected_output=$(< "../tests/declared-type-not-checked/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

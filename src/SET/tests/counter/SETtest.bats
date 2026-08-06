#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "SET counter (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/counter/SET.input)"
  expected_output=$(< "../tests/counter/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET counter (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/counter/SET.input)"
  expected_output=$(< "../tests/counter/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET counter (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/counter/SET.input)"
  expected_output=$(< "../tests/counter/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

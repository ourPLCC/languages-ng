#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "SET let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/let/SET.input)"
  expected_output=$(< "../tests/let/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET let (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/let/SET.input)"
  expected_output=$(< "../tests/let/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET let (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/let/SET.input)"
  expected_output=$(< "../tests/let/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

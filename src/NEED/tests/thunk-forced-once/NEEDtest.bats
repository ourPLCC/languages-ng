#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NEED thunk-forced-once (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/thunk-forced-once/NEED.input)"
  expected_output=$(< "../tests/thunk-forced-once/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NEED thunk-forced-once (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/thunk-forced-once/NEED.input)"
  expected_output=$(< "../tests/thunk-forced-once/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

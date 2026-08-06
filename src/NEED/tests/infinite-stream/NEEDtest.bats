#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NEED infinite-stream (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/infinite-stream/NEED.input)"
  expected_output=$(< "../tests/infinite-stream/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NEED infinite-stream (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/infinite-stream/NEED.input)"
  expected_output=$(< "../tests/infinite-stream/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NEED infinite-stream (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/infinite-stream/NEED.input)"
  expected_output=$(< "../tests/infinite-stream/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

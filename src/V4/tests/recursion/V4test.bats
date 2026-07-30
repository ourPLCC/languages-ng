#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 recursion (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/recursion/V4.input)"
  expected_output=$(< "../tests/recursion/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 recursion (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/recursion/V4.input)"
  expected_output=$(< "../tests/recursion/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 recursion (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/recursion/V4.input)"
  expected_output=$(< "../tests/recursion/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

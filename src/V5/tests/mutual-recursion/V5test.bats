#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V5 mutual-recursion (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/mutual-recursion/V5.input)"
  expected_output=$(< "../tests/mutual-recursion/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 mutual-recursion (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/mutual-recursion/V5.input)"
  expected_output=$(< "../tests/mutual-recursion/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 mutual-recursion (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/mutual-recursion/V5.input)"
  expected_output=$(< "../tests/mutual-recursion/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V6 redefine (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/redefine/V6.input)"
  expected_output=$(< "../tests/redefine/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 redefine (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/redefine/V6.input)"
  expected_output=$(< "../tests/redefine/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 redefine (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/redefine/V6.input)"
  expected_output=$(< "../tests/redefine/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

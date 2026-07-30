#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 multi-formals (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/multi-formals/V4.input)"
  expected_output=$(< "../tests/multi-formals/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 multi-formals (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/multi-formals/V4.input)"
  expected_output=$(< "../tests/multi-formals/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 multi-formals (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/multi-formals/V4.input)"
  expected_output=$(< "../tests/multi-formals/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

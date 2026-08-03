#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V6 capture-copy (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/capture-copy/V6.input)"
  expected_output=$(< "../tests/capture-copy/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 capture-copy (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/capture-copy/V6.input)"
  expected_output=$(< "../tests/capture-copy/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 capture-copy (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/capture-copy/V6.input)"
  expected_output=$(< "../tests/capture-copy/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 seq (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/seq/V4.input)"
  expected_output=$(< "../tests/seq/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 seq (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/seq/V4.input)"
  expected_output=$(< "../tests/seq/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 seq (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/seq/V4.input)"
  expected_output=$(< "../tests/seq/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

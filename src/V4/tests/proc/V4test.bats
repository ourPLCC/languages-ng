#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V4 proc (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/proc/V4.input)"
  expected_output=$(< "../tests/proc/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 proc (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/proc/V4.input)"
  expected_output=$(< "../tests/proc/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 proc (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/proc/V4.input)"
  expected_output=$(< "../tests/proc/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

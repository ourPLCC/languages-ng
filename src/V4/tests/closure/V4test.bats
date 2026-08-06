#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V4 closure (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/closure/V4.input)"
  expected_output=$(< "../tests/closure/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 closure (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/closure/V4.input)"
  expected_output=$(< "../tests/closure/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 closure (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/closure/V4.input)"
  expected_output=$(< "../tests/closure/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

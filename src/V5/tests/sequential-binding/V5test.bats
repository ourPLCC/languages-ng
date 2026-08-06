#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V5 sequential-binding (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/sequential-binding/V5.input)"
  expected_output=$(< "../tests/sequential-binding/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 sequential-binding (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/sequential-binding/V5.input)"
  expected_output=$(< "../tests/sequential-binding/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 sequential-binding (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/sequential-binding/V5.input)"
  expected_output=$(< "../tests/sequential-binding/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

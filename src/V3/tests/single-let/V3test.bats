#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V3 single-let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/single-let/V3.input)"
  expected_output=$(< "../tests/single-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 single-let (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/single-let/V3.input)"
  expected_output=$(< "../tests/single-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 single-let (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/single-let/V3.input)"
  expected_output=$(< "../tests/single-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

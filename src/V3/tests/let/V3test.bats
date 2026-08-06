#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V3 let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/let/V3.input)"
  expected_output=$(< "../tests/let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 let (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/let/V3.input)"
  expected_output=$(< "../tests/let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 let (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/let/V3.input)"
  expected_output=$(< "../tests/let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

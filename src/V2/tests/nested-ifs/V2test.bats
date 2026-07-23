#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V2 nested-ifs (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nested-ifs/V2.input)"
  expected_output=$(< "../tests/nested-ifs/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 nested-ifs (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nested-ifs/V2.input)"
  expected_output=$(< "../tests/nested-ifs/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 nested-ifs (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nested-ifs/V2.input)"
  expected_output=$(< "../tests/nested-ifs/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

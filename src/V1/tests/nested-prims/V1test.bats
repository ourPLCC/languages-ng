#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V1 nested-prims (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nested-prims/V1.input)"
  expected_output=$(< "../tests/nested-prims/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 nested-prims (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nested-prims/V1.input)"
  expected_output=$(< "../tests/nested-prims/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 nested-prims (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nested-prims/V1.input)"
  expected_output=$(< "../tests/nested-prims/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

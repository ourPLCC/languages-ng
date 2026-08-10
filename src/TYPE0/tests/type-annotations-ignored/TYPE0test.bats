#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 type-annotations-ignored (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/type-annotations-ignored/TYPE0.input)"
  expected_output=$(< "../tests/type-annotations-ignored/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE0 type-annotations-ignored (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/type-annotations-ignored/TYPE0.input)"
  expected_output=$(< "../tests/type-annotations-ignored/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE0 type-annotations-ignored (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/type-annotations-ignored/TYPE0.input)"
  expected_output=$(< "../tests/type-annotations-ignored/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

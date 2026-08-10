#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 type-errors (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/type-errors/TYPE1.input)"
  expected_output=$(< "../tests/type-errors/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 type-errors (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/type-errors/TYPE1.input)"
  expected_output=$(< "../tests/type-errors/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 type-errors (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/type-errors/TYPE1.input)"
  expected_output=$(< "../tests/type-errors/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

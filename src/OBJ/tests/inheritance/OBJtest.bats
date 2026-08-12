#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ inheritance (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/inheritance/OBJ.input)"
  expected_output=$(< "../tests/inheritance/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "OBJ inheritance (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/inheritance/OBJ.input)"
  expected_output=$(< "../tests/inheritance/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "OBJ inheritance (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/inheritance/OBJ.input)"
  expected_output=$(< "../tests/inheritance/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

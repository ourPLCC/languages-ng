#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ class (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/class/OBJ.input)"
  expected_output=$(< "../tests/class/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "OBJ class (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/class/OBJ.input)"
  expected_output=$(< "../tests/class/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

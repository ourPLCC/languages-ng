#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ strings-chars (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/strings-chars/OBJ.input)"
  expected_output=$(< "../tests/strings-chars/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "OBJ strings-chars (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/strings-chars/OBJ.input)"
  expected_output=$(< "../tests/strings-chars/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "OBJ strings-chars (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/strings-chars/OBJ.input)"
  expected_output=$(< "../tests/strings-chars/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 relational-prims (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/relational-prims/TYPE0.input)"
  expected_output=$(< "../tests/relational-prims/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE0 relational-prims (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/relational-prims/TYPE0.input)"
  expected_output=$(< "../tests/relational-prims/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE0 relational-prims (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/relational-prims/TYPE0.input)"
  expected_output=$(< "../tests/relational-prims/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

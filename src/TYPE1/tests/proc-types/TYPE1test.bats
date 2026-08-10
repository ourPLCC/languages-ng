#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 proc-types (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/proc-types/TYPE1.input)"
  expected_output=$(< "../tests/proc-types/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 proc-types (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/proc-types/TYPE1.input)"
  expected_output=$(< "../tests/proc-types/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 proc-types (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/proc-types/TYPE1.input)"
  expected_output=$(< "../tests/proc-types/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

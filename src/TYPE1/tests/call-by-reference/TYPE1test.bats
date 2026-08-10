#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 call-by-reference (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/call-by-reference/TYPE1.input)"
  expected_output=$(< "../tests/call-by-reference/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 call-by-reference (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/call-by-reference/TYPE1.input)"
  expected_output=$(< "../tests/call-by-reference/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 call-by-reference (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/call-by-reference/TYPE1.input)"
  expected_output=$(< "../tests/call-by-reference/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

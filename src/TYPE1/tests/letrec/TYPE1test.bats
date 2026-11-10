#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 letrec (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/letrec/TYPE1.input)"
  expected_output=$(< "../tests/letrec/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 letrec (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/letrec/TYPE1.input)"
  expected_output=$(< "../tests/letrec/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 letrec (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/letrec/TYPE1.input)"
  expected_output=$(< "../tests/letrec/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

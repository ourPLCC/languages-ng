#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V5 letrec (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/letrec/V5.input)"
  expected_output=$(< "../tests/letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 letrec (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/letrec/V5.input)"
  expected_output=$(< "../tests/letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 letrec (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/letrec/V5.input)"
  expected_output=$(< "../tests/letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}


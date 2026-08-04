#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET letrec-set (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/letrec-set/SET.input)"
  expected_output=$(< "../tests/letrec-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET letrec-set (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/letrec-set/SET.input)"
  expected_output=$(< "../tests/letrec-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET letrec-set (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/letrec-set/SET.input)"
  expected_output=$(< "../tests/letrec-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

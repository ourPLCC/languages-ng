#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET define-then-set (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/define-then-set/SET.input)"
  expected_output=$(< "../tests/define-then-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET define-then-set (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/define-then-set/SET.input)"
  expected_output=$(< "../tests/define-then-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "SET define-then-set (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/define-then-set/SET.input)"
  expected_output=$(< "../tests/define-then-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

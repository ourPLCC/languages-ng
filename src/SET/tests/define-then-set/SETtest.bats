#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET define-then-set (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/define-then-set/SET.input)"
  expected_output=$(< "../tests/define-then-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

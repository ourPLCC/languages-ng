#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/let/SET.input)"
  expected_output=$(< "../tests/let/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

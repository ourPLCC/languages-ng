#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET formal-is-a-copy (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/formal-is-a-copy/SET.input)"
  expected_output=$(< "../tests/formal-is-a-copy/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

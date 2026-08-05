#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "REF formal-is-a-ref (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/formal-is-a-ref/REF.input)"
  expected_output=$(< "../tests/formal-is-a-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "REF alias-two-formals (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/alias-two-formals/REF.input)"
  expected_output=$(< "../tests/alias-two-formals/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
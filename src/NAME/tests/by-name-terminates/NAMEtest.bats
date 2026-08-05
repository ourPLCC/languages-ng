#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NAME by-name-terminates (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/by-name-terminates/NAME.input)"
  expected_output=$(< "../tests/by-name-terminates/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

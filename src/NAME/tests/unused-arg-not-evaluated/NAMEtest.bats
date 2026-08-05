#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NAME unused-arg-not-evaluated (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/unused-arg-not-evaluated/NAME.input)"
  expected_output=$(< "../tests/unused-arg-not-evaluated/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

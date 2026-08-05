#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NAME operand-evaluated-at-use (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/operand-evaluated-at-use/NAME.input)"
  expected_output=$(< "../tests/operand-evaluated-at-use/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

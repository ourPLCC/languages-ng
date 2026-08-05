#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NAME jensen-device (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/jensen-device/NAME.input)"
  expected_output=$(< "../tests/jensen-device/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

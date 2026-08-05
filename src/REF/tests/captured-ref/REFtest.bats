#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "REF captured-ref (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/captured-ref/REF.input)"
  expected_output=$(< "../tests/captured-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

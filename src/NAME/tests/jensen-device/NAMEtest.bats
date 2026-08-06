#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "NAME jensen-device (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/jensen-device/NAME.input)"
  expected_output=$(< "../tests/jensen-device/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NAME jensen-device (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/jensen-device/NAME.input)"
  expected_output=$(< "../tests/jensen-device/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NAME jensen-device (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/jensen-device/NAME.input)"
  expected_output=$(< "../tests/jensen-device/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

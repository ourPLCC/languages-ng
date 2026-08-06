#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "NAME thunk-reevaluated-per-use (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/thunk-reevaluated-per-use/NAME.input)"
  expected_output=$(< "../tests/thunk-reevaluated-per-use/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NAME thunk-reevaluated-per-use (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/thunk-reevaluated-per-use/NAME.input)"
  expected_output=$(< "../tests/thunk-reevaluated-per-use/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NAME thunk-reevaluated-per-use (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/thunk-reevaluated-per-use/NAME.input)"
  expected_output=$(< "../tests/thunk-reevaluated-per-use/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

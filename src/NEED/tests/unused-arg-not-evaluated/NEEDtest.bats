#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NEED unused-arg-not-evaluated (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/unused-arg-not-evaluated/NEED.input)"
  expected_output=$(< "../tests/unused-arg-not-evaluated/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NEED unused-arg-not-evaluated (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/unused-arg-not-evaluated/NEED.input)"
  expected_output=$(< "../tests/unused-arg-not-evaluated/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NEED unused-arg-not-evaluated (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/unused-arg-not-evaluated/NEED.input)"
  expected_output=$(< "../tests/unused-arg-not-evaluated/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

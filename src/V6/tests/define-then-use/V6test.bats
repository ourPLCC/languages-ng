#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V6 define-then-use (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/define-then-use/V6.input)"
  expected_output=$(< "../tests/define-then-use/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define-then-use (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/define-then-use/V6.input)"
  expected_output=$(< "../tests/define-then-use/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define-then-use (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/define-then-use/V6.input)"
  expected_output=$(< "../tests/define-then-use/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

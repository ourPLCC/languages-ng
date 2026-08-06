#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V6 define (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/define/V6.input)"
  expected_output=$(< "../tests/define/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/define/V6.input)"
  expected_output=$(< "../tests/define/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/define/V6.input)"
  expected_output=$(< "../tests/define/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

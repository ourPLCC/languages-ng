#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 declare-define (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/declare-define/TYPE1.input)"
  expected_output=$(< "../tests/declare-define/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 declare-define (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/declare-define/TYPE1.input)"
  expected_output=$(< "../tests/declare-define/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "TYPE1 declare-define (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/declare-define/TYPE1.input)"
  expected_output=$(< "../tests/declare-define/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

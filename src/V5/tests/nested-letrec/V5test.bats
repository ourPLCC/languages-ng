#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "V5 nested-letrec (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nested-letrec/V5.input)"
  expected_output=$(< "../tests/nested-letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 nested-letrec (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nested-letrec/V5.input)"
  expected_output=$(< "../tests/nested-letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 nested-letrec (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nested-letrec/V5.input)"
  expected_output=$(< "../tests/nested-letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

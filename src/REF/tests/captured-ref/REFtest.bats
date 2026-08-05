#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "REF captured-ref (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/captured-ref/REF.input)"
  expected_output=$(< "../tests/captured-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "REF captured-ref (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/captured-ref/REF.input)"
  expected_output=$(< "../tests/captured-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "REF captured-ref (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/captured-ref/REF.input)"
  expected_output=$(< "../tests/captured-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

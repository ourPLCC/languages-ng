#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NEED memoized-across-calls (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/memoized-across-calls/NEED.input)"
  expected_output=$(< "../tests/memoized-across-calls/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NEED memoized-across-calls (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/memoized-across-calls/NEED.input)"
  expected_output=$(< "../tests/memoized-across-calls/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "NEED memoized-across-calls (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/memoized-across-calls/NEED.input)"
  expected_output=$(< "../tests/memoized-across-calls/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

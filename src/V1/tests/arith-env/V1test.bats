#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V1 arith-env (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/arith-env/V1.input)"
  expected_output=$(< "../tests/arith-env/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 arith-env (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/arith-env/V1.input)"
  expected_output=$(< "../tests/arith-env/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 arith-env (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/arith-env/V1.input)"
  expected_output=$(< "../tests/arith-env/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

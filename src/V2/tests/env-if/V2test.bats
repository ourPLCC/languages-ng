#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V2 env-if (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/env-if/V2.input)"
  expected_output=$(< "../tests/env-if/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 env-if (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/env-if/V2.input)"
  expected_output=$(< "../tests/env-if/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 env-if (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/env-if/V2.input)"
  expected_output=$(< "../tests/env-if/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

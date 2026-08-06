#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "REF nonvar-arg-is-a-copy (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nonvar-arg-is-a-copy/REF.input)"
  expected_output=$(< "../tests/nonvar-arg-is-a-copy/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "REF nonvar-arg-is-a-copy (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nonvar-arg-is-a-copy/REF.input)"
  expected_output=$(< "../tests/nonvar-arg-is-a-copy/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "REF nonvar-arg-is-a-copy (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nonvar-arg-is-a-copy/REF.input)"
  expected_output=$(< "../tests/nonvar-arg-is-a-copy/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

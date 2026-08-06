#!/usr/bin/env bats

load '../bats-tmpdir.bash'
load '../check-run-complete.bash'

write_report () { printf '%s\n' "$@" > "${BATS_TEST_TMPDIR}/report.tap"; }

# A report for a run that planned $1 tests but stopped at $2, whose last line
# is "$3 $2 ..." -- pass 'ok' or 'not ok' as $3.
write_truncated_report () {
  local planned="$1" reached="$2" last_status="$3" i
  {
    printf '1..%s\n' "${planned}"
    for (( i = 1; i < reached; i++ )); do printf 'ok %d test %d\n' "$i" "$i"; done
    printf '%s %d test %d\n' "${last_status}" "${reached}" "${reached}"
  } > "${BATS_TEST_TMPDIR}/report.tap"
}

@test "a complete run passes" {
  write_report '1..3' 'ok 1 a' 'ok 2 b' 'ok 3 c'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 0 ]
}

# The check must never turn ordinary test failures into harness failures.
@test "a complete run with real test failures still passes" {
  write_report '1..3' 'ok 1 a' 'not ok 2 b' 'ok 3 c'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a run truncated after 'ok 96' is a harness failure" {
  write_truncated_report 130 96 'ok'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'HARNESS FAILURE'* ]]
  [[ "$output" == *'planned : 130 tests'* ]]
  [[ "$output" == *'reached : 96'* ]]
}

# The exact case observed in issue #31.
@test "a run truncated after 'not ok 96' is a harness failure, not a test failure" {
  write_truncated_report 130 96 'not ok'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'reached : 96'* ]]
}

@test "a missing report is a harness failure" {
  run check_run_complete "${BATS_TEST_TMPDIR}/absent.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'no report was written'* ]]
}

@test "a report with no plan line is a harness failure" {
  write_report 'ok 1 a'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 1 ]
  [[ "$output" == *'no TAP plan line'* ]]
}

@test "an empty suite is complete" {
  write_report '1..0'
  run check_run_complete "${BATS_TEST_TMPDIR}/report.tap"
  [ "$status" -eq 0 ]
}

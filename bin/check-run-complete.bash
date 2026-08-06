# Decide whether a bats run actually finished, from the TAP report written by
# `bats --report-formatter tap --output <dir>`.
#
# A run that dies partway -- disk exhaustion, OOM, SIGKILL -- leaves output
# that reads like an ordinary result: the last line is often a `not ok` naming
# whatever test was running, and `grep -c '^ok '` returns a plausible number.
# Issue #31 records a run that died at test 96 having written
# `not ok 96 V4 seq (javascript)`, a test that passes whenever the run
# completes.
#
# The witness is the TAP plan. bats writes `1..N` before test 1 runs, so a
# complete run always has a line for test N. Its absence means the harness
# stopped, not that a test failed.
#
# awk throughout rather than grep/tail pipelines, deliberately: no
# "grep found nothing" exit status can leak into the result.

# Print the planned test count from a TAP report; print nothing if absent.
function run_plan_count () {
  awk '/^1\.\.[0-9]+$/ { print substr($0, 4); exit }' "$1"
}

# Print the number of the highest test the run reached; 0 if none.
# Note the field difference: "ok 12 name" vs "not ok 12 name".
function run_last_test_number () {
  awk '/^ok [0-9]+/     { n = $2 }
       /^not ok [0-9]+/ { n = $3 }
       END              { print n + 0 }' "$1"
}

# Quoted heredoc for the prose, printf for the values: nothing in the advice
# text can expand by accident.
function run_incomplete_banner () {
  local report="$1" reason="$2" planned="$3" reached="$4"
  {
    printf '\n%s\n' '================================================================'
    printf 'HARNESS FAILURE: the test run did not finish.\n\n'
    printf '  reason  : %s\n' "${reason}"
    printf '  planned : %s tests\n' "${planned}"
    printf '  reached : %s\n' "${reached}"
    printf '  report  : %s\n\n' "${report}"
    cat <<'ADVICE'
Nothing above is a trustworthy test result. A trailing 'not ok'
names the test that was running when the harness stopped, not a
test that is broken, and the pass count counts a truncated file.

The usual cause is the filesystem holding TMPDIR filling up:
  df -h "${TMPDIR:-/tmp}"

A run killed this way also leaks its whole scratch tree, since
bats only removes it in an EXIT trap. Check for stale
/tmp/bats-run-* directories and remove them.

See dev-docs/issues/031-suite-exhausts-disk-and-reports-spurious-failure.md
ADVICE
    printf '%s\n' '================================================================'
  } >&2
}

# 0 if the report shows a run that reached its last test. Otherwise print the
# banner and return 1.
function check_run_complete () {
  local report="$1" planned reached

  [[ -f "${report}" ]] \
    || { run_incomplete_banner "${report}" 'no report was written' '?' '?'; return 1; }

  planned="$(run_plan_count "${report}")"
  [[ -n "${planned}" ]] \
    || { run_incomplete_banner "${report}" 'the report has no TAP plan line' '?' '?'; return 1; }

  reached="$(run_last_test_number "${report}")"
  if (( reached < planned )); then
    run_incomplete_banner "${report}" 'the run stopped before its last test' \
      "${planned}" "${reached}"
    return 1
  fi
}

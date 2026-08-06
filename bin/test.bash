#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
source "${SCRIPT_DIR}/check-run-complete.bash"
cd "${PROJECT_ROOT}"

# --report-formatter writes a machine-readable TAP copy *alongside* whatever
# formatter stdout is using, so an interactive run keeps its pretty output.
# bats writes it incrementally, which is what makes it a usable witness even
# when the run dies partway.
report_dir="$(mktemp -d)" || {
  printf 'test.bash: could not create a report directory (disk full?)\n' >&2
  exit 2
}

# Remove the report dir on any exit -- normal completion, an error under
# set -e, or this script itself being killed (Ctrl-C, CI timeout, OOM) --
# unless keep_report is set, which happens on the harness-failure path below
# so the banner's named path still exists to inspect.
keep_report=
trap '[[ -n "${keep_report}" ]] || rm -rf "${report_dir}"' EXIT

bats_status=0
bats --recursive --report-formatter tap --output "${report_dir}" src bin \
  || bats_status=$?

# Exit 2, distinct from bats's 1, so a dead harness is never read as a test
# failure by a caller, a CI step, or a person. Full contract: 0 means every
# test passed, 1 means the run completed with real test failures, 2 means
# the harness itself did not finish. Any other value below is bats's own
# exit status passed through untouched -- e.g. 130 if bats was SIGINT'd, or
# 137 for an OOM kill that lands after the last `ok N` is written, so
# check_run_complete sees a complete report and this branch is never taken.
if ! check_run_complete "${report_dir}/report.tap"; then
  keep_report=1     # kept on the failure path; the banner names it
  exit 2
fi

exit "${bats_status}"

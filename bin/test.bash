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

bats_status=0
bats --recursive --report-formatter tap --output "${report_dir}" src bin \
  || bats_status=$?

# Exit 2, distinct from bats's 1, so a dead harness is never read as a test
# failure by a caller, a CI step, or a person.
check_run_complete "${report_dir}/report.tap" || exit 2

rm -rf "${report_dir}"     # kept on the failure path; the banner names it
exit "${bats_status}"

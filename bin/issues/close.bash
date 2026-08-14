#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"

usage() {
    echo "Usage: $(basename "$0") <id>"
    echo "  id  issue number, e.g. 135"
    echo
    echo "Fills in the issue's 'closed' date and stages the file."
    echo
    echo "Issue files never move: status is the 'closed' frontmatter field,"
    echo "so no link to an issue ever needs rewriting."
    exit 1
}

[[ $# -ne 1 ]] && usage

padded=$(printf '%03d' "$(( 10#$1 ))")

matches=( "${ISSUES_DIR}/${padded}"-*.md )
if [[ ! -e "${matches[0]}" ]]; then
    # Unpadded IDs (e.g. 112) predate zero-padding in new.bash.
    matches=( "${ISSUES_DIR}/$(( 10#$1 ))"-*.md )
fi
if [[ ! -e "${matches[0]}" ]]; then
    echo "error: no issue matching '${ISSUES_DIR}/${padded}-*.md'" >&2
    exit 1
fi
if [[ ${#matches[@]} -gt 1 ]]; then
    echo "error: multiple files match issue $1: ${matches[*]}" >&2
    exit 1
fi

issue_file="${matches[0]}"
basename="${issue_file##*/}"

# Already closed? The frontmatter says so.
existing=$(awk '
    NR == 1 { next }
    /^---$/ { exit }
    index($0, "closed:") == 1 { line = $0; sub(/^[^:]*:[[:space:]]*/, "", line); print line; exit }
' "${issue_file}")
if [[ -n "${existing}" ]]; then
    echo "error: issue $1 is already closed (${existing}): ${issue_file}" >&2
    exit 1
fi

today="$(date +%Y-%m-%d)"

# Fill in the closed date, inside the frontmatter block only: a "closed:"
# line in the body must never be touched.
awk -v today="${today}" '
    /^---$/ { n++ }
    n == 1 && !filled && index($0, "closed:") == 1 { print "closed: " today; filled = 1; next }
    { print }
' "${issue_file}" > "${issue_file}.tmp"
mv "${issue_file}.tmp" "${issue_file}"

if ! grep -qx "closed: ${today}" "${issue_file}"; then
    echo "error: ${issue_file} has no 'closed:' key in its frontmatter" >&2
    exit 1
fi

git add "${issue_file}"

bin/issues/check.bash

echo "closed ${issue_file} (closed: ${today})"
echo "Commit:"
echo "  docs(issues): close issue $(( 10#$1 )) (<short title>)"

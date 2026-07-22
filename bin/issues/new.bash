#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"
NEXT_ID_FILE="${ISSUES_DIR}/.next-id.txt"
TEMPLATE="${ISSUES_DIR}/TEMPLATE.md"

usage() {
    echo "Usage: $(basename "$0") <slug> [type]"
    echo "  slug  hyphen-separated short name, e.g. scanner-hangs-on-eof"
    echo "  type  conventional commit type: fix, feat, refactor, … (default: blank)"
    exit 1
}

[[ $# -lt 1 ]] && usage

SLUG="$1"
TYPE="${2:-}"
DATE="$(date +%Y-%m-%d)"

id=$(cat "${NEXT_ID_FILE}")
padded=$(printf '%03d' "${id}")
filename="${ISSUES_DIR}/${padded}-${SLUG}.md"

sed \
    -e "s/NNN/${padded}/" \
    -e "s/Short descriptive title/${SLUG}/" \
    -e "s/(conventional commit type: fix, feat, refactor, perf, docs, test, …)/${TYPE}/" \
    -e "s|(this repo by default; set to the upstream repo, e.g. ourPLCC/plcc-ng, if this issue is actually about a defect found there)|this repo|" \
    -e "s/YYYY-MM-DD/${DATE}/" \
    "${TEMPLATE}" > "${filename}"

echo $(( id + 1 )) > "${NEXT_ID_FILE}"

echo "${filename}"

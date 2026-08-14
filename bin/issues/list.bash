#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"

usage() {
    echo "Usage: $(basename "$0")"
    echo
    echo "Print the path of every open issue, one per line, in id order."
    echo "An issue is open while its 'closed:' frontmatter field is empty."
    echo
    echo "Paths are relative to the root of the tree this script lives in,"
    echo "which is also where it runs. To list a worktree's open issues, run"
    echo "that worktree's copy from that worktree."
    echo
    echo "Compose it with anything that takes file arguments:"
    echo "  $(basename "$0") | xargs head -n 50      # frontmatter, title, and summary"
    echo "  $(basename "$0") | xargs grep -l readline"
}

# A mistyped flag must not silently produce a list the caller did not ask
# for. Issue #43 is what the loose version of this guard costs.
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        exit 0
    fi
    echo "$(basename "$0"): unexpected argument: $1" >&2
    usage >&2
    exit 1
fi

# Zero-padded ids make the glob's lexicographic order id order, and grep
# reports files in argument order, so nothing needs sorting.
shopt -s nullglob
issues=( "${ISSUES_DIR}"/[0-9]*.md )
shopt -u nullglob

(( ${#issues[@]} > 0 )) || exit 0

# The open/closed test documented in dev-docs/issue-conventions.md. grep -L
# exits 1 when it selects no file -- an entirely closed backlog -- which
# 'set -e' would otherwise turn into a failure. Exit 2 and above stay fatal:
# a real grep error must not read as "nothing is open".
status=0
grep -L '^closed: [0-9]' "${issues[@]}" || status=$?
if (( status > 1 )); then
    exit "${status}"
fi

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"
ROADMAP="dev-docs/roadmap.md"

usage() {
    echo "Usage: $(basename "$0") <id>"
    echo "  id  issue number, e.g. 135"
    echo
    echo "Fills in the issue's 'closed' date, removes its entry from the"
    echo "Open Issues section of ${ROADMAP}, and checks its box in any"
    echo "milestone task list. Stages the changes; you review and commit."
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

# Roadmap, pass 1: in milestone task lists, check the box. The link is not
# touched — it has always been issues/${basename} and stays that way.
sed -i -e "s|\[ \] \(\[#[0-9]*\](issues/${basename})\)|[x] \1|" "${ROADMAP}"

# Roadmap, pass 2: drop the issue's Open Issues entry — the bullet line plus
# its indented continuation lines, so back-to-back neighbors are untouched —
# then drop any "###" heading whose section is now empty.
awk -v link="(issues/${basename})" '
    skip { if ($0 ~ /^[ \t]/) next; skip = 0 }
    /^- / && index($0, link) { skip = 1; next }
    { lines[n++] = $0 }
    END {
        for (i = 0; i < n; i++) {
            if (lines[i] ~ /^### /) {
                j = i + 1
                while (j < n && lines[j] == "") j++
                if (j >= n || lines[j] ~ /^##/) { i = j - 1; continue }
            }
            keep[m++] = lines[i]
        }
        for (k = 0; k < m; k++) {
            if (keep[k] == "") { blank = 1; continue }
            if (printed && blank) print ""
            print keep[k]
            blank = 0; printed = 1
        }
    }
' "${ROADMAP}" > "${ROADMAP}.tmp"
mv "${ROADMAP}.tmp" "${ROADMAP}"

git add "${issue_file}" "${ROADMAP}"

bin/issues/check.bash

echo "closed ${issue_file} (closed: ${today})"
echo "Review ${ROADMAP} (milestone rationale text is not auto-edited), then commit:"
echo "  docs(issues): close issue $(( 10#$1 )) (<short title>), update roadmap"

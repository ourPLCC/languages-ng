#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"
ROADMAP="dev-docs/roadmap.md"
NEXT_ID_FILE="${ISSUES_DIR}/.next-id.txt"

failures=0
fail() {
    echo "FAIL: $*" >&2
    failures=$(( failures + 1 ))
}

# Frontmatter is flat scalars, one key per line: the leading block between
# the first "---" and the next one. These two helpers are the only readers.
fm_keys() {
    awk 'NR == 1 { next } /^---$/ { exit } /^[a-z_]+:/ { sub(/:.*/, ""); print }' "$1"
}
fm_value() {
    awk -v key="$2" '
        NR == 1 { next }
        /^---$/ { exit }
        index($0, key ":") == 1 { line = $0; sub(/^[^:]*:[[:space:]]*/, "", line); print line; exit }
    ' "$1"
}

# The open/closed directory split must not creep back.
if [[ -d "${ISSUES_DIR}/done" ]]; then
    fail "${ISSUES_DIR}/done exists; status is a 'closed:' date, not a directory"
fi

open_count=0
closed_count=0
max_id=0

for f in "${ISSUES_DIR}"/[0-9]*.md; do
    [[ -e "${f}" ]] || break
    basename="${f##*/}"
    id=$(( 10#${basename%%-*} ))
    (( id > max_id )) && max_id=${id}

    if [[ "$(head -n 1 "${f}")" != "---" ]]; then
        fail "${basename} does not open with a '---' frontmatter block"
        continue
    fi
    if ! awk 'NR > 1 && /^---$/ { found = 1; exit } END { exit !found }' "${f}"; then
        fail "${basename} frontmatter block is never closed"
        continue
    fi

    keys="$(fm_keys "${f}")"
    missing=0
    for key in type target opened closed; do
        if ! grep -qx -- "${key}" <<< "${keys}"; then
            fail "${basename} frontmatter has no '${key}:' key"
            missing=1
        fi
    done
    if (( missing )); then continue; fi

    opened="$(fm_value "${f}" opened)"
    closed="$(fm_value "${f}" closed)"
    [[ "${opened}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
        || fail "${basename} has a malformed opened date: '${opened}'"
    if [[ -n "${closed}" ]]; then
        [[ "${closed}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
            || fail "${basename} has a malformed closed date: '${closed}'"
        closed_count=$(( closed_count + 1 ))
    else
        open_count=$(( open_count + 1 ))
    fi

    # Open issues are listed in the roadmap; closed ones are not.
    if [[ -z "${closed}" ]]; then
        grep -q "^- \*\*\[#${id}\](issues/${basename})" "${ROADMAP}" \
            || fail "open issue ${basename} has no Open Issues entry in ${ROADMAP}"
    else
        if grep -q "^- \*\*\[#${id}\](issues/${basename})" "${ROADMAP}"; then
            fail "closed issue ${basename} still has an Open Issues entry in ${ROADMAP}"
        fi
    fi
done

# Every roadmap issue link resolves.
while IFS= read -r target; do
    [[ -e "${ISSUES_DIR}/${target}" ]] \
        || fail "roadmap links issues/${target} but that file does not exist"
done < <(grep -o '(issues/[^)]*\.md)' "${ROADMAP}" | tr -d '()' | sed 's|^issues/||' | sort -u)

# Milestone task lists: the checkbox agrees with the issue's closed field.
while IFS= read -r line; do
    box="$(sed -n 's|^[0-9]*\. \[\([ x]\)\].*|\1|p' <<< "${line}")"
    target="$(sed -n 's|.*(issues/\([^)]*\.md\)).*|\1|p' <<< "${line}")"
    if [[ -z "${target}" ]]; then
        fail "milestone item links no issue: ${line}"
        continue
    fi
    if [[ ! -e "${ISSUES_DIR}/${target}" ]]; then
        fail "milestone item links a nonexistent issue: ${line}"
        continue
    fi
    milestone_closed="$(fm_value "${ISSUES_DIR}/${target}" closed)"
    if [[ "${box}" == " " && -n "${milestone_closed}" ]]; then
        fail "unchecked milestone item links a closed issue: ${line}"
    fi
    if [[ "${box}" == "x" && -z "${milestone_closed}" ]]; then
        fail "checked milestone item links an open issue: ${line}"
    fi
done < <(grep '^[0-9]*\. \[[ x]\] ' "${ROADMAP}" || true)

# The ID counter is ahead of every issue ever filed.
next_id=$(( 10#$(cat "${NEXT_ID_FILE}") ))
(( next_id > max_id )) \
    || fail "${NEXT_ID_FILE} is ${next_id} but issue ${max_id} already exists"

if (( failures > 0 )); then
    echo "${failures} check(s) failed" >&2
    exit 1
fi
echo "OK: ${open_count} open, ${closed_count} closed, roadmap consistent, next id ${next_id}"

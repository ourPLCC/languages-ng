#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

ISSUES_DIR="dev-docs/issues"
NEXT_ID_FILE="${ISSUES_DIR}/.next-id.txt"

# An upstream ref is "owner/repo" plus the issue's filename in that repo's
# dev-docs/issues/. Deliberately not GitHub's owner/repo#N form: upstream
# numbers issues and pull requests in one sequence, so #N there names a
# pull request, not the issue meant.
UPSTREAM_RE='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+[[:space:]]+[0-9]+-[A-Za-z0-9._-]+\.md$'

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

    # An open issue carries the triage summary that used to live in the
    # roadmap's Open Issues entry. Closed issues are not required to carry
    # one.
    if [[ -z "${closed}" ]]; then
        awk '
            $0 ~ /^## Summary[[:space:]]*$/ { in_s = 1; next }
            in_s && /^## /                  { exit }
            in_s && NF                      { found = 1; exit }
            END                             { exit !found }
        ' "${f}" || fail "open issue ${basename} has no non-empty '## Summary' section"
    fi

    # `upstream:` is optional: absent and empty both mean "not reported".
    # When present, every comma-separated ref must be well formed. An empty
    # segment fails the pattern, which is what catches a stray comma.
    upstream="$(fm_value "${f}" upstream)"
    if [[ -n "${upstream}" ]]; then
        while IFS= read -r ref; do
            if [[ ! "${ref}" =~ ${UPSTREAM_RE} ]]; then
                fail "${basename} has a malformed upstream ref: '${ref}'"
            fi
        done < <(tr ',' '\n' <<< "${upstream}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    fi
done

# The ID counter is ahead of every issue ever filed.
next_id=$(( 10#$(cat "${NEXT_ID_FILE}") ))
(( next_id > max_id )) \
    || fail "${NEXT_ID_FILE} is ${next_id} but issue ${max_id} already exists"

if (( failures > 0 )); then
    echo "${failures} check(s) failed" >&2
    exit 1
fi
echo "OK: ${open_count} open, ${closed_count} closed, next id ${next_id}"

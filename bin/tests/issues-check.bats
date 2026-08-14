#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# Exercises bin/issues/check.bash against a throwaway repo laid out like
# this one, so the real dev-docs/issues/ is never read.
setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/bin/issues" "${REPO}/dev-docs/issues"

  cp "${BATS_TEST_DIRNAME}/../issues/check.bash" "${REPO}/bin/issues/check.bash"
  echo 900 > "${REPO}/dev-docs/issues/.next-id.txt"
}

# Write a well-formed issue file. A blank closed value means open.
make_issue() {
  local name="$1" closed="$2"
  cat > "${REPO}/dev-docs/issues/${name}" <<EOF
---
type: chore
target: this repo
opened: 2026-01-01
closed:${closed:+ ${closed}}
---

# ${name%%-*} - ${name}

## Summary

A one-paragraph triage summary.

## Description

The full account.
EOF
}

@test "check.bash passes an open issue with no roadmap.md present" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"1 open, 0 closed"* ]]
}

@test "check.bash passes a closed issue with no roadmap.md present" {
  make_issue "001-closed-one.md" "2026-01-02"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"0 open, 1 closed"* ]]
}

@test "check.bash never mentions the roadmap" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/check.bash"

  [[ "${output}" != *"roadmap"* ]]
}

@test "check.bash still rejects a malformed opened date" {
  make_issue "001-open-one.md" ""
  sed -i 's/^opened: .*/opened: January 1st/' "${REPO}/dev-docs/issues/001-open-one.md"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"malformed opened date"* ]]
}

@test "check.bash still rejects an id at or above .next-id.txt" {
  make_issue "901-too-new.md" ""

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"already exists"* ]]
}

# Write an issue whose body is exactly the given lines: for Summary shapes
# that make_issue's well-formed body cannot express.
make_issue_body() {
  local name="$1" closed="$2" body="$3"
  cat > "${REPO}/dev-docs/issues/${name}" <<EOF
---
type: chore
target: this repo
opened: 2026-01-01
closed:${closed:+ ${closed}}
---

# ${name%%-*} - ${name}

${body}
EOF
}

@test "check.bash rejects an open issue with no Summary section" {
  make_issue_body "001-no-summary.md" "" "## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"001-no-summary.md has no non-empty '## Summary' section"* ]]
}

@test "check.bash rejects an open issue whose Summary is empty" {
  make_issue_body "001-empty-summary.md" "" "## Summary

## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"has no non-empty '## Summary' section"* ]]
}

@test "check.bash rejects a Summary holding only whitespace" {
  printf '%s\n' '---' 'type: chore' 'target: this repo' 'opened: 2026-01-01' \
      'closed:' '---' '' '# 001 - ws' '' '## Summary' '   ' '	' \
      '## Description' '' 'x' > "${REPO}/dev-docs/issues/001-ws-summary.md"

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"has no non-empty '## Summary' section"* ]]
}

@test "check.bash does not require a Summary on a closed issue" {
  make_issue_body "001-closed-no-summary.md" "2026-01-02" "## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}

@test "check.bash accepts a Summary containing a ### subheading" {
  make_issue_body "001-sub.md" "" "## Summary

Prose.

### An aside

More prose.

## Description

The full account."

  run "${REPO}/bin/issues/check.bash"

  [ "${status}" -eq 0 ]
}

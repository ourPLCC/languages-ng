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

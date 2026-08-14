#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# Exercises bin/issues/close.bash against a throwaway git repo laid out
# like this one. close.bash stages its work, so the fixture must be a git
# repo; it also runs check.bash, so that script is copied in too.
setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/bin/issues" "${REPO}/dev-docs/issues"

  cp "${BATS_TEST_DIRNAME}/../issues/close.bash" "${REPO}/bin/issues/close.bash"
  cp "${BATS_TEST_DIRNAME}/../issues/check.bash" "${REPO}/bin/issues/check.bash"
  echo 900 > "${REPO}/dev-docs/issues/.next-id.txt"

  git init -q "${REPO}"
}

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

@test "close.bash closes an issue with no roadmap.md present" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -eq 0 ]
  grep -q "^closed: 20" "${REPO}/dev-docs/issues/001-open-one.md"
}

@test "close.bash never mentions the roadmap" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -eq 0 ]
  [[ "${output}" != *"roadmap"* ]]
  [[ "${output}" != *"Roadmap"* ]]
}

@test "close.bash stages only the issue file" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -eq 0 ]
  run git -C "${REPO}" diff --cached --name-only
  [ "${output}" = "dev-docs/issues/001-open-one.md" ]
}

@test "close.bash refuses an already-closed issue" {
  make_issue "001-closed-one.md" "2026-01-02"

  run "${REPO}/bin/issues/close.bash" 1

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"already closed"* ]]
}

@test "close.bash refuses an id with no issue file" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/close.bash" 2

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"no issue matching"* ]]
}

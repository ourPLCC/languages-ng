#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# Exercises bin/issues/list.bash against a throwaway repo laid out like this
# one, so the real dev-docs/issues/ is never read.
setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/bin/issues" "${REPO}/dev-docs/issues"

  cp "${BATS_TEST_DIRNAME}/../issues/list.bash" "${REPO}/bin/issues/list.bash"
}

# Write an issue file. A blank closed value means open.
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
EOF
}

@test "list.bash prints the path of an open issue" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/list.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = "dev-docs/issues/001-open-one.md" ]
}

@test "list.bash omits closed issues" {
  make_issue "001-open-one.md" ""
  make_issue "002-closed-one.md" "2026-01-02"

  run "${REPO}/bin/issues/list.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = "dev-docs/issues/001-open-one.md" ]
}

@test "list.bash prints open issues in id order" {
  make_issue "010-ten.md" ""
  make_issue "002-two.md" ""
  make_issue "001-one.md" ""

  run "${REPO}/bin/issues/list.bash"

  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "dev-docs/issues/001-one.md" ]
  [ "${lines[1]}" = "dev-docs/issues/002-two.md" ]
  [ "${lines[2]}" = "dev-docs/issues/010-ten.md" ]
}

@test "list.bash exits 0 with no output when every issue is closed" {
  make_issue "001-closed-one.md" "2026-01-02"

  run "${REPO}/bin/issues/list.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = "" ]
}

@test "list.bash exits 0 with no output when there are no issue files" {
  run "${REPO}/bin/issues/list.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = "" ]
}

# Issue #43: new.bash's loose argument guard turned --help into a slug and
# filed a spurious issue. list.bash writes nothing, but the same loose guard
# would silently ignore a mistyped flag and print a list the caller did not
# ask for. Reject what we do not understand.
@test "list.bash --help prints usage and exits 0" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/list.bash" --help

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage:"* ]]
  [[ "${output}" != *"001-open-one.md"* ]]
}

@test "list.bash rejects an unknown argument" {
  make_issue "001-open-one.md" ""

  run "${REPO}/bin/issues/list.bash" --closed

  [ "${status}" -ne 0 ]
  [[ "${output}" != *"001-open-one.md"* ]]
}

@test "list.bash reads the tree it lives in, not the caller's directory" {
  make_issue "001-open-one.md" ""

  local elsewhere="${BATS_TEST_TMPDIR}/elsewhere"
  mkdir -p "${elsewhere}"
  cd "${elsewhere}"

  run "${REPO}/bin/issues/list.bash"

  [ "${status}" -eq 0 ]
  [ "${output}" = "dev-docs/issues/001-open-one.md" ]
}

#!/usr/bin/env bats

# Exercises bin/clean.bash against a throwaway repo laid out like this
# one, so the real src/ is never touched.
setup() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}/bin" "${REPO}/src/LANG/java"

  cat > "${REPO}/.gitignore" <<'EOF'
*.class
plcc-ng/
__pycache__/
EOF

  echo 'spec contents' > "${REPO}/src/LANG/java/spec.plcc"
  echo 'work in progress' > "${REPO}/src/LANG/java/untracked.plcc"
  mkdir -p "${REPO}/src/LANG/java/plcc-ng" "${REPO}/src/LANG/java/__pycache__"
  echo 'stale' > "${REPO}/src/LANG/java/plcc-ng/spec.json"
  echo 'stale' > "${REPO}/src/LANG/java/__pycache__/mod.pyc"
  echo 'stale' > "${REPO}/src/LANG/java/Val.class"

  git -C "${REPO}" init --quiet
  git -C "${REPO}" add -A

  cp "${BATS_TEST_DIRNAME}/../clean.bash" "${REPO}/bin/clean.bash"
}

@test "clean.bash removes ignored build artifacts under src" {
  "${REPO}/bin/clean.bash"

  [ ! -e "${REPO}/src/LANG/java/plcc-ng" ]
  [ ! -e "${REPO}/src/LANG/java/__pycache__" ]
  [ ! -e "${REPO}/src/LANG/java/Val.class" ]
}

@test "clean.bash preserves tracked and untracked source files" {
  "${REPO}/bin/clean.bash"

  [ -f "${REPO}/src/LANG/java/spec.plcc" ]
  [ "$(< "${REPO}/src/LANG/java/untracked.plcc")" = 'work in progress' ]
}

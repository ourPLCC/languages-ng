#!/usr/bin/env bats

load '../relocate.bash'

# Builds a throwaway git repo that mimics src/: one language directory
# with a spec, plus the three kinds of build artifact .gitignore names.
# No commit is made -- `git ls-files --cached` reads the index, so
# `git add` is enough and no user.name/user.email config is needed.
setup() {
  FROM="${BATS_TEST_TMPDIR}/from"
  TO="${BATS_TEST_TMPDIR}/to"
  mkdir -p "${FROM}/LANG/java" "${TO}"

  cat > "${FROM}/.gitignore" <<'EOF'
*.class
plcc-ng/
__pycache__/
EOF

  echo 'spec contents' > "${FROM}/LANG/java/spec.plcc"

  mkdir -p "${FROM}/LANG/java/plcc-ng/Java" "${FROM}/LANG/java/__pycache__"
  echo 'stale' > "${FROM}/LANG/java/plcc-ng/spec.json"
  echo 'stale' > "${FROM}/LANG/java/plcc-ng/Java/Val.java"
  echo 'stale' > "${FROM}/LANG/java/__pycache__/mod.pyc"
  echo 'stale' > "${FROM}/LANG/java/Val.class"

  git -C "${FROM}" init --quiet
  git -C "${FROM}" add -A
}

@test "relocate_copy_tree omits gitignored build artifacts" {
  relocate_copy_tree "${FROM}" "${TO}"

  [ ! -e "${TO}/LANG/java/plcc-ng" ]
  [ ! -e "${TO}/LANG/java/__pycache__" ]
  [ ! -e "${TO}/LANG/java/Val.class" ]
}

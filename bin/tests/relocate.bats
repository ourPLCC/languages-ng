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

@test "relocate_copy_tree copies tracked source files" {
  relocate_copy_tree "${FROM}" "${TO}"

  [ -f "${TO}/LANG/java/spec.plcc" ]
  [ "$(< "${TO}/LANG/java/spec.plcc")" = 'spec contents' ]
}

@test "relocate_copy_tree copies a new file that was never git added" {
  echo 'brand new' > "${FROM}/LANG/java/newfile.plcc"

  relocate_copy_tree "${FROM}" "${TO}"

  [ "$(< "${TO}/LANG/java/newfile.plcc")" = 'brand new' ]
}

@test "relocate_copy_tree copies uncommitted edits, not indexed content" {
  echo 'edited in the working tree' > "${FROM}/LANG/java/spec.plcc"

  relocate_copy_tree "${FROM}" "${TO}"

  [ "$(< "${TO}/LANG/java/spec.plcc")" = 'edited in the working tree' ]
}

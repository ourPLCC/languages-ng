# Copy every non-ignored file under $1 into $2, preserving relative
# paths. Driving the copy from git means .gitignore is the single source
# of truth for what counts as build output -- a plain `cp -R` also sweeps
# up the gitignored plcc-ng/, __pycache__/, and *.class directories a
# by-hand plcc-rep run leaves behind, which silently corrupts the next
# suite run (issue #25).
#
# --others --exclude-standard is what keeps uncommitted work visible:
# git ls-files yields a path list and tar reads those paths from the
# working tree, so uncommitted edits and never-added files are copied,
# while ignored files are not.
#
# The existence filter covers a tracked file deleted with plain `rm`
# rather than `git rm`: --cached still lists the path, and tar would
# otherwise emit a "Cannot stat" warning for it on every test run.
#
# pipefail matters more than it looks: without it this function returns
# the *extract* tar's status and reports success even when git or the
# archiving tar failed, handing the test a silently incomplete tree.
function relocate_copy_tree () {
  local from="$1" to="$2" to_abs
  git -C "${from}" rev-parse --git-dir >/dev/null 2>&1 \
    || { echo "relocate: ${from} is not in a git checkout" >&2; return 1; }
  to_abs="$(cd "${to}" && pwd)" || return 1
  (
    set -o pipefail
    cd "${from}" || exit 1
    git ls-files -z --cached --others --exclude-standard \
      | while IFS= read -r -d '' f; do
          if [[ -e "${f}" ]]; then printf '%s\0' "${f}"; fi
        done \
      | tar --null -T - -cf - \
      | ( cd "${to_abs}" && tar -xf - )
  )
}

# BATS_TEST_DIRNAME is .../src/<LANG>/tests/<case>. Copy the whole src/
# tree (not just <LANG>/) for two reasons: migrated specs %include a
# sibling top-level directory -- e.g. V1's spec.plcc reaching into
# ../../Env/envRN/<target>/env.plcc -- and the not-yet-migrated languages
# (NAME, NEED, OBJ, TYPE0, TYPE1) run plccmk, which builds in place and
# has no way to be pointed at a spec elsewhere.
#
# The %include half of that is now avoidable: plcc-rep -s <abs spec path>
# resolves %include from the spec's real location while writing build
# output to the cwd, so migrated tests need no copy at all. See the
# follow-up issue filed alongside issue #25.
#
# Then cd into <LANG>, landing in the same place callers already expect
# (unchanged for languages with no cross-directory %include).
function relocate () {
  local lang_dir
  lang_dir="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  local lang_name
  lang_name="$(basename "${lang_dir}")"
  local src_dir
  src_dir="$(cd "${lang_dir}/.." && pwd)"
  cd "${BATS_TEST_TMPDIR}"
  relocate_copy_tree "${src_dir}" .
  cd "${lang_name}"
}

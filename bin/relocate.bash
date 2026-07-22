function relocate () {
  # BATS_TEST_DIRNAME is .../src/<LANG>/tests/<case>. Copy the whole
  # src/ tree (not just <LANG>/) so that specs which %include a sibling
  # top-level directory -- e.g. V1's spec.plcc reaching into
  # ../../Env/envRN/<target>/env.plcc -- still resolve once relocated.
  # Then cd into <LANG>, landing in the same place callers already
  # expect (unchanged for languages with no cross-directory %include).
  local lang_dir
  lang_dir="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  local lang_name
  lang_name="$(basename "${lang_dir}")"
  local src_dir
  src_dir="$(cd "${lang_dir}/.." && pwd)"
  cd "${BATS_TEST_TMPDIR}"
  cp -R "${src_dir}/"* .
  cd "${lang_name}"
}
#!/usr/bin/env bats

load '../bats-tmpdir.bash'

# The image is pinned in two files that cannot read each other:
# .devcontainer/devcontainer.json, which is what your dev environment
# runs, and the CI workflow's container:, which is what CI runs. The
# entire value of pinning both to one digest is that a local pass
# predicts a CI pass, so a silent divergence destroys the guarantee
# without breaking anything visibly. This is the only drift vector the
# container: design leaves open, and unlike the Java, Python and Node
# versions inside the image, both values are readable from a checkout --
# which is what makes it checkable at all.
#
# Extraction is by pattern, not by parser: devcontainer.json carries
# comments and so is not valid JSON, and no YAML parser is guaranteed
# present in the image.

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."

devcontainer_image () {
  sed -nE 's/^[[:space:]]*"image"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
    "${REPO_ROOT}/.devcontainer/devcontainer.json"
}

workflow_image () {
  sed -nE 's/^[[:space:]]*image:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' \
    "${REPO_ROOT}/.github/workflows/test-languages.yaml"
}

# Guard the extractors themselves. Without these, a renamed key or a
# reformatted file yields no match, and the comparison below passes by
# comparing one empty string to another -- a green test proving nothing.

@test "devcontainer.json names exactly one image" {
  run devcontainer_image
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "the workflow names exactly one container image" {
  run workflow_image
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "devcontainer and CI pin the same image" {
  local dev ci
  dev="$(devcontainer_image)"
  ci="$(workflow_image)"
  [ -n "${dev}" ]
  if [[ "${dev}" != "${ci}" ]]; then
    echo "devcontainer.json: ${dev}" >&2
    echo "workflow:          ${ci}" >&2
    return 1
  fi
}

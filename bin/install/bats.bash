#!/usr/bin/env bash

# Install the pinned bats under ~/.local, if it is not already there.
#
# One script, two callers: devcontainer.json's postCreateCommand and the
# CI workflow. That is the point -- bats is the one part of the
# toolchain the pinned image does not carry, so a second copy of this
# logic is a second bats version waiting to diverge.
#
# ~/.local rather than /usr/local because CI and the devcontainer run as
# different users; a user-local install needs no sudo in either. The
# image already has ~/.local/bin on PATH, so the devcontainer needs no
# PATH handling. CI's HOME differs, so the workflow appends to
# GITHUB_PATH itself.
#
# Modeled on ourPLCC/plcc-ng's bin/install/bats.bash so the two
# repositories share one idiom.

set -euo pipefail

BATS_VERSION="1.11.0"

if command -v bats >/dev/null 2>&1 \
    && bats --version | grep -q "${BATS_VERSION}"; then
  echo "bats ${BATS_VERSION} already installed: $(command -v bats)"
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

git clone --depth 1 --branch "v${BATS_VERSION}" \
  https://github.com/bats-core/bats-core.git "${tmp_dir}/bats-core"
"${tmp_dir}/bats-core/install.sh" "${HOME}/.local"

echo "installed bats ${BATS_VERSION} into ${HOME}/.local"

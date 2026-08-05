#!/usr/bin/env bash

# Remove the build output plcc-rep and plccmk leave under src/ --
# plcc-ng/, __pycache__/, and *.class. Uses `git clean -X`, which removes
# only *ignored* files, so .gitignore stays the single source of truth and
# untracked work in progress is never touched.

set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." &> /dev/null && pwd )"
cd "${PROJECT_ROOT}"

git clean -X -d -f src

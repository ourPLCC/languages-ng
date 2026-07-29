# Roadmap

## Open Issues

### Chore

- **[#11](issues/011-devcontainer-image-stale-plcc-ng-version.md) — devcontainer image stale plcc-ng version** *(Target: ourPLCC/devcontainers)*
  The devcontainer image pinned/tagged `plcc-ng:2.0.1` still installs plcc-ng 2.0.0 after a fresh rebuild, silently reintroducing issue #10's bug; needs a corrected image republish.
- **[#12](issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) — CI cannot run plcc-ng-migrated languages**
  CI's test image only installs old-PLCC with no Node.js, so plcc-ng-migrated languages (V0-V3) fail in CI with `command not found` while passing locally — the opposite of local dev; needs plcc-ng + Node.js added to CI's image.

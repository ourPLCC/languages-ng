# Roadmap

## Open Issues

### Chore

- **[#8](issues/008-update-plcc-ng-2.0.0.md) — Update to plcc-ng 2.0.0**
  Adopt plcc-ng 2.0.0 (fixes the #3/#4/#6 workarounds), pin the devcontainer image, and restore the original course materials' camelCased identifiers.
- **[#11](issues/011-devcontainer-image-stale-plcc-ng-version.md) — devcontainer image stale plcc-ng version** *(Target: ourPLCC/devcontainers)*
  The devcontainer image pinned/tagged `plcc-ng:2.0.1` still installs plcc-ng 2.0.0 after a fresh rebuild, silently reintroducing issue #10's bug; needs a corrected image republish.

### Feat

- **[#9](issues/009-migrate-v3-to-plcc-ng.md) — Migrate V3 to plcc-ng**
  Ports V3's grammar and Java semantics to plcc-ng, adds Python and JavaScript semantics, and introduces the envVal Env variant (empty initEnv, checkDuplicates, two-list Bindings constructor) reused by V4-V6.

# Roadmap

## Open Issues

### Chore

- **[#11](issues/011-devcontainer-image-stale-plcc-ng-version.md) — devcontainer image stale plcc-ng version** *(Target: ourPLCC/devcontainers)*
  The devcontainer image pinned/tagged `plcc-ng:2.0.1` still installs plcc-ng 2.0.0 after a fresh rebuild, silently reintroducing issue #10's bug; needs a corrected image republish.

### Feat

- **[#9](issues/009-migrate-v3-to-plcc-ng.md) — Migrate V3 to plcc-ng**
  Ports V3's grammar and Java semantics to plcc-ng, adds Python and JavaScript semantics, and introduces the envVal Env variant (empty initEnv, checkDuplicates, two-list Bindings constructor) reused by V4-V6.

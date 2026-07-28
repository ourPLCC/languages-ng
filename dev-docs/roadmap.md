# Roadmap

## Open Issues

### Chore

- **[#8](issues/008-update-plcc-ng-2.0.0.md) — Update to plcc-ng 2.0.0**
  Adopt plcc-ng 2.0.0 (fixes the #3/#4/#6 workarounds), pin the devcontainer image, and restore the original course materials' camelCased identifiers.
- **[#10](issues/010-plcc-ng-arbno-drops-mid-body-terminal.md) — plcc-ng arbno drops mid-body terminal** *(Target: ourPLCC/plcc-ng)*
  A `**=` rule with a non-capturing terminal between two captures and no separator (e.g. `<LetDecls> **= <SYMBOL> EQUALS <Exp>`) drops the terminal at parse time. Blocks V3's `let`; V3 is paused pending the upstream fix.

### Feat

- **[#9](issues/009-migrate-v3-to-plcc-ng.md) — Migrate V3 to plcc-ng** *(paused — blocked on #10)*
  Ports V3's grammar and Java semantics to plcc-ng, adds Python and JavaScript semantics, and introduces the envVal Env variant (empty initEnv, checkDuplicates, two-list Bindings constructor) reused by V4-V6.

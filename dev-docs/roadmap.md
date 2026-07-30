# Roadmap

## Open Issues

### Feat

- **[#14](issues/014-migrate-v4-to-plcc-ng.md) — Migrate V4 to plcc-ng**
  Ports V4's grammar and Java semantics to plcc-ng and adds Python and JavaScript semantics. V4 is V3 + procedures (proc/application, closures) and the sequence operator, reusing envVal unchanged. Also verifies V4's Prog/ example programs against all three targets.

### Chore

- **[#12](issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) — CI cannot run plcc-ng-migrated languages**
  CI's test image only installs old-PLCC with no Node.js, so plcc-ng-migrated languages (V0-V3) fail in CI with `command not found` while passing locally — the opposite of local dev. Deferred until every language has migrated: the job is `on: pull_request` and no PRs are opened yet, and the fix collapses to basing CI on the devcontainer image once old-PLCC is needed nowhere.

### Docs

- **[#13](issues/013-dev-docs-link-checker-not-fence-aware.md) — dev-docs link checker is not fence-aware**
  The plan-embedded link checker reports 19 broken links, but 15 are Markdown links inside fenced code blocks that were never meant to resolve; its "all links resolve" gate is unsatisfiable until it skips fences, and the 4 real breaks come from a `close.bash` link-rewriting gap.

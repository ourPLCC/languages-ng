# Roadmap

## Open Issues

### Chore

- **[#12](issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) — CI cannot run plcc-ng-migrated languages**
  CI's test image only installs old-PLCC with no Node.js, so plcc-ng-migrated languages (V0-V3) fail in CI with `command not found` while passing locally — the opposite of local dev; needs plcc-ng + Node.js added to CI's image.

### Docs

- **[#13](issues/013-dev-docs-link-checker-not-fence-aware.md) — dev-docs link checker is not fence-aware**
  The plan-embedded link checker reports 19 broken links, but 15 are Markdown links inside fenced code blocks that were never meant to resolve; its "all links resolve" gate is unsatisfiable until it skips fences, and the 4 real breaks come from a `close.bash` link-rewriting gap.

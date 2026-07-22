# Roadmap

## Open Issues

### Feat

- **[#2](issues/002-migrate-v0-to-plcc-ng.md) — Migrate V0 to plcc-ng**
  Ports V0's grammar and Java semantics to plcc-ng syntax and adds Python and JavaScript semantics; serves as the syntax pathfinder for the rest of the migration.

### Docs

- **[#3](issues/003-python-run-return-value-quoted.md) — Python _run() return value printed with quotes**
  plcc-ng's Python target wraps a string returned from _run() in quotes, contradicting its own docs; upstream defect, tracked here pending approval to file.
- **[#4](issues/004-js-var-field-reserved-word.md) — JS target breaks on a VAR field name**
  A token auto-captured as `var` generates invalid JavaScript; upstream defect, tracked here pending approval to file.

# Roadmap

## Open Issues

### Feat

- **[#5](issues/005-migrate-v1-to-plcc-ng.md) — Migrate V1 to plcc-ng**
  Ports V1's grammar and Java semantics to plcc-ng syntax, adds Python and JavaScript semantics, and ports the envRN Env variant into the shared src/Env/envRN/ location.

### Docs

- **[#3](issues/003-python-run-return-value-quoted.md) — Python _run() return value printed with quotes**
  plcc-ng's Python target wraps a string returned from _run() in quotes, contradicting its own docs; upstream defect, tracked here pending approval to file.
- **[#4](issues/004-js-var-field-reserved-word.md) — JS target breaks on a VAR field name**
  A token auto-captured as `var` generates invalid JavaScript; upstream defect, tracked here pending approval to file.

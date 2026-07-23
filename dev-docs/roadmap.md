# Roadmap

## Open Issues

### Docs

- **[#3](issues/003-python-run-return-value-quoted.md) — Python _run() return value printed with quotes**
  plcc-ng's Python target wraps a string returned from _run() in quotes, contradicting its own docs; upstream defect, tracked here pending approval to file.
- **[#4](issues/004-js-var-field-reserved-word.md) — JS target breaks on a VAR field name**
  A token auto-captured as `var` generates invalid JavaScript; upstream defect, tracked here pending approval to file.
- **[#6](issues/006-multi-capture-alt-name-case-mismatch.md) — Multi-capture alt-name case mismatch**
  A camelCase alt-name on a repeated nonterminal capture (e.g. IfExp's testExp/trueExp/falseExp) generates fields the parser can't find at runtime because it always lowercases alt-names; upstream defect, tracked here pending approval to file.

### Feat

- **[#7](issues/007-migrate-v2-to-plcc-ng.md) — Migrate V2 to plcc-ng**
  Ports V2's grammar and Java semantics to plcc-ng syntax, adds Python and JavaScript semantics, reusing envRN and V1's Prim/Val unchanged.

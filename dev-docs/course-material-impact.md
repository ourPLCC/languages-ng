# Course Material Impact Log

This document tracks changes made while porting a language to `plcc-ng`
that affect something an instructor's slides, handouts, or lecture notes
would need to match — a renamed field referenced in a semantics
walkthrough, a changed output format, a renamed grammar symbol. It is
distinct from `CHANGELOG.md` and issue history: those answer "what
happened in the repo"; this answers "what do I need to update in my
course materials."

Entries are added under the relevant language's heading, in the same
commit that makes the change (see [CLAUDE.md](../CLAUDE.md)). Language
headings are added in the order each language is migrated.

## V0

- The `VAR` token's captured field is renamed from the auto-generated
  `var` to `name` in the shared grammar (all 3 targets), because `var` is
  a reserved word in JavaScript and would otherwise break the generated
  JavaScript code. Semantics code and any course material walking through
  V0's implementation should refer to the `name` field (`self.name` /
  `name` / `this.name`), not `var`.

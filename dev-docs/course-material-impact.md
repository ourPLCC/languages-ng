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

## V1

- Same `VAR`-field rename as V0, applied to V1's grammar: the captured
  field is `name`, not `var`. V1's semantics now read it as
  `env.applyEnv(self.name.lexeme)` / `env.applyEnv(name.lexeme)` /
  `env.applyEnv(this.name.lexeme)`, so course material walking through
  V1's `VarExp` evaluation should refer to `name`, not `var`.
- Nonterminals are PascalCased (`<program>` → `<Program>`, `<exp>` →
  `<Exp>`, `<prim>` → `<Prim>`, `<rands>` → `<Rands>`), following the same
  convention V0 established. V1 is the first language with real semantics
  (Env-based evaluation) to carry it, so course material walking through
  V1's grammar or its Env-lookup semantics should use the PascalCased
  nonterminal names.

## V2

- Same `VAR`-field rename as V0/V1: the captured field is `name`, not
  `var`.
- `IfExp`'s three `Exp` children are captured as `testexp`, `trueexp`,
  `falseexp` — **all lowercase**, not the camelCase `testExp`/`trueExp`/
  `falseExp` the old PLCC grammar used. This isn't a style choice: a
  camelCase alt-name on a repeated nonterminal capture hits a live
  `plcc-ng` bug (parser vs. codegen disagree on casing — see issue #6),
  so the lowercase spelling is required, not optional. Course material
  walking through `IfExp.eval()` should refer to `self.testexp` /
  `testexp` / `this.testexp`, etc., not the old camelCase names.

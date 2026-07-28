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

- The identifier token is renamed from `VAR` to **`SYMBOL`**, and captured
  as bare `<SYMBOL>`, so `VarExp`'s field is **`symbol`** (`self.symbol` /
  `symbol` / `this.symbol`), not the original `var`. This corrects a
  misnomer — in V0–V6 a `SYMBOL` names an immutable binding, not a mutable
  variable — and sidesteps the `var`/JavaScript reserved-word collision
  (plcc-ng 2.0.0 rejects a `var` field outright). The AST node class stays
  `VarExp`. This `SYMBOL`/`symbol` spelling is the standing convention for
  every language. Course material walking through V0 should refer to the
  `SYMBOL` token and the `symbol` field.

## V1

- Same `VAR` → `SYMBOL` token rename as V0: the field is `symbol`, not the
  original `var`. V1's semantics now read `env.applyEnv(self.symbol.lexeme)`
  / `env.applyEnv(symbol.lexeme)` / `env.applyEnv(this.symbol.lexeme)`, so
  course material walking through V1's `VarExp` evaluation should refer to
  the `symbol` field.
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

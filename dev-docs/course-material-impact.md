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

- Same `VAR` → `SYMBOL` token rename as V0/V1: the field is `symbol`,
  not the original `var`.
- `IfExp`'s three `Exp` children are captured with the original camelCase
  alt-names `testExp` / `trueExp` / `falseExp` (plcc-ng 2.0.0 preserves
  alt-name casing; the earlier all-lowercase workaround for issue #6 is no
  longer needed). Course material walking through `IfExp.eval()` should
  refer to `self.testExp` / `testExp` / `this.testExp`, etc.

## V3

- Same `SYMBOL`/`symbol` convention as V0-V2 (the identifier token is
  `SYMBOL`, captured as `symbol`; in `let` LHS positions it is captured
  as the list `symbolList`).
- New `let` productions: `<Exp:LetExp> ::= LET <LetDecls> IN <Exp>` and
  `<LetDecls> **= <SYMBOL> EQUALS <Exp>`. Course material walking through
  `LetDecls` should refer to its `symbolList` / `expList` fields.
- `envVal.initEnv()` is **empty** (no preset bindings) — unlike V1/V2's
  `envRN`, which preset the Roman-numeral values. Every V3 example must
  `let`-bind the variables it uses; there is no ambient `x`/`v`/`m`.
- Duplicate-detection and the two-list binding construction now read a
  token's value via `.lexeme` (not `.toString()`, which under plcc-ng
  2.0.0 (and unchanged in 2.0.1) yields the `source:line:col TOKEN
  'lexeme'` scan format), and raise `LanguageError` rather than the old
  `PLCCException`.
- `LetDecls.addBindings` evaluates each `Exp` in `expList` inline (e.g.
  Python: `[e.eval(env) for e in self.expList]`) rather than
  constructing a `Rands` object and calling `evalRands` on it, unlike
  `PrimappExp.eval`, which does delegate through `Rands`/`evalRands`.
  This is a deviation from how the original pre-migration course
  material's `LetDecls` was shaped. Course material comparing
  `LetDecls.addBindings` against `PrimappExp.eval` should note that the
  two look different on purpose: `LetDecls` doesn't have a pre-existing
  `Rands` node to reuse the way `PrimappExp` does.
- `LetExp.toString()` / `LetDecls.toString()` are the original course
  material's placeholder stubs (`"... LetExp ..."` / `"... LetDecls ..."`)
  and are preserved verbatim, not "finished".

## V4

- Same `SYMBOL`/`symbol` convention as V0-V3, but V4 **widens** the
  identifier pattern to `[A-Za-z][\w?]*` so a name may end in `?`. This
  is a real V4 language feature carried over from the original grammar,
  not migration drift — `Prog/oe` names its procedures `even?` and
  `odd?`. (V5's old grammar carries a comment claiming the `?` arrives
  at V5; that comment is stale — the widening is already V4's.)
- New productions: `<Exp:ProcExp> ::= <Proc>`,
  `<Exp:AppExp> ::= DOT <Exp> LPAREN <Rands> RPAREN`,
  `<Exp:SeqExp> ::= LBRACE <Exp> <SeqExps> RBRACE`,
  `<SeqExps> **= SEMI <Exp>`,
  `<Proc> ::= PROC LPAREN <Formals> RPAREN <Exp>`, and
  `<Formals> **= <SYMBOL> +COMMA`.
- `Formals`' list field is **`symbolList`** (`self.formals.symbolList` /
  `formals.symbolList` / `this.formals.symbolList`), not the original
  Java code's `varList`. Course material walking through `ProcVal.apply`
  or the `proc` formals duplicate-check should use `symbolList`.
- `SeqExp` reads its trailing expressions from `seqExps.expList`; the
  first expression is the separate field `exp`. `{a; b; c}` evaluates
  `a` first and yields the value of `c`.
- `Prog/oe` and `Prog/fib` are **shrunk** so every shipped example runs
  in all three targets. `oe`'s final call is now `.even?(10, even?, odd?)`
  instead of `.even?(11000, even?, odd?)` (output unchanged: `1`), and
  `fib` now computes `.fib(10)` instead of `.fib(30)`, so its output
  changes from `832040` to `55`. The original arguments exceeded the
  interpreter recursion depth available in Python (a ~1,000-frame default
  limit, several frames per language-level call) and made `fib` take
  minutes. Course material quoting either argument or `fib`'s result
  needs updating.

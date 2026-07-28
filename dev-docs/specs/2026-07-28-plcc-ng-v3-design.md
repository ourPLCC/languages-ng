# plcc-ng Migration — V3 Design

This is a focused design of record for the V3 phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. This document
captures only the decisions and porting subtleties specific to V3, settled in
brainstorming on 2026-07-28.

V3 is the first phase to run against **plcc-ng 2.0.0** (issue #8), so it adopts
the restored conventions V0–V2 were refactored to: capitalized nonterminals,
the `SYMBOL` token with `symbol` field, camelCase `IfExp` captures, and a
`_run()` that **returns** its output string.

## Goal

Port V3 (`V2 + let`) to plcc-ng: one shared `grammar.plcc` plus three target
`spec.plcc`s (Python, Java, JavaScript). V3 introduces the `envVal` Env variant,
ported once here and reused by V4–V6 in later phases. The phase closes when all
three targets pass their bats suite.

## Grammar

`src/V3/grammar.plcc` is V2's grammar plus the `let` production, in current
(2.0.0) conventions:

```
<Exp:LetExp>  ::= LET <LetDecls> IN <Exp>
<LetDecls>    **= <SYMBOL> EQUALS <Exp>
```

New tokens: `LET 'let'`, `IN 'in'`, `EQUALS '='` (added alongside V2's tokens,
before the `SYMBOL` catch-all so the keywords win). The `<LetDecls>` repetition
captures produce `symbolList` (a list of `SYMBOL` tokens) and `expList`.
Everything else (`LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `Rands`, the seven
`Prim`s) is carried over from V2 unchanged.

## envVal Port

Ported into `src/Env/envVal/{python,java,javascript}/env.plcc`, `%include`d by
each V3 target. As with `envRN`/`envRef`, the flat old-PLCC `src/Env/envVal`
file sits at the exact path the new directory needs — **delete it first** (it is
a pure duplicate of the per-language `envVal` copies).

`envVal` is structurally `envRN` (same `Env`/`EnvNode`/`EnvNull`/`Binding`/
`Bindings` classes) with three deliberate differences, all of which V3's `let`
(and later V4's `proc`) rely on:

1. **`checkDuplicates` (both overloads) is kept.** `envRN` correctly dropped it
   as dead weight; V3's `LetDecls:init` calls the two-argument form to reject
   duplicate binding identifiers at parse time.
2. **The two-list `Bindings(idList, valList)` constructor is kept.** V3's
   `addBindings` uses it to zip the LHS symbols with the evaluated RHS values.
3. **`initEnv()` returns an *empty* environment** — `new EnvNode(new Bindings(),
   new EnvNull())` — not `envRN`'s preset Roman-numeral bindings. V3 programs
   start with no bindings; every variable is `let`-bound. (Port `envVal`'s own
   `empty`/`initEnv` shape faithfully.)

### Two porting corrections from old to 2.0.0

- **Token keys use `.lexeme`, not `.toString()`.** The flat `envVal`'s
  `checkDuplicates` and two-list `Bindings` constructor build their string keys
  by calling `token.toString()`. Under plcc-ng 2.0.0 a token's string form is
  the scan format (`source:line:col TOKEN 'lexeme'`), not the bare identifier,
  so both must read `.lexeme` — the same switch V1/V2's `VarExp` already made.
- **`PLCCException(...)` → `LanguageError(...)`.** Old `envVal` raises
  `PLCCException("Semantic error", msg)`; the 2.0.0 runtime error class (already
  used by V2's `Val`/`Prim`) is `LanguageError`. Duplicate detection raises
  `LanguageError(msg)`.

Per-target idioms mirror `envRN` exactly: Python's intra-package `:import`
chains and `runtime.base.LanguageError`; JavaScript's `require`/`module.exports`
and `require('./runtime/base')`; Java's package-less same-directory references
and `runtime.LanguageError`.

## Semantics

Each target's `spec.plcc` does `%include ../grammar.plcc` then
`%include ../../Env/envVal/<target>/env.plcc`, then the semantic section. All of
V2's semantic classes — `Val`, `IntVal`, the seven `Prim`s, `Rands`, `Program`,
`LitExp`, `VarExp`, `IfExp`, `PrimappExp` — are reused **unchanged**. Two new
classes:

**`LetExp`**
- `eval(env)`: `nenv = letDecls.addBindings(env)`, then `return exp.eval(nenv)`.
- `toString()`: the faithful placeholder stub `"... LetExp ..."` — this is what
  the original course material contains; it is preserved verbatim rather than
  "finished". It is not exercised by any test (programs print an evaluated
  value, never the tree).

**`LetDecls`**
- `:init` hook: `Env.checkDuplicates(symbolList, " in let LHS identifiers")` —
  the direct 2.0.0 equivalent of old PLCC's `LetDecls:init` action, confirmed
  supported.
- `addBindings(env)`: evaluate each `Exp` in `expList` in `env`, zip with
  `symbolList` (via the two-list `Bindings` constructor), and return
  `env.extendEnv(bindings)`.
- `toString()`: the faithful placeholder stub `"... LetDecls ..."`.
- `:import` for `Env`/`Bindings` in Python and JavaScript only; Java needs none.

**Smoke-test early (per the migration spec's "spike novel mechanics" rule):**
the original `addBindings` reuses `new Rands(expList).evalRands(env)`.
Constructing a grammar-derived class (`Rands`) by hand may not survive plcc-ng
codegen. Validate it against the installed CLI first; if it fails, inline the
equivalent per-`Exp` evaluation (`[e.eval(env) for e in expList]` and the Java/
JS equivalents) directly in `addBindings`. Either way the observable behavior is
identical.

## Tests

`src/V3/tests/<case>/`, each case a shared `V3.input` + `V3.expected` (all three
targets must produce identical output) plus one `V3test.bats` with three `@test`
blocks, one per target directory, driven by `plcc-rep` (porting the old
`plccmk`/`rep` invocation off the existing bats file). Value cases only — no
error-path (duplicate-id) test, to keep the one-shared-expected model clean:

- `let/` — the existing multi-binding case (`let three = 2 four = 5 in
  +(three, four)` → `7`), retained.
- `nested-let/` — a nested `let` whose inner binding shadows an outer one,
  exercising `extendEnv` chaining and lexical shadowing.
- `single-let/` — a single binding referenced in the body.

## Bookkeeping (in the same commits as the work)

- File a V3 issue with `bin/issues/new.bash <slug> feat` and add its roadmap
  entry; close it with `bin/issues/close.bash` as the branch's final commit.
- Log V3 entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md): the
  `SYMBOL`/`symbol` rename, `.lexeme` token access, `LanguageError` in place of
  `PLCCException`, and `envVal.initEnv()` being empty (no preset bindings) — each
  filed under a V3 heading in the commit that makes the change.
- The implementation plan lands under `dev-docs/plans/` (via writing-plans).

## Out of Scope

- V4–V6, and any `envVal` reuse work beyond the initial port.
- The `envRef` variant (Phase 3).
- A duplicate-id / error-path test.
- Any unification of `envVal` with `envRN`/`envRef`, or "finishing" the
  placeholder `toString`s.

# plcc-ng Migration — V4 Design

This is a focused design of record for the V4 phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It also builds
directly on the [V3 design](2026-07-28-plcc-ng-v3-design.md), which ported the
`envVal` Env variant that V4 reuses unchanged. This document captures only the
decisions and porting subtleties specific to V4, settled in brainstorming on
2026-07-30.

## Goal

Port V4 (`V3 + procedures and the sequence operator`) to plcc-ng: one shared
`grammar.plcc` plus three target `spec.plcc`s (Python, Java, JavaScript). V4
adds first-class procedures (`proc`/application, closures) and the sequence
expression. It is also the first migrated language that ships example programs
in a `Prog/` directory, so this phase settles what happens to those. The phase
closes when all three targets pass their bats suite.

## Grammar

`src/V4/grammar.plcc` is V3's grammar plus five tokens and six productions,
keeping the original V4 token order (new keywords stay ahead of the `SYMBOL`
catch-all):

```
token PROC 'proc'
token DOT '\.'
token LBRACE '\{'
token RBRACE '\}'
token SEMI ';'
token SYMBOL '[A-Za-z][\w?]*'
```

```
<Exp:ProcExp> ::= <Proc>
<Exp:AppExp>  ::= DOT <Exp> LPAREN <Rands> RPAREN
<Exp:SeqExp>  ::= LBRACE <Exp> <SeqExps> RBRACE
<SeqExps>     **= SEMI <Exp>
<Proc>        ::= PROC LPAREN <Formals> RPAREN <Exp>
<Formals>     **= <SYMBOL> +COMMA
```

Generated fields: `ProcExp.proc`; `AppExp.exp` / `.rands`; `SeqExp.exp` /
`.seqExps`; `SeqExps.expList`; `Proc.formals` / `.exp`; `Formals.symbolList`
(the old Java code's `formals.varList`).

Everything else — `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`,
`LetDecls`, `Rands`, and the seven `Prim`s — is carried over from V3 unchanged.

### The widened SYMBOL is a real V4 language feature

V3's identifier token is `[A-Za-z]\w*`; V4's original `VAR` is
`[A-Za-z][\w?]*`, admitting a trailing `?`. This is a deliberate widening at
V4, not drift — `Prog/oe` names its procedures `even?` and `odd?` and cannot
scan without it. (V5's grammar carries a comment claiming the `?` arrives at
V5; that comment is stale — the regex already widened at V4.) The port keeps
the widening under the standing `SYMBOL` spelling: `token SYMBOL
'[A-Za-z][\w?]*'`.

## envVal Reuse

Zero-touch. V3 ported `src/Env/envVal/{python,java,javascript}/env.plcc` and
deliberately **kept** `checkDuplicates` and the two-list
`Bindings(idList, valList)` constructor — both of which V4 needs, for
`Formals:init` and for `ProcVal.apply` respectively. Each V4 target's
`spec.plcc` does `%include ../grammar.plcc` then
`%include ../../Env/envVal/<target>/env.plcc`. No `envVal` file is modified in
this phase. (`Bindings`'s Java signature is
`Bindings(List<Token> idList, List<Val> valList)`, which `Formals.symbolList`
and an evaluated argument list satisfy directly.)

## Semantics

All of V3's semantic classes — `Val` (extended, see below), `IntVal`, the seven
`Prim`s, `Rands`, `Program`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`,
`LetExp`, `LetDecls` — are reused. New work:

**`ProcVal`** — a free-standing closure class (like `Val`/`IntVal`, duplicated
per target inside each `spec.plcc`, not shared via `%include`). Fields
`formals`, `body`, `env`. `apply(args, e)` rejects an arity mismatch, builds
`Bindings(formals.symbolList, args)`, extends the **captured** `env` (not the
caller's), and evaluates `body` in the result. `toString()` returns `"proc"`.
Java's block needs `import java.util.List`; Python and JavaScript need
`Bindings` and `LanguageError` imports. None of the three needs to import
`Formals` or `Exp`: Java's free-standing classes are same-directory and
package-less, and Python/JavaScript are duck-typed.

**`Val.apply(args, env)`** — the base implementation throws
`LanguageError("Cannot apply " + this)`, overridden only by `ProcVal`. The
`env` parameter is unused in V4, and stays unused in V5 and V6 (verified
against their old-PLCC `val`/`code` files), but it is part of the signature the
course material shows, so it is ported faithfully rather than trimmed.

**`Proc`** — `makeClosure(env)` returns `new ProcVal(formals, exp, env)`.

**`ProcExp`** — `eval(env)` delegates to `proc.makeClosure(env)`. No
`toString()`: the original has none, and the port does not invent one.

**`AppExp`** — `eval(env)` evaluates the operator `Exp`, then
`rands.evalRands(env)`, then `v.apply(args, env)`. `toString()` is the faithful
placeholder stub `" ... AppExp ..."`.

**`SeqExp`** — `eval(env)` evaluates `exp`, then folds over `seqExps.expList`
in order, returning the last value. `toString()` is the faithful placeholder
stub `" ... SeqExp ... "`.

**`Formals:init`** — `Env.checkDuplicates(symbolList, " in proc formals")`, the
direct analogue of V3's `LetDecls:init`. Needs an `Env` `:import` in Python and
JavaScript; Java needs none.

The `AppExp` and `SeqExp` `toString()` stubs are preserved **verbatim**,
including their irregular leading and trailing spaces — the same treatment V3
gave `LetExp`/`LetDecls`. They are not exercised by any test (programs print an
evaluated value, never the tree).

## Smoke-test early

Per the migration spec's "spike novel mechanics" rule, two things are validated
against the installed CLI before the full port is written:

1. **`<SeqExps> **= SEMI <Exp>`** is an arbno whose repeated body *begins* with
   a non-capturing terminal and declares no separator. This is the family of
   bug filed as issue #10 (fixed upstream in plcc-ng 2.0.1 for the *mid*-body
   case, validated there against V3's `<LetDecls> **= <SYMBOL> EQUALS <Exp>`).
   Leading position should be the same code path, but that is inference, not
   evidence. Scan/parse `{1; 2; 3}` first.
2. **The widened `SYMBOL` now overlaps the `zero?` keyword** — an overlap V3's
   narrower regex made impossible. Confirm `zero?(x)` still scans as `ZEROP`
   (declaration order should decide the tie) and that `even?` scans as a single
   `SYMBOL`. A keyword/identifier prefix case (`inx`, `procx`) is worth a
   glance at the same time.

If either fails, file it per the Defect Tracking process rather than silently
restructuring the grammar around it — the same call V3 made for issue #10.

## Example Programs (`src/V4/Prog/`)

V4 is the first migrated language with a `Prog/` directory (V0–V3 have none;
V6 also has one, for its own later phase). These are course artifacts, so they
stay where they are — but this phase actually **runs** all six (`pp`,
`fact-acc`, `oe`, `fib`, `11`, `11-nolet`) against all three targets rather
than assuming they still work.

Two of them cannot run as written. `oe` recurses ~11,000 language-level calls
deep, well past Python's default 1,000-frame recursion limit (and each
language-level call costs several interpreter frames); `fib` computes
`fib(30)`, roughly 2.7M calls, which is minutes in Python. Both are **shrunk in
place** so every shipped example runs in every target:

- `Prog/oe`: `.even?(11000, ...)` → `.even?(10, ...)`. Output is unchanged
  (`1` — both arguments are even).
- `Prog/fib`: `.fib(30)` → `.fib(10)`. Output changes from `832040` to `55`.

Both changes get course-material-impact entries, since an instructor's notes
may quote the argument or the result.

## Tests

`src/V4/tests/<case>/`, each case a shared `V4.input` + `V4.expected` (all
three targets must produce identical output) plus one `V4test.bats` with three
`@test` blocks, one per target directory, driven by `plcc-rep` — the same shape
V3 uses. Five cases, one per V4 addition, each traceable to a `Prog/` example
where one exists:

- `proc/` — the existing case (`.proc(x) +(x,3) (5)` → `8`), retained, ported
  off the old `plccmk`/`rep` invocation.
- `seq/` — hand-written. **No `Prog/` example exercises `{e; e; e}` at all**,
  so sequence coverage cannot be mined; it has to be written. The case is
  `let x = 4 in {add1(x); sub1(x); *(x, x)}` → `16`: three sequenced
  expressions, of which only the last supplies the value.
- `closure/` — from `Prog/pp`, exercising lexical capture two ways (a `let`
  inside a `proc` body, and a `proc` closing over an enclosing `let`).
- `recursion/` — from `Prog/fact-acc` (`.fact(5)` → `120`), self-application
  recursion without `letrec`.
- `multi-formals/` — from the shrunk `Prog/oe`, exercising multi-argument
  `Formals` and mutual recursion by parameter passing.

`Prog/11` and `Prog/11-nolet` are verified but deliberately **not** promoted
into the suite: both are one-liners whose coverage (`let` binding, single-formal
application) is already carried by `proc/` and V3's own cases.

Value cases only — no error-path test (duplicate formals, arity mismatch,
applying a non-procedure), keeping the one-shared-expected model clean, the
same call V3 made.

**`closure/` doubles as an early probe of `plcc-rep`'s multi-parse loop.**
`Prog/pp` holds *two* complete programs in one file, so the case reads and
evaluates both in a single `plcc-rep` run and expects two lines of output. That
is half of the risk the overarching design flagged for V6 (`define` needs
`Program`-level state to *persist* across those parses; `pp` only needs the
loop itself to work), obtained here for free. If the two-program input does not
work, the case falls back to a single program and the finding is filed as an
issue — V6's phase then knows about it in advance instead of discovering it
cold.

## Bookkeeping (in the same commits as the work)

- File a V4 issue with `bin/issues/new.bash <slug> feat` and add its roadmap
  entry; close it with `bin/issues/close.bash` as the branch's final commit.
- Delete the old flat old-PLCC files `src/V4/{grammar,code,prim,envVal,val}`
  once the three targets pass. Note that unlike `src/Env/envVal`, these do not
  collide with any new path (`src/V4/grammar` vs `src/V4/grammar.plcc`), so the
  deletion can come at the end rather than up front.
- Log V4 entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change: the `SYMBOL` widening to `[A-Za-z][\w?]*`;
  `Formals`' field being `symbolList` rather than `varList`; the `Proc` /
  `ProcVal` closure shape and `Val.apply`'s retained-but-unused `env`
  parameter; the preserved placeholder `toString`s on `AppExp`/`SeqExp`;
  `LanguageError` in place of `PLCCException`; and the shrunk `Prog/oe` and
  `Prog/fib` arguments.
- The implementation plan lands under `dev-docs/plans/` (via writing-plans).

## Out of Scope

- V5 and V6, including `letrec` and anything `Prog/`-related in V6.
- Error-path / diagnostic tests.
- Any change to `envVal`, or any unification of the Env variants.
- Unifying the per-language `Val`/`IntVal`/`Prim` duplication — ruled out
  repo-wide by the overarching design.
- "Finishing" the placeholder `toString`s.

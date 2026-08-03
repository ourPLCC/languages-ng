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
  changes from `832040` to `55`. `oe`'s original argument exceeded the
  interpreter recursion depth available in Python (a ~1,000-frame
  default limit, several frames per language-level call; measured at
  roughly 330 language-level calls); `fib`'s original argument was
  measured at 66 seconds of Python runtime, not minutes. Course material
  quoting either argument or `fib`'s result needs updating.
- `ProcVal` holds `formals`, `body`, and the environment captured at
  `proc`-evaluation time (`self.env` / `env` / `this.env`); `apply`
  extends *that* captured environment, not the caller's — this is what
  makes V4's procedures lexically scoped, and it's the first question a
  student asks walking `ProcVal.apply`. `Val.apply` keeps a second `env`
  parameter (Python `Val.apply(self, args, env)`, Java `apply(List<Val>
  args, Env e)`, JavaScript `apply(args, env)`) that nothing in V4 (or
  V5/V6) reads; it is preserved because it is the signature the course
  material shows. Course material walking `ProcVal.apply` should point
  out that the environment it extends is the one closed over at
  `proc`-time, not the `env`/`e` argument passed to `apply`.
- `AppExp.toString()` and `SeqExp.toString()` are the original course
  material's placeholder stubs — `" ... AppExp ..."` and
  `" ... SeqExp ... "`, irregular spacing included — preserved verbatim
  rather than "finished", the same treatment V3 gave `LetExp`/`LetDecls`.
  `ProcExp` has **no** `toString()` at all, because the original has
  none. Course material quoting any of the three should not expect a real
  rendering of a procedure application, a sequence, or a `proc`
  expression.
- V4's runtime errors — `Cannot apply …` (`Val.apply`'s default), the
  `formals`/`args` number mismatch, and the duplicate-formals check
  (`Env.checkDuplicates` on `Formals.symbolList`) — raise plcc-ng's
  `LanguageError`, the same substitution V3 made for old PLCC's
  `PLCCException`. Course material quoting V4's error handling should
  refer to `LanguageError`.

## V5

- New token `LETREC 'letrec'` and one new production,
  `<Exp:LetrecExp> ::= LETREC <LetDecls> IN <Exp>`. `LetDecls` is shared
  with `LetExp` — `letrec` introduces no new nonterminal.
- Same `SYMBOL`/`symbol` convention as V0-V4. V5's old grammar carried a
  header comment claiming variable names "now can have a `?` in them" at
  V5; that comment was **stale** and is not carried forward — the
  widening to `[A-Za-z][\w?]*` already happened at V4. Course material
  that attributes the `?` to V5 should attribute it to V4.
- `LetrecExp` and `ProcExp` **do** have placeholder `toString()`/`__str__`
  methods, returning `" ...LetrecExp... "` and `" ...ProcExp... "`.
  *(Corrected: V5 originally shipped without them, on the grounds that
  the pre-migration source had none. That was true of V5 alone — V6 and
  all seven languages of Phases 3-5 have both — so V5 was brought into
  line rather than left as the outlier.)*
- `letrec` is implemented by **mutation, not by a fixpoint**.
  `LetDecls.addLetrecBindings(env)` extends the environment with an
  *empty* `Bindings`, then evaluates each right-hand side **in that
  already-extended environment** and adds the resulting binding to that
  same node with `env.add(...)`. A `proc` right-hand side captures the
  env object while it still holds zero bindings; later additions to that
  same node are what make its siblings (and itself) visible by the time
  anything is called. This is worth showing explicitly on a slide — it
  is not the placeholder-and-patch `letrec` most textbooks present.
- A consequence worth stating in class: the binding pass is **eager and
  sequential**, so a right-hand side that *looks something up* can only
  see bindings to its left. `letrec f = proc(...) .g(...) g = proc(...)
  .f(...) in ...` works (neither side looks anything up while binding),
  but `letrec a = b b = 1 in a` fails with `no binding for b`. Faithful
  to the original V5, not a porting artifact.
- `LetDecls`' list fields are **`symbolList`** and **`expList`** (the
  original Java code's `varList`/`expList`). Course material walking
  through `addBindings` or `addLetrecBindings` should use `symbolList`.
- The duplicate-identifier message is now
  `duplicate ID <id> in let/letrec LHS identifiers` — V4 and earlier say
  `... in let LHS identifiers`. `LetDecls` is shared by both `let` and
  `letrec`, so the check covers both.
- `letrec` makes direct self-recursion (`.f(sub1(x))`) the natural thing
  to write, and Python's practical ceiling for it is far lower than
  Java's or JavaScript's: measured with `letrec f = proc(x) if zero?(x)
  then 0 else .f(sub1(x)) in .f(N)`, Python dies around `N=330` while
  Java and JavaScript both survive past `N=2700`. If a live demo or
  assignment pushes recursion depth into the hundreds on the Python
  target, expect a `RecursionError` there well before the other two
  targets show any trouble — see
  [issue #19](issues/019-python-recursion-ceiling.md).
- V5's four placeholder strings were normalized to the
  `" ...ClassName... "` spelling every other language uses.
  `"... LetExp ..."`, `"... LetDecls ..."`, `" ... AppExp ..."`, and
  `" ... SeqExp ... "` — three different spacings — became
  `" ...LetExp... "`, `" ...LetDecls... "`, `" ...AppExp... "`, and
  `" ...SeqExp... "`. No observable output changed: nothing in the test
  suite prints an `Exp`. Slides quoting the old spellings should be
  updated, but no result differs.

## V6

- New token `DEFINE 'define'`, declared directly after `LETREC`.
- `<Program>` is no longer a single production. It splits into two
  alternatives, `<Program:Define> ::= DEFINE <SYMBOL> EQUALS <Exp>` and
  `<Program:Eval> ::= <Exp>`, so a V6 "program" is now one *or* the
  other and a source file is a sequence of them. Course material that
  describes `<program> ::= <exp>` for V6 needs both alternatives.
- Same `SYMBOL`/`symbol` convention as V0-V5: the pre-migration V6
  grammar's `VAR` token is named `SYMBOL` in the port, so `Define`'s
  generated field is `symbol`, not `var`.
- `Program` no longer has a `_run()`. It keeps only the shared
  `env = Env.initEnv()`, and `Define` and `Eval` each get their own
  `_run()`. The environment is created **once per `plcc-rep` process**
  and shared by every program in the run.
- `Define._run()` **returns the defined name**, not the value. The
  pre-migration Java ended in `System.out.println(s)` and returned
  `void`; under plcc-ng an entry point must return its output as a
  string. Same observable output, different mechanism - worth a note
  wherever the Java source is shown.
- `define` is implemented by **mutating a single environment node**, the
  same mechanism V5's `letrec` uses, hoisted to the top level. A new
  name is `add`ed to that node; an existing name has its `Binding.val`
  **reassigned in place**. `define` never extends or replaces the
  environment.
- Two consequences worth showing on a slide, both demonstrated by files
  already in `src/V6/Prog/`:
  - A redefinition **reaches closures that already exist**, because the
    assignment goes through the very `Binding` object the closure holds.
    `Prog/x`: `.f()` gives `2`, then `define x=3`, then `.f()` gives `3`.
  - A closure over a **`let`-bound copy is immune**, because `let`
    extends a new node with its own `Binding`. `Prog/xx`: `.f()` gives
    `2` both before and after `define x=3`.
- A `define` right-hand side may name a procedure defined **later**, as
  the shipped `define` test does with `even?`/`odd?` - the closure
  captured the node, and the later binding lands in that same node.
- `Define` looks names up with `env.lookup(s)` (local bindings only),
  not `env.applyEnv(s)`. Faithful to the original, but note that at top
  level the two are indistinguishable: the environment's parent is
  `EnvNull`, so no program can tell them apart.
- V6's `LetrecExp`/`ProcExp` `toString()`s and its `" ...ClassName... "`
  placeholder spellings match its pre-migration source exactly - no
  change on that axis. (V5's needed correcting; V6's did not.)

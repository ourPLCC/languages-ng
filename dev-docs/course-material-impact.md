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
- Java's `Prim.apply` now takes `Val [] va` rather than `List<Val> args`,
  with `Val.toArray` restoring the array from the list in
  `PrimappExp.eval`. Operand access is `va[0]` / `va.length`, matching
  Python's `args[0]` / `len(args)` and JavaScript's `args[0]` /
  `args.length`. Course material walking through a primitive's `apply` can
  now use one indexing idiom across all three target appendices instead of
  Java's `args.get(0)` / `args.size()`.

## V2

- Same `VAR` → `SYMBOL` token rename as V0/V1: the field is `symbol`,
  not the original `var`.
- `IfExp`'s three `Exp` children are captured with the original camelCase
  alt-names `testExp` / `trueExp` / `falseExp` (plcc-ng 2.0.0 preserves
  alt-name casing; the earlier all-lowercase workaround for issue #6 is no
  longer needed). Course material walking through `IfExp.eval()` should
  refer to `self.testExp` / `testExp` / `this.testExp`, etc.
- Java's `Prim.apply` now takes `Val [] va` rather than `List<Val> args`,
  with `Val.toArray` restoring the array from the list in
  `PrimappExp.eval`. Operand access is `va[0]` / `va.length`, matching
  Python's `args[0]` / `len(args)` and JavaScript's `args[0]` /
  `args.length`. Course material walking through a primitive's `apply` can
  now use one indexing idiom across all three target appendices instead of
  Java's `args.get(0)` / `args.size()`.

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
- Java's `Prim.apply` now takes `Val [] va` rather than `List<Val> args`,
  with `Val.toArray` restoring the array from the list in
  `PrimappExp.eval`. Operand access is `va[0]` / `va.length`, matching
  Python's `args[0]` / `len(args)` and JavaScript's `args[0]` /
  `args.length`. Course material walking through a primitive's `apply` can
  now use one indexing idiom across all three target appendices instead of
  Java's `args.get(0)` / `args.size()`.

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
- Java's `Prim.apply` now takes `Val [] va` rather than `List<Val> args`,
  with `Val.toArray` restoring the array from the list in
  `PrimappExp.eval`. Operand access is `va[0]` / `va.length`, matching
  Python's `args[0]` / `len(args)` and JavaScript's `args[0]` /
  `args.length`. Course material walking through a primitive's `apply` can
  now use one indexing idiom across all three target appendices instead of
  Java's `args.get(0)` / `args.size()`.

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
  the pre-migration source had none. For `LetrecExp` that was true of V5
  alone — the production is new at V5, so there is no earlier instance to
  compare against. For `ProcExp` it wasn't: V4's `ProcExp` has no
  `toString()` either, and V4 is out of scope for this branch and keeps
  it that way. V6 and all seven languages of Phases 3-5 give both
  methods a `toString()`, so V5 was brought into line with those rather
  than left as an outlier on this point.)*
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
  `" ...ClassName... "` spelling V6 and the seven not-yet-ported
  languages (Phases 3-5) use.
  `"... LetExp ..."`, `"... LetDecls ..."`, `" ... AppExp ..."`, and
  `" ... SeqExp ... "` — three different spacings — became
  `" ...LetExp... "`, `" ...LetDecls... "`, `" ...AppExp... "`, and
  `" ...SeqExp... "`. No observable output changed: nothing in the test
  suite prints an `Exp`. V3 and V4 were out of scope for this
  normalization and still carry the old irregular spellings, so course
  material walking V3 → V4 → V5 will see the spelling change land at V5.
  Slides quoting the old spellings should be updated, but no result
  differs.
- Java's `Prim.apply` now takes `Val [] va` rather than `List<Val> args`,
  with `Val.toArray` restoring the array from the list in
  `PrimappExp.eval`. Operand access is `va[0]` / `va.length`, matching
  Python's `args[0]` / `len(args)` and JavaScript's `args[0]` /
  `args.length`. Course material walking through a primitive's `apply` can
  now use one indexing idiom across all three target appendices instead of
  Java's `args.get(0)` / `args.size()`.

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
- `Prog/p1` + `Prog/p2` demonstrate a reader spanning file boundaries.
  The invocation changed: `rep Prog/p1 Prog/p2` no longer works, because
  plcc-rep parses each SOURCE argument as its own stream. Use
  `cat Prog/p1 Prog/p2 | plcc-rep` instead, which still yields `7`. Both
  files are unchanged; only the command demonstrating them differs.
  Tracked as issue #22.
- Java's `Prim.apply` now takes `Val [] va` rather than `List<Val> args`,
  with `Val.toArray` restoring the array from the list in
  `PrimappExp.eval`. Operand access is `va[0]` / `va.length`, matching
  Python's `args[0]` / `len(args)` and JavaScript's `args[0]` /
  `args.length`. Course material walking through a primitive's `apply` can
  now use one indexing idiom across all three target appendices instead of
  Java's `args.get(0)` / `args.size()`.

## SET

- New token `SET` (`set`) and new production
  `<Exp:SetExp> ::= SET <SYMBOL> EQUALS <Exp>`, giving fields
  `SetExp.symbol` and `SetExp.exp`. `set x = e` is an **expression** and
  evaluates to the assigned value, so it composes inside `{...}` sequences
  and as an operand.
- SET introduces the `envRef` environment: a `Binding` holds a **`Ref`**
  (field `ref`), not a `Val`. `applyEnvRef` is the primitive lookup and
  returns the `Ref`; `applyEnv` is derived from it as
  `applyEnvRef(sym).deRef()`. Extension is `extendEnvRef(bindings)`, and
  `Bindings` is built from an id list and a **ref** list. Course material
  drawing environment diagrams for SET onward needs the extra box: name →
  ref → value, where V0–V6 had name → value.
- `Env.checkDuplicates` returns nothing. The pre-migration
  `src/Env/envRef` and `src/REF/envRef` returned the `Set` of names they
  built; no caller ever used it, and the majority of the languages already
  declared it `void`.
- `ProcVal.apply` wraps its arguments in **fresh** `ValRef`s before
  binding them, which is why assigning to a formal (`proc(t) set t = ...`)
  cannot reach the caller's variable. This is the exact line REF changes
  to get call-by-reference, and the `formal-is-a-copy` test is the same
  program REF ships with a different expected value.
- `apply` takes an `env` parameter it does not read
  (`apply(args, env)`). This is deliberate: it is the hook for the
  dynamic-scoping exercise, in which a proc resolves free variables in the
  **calling** environment passed here rather than the one it captured.
  It must not be removed.
- `Define._run()` returns the defined name rather than printing it, the
  same `_run()` contract V6 adopted. Observable output is unchanged.
- Java's `Prim.apply` takes `Val [] va`, with operand access `va[0]` /
  `va.length`, matching Python's `args[0]` / `len(args)` and JavaScript's
  `args[0]` / `args.length`. Unlike V1–V6, this is **not** a change from
  SET's pre-migration original — SET's Java already built the array with
  `Val.toArray`. SET simply carries forward the shape V1–V6 were
  retro-fixed to match, so all three target appendices read alike from
  SET onward too.

## REF

- REF adds **no grammar changes at all** — `src/REF/grammar.plcc` is SET's
  file with a different header comment. Anything a handout says about SET's
  syntax is true of REF verbatim, including the `SET` token and
  `<Exp:SetExp>`.
- `Exp` gains `evalRef(env)`, which by default wraps `eval(env)` in a
  **fresh** `ValRef`. `VarExp` overrides it to return
  `env.applyEnvRef(...)` — the binding's own `Ref`. That one override is
  call-by-reference: a bare variable operand passes its cell, and every
  other kind of operand passes a copy.
- `Rands` gains `evalRandsRef`, and `AppExp.eval` calls it. `evalRands`
  and `PrimappExp` are unchanged — **primitives still take `Val`s**, so
  `+(x,0)` never passes a reference. This is the distinction
  `tests/nonvar-arg-is-a-copy/` pins down.
- `Val.apply` and `ProcVal.apply` take a list of **`Ref`s**
  (Java: `apply(List<Ref> args, Env e)`). `ProcVal` no longer wraps
  anything, because its caller already did — deleting SET's
  `Ref.valsToRefs(args)` line *is* the SET→REF change. `Ref.valsToRefs`
  itself remains, since `LetDecls.addBindings` still uses it.
- `apply` keeps the `env` parameter it does not read, for the same
  dynamic-scoping exercise SET's entry describes. It must not be removed.
- `src/REF/tests/formal-is-a-ref/` has the same input program as
  SET's `tests/formal-is-a-copy/` but expects **`4`** where SET
  expects `3`. Diffing the two expected files is the shortest
  possible demonstration of what REF adds.
- The old `src/REF/tests/let/` is now `tests/nonvar-arg-is-a-copy/`. Same
  program, renamed for what it tests. Any handout citing the path needs
  updating.
- REF's example programs are now all under `src/REF/Prog/`. The `Stuff/`
  directory is gone — `counter1`–`counter5` moved into `Prog/`, and
  `Stuff/factory` was dropped as a byte-identical duplicate of
  `Prog/factory`. Any handout pointing at `src/REF/Stuff/...` needs the
  path updated.
- `Prog/oe` had an unbalanced `{` and never parsed; the stray brace is
  removed and it now runs (`.odd?(5)` → `1`, `.even?(5)` → `0`). It also
  moved from the top level into `Prog/`, matching V4, OBJ, and TYPE1.
- `Prog/counter1` (`1 1 1`) and `Prog/counter3` (a parse error) are
  **left as they were** — they read as deliberate counter-examples in a
  five-program progression. `counter3`'s error text now comes from
  plcc-ng and reads differently than old PLCC's did.
- `Prog/counter4` is a second SET/REF contrast, alongside
  `formal-is-a-ref`. It gives `1 2 3` under REF because `.next(x)` passes
  `x` by reference; run against SET's spec the same program gives
  `1 1 1`. Worth flagging if it appears in a lecture as an ordinary
  counter.

## NAME

- Identifier token is now `SYMBOL`, not `VAR`, and the corresponding
  field is `symbol`, not `var` — the standing convention since V0.
  `VarExp.eval` reads `env.applyEnv(self.symbol.lexeme)`, not
  `env.applyEnv(self.var.lexeme)`.
- `$run()` is now `_run()`, and it **returns** its output string rather
  than printing it, the same `_run()` contract every migrated language
  adopts.
- `Define` now prints the defined name, where pre-migration NAME printed
  nothing — its `// System.out.println(id);` line was commented out.
  `Prog/jensen`, `Prog/sumsq`, `Prog/countdown`, and `Prog/looper` each
  gain a leading output line naming what they define (`while` for the
  first three, `p` then `g` for `looper`, which has two top-level
  `define`s). This isn't a stylistic choice: plcc-ng's `_run()` must
  return a string, so "print nothing" was never an option, and returning
  `""` would print a blank line rather than nothing at all.
- `ThunkRef` is a new `Ref` subclass living beside `ValRef`. Its `deRef`
  re-evaluates the captured expression **every** time it's called — no
  memoization — which is precisely what distinguishes call-by-name from
  call-by-need. Its `setRef` raises `cannot modify a read-only
  expression`: a thunk has no cell to write into.
- `Exp.evalRef` now returns a `ThunkRef(self, env)` instead of wrapping
  `eval(env)` in a `ValRef`. `LitExp` and `ProcExp` both override it back
  to the old `ValRef`-wrapping behavior — a literal or a proc value gains
  nothing from being thunked and eagerly evaluating them is harmless —
  while `VarExp` keeps REF's `applyEnvRef` override unchanged, so a bare
  variable operand is still passed by reference. This three-way split
  (`ThunkRef` by default, `ValRef` for literals/procs, the inherited
  reference override for variables) is the entire mechanism of
  call-by-name and is worth a slide of its own.
- `apply` now takes a `List<Ref>` **and** an `Env` (`apply(args, env)`
  in Python/JavaScript, `apply(List<Ref> args, Env e)` in Java) — the
  same unread `env` parameter, for the same dynamic-scoping exercise
  SET's entry describes. Pre-migration NAME's `apply(List<Ref>)` had no
  `Env` parameter at all. `ProcVal.apply` also now raises
  `formals/args number mismatch` on an arity error; pre-migration NAME
  had no arity check at all, going straight to
  `new Bindings(formals.varList, refList)`.
- `let` and `letrec` are untouched: both `LetDecls` methods still
  evaluate their bindings eagerly, exactly as REF does. Call-by-name in
  this language is a rule about **operands to a proc call**, not about
  `let`.
- The old `src/NAME/tests/let-proc/` is now
  `tests/operand-evaluated-at-use/`. Same program (expected value still
  `7`), renamed for what it actually demonstrates.
- All eight of `Prog/{countdown, counter, divideByZero, jensen, looper,
  pppp, sumsq, test}` were run against all three targets (Task 5) and are
  byte-identical across Python, Java, and JavaScript. Four of them were
  also run against REF's own shipped `spec.plcc`, giving a live
  NAME-versus-REF contrast — not a predicted one, since both are shipped
  specs and both numbers come from actually running the same source file:

  | program | NAME | REF |
  |---|---|---|
  | `Prog/pppp` | `7` | `6` |
  | `Prog/test` | `10` | `4` |
  | `Prog/counter` | `1` | `4` |
  | `Prog/divideByZero` | `11` | `attempt to divide by zero` |

  This table doubles as a demo: `( cd src/NAME/python && plcc-rep <
  ../Prog/pppp )` next to `( cd src/REF/python && plcc-rep <
  ../../NAME/Prog/pppp )` shows the divergence live, in class, from the
  same source file against two different `spec.plcc`s.
- `Prog/jensen` and `Prog/looper` **do not terminate** under call-by-value
  — run against REF, Python raises `RecursionError` after a long climb,
  and Java and JavaScript may simply hang. This is the sharpest available
  demonstration that call-by-name is not merely a different answer to the
  same program: it is a different set of programs that terminate at all.
  Do not add these two to the REF-contrast table above; the divergence is
  the finding, not a number to fill in.
- `Prog/counter` reads like an ordinary counter — `.times4(let count=0 in
  proc() set count=add1(count))` — and gives `1`, not `4`, because the
  operand is a thunk rebuilt on every one of `times4`'s four calls, so
  each call gets a fresh `count`. `Prog/test` gives `10`, not `4`, because
  the thunk `set x=add1(x)` is forced seven times, incrementing `x` each
  time. Both are call-by-name working correctly, not regressions, and
  both are worth pre-empting on a slide before a student reports either
  as a bug.

## NEED

- Identifier token is now `SYMBOL`, not `VAR`, and the corresponding
  field is `symbol`, not `var` — the standing convention since V0.
  `VarExp.eval` reads `env.applyEnv(self.symbol.lexeme)`, not
  `env.applyEnv(self.var.lexeme)`.
- `$run()` is now `_run()`, and it **returns** its output string rather
  than printing it, the same `_run()` contract every migrated language
  adopts.
- `ThunkRef` now memoizes: a `val` field initialized to `None`/`null`,
  and a `deRef` that evaluates the captured expression on first call and
  returns the cached value on every call after. This one method is the
  entire difference between NAME and NEED — nothing else in `ThunkRef`
  changes, and no other class needs to. `Prog/test` demonstrates it
  directly: the same program that gives `10` under NAME (the thunk
  `set x=add1(x)` re-forced on all seven uses) gives `4` under NEED (the
  thunk forced once, on first use, and cached thereafter).
- `ValRORef` is a new `ValRef` subclass, read-only: it inherits
  `deRef`, but overrides `setRef` to raise `cannot modify a read-only
  reference`. `LitExp.evalRef` and `ProcExp.evalRef` both return a
  `ValRORef` where NAME returned a plain `ValRef` — a literal or a proc
  value is being handed out as an operand with nothing to assign into.
  The observable: `let p = proc(t) set t=9 in .p(11)` now raises
  `cannot modify a read-only reference`, where NAME's same program
  returns `9`. `VarExp.evalRef` is untouched, so assigning through a
  bare variable formal still works exactly as it does under NAME —
  `let x=3 p=proc(t) set t=add1(t) in {.p(x); x}` still gives `4`.
- A new `ERROR` token and `<Prim:ErrorPrim>` production — NEED's only
  syntax delta from NAME. `ErrorPrim.apply` raises `user-defined error`
  regardless of how `error()` is called; the primitive ignores its
  argument list entirely.
- `apply` now takes a `List<Ref>` **and** an `Env` (`apply(args, env)`
  in Python/JavaScript, `apply(List<Ref> args, Env e)` in Java) — the
  same unread `env` parameter, for the same dynamic-scoping exercise
  SET's and NAME's entries describe. Pre-migration NEED's
  `apply(List<Ref>)` had no `Env` parameter at all. `ProcVal.apply` also
  now raises `formals/args number mismatch` on an arity error;
  pre-migration NEED had no arity check at all.
- The old `src/NEED/tests/let/` is now `tests/thunk-forced-once/`, and
  its input was upgraded from a three-use program to the seven-use
  `Prog/test` — the same file NAME's `tests/thunk-reevaluated-per-use/`
  runs (ignoring one blank line NAME's copy carries and NEED's does
  not). One program, two expected values: `4` under NEED, `10` under
  NAME, both correct for their language.

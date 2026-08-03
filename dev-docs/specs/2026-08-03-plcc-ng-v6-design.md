# plcc-ng Migration — V6 Design

This is a focused design of record for the V6 phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [V5 design](2026-07-31-plcc-ng-v5-design.md), whose grammar,
semantics, and `envVal` reuse V6 inherits almost entirely unchanged. This
document captures only the decisions and porting subtleties specific to V6,
settled in brainstorming on 2026-08-03.

## Goal

Port V6 (`V5 + top-level define`) to plcc-ng: one shared `grammar.plcc` plus
three target `spec.plcc`s (Python, Java, JavaScript). The phase closes when all
three targets pass their bats suite.

**V6 is the last of the V-series, so this phase closes Phase 2.** After it,
every remaining test failure belongs to Phases 3–5 (SET, REF, NAME, NEED,
TYPE0, TYPE1, OBJ).

The delta is small in line count but is not the mechanical exercise V5 was.
V6 is the first language whose `<Program>` has alternatives, and the first
whose semantics depend on state persisting *across* programs rather than
within one. Those two facts are what this document is mostly about.

## Validated Mechanics

The overarching design flagged exactly one unvalidated risk for V6:

> V6's `<program>` grammar has two alternatives (`Define`/`Eval`), and
> `plcc-rep` reads and evaluates one at a time from stdin in a loop, with
> `define` mutating a `Program`-level environment that later reads in the same
> run must see. Whether `plcc-ng`'s equivalent REP loop preserves that
> persistent state across multiple parses in one process is unvalidated.

It was run against the installed CLI before this design was written, using a
minimal spec in V6's exact shape — two `<Program>` alternatives, a mutable
static on the `Program` base, a `_run()` on each subclass:

```
$ printf 'set 5\nx\nset 9\ny\n' | plcc-rep
set to 5
get x = 5
set to 9
get y = 9
```

**`plcc-rep` preserves process-level state across programs**, and it does so
identically in all three targets (the spike was run for Python, Java, and
JavaScript). V6 therefore needs no spike of its own — the same call V5 made.

Two further facts, neither flagged in advance, were established by the same
exercise and are load-bearing for the port:

**`_run()` must return a string, in all three targets.** The overarching
design's addendum still claims an asymmetry — that Python and Java should call
`print()`/`System.out.println()` and return void, and only JavaScript must
`return`. That is obsolete as of the
[2.0.0 update](2026-07-27-plcc-ng-2.0.0-update-design.md); returning `None`
from Python's `_run()` is now a hard error:

```
Specification error: TypeError: _run() must return a string, got NoneType
```

This matters specifically here because V6's `Define` is the first entry point
in the migration whose Java original *ends* in a `println` and returns `void`.
It cannot be ported literally. See
[Overarching Design Corrections](#overarching-design-corrections) below.

**Zero-formal `proc()` and zero-rand `.f()` work.** `let f = proc() 7 in .f()`
evaluates to `7`. Both sides are an empty arbno, a shape no V4 or V5 test
exercises, and two of V6's four new tests depend on it.

## Grammar

`src/V6/grammar.plcc` is V5's grammar plus one token and a split `<Program>`.
The new keyword goes directly after `LETREC`, keeping V6's original token
order and staying well ahead of the `SYMBOL` catch-all:

```
token DEFINE 'define'
```

```
<Program:Define> ::= DEFINE <SYMBOL> EQUALS <Exp>
<Program:Eval>   ::= <Exp>
```

Generated fields: `Define.symbol` / `Define.exp`, and `Eval.exp`. Everything
else — the rest of the token list, the nine `<Exp>` alternatives, `<LetDecls>`,
`<Rands>`, `<Proc>`, `<Formals>`, `<SeqExps>`, and the seven `<Prim>`s — is
carried over from V5 unchanged.

Two properties make this safe without further checking. The split is LL(1)
because `DEFINE` is not in `FIRST(<Exp>)`, so one token of lookahead separates
the alternatives. And `define` does not shadow variables that merely start with
it — plcc-ng's scanner is maximal-munch, established at V5, so `defined` scans
as a single `SYMBOL`.

Note for anyone diffing against the pre-migration `src/V6/grammar`: the port
uses `SYMBOL` where the original used `VAR` (the JS reserved-word fix, adopted
repo-wide), and camelCase alt-names `<Exp:testExp>` rather than the lowercase
workaround the overarching design still describes — issue
[#6](../issues/006-multi-capture-alt-name-case-mismatch.md) was fixed in
plcc-ng 2.0.0.

## Semantics

Every V5 semantic class — `Val`, `IntVal`, `ProcVal`, the seven `Prim`s,
`Rands`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`, `LetrecExp`,
`ProcExp`, `Proc`, `Formals`, `LetDecls`, `AppExp`, `SeqExp` — is reused
verbatim. "Verbatim" here means *after* the V5 retro-fix described under
[Convergence on the Post-V5 Shape](#convergence-on-the-post-v5-shape), which
lands first precisely so that V6 can copy V5 without exception: sequencing it
that way keeps this section's rule absolute instead of carving out two classes.

New work specific to `define` is then confined to three places.

**`Program`** keeps its `static env = Env.initEnv()` and **loses** its
`_run()`. With `<Program>` now abstract over two alternatives, the entry point
belongs on the subclasses; the shared environment stays on the base, where both
subclasses inherit it and where it is created exactly once per `plcc-rep`
process.

**`Define._run()`** resolves the name against the top-level environment's
*local* bindings only, then either replaces the existing binding's value in
place or adds a new one, and returns the **name** — not the value:

```python
def _run(self):
    env = Program.env
    s = self.symbol.lexeme
    val = self.exp.eval(env)
    b = env.lookup(s)
    if b is not None:
        b.val = val
    else:
        env.add(Binding(s, val))
    return s
```

The `return s` is where the port necessarily diverges from the Java original's
`System.out.println(s)` — same observable output, different mechanism, forced
by the `_run()` contract described above.

**`Eval._run()`** returns the string form of the value:

```python
def _run(self):
    return str(self.exp.eval(Program.env))
```

**Imports.** `Define` needs `Env` and `Binding` in Python and JavaScript;
`Eval` needs neither, since the generated subclass file already requires its
own base class. Java needs no import block at all, its free-standing classes
being same-directory and package-less.

### What `define` actually means — letrec's trick, hoisted to top level

This is the one idea in V6 that a reader has to be told rather than shown, and
it is what an instructor explains at the board, so the design states it
precisely.

`Program.env` is a **single `EnvNode`**, created once when the class is
initialized and shared by every program in a `plcc-rep` run. Every `define`
mutates *that node* — it never extends the environment and never replaces it.
Rebinding an existing name assigns to `b.val` on the `Binding` **object**, not
to a fresh binding in a fresh node.

Three consequences follow, each already demonstrated by a file in `src/V6/Prog/`:

- **Forward references work.** `define even? = proc(x) ... .odd?(...)` is legal
  before `odd?` exists. The closure captured the node, and `odd?` lands in that
  same node later, so by the time anything is *called* the binding is there.
  This is exactly V5's `letrec` mechanism — recursion by aliasing a mutable
  node — hoisted one level up, and it is why the shipped `define` test can
  define two mutually recursive procedures as two separate top-level programs.

- **Redefinition reaches closures that already exist.** Because rebinding
  assigns through the `Binding` a closure holds a reference to, a closure
  written before the redefinition sees the new value. `Prog/x`:

  ```
  define x=2
  define f = proc() x
  .f()          % => 2
  define x=3
  .f()          % => 3
  ```

- **…unless the closure captured a copy.** A `let` extends a *new* node holding
  its own binding, which no later top-level `define` can reach. `Prog/xx`:

  ```
  define x=2
  define f = let x=x in proc() x
  .f()          % => 2
  define x=3
  .f()          % => 2   -- still
  ```

That last pair is the contrast V6 exists to teach, and it is what the two new
tests assert. Both behaviors are faithful to the original V6, not porting
artifacts, and both belong in the course-material-impact log.

## envVal Reuse

Zero-touch, for the fourth consecutive language. `src/V6/envVal` is
byte-identical to V5's, so each target's `spec.plcc` does
`%include ../grammar.plcc` then
`%include ../../Env/envVal/<target>/env.plcc`, and **no file under `src/Env/`
is modified in this phase.**

Every facility `Define` needs is already in the port, unchanged since V3:
`initEnv()` returns a mutable `EnvNode(Bindings(), EnvNull())` rather than a
bare `EnvNull`, so there is always a node to add to; `EnvNode.lookup` consults
local bindings only and does not walk the parent chain, which is exactly the
"only look at local bindings" the Java original comments on; `EnvNode.add`
mutates in place; and `Binding.val` is a plain assignable field in all three
targets.

## Convergence on the Post-V5 Shape

V6's pre-migration files differ from V5's in three ways unrelated to `define`.
Checking those differences against the seven languages still to be ported
showed that **V5, not V6, is the outlier**:

| | `LetrecExp`/`ProcExp` `toString()` | placeholder spelling | dead `zero` field |
|---|---|---|---|
| V5 | absent | `"... LetExp ..."`, `" ... AppExp ..."`, `" ... SeqExp ... "` — three spacings | absent |
| V6 | present | `" ...LetExp... "` uniformly | `IntVal zero` |
| SET, REF, NAME, NEED, TYPE0, TYPE1 | present | `" ...LetExp... "` uniformly | absent |
| OBJ | present | `" ...LetExp... "` uniformly | `Val zero` |

So on two of the three items, dropping V6's "drift" would only mean Phase 3's
first language has to add it straight back. V6 therefore **adopts its own
shape**, and V5 is retro-fixed to match — in its own commit, sequenced
**before** V6's three `spec.plcc`s are written, so that V6 is a clean copy of
V5 plus `define` rather than a copy plus a scattering of corrections:

- Add `LetrecExp.toString()` and `ProcExp.toString()` to both V5 and V6. V5's
  design declined to invent these on the grounds that "the original has none" —
  correct for V5 in isolation, but every other kept language does have them.
- Normalize the four V5 placeholder strings to the uniform `" ...X... "`
  spelling V6 and all seven remaining languages use.

The dead `zero` field is **not** carried. It appears only in V6 and OBJ, is
referenced by neither, and the two declarations do not even agree on its type
(`IntVal zero` versus `Val zero`). Whether OBJ wants it is Phase 5's call.

All of this is behaviorally inert — no test prints an `Exp`, and these
`toString()`s are pedagogical artifacts rather than live output — so it
produces course-material-impact entries for both V5 and V6, and no test
changes. Reopening a closed phase is a deliberate, bounded exception, taken
because V6 is the last checkpoint before Phase 3 fans the inconsistency out
across seven languages.

## Tests

`src/V6/tests/<case>/`, each case a shared `V6.input` + `V6.expected` (all three
targets must produce identical output) plus one `V6test.bats` with three `@test`
blocks, one per target directory, driven by `plcc-rep` — the same shape V3, V4,
and V5 use. Unlike every earlier language, a V6 input file holds a *sequence* of
programs and the expected file holds one line per program; the existing shipped
test already has this shape, so nothing about the harness changes.

Four cases:

- **`define/`** — the existing case, ported off the old `plccmk`/`rep`
  invocation: `even?` and `odd?` defined as two separate top-level programs and
  then applied. Exercises the forward reference described above, since `even?`
  names `odd?` before `odd?` exists. → `even?` / `odd?` / `0` / `1`.
- **`define-then-use/`** — from `Prog/inits`: `define x=10` then `+(x,4)`. The
  minimal proof that a binding made by one program is visible to the next, and
  the only case that pairs a `Define` program with a bare `Eval` program.
  → `x` / `14`.
- **`redefine/`** — from `Prog/x`. Rebinding mutates through a closure that
  already exists.
- **`capture-copy/`** — from `Prog/xx`. A `let`-captured copy is immune to the
  same rebinding.

Note when writing the expected files that **every `Define` program emits a
line** — its name — so the two closure cases are five lines each, not two. The
`.f()` results are the third and fifth lines, and they are the only lines that
differ between the pair:

```
   redefine/ (Prog/x)        capture-copy/ (Prog/xx)
   x                         x
   f                         f
   2                         2
   x                         x
   3      <-- differs        2      <-- differs
```

**All four expected outputs above are measured, not predicted.** A throwaway
Python `spec.plcc` — V5's, with only the `Program`/`Define`/`Eval` change of
this design applied — was run against `Prog/x`, `Prog/xx`, `Prog/inits`, and
the existing `tests/define/V6.input` during design. Each produced exactly the
output recorded here, and the shipped `define` case reproduced byte-for-byte
through the new two-alternative `<Program>`. The semantics in
[What `define` actually means](#what-define-actually-means--letrecs-trick-hoisted-to-top-level)
are therefore evidence rather than inference — in particular the
`capture-copy/` result, which is the one claim in this document that a careful
reader would otherwise be right to doubt.

The last two are a matched pair and should be read together; separately, each
looks like an arbitrary scoping test, and together they are the whole point of
the language.

Value cases only — no error-path test for the duplicate-identifier check or for
a parse failure mid-stream — keeping the one-shared-expected model clean, the
same call V3, V4, and V5 made.

Magnitudes and recursion depths stay small in every case, clear of the two live
constraints: the 32-bit Java `IntVal` overflow of open issue
[#16](../issues/016-cross-target-integer-divergence.md), and the Python
recursion ceiling of open issue
[#19](../issues/019-python-recursion-ceiling.md). Nothing in these four cases
comes close to either.

## Example Programs (`src/V6/Prog/`)

V4 established the precedent: `Prog/` files are course artifacts, so they stay
where they are, but the phase **actually runs** all of them against all three
targets rather than assuming they still work. V6 has nine — `dddd`, `inits`,
`ivx`, `p1`, `p2`, `pair`, `util`, `x`, `xx`. All are small, so unlike V4 no
shrinking for Python's recursion ceiling is expected; the plan should still run
them rather than assume it.

`p1` and `p2` are a special case. They are deliberate *fragments* — `+(3` and
`,4)` — that form a valid program only when read together, demonstrating a
reader that spans file boundaries. Under plcc-ng that demonstration no longer
survives being passed as two file arguments:

```
$ plcc-rep p1 p2
plcc-parser-table: -:1:3: error: expected 'RPAREN', got end of file
plcc-parser-table: -:1:1: error: unexpected 'COMMA', no production for 'Program'

$ cat p1 p2 | plcc-rep
7
```

`plcc-rep` parses each `SOURCE` argument as its own independent stream. Both
files are **kept unchanged** — the pedagogical point still holds, only the
invocation changed — with a course-material-impact entry recording
`cat Prog/p1 Prog/p2 | plcc-rep` as the replacement for `rep Prog/p1 Prog/p2`,
and a `docs` issue filed with `**Target:** ourPLCC/plcc-ng` recording the
behavior difference. It is filed as a migration hazard worth documenting
upstream rather than as a defect in our own `src/`; per-source parsing is
arguably the more sensible design.

Incidentally confirmed by the run above: a failing program does **not** abort
the rest of the stream — plcc-rep reported the error in `p1` and went on to
parse `p2`.

## Overarching Design Corrections

The overarching
[migration design](2026-07-22-plcc-ng-migration-design.md) has no reference to
the [2.0.0 update](2026-07-27-plcc-ng-2.0.0-update-design.md) and carries four
claims that are now false. A commit on this branch corrects each in place,
pointing at the design or issue that superseded it:

| Where | Stale claim | Reality |
|---|---|---|
| Phasing, V2 bullets | Spell alt-names entirely lowercase (`<Exp:testexp>`) to dodge issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md) | Fixed in 2.0.0; V3–V5 all ship camelCase `<Exp:testExp>` |
| Addendum | Python and Java `_run()` should `print()`; only JavaScript returns | All three return a string; `print()` plus `None` is a hard error |
| Addendum | Returning a plain string from Python's `_run()` prints it quoted | Issue [#3](../issues/003-python-run-return-value-quoted.md), closed 2026-07-28 |
| Addendum | Rename the *capture* (`<VAR:name>`) for the JS reserved word | The port renamed the *token* to `SYMBOL` |

This is in scope for V6 specifically because V6 is the last phase before
Phase 3 fans out to seven languages whose implementers will read that document
first — the cost of leaving it stale multiplies from here.

## Bookkeeping (in the same commits as the work)

- File a V6 issue with `bin/issues/new.bash <slug> feat` and add its roadmap
  entry in the same commit; close it with `bin/issues/close.bash` as the
  branch's final commit.
- File the `plcc-rep` multi-source `docs` issue described above, with
  `**Target:** ourPLCC/plcc-ng`.
- Delete the old flat old-PLCC files `src/V6/{grammar,code,prim,envVal,val}`
  once the three targets pass. As with V4 and V5, none of them collides with a
  new path (`src/V6/grammar` versus `src/V6/grammar.plcc`), so the deletion
  comes at the end rather than up front.
- Log V6 entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change: the `DEFINE` token and the
  `<Program:Define>`/`<Program:Eval>` split; `Define._run()` returning the name
  rather than printing it; the top-level-node mutation semantics **and** both
  of its visible consequences (redefinition reaching existing closures, and
  `let`-captured copies being immune); the `p1`/`p2` invocation change; and the
  `LetrecExp`/`ProcExp` `toString()` additions plus placeholder-string
  normalization. Log the V5 half of that last item under V5's heading.
- The implementation plan lands under [dev-docs/plans/](../plans/) (via
  writing-plans).

### Expected test counts

Measured on this branch with a full `bin/test.bash` run at design time, not
derived from V5's numbers — V2's plan got this wrong by copying and adjusting,
and V5's first draft got it wrong by reading a `tail` of the output instead of
the whole run. Count from the whole run, or from `grep -c`.

The suite today is **59 tests: 51 passing and 8 failing**, every failure a
`plccmk: command not found` from a language still on old PLCC — NAME, NEED,
OBJ, REF, SET, TYPE0, TYPE1, and V6.

After this phase: **70 tests** — 59, minus V6's 1 old test, plus 12 new
(4 cases × 3 targets) — **63 passing and 7 failing**, the same
`command not found` set minus V6.

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after. Because V6 closes Phase 2, the 7 remaining failures
should all be non-V languages; a surviving `V`-prefixed failure means something
regressed.

## Out of Scope

- Phases 3–5 — SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ — and the `envRef` port
  they share.
- Issue [#16](../issues/016-cross-target-integer-divergence.md) and issue
  [#19](../issues/019-python-recursion-ceiling.md) — both repo-wide and
  inherited from V0, not V6's to fix.
- Error-path and diagnostic tests, including the behavior of a parse failure
  partway through a program stream.
- Any change to `envVal`, or any unification of the Env variants.
- Adding a `zero` field to OBJ's `Val`, or otherwise reconciling OBJ's fork —
  Phase 5's call.
- Unifying the per-language `Val`/`IntVal`/`Prim` duplication — ruled out
  repo-wide by the overarching design.

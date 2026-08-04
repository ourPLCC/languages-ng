# plcc-ng Migration — SET Design

This is a focused design of record for the SET phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [V6 design](2026-08-03-plcc-ng-v6-design.md), whose grammar and
semantics SET inherits almost entirely unchanged. This document captures only
the decisions and porting subtleties specific to SET, settled in brainstorming
on 2026-08-04.

## Goal

Port SET (`V6 + references/set`) to plcc-ng: one shared `grammar.plcc` plus
three target `spec.plcc`s (Python, Java, JavaScript). The phase closes when all
three targets pass their bats suite.

**SET opens Phase 3**, and does two jobs rather than one: it ports SET, and it
ports **`envRef`** — the Env variant shared by all four Phase 3 languages
(SET, REF, NAME, NEED) and, in extended form, by TYPE0, TYPE1, and OBJ.

## Why SET Goes First

The four Phase 3 languages form a strict inclusion chain, confirmed by diffing
their pre-migration `code`, `val`, and `ref` files:

| language | delta over its predecessor |
|---|---|
| SET | V6 + `SET`/`SetExp` + `Ref`/`ValRef` indirection through `envRef` |
| REF | + `evalRef` (a bare variable passes its own `Ref`, not a copy) |
| NAME | + `ThunkRef` (call-by-name) |
| NEED | + memoized `ThunkRef`, `ValRORef`, `ErrorPrim` |

Their grammars are byte-identical except for NEED's extra `ERROR` token and
`ErrorPrim` production. SET is therefore both the base of the chain and the
smallest delta on the just-completed V6, and each later language is a pure
delta on it.

Two further facts confirm the order. `src/SET/envRef` is already the majority
**`void`** `checkDuplicates` shape the overarching design's corrected Phase 3
section says to adopt as canonical — so the language that ports `envRef` first
is also the one carrying the right shape. And SET's `Define` still ends in
`System.out.println(id)` exactly as V6's did, so SET reuses V6's
`_run()`-returns-a-string resolution verbatim, where NAME's `Define` has that
`println` **commented out** — a wrinkle better met after the pattern is
established than at the head of the phase.

## Validated Mechanics

Two spikes were run against the installed CLI before this design was written.
Both were clean, and both are the reason this document commits to decisions
rather than flagging them as risks.

### Spike 1 — `envRef` and SET's semantics, Python, end to end

A throwaway `Env/envRef/python/env.plcc` plus a SET `spec.plcc` built as
V6-plus-delta. Measured:

| program | output |
|---|---|
| `let x=42 in {set x=add1(x); x}` (the shipped test) | `43` |
| `Prog/g` — counter closure, `.g()` three times | `3` |
| `let x=3 p=proc(t) set t=add1(t) in {.p(x); x}` | `3` |
| `define x=1` / `set x=2` / `x` | `x` / `2` / `2` |
| `letrec f = ... in .f(10)` summing to 10 (V5 surface) | `55` |
| `let f=proc(a,a) a in .f(1,2)` | `duplicate ID a in proc formals` |
| `set q = 1` | `no binding for q` |

**SET needs no plcc-ng mechanics that earlier phases have not already
validated.** `Ref` and `ValRef` are ordinary free-standing classes of the kind
V1 established, and `Ref.valsToRefs` resolves its `ValRef` import *inside the
method* — the same circular-import dodge `Env.initEnv` has used since V3.

The last two rows are recorded as evidence that the duplicate check and the
unbound-variable path survive the port. Neither becomes a test case; SET keeps
the value-cases-only rule V3–V6 set.

### Spike 2 — the Java `Prim.apply(Val[] va)` retro-fix

V6's Java `spec.plcc` was converted to the array shape and run against V6's
entire shipped suite — `define`, `define-then-use`, `redefine`, `capture-copy`
— producing byte-identical output. The conversion per language is `Val.toArray`
restored to `Val`, one abstract signature, seven concrete ones, and
`PrimappExp.eval`. See [Convergence Decisions](#convergence-decisions).

## Grammar

`src/SET/grammar.plcc` is V6's grammar plus one token and one production, each
in the position SET's original grammar put it — `SET` after `PROC` and before
`DOT`, `SetExp` after `SeqExp`:

```
token SET 'set'
```

```
<Exp:SetExp>     ::= SET <SYMBOL> EQUALS <Exp>
```

Generated fields: `SetExp.symbol` and `SetExp.exp`.

Two properties make this safe. The grammar stays LL(1) because `SET` is not in
`FIRST(<Exp>)`, so one token of lookahead separates `SetExp` from the other ten
alternatives. And `set` does not shadow variables that merely start with it —
plcc-ng's scanner is maximal-munch, established at V5, so `settings` scans as a
single `SYMBOL`.

Everything else carries over from V6 unchanged, including the `SYMBOL` token
name (the JS reserved-word fix, adopted repo-wide) and the camelCase alt-names
`<Exp:testExp>`/`<Exp:trueExp>`/`<Exp:falseExp>`.

## The `envRef` Port

`src/Env/envRef/<target>/env.plcc`, ported once here and `%include`d unchanged
by REF, NAME, and NEED. It is **`envVal` with one level of indirection**: a
`Binding` holds a `Ref` rather than a `Val`, so a binding's value can be
mutated in place.

| `envVal` | `envRef` |
|---|---|
| `Binding.val` | `Binding.ref` |
| `applyEnv` is the abstract primitive | `applyEnvRef` is the primitive; `applyEnv` is derived as `applyEnvRef(sym).deRef()` |
| `extendEnv(bindings)` | `extendEnvRef(bindings)` |
| `Bindings(idList, valList)` | `Bindings(idList, refList)` |
| `Binding.__str__` prints `val` | prints `ref.deRef()` |

`checkDuplicates`, `initEnv`, `lookup`, `add`, and `size` are unchanged from
`envVal`, as is the rule that `initEnv()` returns a mutable
`EnvNode(Bindings(), EnvNull())` rather than a bare `EnvNull`.

Two points the overarching design's corrected Phase 3 section settles, restated
here because both are easy to get wrong from the pre-migration sources:

- **Port the `void` `checkDuplicates`, not the `Set<String>` one.** The flat
  `src/Env/envRef` and `src/REF/envRef` are the *minority* shape, and no caller
  anywhere in `src/` uses the returned set. Do not carry the return type
  forward on the grounds that the flat file has it.

- **Delete the flat `src/Env/envRef` up front.** Unlike V6's `grammar` versus
  `grammar.plcc`, this is a genuine path collision — the flat file sits exactly
  where the new `src/Env/envRef/` directory must go, so the deletion is the
  phase's first step rather than its last.

## Semantics

Every V6 semantic class is reused. The delta is confined to five places, all of
which follow from the same fact: bindings now hold `Ref`s.

**`Ref` and `ValRef`** are added as free-standing classes in each language's
`spec.plcc` — *per language*, not shared under `src/Env/`, matching the
original's per-language `%include ref`. `Ref` carries the abstract `deRef` /
`setRef` pair and the static `valsToRefs` helper; `ValRef` is the mutable cell.

**`ProcVal.apply`** wraps its arguments in fresh `ValRef`s and extends with
`extendEnvRef`:

```python
def apply(self, args, env):
    if len(self.formals.symbolList) != len(args):
        raise LanguageError("formals/args number mismatch")
    refList = Ref.valsToRefs(args)
    bindings = Bindings(self.formals.symbolList, refList)
    nenv = self.env.extendEnvRef(bindings)
    return self.body.eval(nenv)
```

Those fresh `ValRef`s are *why* `formal-is-a-copy/` evaluates to `3`, and they
are the single line REF changes to get `4`. Whoever ports REF should start
here.

**`LetDecls.addBindings` and `addLetrecBindings`** likewise bind `ValRef`s and
call `extendEnvRef`, and **`Define._run`** builds a `ValRef` and assigns
`b.ref` (rather than `b.val`) when rebinding an existing name.

**`SetExp.eval`** is the only genuinely new method:

```python
def eval(self, env):
    v = self.exp.eval(env)
    ref = env.applyEnvRef(self.symbol.lexeme)
    return ref.setRef(v)
```

It returns the assigned value, which is what makes `set x = 2` a usable
expression rather than a statement — the middle line of `define-then-set/`
prints `2`.

**Imports.** `ProcVal` and `LetDecls` gain `Ref`; `Define` and `LetDecls` gain
`ValRef`. Java needs no import block, its free-standing classes being
same-directory and package-less.

## Convergence Decisions

Two shape questions arise from the fact that SET's pre-migration source differs
from the migrated V-series. Both are settled here, before Phase 3 fans the
answer out across six more languages.

### `apply` keeps its `Env` parameter

V4, V5, and V6 declare `Val.apply(args, env)` / `ProcVal.apply(args, env)` and
**never read `env`** — `ProcVal` uses the environment it captured at definition
time. It came from the pre-migration V4/V5 source, not from the port, and none
of the seven remaining languages has it: SET and OBJ use `apply(List<Val>)`,
REF/NAME/NEED/TYPE0/TYPE1 use `apply(List<Ref>)`.

**SET's port adds the parameter to its own original signature, and every later
Phase 3–5 language does the same.** The parameter is not dead code: it is the
seam for a **homework assignment in which students reimplement `proc` with
dynamic scoping**, resolving free variables in the *calling* environment — the
one passed in — instead of the captured one. With the parameter already in
place that assignment is a small edit inside `ProcVal.apply`; without it, it is
a signature change rippling through every call site.

This is recorded explicitly because a reader encountering an unused parameter
will otherwise remove it as a cleanup. **It must not be removed**, and it
should be carried into REF/NAME/NEED as `apply(refList, env)`.

### Java's `Prim.apply` takes `Val[] va`, and V1–V6 are retro-fixed

All seven remaining pre-migration languages declare `Prim.apply(Val[] va)` and
build the array with `Val.toArray`. The V-series port dropped that for
`List<Val> args`, which left Java reading differently from the other two
targets:

| target | length check | element access |
|---|---|---|
| Python | `len(args)` | `args[0]` |
| JavaScript | `args.length` | `args[0]` |
| Java, as ported | `args.size()` | `args.get(0)` |
| Java, with `Val[] va` | `va.length` | `va[0]` |

Restoring the array makes all three targets read alike, which is exactly what
the overarching design's *Structural Fidelity Across Targets* section exists
for: one textbook discussing `AddPrim.apply` once, with three appendices a
reader can follow in parallel. Only Java changes — Python lists and JavaScript
arrays already index natively.

**SET's Java uses `Val[] va` from the start, and V1–V6's Java `Prim`s are
converted back in their own commit, sequenced before SET's `spec.plcc`s are
written.** Reopening six closed phases is a deliberate, bounded exception,
taken for the reason V6's design gave for reopening V5: this is the last
checkpoint before the shape fans out across seven more languages, and the cost
of leaving it multiplies from here. The change is behaviorally inert — verified
against V6's full suite in [Spike 2](#spike-2--the-java-primapplyval-va-retro-fix)
— so it produces course-material-impact entries and no test changes.

Per language — the six being retro-fixed **and SET itself** — the conversion is:
`Val.toArray` restored to `Val`, one abstract `apply` signature, seven concrete
ones, and `PrimappExp.eval` gaining a `Val [] va = Val.toArray(args);` line.
V0 is unaffected: its semantic section is `toString()`s only, with no
`Prim.apply` at all.

## Tests

`src/SET/tests/<case>/`, each case a shared `SET.input` + `SET.expected` (all
three targets must produce identical output) plus one `SETtest.bats` with three
`@test` blocks, one per target directory, driven by `plcc-rep` — the same shape
V3–V6 use.

Four cases. **Every expected output below was measured** in
[Spike 1](#spike-1--envref-and-sets-semantics-python-end-to-end), not predicted:

- **`let/`** — the existing case, ported off the old `plccmk`/`rep` invocation:
  `let x=42 in {set x=add1(x); x}`. `set` on a `let`-bound variable. → `43`
- **`counter/`** — from `Prog/g`: `let g = let count=0 in proc() set
  count=add1(count) in {.g(); .g(); .g()}`. `set` on a *closure-captured*
  binding, proving the closure holds the environment node rather than a copy of
  it. SET's signature demonstration. → `3`
- **`formal-is-a-copy/`** — `let x=3 p=proc(t) set t=add1(t) in {.p(x); x}`.
  `set` on a formal does not reach the caller's variable. → `3`
- **`define-then-set/`** — `define x=1` / `set x=2` / `x`. `set` on a binding in
  the persistent top-level node, and the only case that shows `set` returning
  its assigned value. → `x` / `2` / `2`

Together these cover every place `envRef` can be mutated: a `let` binding, a
closure-captured binding, a formal, and a top-level `define` binding.

`formal-is-a-copy/` is deliberately the same program REF will ship, where the
expected file reads `4` instead of `3`. Shipping it in both languages makes the
SET→REF contrast — the entire point of REF — a one-file diff rather than a
claim in prose. It should not be dropped from SET as redundant.

Value cases only: no error-path test for the duplicate-identifier check or the
unbound-variable path, both of which Spike 1 confirms still work. This keeps
the one-shared-expected model clean, the same call V3–V6 made.

Magnitudes and recursion depths stay small, clear of the 32-bit Java `IntVal`
overflow of issue [#16](../issues/016-cross-target-integer-divergence.md) and
the Python recursion ceiling of issue
[#19](../issues/019-python-recursion-ceiling.md).

## Example Programs (`src/SET/Prog/`)

SET has exactly one: `Prog/g`, the counter closure. It is **promoted to the
`counter/` test case** and, per the V4 precedent, is also run as a program
against all three targets rather than assumed to still work. Design-time
verification was Python-only.

## Bookkeeping (in the same commits as the work)

- File a SET issue with `bin/issues/new.bash <slug> feat` and add its roadmap
  entry in the same commit; close it with `bin/issues/close.bash` as the
  branch's final commit.
- Delete the flat `src/Env/envRef` **first** (path collision, see above).
- Delete the old flat old-PLCC files `src/SET/{grammar,code,prim,envRef,val,ref}`
  once the three targets pass. None collides with a new path
  (`src/SET/grammar` versus `src/SET/grammar.plcc`), so this deletion comes at
  the end.
- Log SET entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change: the `SET` token and the `<Exp:SetExp>`
  production; the `envRef` indirection (`Binding.ref`, `applyEnvRef`,
  `extendEnvRef`, `Bindings(idList, refList)`); `Define._run()` returning the
  name rather than printing it; the `apply(args, env)` parameter added to SET's
  signature; and the Java `Prim.apply(Val[] va)` signature — filed under SET
  **and** under V1–V6 for the retro-fix.
- The implementation plan lands under [dev-docs/plans/](../plans/) (via
  writing-plans).

### Expected test counts

Measured on this branch with a full `bin/test.bash` run at design time, counted
with `grep -c` over the whole run rather than derived from V6's numbers.

The suite today is **70 tests: 63 passing and 7 failing** — NAME, NEED, OBJ,
REF, SET, TYPE0, and TYPE1, every failure a `plccmk: command not found` from a
language still on old PLCC.

After this phase: **81 tests** — 70, minus SET's 1 old test, plus 12 new
(4 cases × 3 targets) — **75 passing and 6 failing**, the same
`command not found` set minus SET.

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after. The V1–V6 Java retro-fix touches six passing languages,
so a regression there would show up as a V-prefixed failure — watch for it
specifically.

## Noted for Later Phases

**NAME's `Define` prints nothing.** `src/NAME/code` has
`// System.out.println(id);` commented out, where SET, REF, and NEED all print
the name. Under plcc-ng `_run()` must return a string, so NAME cannot port this
literally. NAME's phase decides between returning `""` and matching the other
three; it is called out here only so that phase does not discover it while
debugging an off-by-one expected file.

## Out of Scope

- REF, NAME, and NEED, and the `evalRef`/`ThunkRef`/`ValRORef` work they add.
- TYPE0, TYPE1, and OBJ, including whether OBJ's reserved-ID extension of
  `envRef` is still wanted — Phase 5's call.
- Error-path and diagnostic tests.
- Issue [#16](../issues/016-cross-target-integer-divergence.md) and issue
  [#19](../issues/019-python-recursion-ceiling.md) — both repo-wide and
  inherited from V0.
- Any unification of the Env variants, or of the per-language
  `Val`/`IntVal`/`Prim`/`Ref` duplication — ruled out repo-wide by the
  overarching design.

# plcc-ng Migration — REF Design

This is a focused design of record for the REF phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [SET design](2026-08-04-plcc-ng-set-design.md), whose grammar,
`envRef` port, and semantic classes REF inherits almost entirely unchanged.
This document captures only the decisions and porting subtleties specific to
REF, settled in brainstorming on 2026-08-04.

## Goal

Port REF (`SET + call-by-reference semantics`) to plcc-ng: one
`src/REF/grammar.plcc` plus three target `spec.plcc`s (Python, Java,
JavaScript). The phase closes when all three targets pass their bats suite.

REF is the second of Phase 3's four languages and the first in the entire
migration with a **zero syntax delta**. It adds no token and no production; its
whole content is five methods of semantics. It also does only one job, where
SET did two — SET ported `envRef` on REF's behalf, so this phase touches
nothing under `src/Env/`.

## Validated Mechanics

The complete REF delta was spiked against the installed CLI in **all three
targets** before this document was written — SET's three shipped `spec.plcc`s
plus the five-method patch of [Semantics](#semantics--the-five-method-delta),
run under `plcc-rep`. This is why the document commits to decisions rather than
flagging risks, and why every expected output below is measured rather than
predicted.

All three targets produced **byte-identical** output on every program. The SET
column is measured too — run against SET's own shipped `spec.plcc`, not
predicted from how call-by-value ought to behave:

| program | REF | SET |
|---|---|---|
| `let x=3 p=proc(t) set t=add1(t) in {.p(x); x}` | `4` | `3` |
| same, but `.p(+(x,0))` | `3` | `3` |
| `let x=1 f=proc(a,b) {set a=9; b} in {.f(x,x); x}` | `9` | `1` |
| `define x=0` / `define g=proc(t) proc() set t=add1(t)` / `define h=.g(x)` / `.h()` / `.h()` / `x` | `x g h 1 2 2` | `x g h 1 2 0` |
| `.swap(p,q)` via `proc(a,b) let t=a in {set a=b; set b=t}`, then `p` / `q` | `2` / `1` | `1` / `2` |
| `Prog/xx`, `Prog/factory`, `Prog/double`, `Prog/counter{1,2,4,5}` | all run | — |
| `let f=proc(a,a) a in .f(1,2)` | `duplicate ID a in proc formals` | same |

The `captured-ref` row is worth reading closely, because the interesting part
is the *last* value, not the first two. Under both languages the closure counts
`1`, `2` — it mutates whatever cell `t` names. Only the final `x` distinguishes
them: `2` under REF, where `t` names `x`'s own cell, against `0` under SET,
where `t` named a copy made at call time.

The last row is recorded as evidence that the duplicate check survives the
port. It does not become a test case; REF keeps the value-cases-only rule
V3–V6 and SET set.

### The one new mechanic: a base-class `Exp` section in Python and JavaScript

Java's `spec.plcc` has carried an `Exp` block since V1 (`public abstract Val
eval(Env env);`), but **no prior phase has put code on a generated base class in
Python or JavaScript** — every previous non-Java block named either a concrete
grammar alternative or a free-standing class. REF requires it, because
`evalRef`'s default implementation belongs on `Exp`.

It works in both. The JavaScript case carried the greater risk, since
`Exp:import` must `require('./ValRef')` while `ValRef` requires `Ref` — measured
clean, with no circular-require failure and no clash with the auto-injected
`{ Node, Token, LanguageError }`.

This is not merely REF's convenience. NAME's delta over REF is precisely a
rewrite of this one method — `Exp.evalRef` returning a `ThunkRef` instead of a
`ValRef`, with `LitExp` and `ProcExp` overriding back — so putting it on the
base class is what makes NAME a small edit rather than a restructuring.

## Grammar

`src/REF/grammar.plcc` is SET's file with its header comment changed:

```
# Language REF
#   Language SET + call-by-reference semantics
```

Nothing else differs. Confirmed by diffing the pre-migration flat
`src/SET/grammar` (recovered from git history) against `src/REF/grammar`: the
two are byte-identical apart from those two comment lines. The `SYMBOL` token,
the camelCase `<Exp:testExp>`/`<Exp:trueExp>`/`<Exp:falseExp>` alt-names, the
`SET` token, `<Exp:SetExp>`, and all eleven `<Exp>` alternatives carry over
untouched.

**REF gets its own copy rather than `%include`ing SET's.** Every migrated
language V0–V6 and SET has its own `grammar.plcc`, and a reader working through
the REF appendix should find REF's syntax in REF's directory rather than
following a cross-language include. A shared-grammar chain would also break
partway through the phase regardless: NEED adds an `ERROR` token and an
`ErrorPrim` production. The cost is 55 duplicated lines, paid once.

## The `envRef` Reuse

Each `spec.plcc` opens with `%include ../../Env/envRef/<target>/env.plcc`,
**unchanged**. There is no Env work in this phase.

REF's pre-migration flat `src/REF/envRef` differs from the ported canonical
file in exactly one respect: `checkDuplicates` returns the `Set<String>` it
builds internally instead of `void`. The overarching design already settled
this — the `void` shape is canonical, the return value is used by no caller
anywhere in `src/`, and `src/REF/envRef` is a byte-identical copy of the old
flat `src/Env/envRef` rather than independent evidence that anyone wanted the
return type. REF's flat file is deleted with the rest of its old-PLCC sources;
nothing about it is carried forward.

This makes `envRef` the third Env variant to be reused with literally zero
changes on first re-use, after `envRN` (V2) and `envVal` (V4–V6). The
Env-sharing pattern is now confirmed across all three variants.

## Semantics — the five-method delta

Every SET semantic class is reused. The delta is confined to five places, all
of which follow from one fact: **operands evaluate to `Ref`s, not `Val`s**.

**1. `Exp` gains a default `evalRef`.** An arbitrary expression has no home of
its own, so it gets a fresh cell:

```python
Exp:import
%%%
from ValRef import ValRef
%%%

Exp
%%%
def evalRef(self, env):
    return ValRef(self.eval(env))
%%%
```

Java's existing `Exp` block gains the same method beside its abstract `eval`,
and needs no import (same-directory, package-less). JavaScript needs
`Exp:import` with `const { ValRef } = require('./ValRef');`.

**2. `VarExp` overrides it.** This single method *is* call-by-reference — a
bare variable passes its own binding's `Ref` rather than a copy:

```python
def evalRef(self, env):
    return env.applyEnvRef(self.symbol.lexeme)
```

**3. `Rands` gains `evalRandsRef`.** `evalRands` stays exactly as it is;
primitives still take `Val`s, and only procedure application switches to `Ref`s:

```python
def evalRandsRef(self, env):
    return [e.evalRef(env) for e in self.expList]
```

**4. `AppExp.eval` calls it** — `self.rands.evalRandsRef(env)` in place of
`evalRands(env)`. `PrimappExp.eval` is untouched.

**5. `Val.apply` and `ProcVal.apply` take a list of `Ref`s.** `ProcVal` no
longer wraps anything, because its caller already did:

```python
def apply(self, args, env):
    if len(self.formals.symbolList) != len(args):
        raise LanguageError("formals/args number mismatch")
    bindings = Bindings(self.formals.symbolList, args)
    nenv = self.env.extendEnvRef(bindings)
    return self.body.eval(nenv)
```

Deleting SET's `refList = Ref.valsToRefs(args)` line is the whole of the
SET→REF behavioral change, exactly as SET's design predicted ("those fresh
`ValRef`s are the single line REF changes to get `4`").

**Imports.** `Ref` becomes unused in `ProcVal` and its import comes out in
Python (`from Ref import Ref`) and JavaScript (`const { Ref } =
require('./Ref');`) — verified by re-running the suite with the imports removed,
not assumed. `Ref.valsToRefs` itself **stays on `Ref`**: `LetDecls.addBindings`
still calls it. Java needs no import changes.

### What does not change

`Define`, `Eval`, `LitExp`, `IfExp`, `PrimappExp`, `LetExp`, `LetrecExp`,
`LetDecls` (both `addBindings` and `addLetrecBindings`), `ProcExp`, `Proc`,
`Formals`, `SeqExp`, `SetExp`, `Rands.evalRands`, all seven `Prim` subclasses,
and the bodies of `Val`, `IntVal`, `Ref`, and `ValRef`.

Java's `Prim.apply(Val [] va)` and `Val.toArray` are inherited from SET's
convergence decision and need no further work — `PrimappExp` still builds a
`List<Val>` via `evalRands`, so the array shape is unaffected by REF's switch
to `Ref`s in `AppExp`. **No V-series retro-fix in this phase**, unlike SET's.

### `apply` keeps its `Env` parameter

Carried forward from SET's convergence decision, as `apply(refList, env)`. The
parameter is read by nothing: `ProcVal` uses the environment it captured at
definition time. **It must not be removed as dead code.** It is the seam for a
homework assignment in which students reimplement `proc` with dynamic scoping,
resolving free variables in the *calling* environment — the one passed in. With
the parameter in place that assignment is a small edit inside `ProcVal.apply`;
without it, it is a signature change rippling through every call site.

## Tests

`src/REF/tests/<case>/`, each case a shared `REF.input` + `REF.expected` (all
three targets must produce identical output) plus one `REFtest.bats` with three
`@test` blocks, one per target directory, driven by `plcc-rep` — the same shape
V3–V6 and SET use.

Four cases, each specific to REF's own delta. Precedent is that a language
tests what it adds and does not re-ship its predecessor's suite — V4 does not
re-ship V3's `let/`, V5 does not re-ship V4's `proc/`. For REF that means
call-by-reference, not `set`, which SET's five cases already cover.

**Every expected output below was measured against all three targets**, not
predicted:

- **`formal-is-a-ref/`** — `let x=3 p=proc(t) set t=add1(t) in {.p(x); x}`.
  `set` on a formal reaches the caller's variable. REF's signature
  demonstration. → `4`
- **`nonvar-arg-is-a-copy/`** — the same program with `.p(+(x,0))`. A
  non-variable operand still gets a fresh cell, so the caller is untouched. The
  only case that exercises the `Exp.evalRef` default. → `3`
- **`alias-two-formals/`** — `let x=1 f=proc(a,b) {set a=9; b} in {.f(x,x); x}`.
  Two formals aliasing one binding, so a write through `a` is visible through
  `b`. Impossible under SET. → `9`
- **`captured-ref/`** — `define x=0` / `define g=proc(t) proc() set t=add1(t)` /
  `define h=.g(x)` / `.h()` / `.h()` / `x`. A closure holding the *caller's*
  ref, through the persistent top-level environment. → `x` `g` `h` `1` `2` `2`

Together these cover both `evalRef` paths (the `VarExp` override and the `Exp`
default), aliasing, and a ref escaping into a closure that outlives the call.

`formal-is-a-ref/` is deliberately the same program SET ships as
`formal-is-a-copy/`, where the expected file reads `3`. Shipping it in both
languages makes the SET→REF contrast — the entire point of REF — a one-file
diff rather than a claim in prose. It should not be dropped from either
language as redundant, and the two directory names differ on purpose: each
names the behavior of the language it lives in.

REF's existing single test, `src/REF/tests/let/`, **is**
`nonvar-arg-is-a-copy/` — the same program, ported off the old `plccmk`/`rep`
invocation and renamed for what it actually tests. It is not dropped and not
duplicated.

Value cases only: no error-path test for the duplicate-identifier check or the
unbound-variable path, both of which the spike confirms still work. This keeps
the one-shared-expected model clean, the same call V3–V6 and SET made.

Magnitudes and recursion depths stay small, clear of the 32-bit Java `IntVal`
overflow of issue [#16](../issues/016-cross-target-integer-divergence.md) and
the Python recursion ceiling of issue
[#19](../issues/019-python-recursion-ceiling.md).

## Example Programs (`src/REF/Prog/`)

REF's example programs are spread across three places today: `Prog/{double,
factory, xx}`, a `Stuff/{counter1..5, factory}` directory no other language
has, and a loose top-level `oe`. They consolidate into `Prog/`:

- **`Stuff/` folds into `Prog/`** and is removed. REF is the only one of the
  fourteen kept languages with a `Stuff/` directory, and its contents are
  example programs like any other.
- **`Stuff/factory` is dropped** — byte-identical to `Prog/factory`.
- **`oe` moves into `Prog/`**, matching V4, OBJ, and TYPE1, which all keep
  theirs there.
- **`oe`'s syntax error is fixed.** As shipped it has an unbalanced `{` on the
  `odd?` line and does not parse (`error: expected 'RBRACE', got 'DEFINE'`).
  Removing the stray brace makes it run: `.odd?(5)` → `1`, `.even?(5)` → `0`.
  This is the same repair V4's phase made to its own `Prog/oe`.
- **`counter1` and `counter3` are left exactly as written.** `counter1`
  evaluates to `1, 1, 1` because it re-`let`s `x` on every call, and `counter3`
  does not parse at all (`define` inside `let … in` is not a `<Program>`
  alternative). Both read as deliberate "here is what does not work" steps in a
  five-program progression, not as bit-rot. Repairing them would destroy the
  lesson.

All nine resulting programs are run against all three targets rather than
assumed to still work — the V4 precedent, and the one SET followed for
`Prog/g`. `counter2`, `counter4`, and `counter5` give `1, 2, 3`; `double`,
`factory`, and `xx` run clean.

**Course-material note: `Prog/counter4` is a second SET/REF contrast**, already
on disk. It reads `define counter = let x=0 next=proc(t) set t=add1(t) in
proc() .next(x)` and gives `1, 2, 3` under REF; run against SET's shipped
`spec.plcc` it gives `1, 1, 1`, because `.next(x)` copies. Worth knowing before
it appears in a lecture as an ordinary counter.

## Bookkeeping (in the same commits as the work)

- File a REF issue with `bin/issues/new.bash <slug> feat` and add its roadmap
  entry in the same commit; close it with `bin/issues/close.bash` as the
  branch's final commit.
- **No `src/Env/` deletion this phase.** SET already removed the flat
  `src/Env/envRef` when it ported the directory.
- Delete the old flat old-PLCC files
  `src/REF/{grammar,code,prim,envRef,val,ref}` and the top-level `src/REF/oe`
  once the three targets pass. None collides with a new path (`src/REF/grammar`
  versus `src/REF/grammar.plcc`), so this deletion comes at the end — unlike
  SET's `envRef`, which had to go first.
- Log REF entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change: `evalRef` added to `Exp` and `VarExp`;
  `Rands.evalRandsRef`; `apply` taking `List<Ref>` rather than `List<Val>`; the
  `Stuff/` → `Prog/` consolidation with `Stuff/factory` dropped; the `oe` brace
  fix and move into `Prog/`; `counter3`'s parse error now coming from plcc-ng
  with a different message; and the `tests/let/` → `nonvar-arg-is-a-copy/`
  rename.
- The implementation plan lands under [dev-docs/plans/](../plans/) (via
  writing-plans).

### Expected test counts

Measured on this branch with a full `bin/test.bash` run at design time, counted
with `grep -c` over the whole run rather than derived from SET's numbers.

The suite today is **84 tests: 78 passing and 6 failing** — NAME, NEED, OBJ,
REF, TYPE0, and TYPE1, every failure a `plccmk: command not found` from a
language still on old PLCC.

After this phase: **95 tests** — 84, minus REF's 1 old test, plus 12 new
(4 cases × 3 targets) — **90 passing and 5 failing**, the same
`command not found` set minus REF.

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after. Unlike SET's phase there is no retro-fix touching
already-passing languages, so a V-prefixed or SET failure would be a genuine
regression rather than expected churn.

## Noted for Later Phases

**NAME is a one-method rewrite of REF, plus two wrinkles.** Diffing
`src/NAME/{code,val,ref}` against REF's confirms the delta is: `Exp.evalRef`
returns `new ThunkRef(this, env)` instead of `new ValRef(eval(env))`; `LitExp`
and `ProcExp` override it back to the `ValRef` form; `ThunkRef` is added to
`ref` as a new `Ref` subclass whose `deRef` evaluates its captured expression
and whose `setRef` throws. `VarExp.evalRef`, `Rands.evalRandsRef`, `AppExp`,
and the `apply(List<Ref>)` signatures are all inherited from REF unchanged.

The two wrinkles, neither of them new information but both now confirmed
against REF rather than SET:

- **NAME's `Define` prints nothing** — `// System.out.println(id);` is
  commented out, where SET, REF, and NEED all print the name. Under plcc-ng
  `_run()` must return a string, so NAME cannot port this literally. Already
  flagged by SET's design; unchanged by this phase.
- **NAME's `evalRandsRef` loop names its variable `e` where REF's names it
  `exp`.** Cosmetic, and REF's port should not chase it.

## Out of Scope

- NAME and NEED, and the `ThunkRef`/`ValRORef`/`ErrorPrim` work they add.
- TYPE0, TYPE1, and OBJ.
- Error-path and diagnostic tests.
- Repairing `Prog/counter1` and `Prog/counter3` (see
  [Example Programs](#example-programs-srcrefprog)).
- Issue [#16](../issues/016-cross-target-integer-divergence.md), issue
  [#19](../issues/019-python-recursion-ceiling.md), and issue
  [#22](../issues/022-plcc-rep-parses-each-source-independently.md) — all
  repo-wide and inherited.
- Any unification of the Env variants, or of the per-language
  `Val`/`IntVal`/`Prim`/`Ref` duplication — ruled out repo-wide by the
  overarching design.

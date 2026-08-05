# plcc-ng Migration — NAME Design

This is a focused design of record for the NAME phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [REF design](2026-08-04-plcc-ng-ref-design.md), whose grammar,
`envRef` reuse, and semantic classes NAME inherits almost entirely unchanged,
and through REF on the [SET design](2026-08-04-plcc-ng-set-design.md). This
document captures only the decisions and porting subtleties specific to NAME,
settled in brainstorming on 2026-08-05.

## Goal

Port NAME (`REF + call-by-name semantics`) to plcc-ng: one
`src/NAME/grammar.plcc` plus three target `spec.plcc`s (Python, Java,
JavaScript). The phase closes when all three targets pass their bats suite.

NAME is the third of Phase 3's four languages and the second in a row with a
**zero syntax delta**. Like REF it does only one job — there is no Env work,
because SET ported `envRef` on behalf of all four.

## Validated Mechanics

The complete NAME delta was spiked against the installed CLI in **all three
targets** before this document was written — REF's three shipped `spec.plcc`s
plus the four-part patch of [Semantics](#semantics--the-four-part-delta), run
under `plcc-rep`. This is why the document commits to decisions rather than
flagging risks, and why every expected output below is measured rather than
predicted.

All three targets produced **byte-identical** output on every program. The REF
column is measured too — the same inputs run against REF's own shipped
`spec.plcc`, not predicted from how call-by-value ought to behave. The NAME
column was measured in all three targets; the REF column in Python only, REF's
own phase having already established that its three targets agree:

| program | NAME | REF |
|---|---|---|
| `Prog/pppp` — `let x=1 f=proc(t,u) {set t=add1(t); u} in .f(x,+(x,5))` | `7` | `6` |
| `Prog/test` — `.q(set x=add1(x))` with the formal used seven times | `10` | `4` |
| `Prog/counter` — `.times4(let count=0 in proc() set count=add1(count))` | `1` | `4` |
| `Prog/divideByZero` — `let p=proc(t,u) t in .p(11,/(1,0))` | `11` | `attempt to divide by zero` |
| `Prog/jensen` | `while` `55` | infinite recursion |
| `Prog/looper` — `.g(5,3)` | `p` `g` `8` | infinite recursion |
| `Prog/sumsq` | `while` `385` | — |
| `Prog/countdown` | `while` `42` | — |
| `let p=proc(t) set t=9 in .p(+(1,1))` | `cannot modify a read-only expression` | `9` |
| `let f=proc(a,a) a in .f(1,2)` | `duplicate ID a in proc formals` | same |
| `let x=3 p=proc(t) set t=add1(t) in {.p(x); x}` | `4` | `4` |

The last two rows are recorded as evidence that inherited behavior survives the
port: the duplicate check still fires, and REF's signature case still gives `4`
because a bare variable operand is a `VarExp`, whose `evalRef` override NAME
does not touch. Neither becomes a test case.

The `Prog/counter` and `Prog/test` rows deserve a second look, because both
outputs *fall* relative to REF and read at first glance like a regression.
They are not. Under call-by-name the operand expression is re-evaluated on
every use, so `counter` rebuilds `let count=0 in proc() …` on each of the four
calls (giving `1`, not `4`), and `test` re-runs `set x=add1(x)` seven times
(giving `10`, not `4`). Both are the language working as designed.

REF's failure on `Prog/jensen` and `Prog/looper` is the sharpest evidence in
the table: these two programs do not merely produce a different answer under
call-by-value, they do not terminate. Call-by-name is what makes them programs
at all.

## Grammar

`src/NAME/grammar.plcc` is REF's file with its header comment changed:

```
# Language NAME
#   Language REF with call-by-name semantics
```

Nothing else differs. Confirmed by diffing the pre-migration flat
`src/REF/grammar` (recovered from git history) against `src/NAME/grammar`: the
two are byte-identical apart from those two comment lines. The `SYMBOL` token,
the camelCase `<Exp:testExp>`/`<Exp:trueExp>`/`<Exp:falseExp>` alt-names, the
`SET` token, `<Exp:SetExp>`, and all eleven `<Exp>` alternatives carry over
untouched.

**NAME gets its own copy rather than `%include`ing REF's**, for the reason REF
gave for not including SET's: a reader working through the NAME appendix should
find NAME's syntax in NAME's directory rather than following a cross-language
include, and the chain would break at NEED anyway, which adds an `ERROR` token
and an `ErrorPrim` production. The cost is 55 duplicated lines, paid once.

## The `envRef` Reuse

Each `spec.plcc` opens with `%include ../../Env/envRef/<target>/env.plcc`,
**unchanged**. There is no Env work in this phase, and no `src/Env/` deletion —
SET removed the flat `src/Env/envRef` when it ported the directory.

NAME's own pre-migration flat `src/NAME/envRef` already **is** the canonical
`void checkDuplicates` shape that Phase 3 ported (it is one of the five files
in the majority-shape row of the overarching design's table). Nothing about it
needs reconciling; it is deleted with the rest of NAME's old-PLCC sources and
nothing is carried forward from it.

This makes `envRef` the first Env variant reused with zero changes *twice* — by
REF and now by NAME — after `envRN` (V2) and `envVal` (V4–V6) each proved the
pattern once.

## Semantics — the four-part delta

Every REF semantic class is reused. The delta is confined to four places, all
of which follow from one fact: **an operand becomes a thunk, not a value.**

**1. `ThunkRef` is a new free-standing `Ref` subclass.** Its `deRef` evaluates
the captured expression in the captured environment *every time it is called* —
the absence of memoization here is precisely what separates NAME from NEED. Its
`setRef` throws, because an arbitrary expression is not an assignable location:

```python
ThunkRef
%%%
from Ref import Ref
from runtime.base import LanguageError


class ThunkRef(Ref):

    def __init__(self, exp, env):
        self.exp = exp
        self.env = env

    def deRef(self):
        return self.exp.eval(self.env)

    def setRef(self, v):
        raise LanguageError("cannot modify a read-only expression")

    def __str__(self):
        return "thunk"
%%%
```

Java's block is the same class with `import runtime.LanguageError;`.
JavaScript's needs `const { Ref } = require('./Ref');` and
`const { LanguageError } = require('./runtime/base');` — free-standing classes
get no auto-injected requires, so unlike a grammar-derived class it must
require `LanguageError` explicitly. It ends with
`module.exports = { ThunkRef };`.

The block goes **between `Ref` and `ValRef`**, matching the order of the
pre-migration flat `src/NAME/ref`. Block order in the spec has no effect on
generated code (each free class becomes its own file), so this is fidelity
rather than necessity.

**2. `Exp.evalRef` is rewritten.** This one method *is* call-by-name:

```python
Exp
%%%
def evalRef(self, env):
    return ThunkRef(self, env)
%%%
```

REF's design put `evalRef` on the generated base class in all three targets
specifically so that NAME would be this edit rather than a restructuring. That
holds: no prior phase had put code on a base class in Python or JavaScript, and
having done it once, NAME inherits the mechanism for free.

**3. `LitExp` and `ProcExp` override it back** to REF's `ValRef` form. There is
nothing to defer in a literal or a closure — both are already values:

```python
def evalRef(self, env):
    return ValRef(self.eval(env))
```

The old flat file carries the comment `// this covers all but a LitExp,
ProcExp, and VarExp` on `Exp.evalRef`; it ports across as-is, and is worth
keeping because it is the only place the three-way split is stated in one
sentence.

**4. Imports follow the class moves.** In Python and JavaScript, `Exp:import`
switches from `ValRef` to `ThunkRef`; `LitExp:import` gains `ValRef` alongside
its existing `IntVal`; and `ProcExp` gains a `ProcExp:import` block it did not
have under REF. Java needs no import changes at all (same-directory,
package-less classes). Omitting any one of the three Python/JS import blocks
produces a `NameError`/`ReferenceError` in that one generated file only — the
per-file import rule from the overarching design, unchanged.

### What does not change

`Define` (apart from its return value, below), `Eval`, `VarExp` — **including
its `evalRef` override**, which is what keeps a bare variable operand
call-by-reference — `IfExp`, `PrimappExp`, `LetExp`, `LetrecExp`, `LetDecls`
(both `addBindings` and `addLetrecBindings`), `Proc`, `Formals`, `SeqExp`,
`SetExp`, `AppExp`, `Rands` (both `evalRands` and `evalRandsRef`), all seven
`Prim` subclasses, and the bodies of `Val`, `IntVal`, `Ref`, `ValRef`, and
`ProcVal`.

Two of these are worth stating explicitly because a reader may expect them to
change and they do not:

- **`let` stays eager.** `LetDecls.addBindings` still evaluates each
  right-hand side to a `Val` and wraps it in a `ValRef`. Call-by-name is a rule
  about *operands*, not about every binding form, and the pre-migration NAME
  behaves this way. Making `let` lazy would be a language change, not a port.
- **`Rands.evalRandsRef` is inherited verbatim from REF.** REF's design noted
  that the flat NAME file spells its loop variable `e` where REF's spells it
  `exp`; REF's port renders both as a list comprehension over `e`, so the
  cosmetic difference dissolved and there is nothing to chase.

### `apply` keeps its `Env` parameter

Carried forward from SET's convergence decision, as `apply(args, env)` over a
list of `Ref`s. The parameter is read by nothing: `ProcVal` uses the
environment it captured at definition time. **It must not be removed as dead
code.** It is the seam for a homework assignment in which students reimplement
`proc` with dynamic scoping, resolving free variables in the *calling*
environment — the one passed in. With the parameter in place that assignment is
a small edit inside `ProcVal.apply`; without it, it is a signature change
rippling through every call site.

The pre-migration flat `src/NAME/val` declares `apply(List<Ref> refList)` with
no `Env`, and its `ProcVal.apply` has no formals/args count check. Neither
absence carries forward: the ported shape is REF's, already converged across
SET and REF, and the count check produces
`formals/args number mismatch` in all three targets.

### `Define` returns the defined name

`src/NAME/code` has `// System.out.println(id);` **commented out** — the only
`Define` in the repository that suppresses it. Among the still-unmigrated
languages, `grep -n "System.out.println(id)" src/*/code` matches NEED and OBJ
uncommented and NAME commented; SET and REF, whose flat files are gone, both
`return s` in their shipped `spec.plcc`s. Under plcc-ng `_run()` must return a
string, so "print nothing" is not available: the closest literal port,
`return ""`, still emits a line — measured in Python, it prints a leading
blank line rather than silence.

**Decision: `return s`, matching the other four.** The commented-out line reads
as a debugging leftover rather than a deliberate design choice — it is
commented, not deleted, and every neighbor prints — and keeping Phase 3's four
languages uniform means a SET → REF → NAME → NEED diff is pure semantics
rather than semantics plus an output convention. The visible consequence is
that `jensen`, `sumsq`, `countdown`, and `looper` now print the defined names
before their results; that is logged in
[course-material-impact.md](../course-material-impact.md), not smoothed over.

## Tests

`src/NAME/tests/<case>/`, each case a shared `NAME.input` + `NAME.expected`
(all three targets must produce identical output) plus one `NAMEtest.bats` with
three `@test` blocks, one per target directory, driven by `plcc-rep` — the same
shape V3–V6, SET, and REF use.

Five cases, each specific to NAME's own delta. Precedent is that a language
tests what it adds and does not re-ship its predecessor's suite. For NAME that
means laziness and re-evaluation, not `set` or aliasing, which SET's and REF's
suites already cover.

**Every expected output below was measured against all three targets**, not
predicted:

- **`operand-evaluated-at-use/`** — `let x=1 f=proc(t,u) {set t=add1(t); u} in
  .f(x,+(x,5))`. `u` is a thunk, so `+(x,5)` is evaluated *after* `set t` has
  bumped `x`. NAME's signature demonstration. → `7` (REF: `6`)
- **`thunk-reevaluated-per-use/`** — `let x=3 p=proc(t) {t;t;t;t;t;t;t} in let
  q=proc(u) .p(u) in .q(set x=add1(x))`. The thunk is forced seven times and
  re-runs its side effect each time. The one case that pins the *absence* of
  memoization, and therefore the NAME↔NEED discriminator. → `10` (REF: `4`)
- **`unused-arg-not-evaluated/`** — `let p=proc(t,u) t in .p(11,/(1,0))`. An
  operand that is never used is never forced, so the division never happens.
  The other half of laziness: not just *when* an operand is evaluated but
  *whether*. → `11` (REF: `attempt to divide by zero`)
- **`jensen-device/`** — `Prog/jensen`. A `while` loop built out of nothing but
  call-by-name: `test?` and `do` are thunks re-forced on each iteration of a
  `letrec` loop, over the persistent top-level environment. The course
  centerpiece. → `while` `55` (REF: does not terminate)
- **`by-name-terminates/`** — `Prog/looper`, `define p = proc(x,y,z) if x then
  z else y` / `define g = proc(t,u) .p(t,u,.g(sub1(t),add1(u)))` / `.g(5,3)`.
  The recursive third operand is never forced once `x` reaches zero, so the
  program terminates where call-by-value cannot. → `p` `g` `8` (REF: does not
  terminate)

`operand-evaluated-at-use/` **is** NAME's existing `src/NAME/tests/let-proc/` —
the same program, ported off the old `plccmk`/`rep -n` invocation and renamed
for what it actually tests. It is not dropped and not duplicated.

`jensen-device/` and `by-name-terminates/` overlap in what they prove — both
turn on an operand that is not forced — and are both kept anyway. They are the
two programs in the suite that *do not terminate* under call-by-value, which
makes them the strongest evidence the port is correct, and both are course
material already sitting in `Prog/`.

Value cases only: no test for `cannot modify a read-only expression` (the
`ThunkRef.setRef` path) or for the duplicate-identifier check, both of which
the spike confirms work in all three targets. This keeps the one-shared-expected
model clean, the same call V3–V6, SET, and REF made.

Magnitudes and recursion depths stay small, clear of the 32-bit Java `IntVal`
overflow of issue [#16](../issues/016-cross-target-integer-divergence.md).
`jensen-device/` is the deepest case at ten iterations; `Prog/countdown`, at a
hundred, was run in all three targets during the spike and clears the Python
recursion ceiling of issue [#19](../issues/019-python-recursion-ceiling.md)
with room.

## Example Programs (`src/NAME/Prog/`)

**Nothing to do.** Unlike REF, NAME has no `Stuff/` directory, no loose
top-level program, and no file with a syntax error. All eight of
`Prog/{countdown, counter, divideByZero, jensen, looper, pppp, sumsq, test}`
are already in `Prog/` and all eight run clean in all three targets — run, per
the V4 precedent, rather than assumed still to work.

Two results are recorded here so that a later reader does not "fix" them:
`Prog/counter` gives `1` and `Prog/test` gives `10`, both *lower* and *higher*
respectively than REF's `4`, and both correct — see
[Validated Mechanics](#validated-mechanics).

## Bookkeeping (in the same commits as the work)

- File a NAME issue with `bin/issues/new.bash migrate-name-to-plcc-ng feat` and
  add its roadmap entry in the same commit; close it with
  `bin/issues/close.bash` as the branch's final commit.
- **No `src/Env/` work this phase** — no port, no deletion.
- Delete the old flat old-PLCC files
  `src/NAME/{grammar,code,prim,envRef,val,ref}` once the three targets pass.
  None collides with a new path (`src/NAME/grammar` versus
  `src/NAME/grammar.plcc`), so this deletion comes at the end — the REF
  ordering, not SET's.
- Log NAME entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change: the `VAR` → `SYMBOL` token rename and
  `var` → `symbol` field rename; `$run()` → `_run()` returning a string instead
  of printing; `Define` now printing the defined name where pre-migration NAME
  printed nothing; `ThunkRef` as a new `Ref` subclass; `Exp.evalRef` returning
  a `ThunkRef` with `LitExp` and `ProcExp` overriding back to `ValRef`; `apply`
  taking a `List<Ref>` and an `Env`; the `tests/let-proc/` →
  `tests/operand-evaluated-at-use/` rename; and the NAME-versus-REF contrast
  table from [Validated Mechanics](#validated-mechanics), which is lecture
  material in its own right.
- The implementation plan lands under [dev-docs/plans/](../plans/) (via
  writing-plans).

### Expected test counts

Measured on this branch with a full `bin/test.bash` run at design time, counted
with `grep -c` over the whole run rather than derived from REF's numbers.

The suite today is **105 tests: 100 passing and 5 failing** — NAME, NEED, OBJ,
TYPE0, and TYPE1, every failure a `plccmk: command not found` from a language
still on old PLCC.

After this phase: **119 tests** — 105, minus NAME's 1 old test, plus 15
(5 cases × 3 targets) — **115 passing and 4 failing**, the same
`command not found` set minus NAME.

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after. As in REF's phase there is no retro-fix touching
already-passing languages, so a V-prefixed, SET, or REF failure would be a
genuine regression rather than expected churn.

## Noted for Later Phases

**NEED is NAME with memoization.** The two languages differ in exactly the
behavior `thunk-reevaluated-per-use/` pins, which makes that case NEED's
starting point:

- **NEED should ship the mirror case** — the same program under a name
  describing NEED's answer (the thunk is forced once and its value cached),
  expecting `4` where NAME expects `10`. That makes the NAME → NEED contrast a
  one-file diff rather than a claim in prose, exactly as REF's
  `formal-is-a-ref/` mirrors SET's `formal-is-a-copy/`. Neither language should
  drop its copy as redundant.
- **`Prog/counter` is a second such pair, already on disk** — `1` under NAME,
  because the operand `let count=0 in proc() set count=add1(count)` is rebuilt
  on every call; `4` under NEED, once it is built only once. Worth knowing
  before it appears in a lecture as an ordinary counter.
- **NEED's `Define` already prints the name**, so this phase's `_run()`-must-
  return-a-string question does not recur there.

## Out of Scope

- NEED, and the `ValRORef`/`ErrorPrim` work it adds.
- TYPE0, TYPE1, and OBJ.
- Error-path and diagnostic tests, including the `ThunkRef.setRef` throw.
- Making `let` lazy, or any other extension of call-by-name beyond operands —
  a language change, not a port.
- Issue [#16](../issues/016-cross-target-integer-divergence.md), issue
  [#19](../issues/019-python-recursion-ceiling.md), and issue
  [#22](../issues/022-plcc-rep-parses-each-source-independently.md) — all
  repo-wide and inherited.
- Any unification of the Env variants, or of the per-language
  `Val`/`IntVal`/`Prim`/`Ref` duplication — ruled out repo-wide by the
  overarching design.

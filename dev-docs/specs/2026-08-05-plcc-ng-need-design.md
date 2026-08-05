# plcc-ng Migration — NEED Design

This is a focused design of record for the NEED phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [NAME design](2026-08-05-plcc-ng-name-design.md), whose grammar,
`envRef` reuse, and semantic classes NEED inherits almost entirely unchanged,
and through NAME on the [REF](2026-08-04-plcc-ng-ref-design.md) and
[SET](2026-08-04-plcc-ng-set-design.md) designs. This document captures only the
decisions and porting subtleties specific to NEED, settled in brainstorming on
2026-08-05.

## Goal

Port NEED (`NAME + memoization`) to plcc-ng: one `src/NEED/grammar.plcc` plus
three target `spec.plcc`s (Python, Java, JavaScript). The phase closes when all
three targets pass their bats suite.

NEED is the last of Phase 3's four languages, and the only one of the four with
a **syntax delta**: it adds an `ERROR` token and an `ErrorPrim` production. Like
REF and NAME it does no Env work — SET ported `envRef` on behalf of all four.

## Validated Mechanics

The complete NEED delta was spiked against the installed CLI in **all three
targets** before this document was written — NAME's three shipped `spec.plcc`s
plus the three-part patch of [Semantics](#semantics--the-three-part-delta), run
under `plcc-rep`. This is why the document commits to decisions rather than
flagging risks, and why every expected output below is measured rather than
predicted.

All three targets produced **byte-identical** output on every program. The NAME
column is measured too — the same inputs run against NAME's own shipped
`spec.plcc`, not predicted from how call-by-need ought to differ:

| program | NEED | NAME |
|---|---|---|
| `Prog/test` — `.q(set x=add1(x))` with the formal used seven times | `4` | `10` |
| `Prog/counter` — `.times4(let count=0 in proc() set count=add1(count))` | `4` | `1` |
| `let p = proc(t,u) t in .p(11,error())` | `11` | parse error — no `ERROR` token |
| `let p = proc(t) set t=9 in .p(11)` | `cannot modify a read-only reference` | `9` |
| `let p = proc(t) set t=9 in .p(proc() 1)` | `cannot modify a read-only reference` | `9` |
| `let x=1 p=proc(t) set t=9 in .p(+(x,1))` | `cannot modify a read-only expression` | same |
| `Prog/jensen`, `Prog/sumsq`, `Prog/countdown` (NAME's) | **stack exhaustion** | `55` / `385` / `42` |
| `Prog/natno`, `Prog/seq` | `0` `1` `2` `100` | same |
| `Prog/nn` | `0` `1` `2` `1000` `1000` (Java/JS only) | same, same targets |
| `Prog/fib` | `55` | same |
| `Prog/squares` | `10000` | same |
| `Prog/looper` — `.g(5,3)` | `p` `g` `8` | same |
| `Prog/pppp` (NAME's) | `7` | `7` |
| `let x=3 p=proc(t) set t=add1(t) in {.p(x); x}` | `4` | `4` |
| `let f=proc(a,a) a in .f(1,2)` | `duplicate ID a in proc formals` | same |
| `let f=proc(a) a in .f(1,2)` | `formals/args number mismatch` | same |

Program outputs above omit the leading `define`-name lines for brevity where the
program has top-level `define`s; the test cases below give the full expected
text.

Three rows deserve a second look.

**`Prog/test` and `Prog/counter` are the memoization discriminators**, and they
move in opposite directions. `test` re-runs `set x=add1(x)` seven times under
NAME (`10`) but forces it once under NEED (`4`). `counter` rebuilds
`let count=0 in proc() …` on each of four calls under NAME (`1`) but builds it
once under NEED (`4`). Neither is a regression; each is its language working as
designed.

**The Jensen device does not terminate under NEED** — see
[The Jensen Device Diverges](#the-jensen-device-diverges).

**The streams are not discriminators.** `natno`, `seq`, `nn`, `fib`, and
`squares` behave identically under NAME and NEED, and at the same speed. This
was measured, not assumed, and it is worth recording because it contradicts the
intuition the programs invite: `nth` walks each level of the list exactly once,
so no thunk is ever forced twice and memoization has nothing to save. Under both
languages a `pair` closure is a `ProcExp`, whose `evalRef` returns an eagerly
built value rather than a thunk, which keeps rebuilding one level cheap. NEED's
advantage over NAME appears when the *same* thunk is forced repeatedly — which
is `Prog/test` and `Prog/counter`, not the streams.

## Grammar

`src/NEED/grammar.plcc` is NAME's file with three edits:

1. The header comment becomes:

   ```
   # Language NEED
   #   Language NAME with call-by-need instead of call-by-name semantics
   ```

2. `token ERROR 'error'` is added, after `token SET 'set'` and before
   `token SYMBOL`. Position matters only in that every keyword must precede
   `SYMBOL`, whose pattern would otherwise swallow it.

3. `<Prim:ErrorPrim> ::= ERROR` is added after `<Prim:ZeropPrim> ::= ZEROP`.

Nothing else differs. Confirmed by diffing the pre-migration flat
`src/NAME/grammar` (recovered from git history) against `src/NEED/grammar`: the
two differ only in those three places. The `SYMBOL` token, the camelCase
`<Exp:testExp>`/`<Exp:trueExp>`/`<Exp:falseExp>` alt-names, `<Exp:SetExp>`, and
all eleven `<Exp>` alternatives carry over untouched.

**NEED gets its own copy rather than `%include`ing NAME's**, for the reason REF
and NAME each gave in turn: a reader working through the NEED appendix should
find NEED's syntax in NEED's directory rather than following a cross-language
include. Here the argument is stronger than it was for NAME, since NEED's
grammar genuinely differs — an `%include` of NAME's would have to be patched
rather than merely included.

## The `envRef` Reuse

Each `spec.plcc` opens with `%include ../../Env/envRef/<target>/env.plcc`,
**unchanged**. There is no Env work in this phase, and no `src/Env/` deletion —
SET removed the flat `src/Env/envRef` when it ported the directory.

NEED's own pre-migration flat `src/NEED/envRef` is **byte-identical** to NAME's,
which is to say it already is the canonical `void checkDuplicates` shape Phase 3
ported (both are in the majority-shape row of the overarching design's table).
Nothing about it needs reconciling; it is deleted with the rest of NEED's
old-PLCC sources and nothing is carried forward from it.

This makes `envRef` the first Env variant reused with zero changes three times —
by REF, NAME, and now NEED.

## Semantics — the three-part delta

Every NAME semantic class is reused. The delta is confined to three places, two
of which follow from one fact: **a thunk is forced at most once and caches its
value.**

### 1. `ThunkRef` memoizes

A `val` field initialized to null, and a `deRef` that computes it on first call
and returns the cache thereafter:

```python
ThunkRef
%%%
from Ref import Ref
from runtime.base import LanguageError


class ThunkRef(Ref):

    def __init__(self, exp, env):
        self.exp = exp
        self.env = env
        self.val = None  # memoized

    # implements call-by-need:
    # evaluate the expression, if needed, and memoize the result
    def deRef(self):
        if self.val is None:
            self.val = self.exp.eval(self.env)
        return self.val

    def setRef(self, v):
        raise LanguageError("cannot modify a read-only expression")

    def __str__(self):
        return "thunk"
%%%
```

Java is the same class with `public Val val;` and `if (val == null)`;
JavaScript with `this.val = null;` and `if (this.val === null)`.

**The null sentinel is kept in all three targets**, rather than replaced by a
`forced` boolean flag. The flag would be the more defensive design in a language
where a computation can legitimately produce null, but no `Val` in this
repository ever is, and the standing structural-fidelity rule is that the three
targets mirror the Java reference shape. A reader comparing `ThunkRef` across
the three appendices should see one algorithm, not two.

`setRef` and `__str__` are unchanged from NAME.

### 2. `ValRORef` is a new free-standing `Ref` subclass

It extends `ValRef` and overrides `setRef` to throw:

```python
# read-only value
ValRORef
%%%
from ValRef import ValRef
from runtime.base import LanguageError


class ValRORef(ValRef):

    def setRef(self, v):
        raise LanguageError("cannot modify a read-only reference")
%%%
```

Java's block is the same class with `import runtime.LanguageError;`.
JavaScript's needs `const { ValRef } = require('./ValRef');` and
`const { LanguageError } = require('./runtime/base');` — free-standing classes
get no auto-injected requires — and ends with `module.exports = { ValRORef };`.

The block goes **after `ValRef`**, matching the order of the pre-migration flat
`src/NEED/ref`. Block order in the spec has no effect on generated code, so this
is fidelity rather than necessity.

`LitExp.evalRef` and `ProcExp.evalRef` return `ValRORef` where NAME returned
`ValRef` — the only two places NAME wrapped an eagerly computed value. These are
exactly the operands with nothing to defer, and now nothing to assign into
either: a literal and a closure are values, not locations.

`VarExp.evalRef` is **untouched**, so a bare variable operand is still passed by
reference and still assignable — which is why
`let x=3 p=proc(t) set t=add1(t) in {.p(x); x}` still gives `4`.

### 3. `ErrorPrim`

The one grammar-derived addition:

```python
ErrorPrim
%%%
def __str__(self):
    return "error"

def apply(self, args):
    raise LanguageError("user-defined error")
%%%
```

**Only Python needs an `ErrorPrim:import`**, `from runtime.base import
LanguageError`, in the same form its sibling `Prim` subclasses already use.
Java needs none — same-directory, package-less classes, and its shipped spec
carries only two `:import` blocks in total, both for `java.util`. JavaScript
needs none either, for a different reason: `ErrorPrim` is grammar-derived, so
plcc-ng auto-injects
`const { Node, Token, LanguageError } = require('./runtime/base');` into its
generated file, and an explicit `:import` would redeclare `LanguageError` and
fail with `Identifier 'LanguageError' has already been declared`. This is the
rule from the overarching design's addendum, confirmed again here: among NEED's
additions only the free-standing `ValRORef` needs explicit requires in
JavaScript.

### Imports follow the class moves

In Python and JavaScript, `LitExp:import` and `ProcExp:import` each switch
`ValRef` → `ValRORef`. Java needs no import changes at all (same-directory,
package-less classes). Omitting either block produces a
`NameError`/`ReferenceError` in that one generated file only — the per-file
import rule from the overarching design, unchanged.

### What does not change

`Program`, `Define`, `Eval`, `Exp.evalRef` (still `ThunkRef(self, env)`),
`VarExp`, `IfExp`, `PrimappExp`, `LetExp`, `LetrecExp`, `LetDecls` (both
`addBindings` and `addLetrecBindings`), `Proc`, `Formals`, `SeqExp`, `SetExp`,
`AppExp`, `Rands` (both `evalRands` and `evalRandsRef`), the other seven `Prim`
subclasses, and the bodies of `Val`, `IntVal`, `Ref`, `ValRef`, and `ProcVal`.

Two are worth stating explicitly because a reader may expect them to change:

- **`let` stays eager.** `LetDecls.addBindings` still evaluates each right-hand
  side to a `Val` and wraps it in a `ValRef`. Call-by-need here is a rule about
  *operands*, not about every binding form, and the pre-migration NEED behaves
  this way. Making `let` lazy would be a language change, not a port.
- **`Define` needs no decision.** NEED's `System.out.println(id)` is already
  uncommented in `src/NEED/code` — NAME's was the repository's only commented
  one — so NEED's ported `Define` returns the defined name with no divergence
  from the shape NAME settled on. The `_run()`-must-return-a-string question
  that NAME had to resolve does not recur.

### `apply` keeps its `Env` parameter

Carried forward from SET's convergence decision, as `apply(args, env)` over a
list of `Ref`s. The parameter is read by nothing: `ProcVal` uses the environment
it captured at definition time. **It must not be removed as dead code.** It is
the seam for a homework assignment in which students reimplement `proc` with
dynamic scoping, resolving free variables in the *calling* environment — the one
passed in. With the parameter in place that assignment is a small edit inside
`ProcVal.apply`; without it, it is a signature change rippling through every
call site.

The pre-migration flat `src/NEED/val` is byte-identical to NAME's: it declares
`apply(List<Ref> refList)` with no `Env`, and its `ProcVal.apply` has no
formals/args count check. Neither absence carries forward. The ported shape is
NAME's — already converged across SET, REF, and NAME — and the count check
produces `formals/args number mismatch` in all three targets.

## The Jensen Device Diverges

NAME's centerpiece — a `while` loop built out of nothing but call-by-name —
**does not terminate under NEED**, in all three targets:

```
define while = proc(test?, do, ans)
  letrec loop = proc() if test? then {do ; .loop()} else ans
  in .loop()
```

`test?` and `do` arrive as thunks, and the loop depends on re-forcing them on
every iteration. Memoization removes exactly that: `test?` is evaluated once,
caches a true value, and every later iteration reads the cache. The loop
condition can never become false, and `.loop()` recurses until the stack is
exhausted — `StackOverflowError` in Java, `RangeError: Maximum call stack size
exceeded` in JavaScript, `RecursionError` in Python. Measured against all three
of NAME's shipped specs and all three of NEED's, on `Prog/jensen`, `Prog/sumsq`,
and `Prog/countdown`.

**This is correct call-by-need semantics, not a defect and not something to fix.**
It is the classic reason call-by-need and side effects do not mix, and it is the
sharpest NAME↔NEED contrast in the language pair: NAME gains the ability to
express a loop that call-by-value cannot, and NEED gives it back.

**Decision: document only.** Nothing is copied into `src/NEED/Prog/`, and no
test pins the divergence. Two reasons. The failure is an error path, excluded by
the value-cases-only rule every migrated language has followed. And its output
differs per target by construction — three different exception names — so it
could not share one `NEED.expected` file even if the rule allowed it.

The contrast is recorded in
[course-material-impact.md](../course-material-impact.md), where an instructor
comparing the NAME and NEED appendices will find it.

## Tests

`src/NEED/tests/<case>/`, each case a shared `NEED.input` + `NEED.expected` (all
three targets must produce identical output) plus one `NEEDtest.bats` with three
`@test` blocks, one per target directory, driven by `plcc-rep` — the same shape
V3–V6, SET, REF, and NAME use.

Four cases. Precedent is that a language tests what it adds and does not
re-ship its predecessor's suite; for NEED that means memoization and
`ErrorPrim`, not laziness in general, which NAME's suite already covers.

**Every expected output below was measured against all three targets**, not
predicted, and `infinite-stream/`'s output is md5-identical across the three:

- **`thunk-forced-once/`** — `Prog/test`, `let x=3 p=proc(t) {t;t;t;t;t;t;t} in
  let q=proc(u) .p(u) in .q(set x=add1(x))`. The thunk is forced once and its
  value cached, so the side effect runs once. → `4` (NAME: `10`)
- **`memoized-across-calls/`** — `Prog/counter`, `let times4 = proc(f) {.f();
  .f(); .f(); .f()} in .times4(let count=0 in proc() set count=add1(count))`.
  The operand is built once, so all four calls share one counter. → `4`
  (NAME: `1`)
- **`unused-arg-not-evaluated/`** — `let p = proc(t,u) t in .p(11,error())`. An
  operand that is never used is never forced, so `error()` never raises. → `11`
  (NAME: cannot parse it — no `ERROR` token)
- **`infinite-stream/`** — `Prog/natno`, the infinite list of natural numbers
  built from `pair`/`first`/`rest`/`nth`. NEED's course centerpiece and the only
  end-to-end coverage of the stream idiom. → `pair` `first` `rest` `nth` `seq`
  `natno` `0` `1` `2` `100`

`thunk-forced-once/` **is** NEED's existing `src/NEED/tests/let/` — ported off
the old `plccmk`/`rep -n` invocation, renamed for what it tests, and upgraded
from the three-use variant to the seven-use program already on disk at
`Prog/test`. The upgrade is deliberate: `Prog/test` is byte-identical to NAME's
`tests/thunk-reevaluated-per-use/NAME.input`, so the NAME↔NEED contrast becomes
a one-file diff — same input, different expected value — rather than a claim in
prose. This is the mirror case NAME's design asked NEED to ship. Neither
language drops its copy as redundant.

`memoized-across-calls/` requires copying `counter` from `src/NAME/Prog/` into
`src/NEED/Prog/`; it is the second NAME↔NEED mirror pair, and NAME's design
already flagged it as one.

**Not tested, deliberately.** `ValRORef`'s `cannot modify a read-only reference`
and `ErrorPrim`'s own `user-defined error` are both error paths, excluded by the
value-cases-only rule V3–V6, SET, REF, and NAME all followed. `ValRORef`
therefore ships with no direct test at all — stated plainly here rather than
left implied. The spike confirms both throws work in all three targets.
`unused-arg-not-evaluated/` does exercise `ErrorPrim`'s existence — the grammar
production, the token, and the generated class — since the program would not
parse without it.

Magnitudes and depths stay small: the largest value is `100`, well clear of the
32-bit Java `IntVal` overflow of issue
[#16](../issues/016-cross-target-integer-divergence.md), and the deepest
recursion is `infinite-stream/`'s hundred levels, which clears the Python
recursion ceiling of issue [#19](../issues/019-python-recursion-ceiling.md) with
room.

## Example Programs (`src/NEED/Prog/`)

All eight of `Prog/{fib, jeh, looper, natno, nn, seq, squares, test}` stay, plus
`counter` copied in from `src/NAME/Prog/` for `memoized-across-calls/`.

Eight of the nine run clean and byte-identical in all three targets — run, per
the V4 precedent, rather than assumed still to work. `jeh` produces only its
`define` names, its example applications all being commented out in the source;
that is how it stands pre-migration and is not a porting artifact.

**`Prog/nn` is the exception**, and it is kept as-is. It runs
`.nth(1000,natno)` twice, which succeeds in Java and JavaScript but dies in
Python with `RecursionError` — issue
[#19](../issues/019-python-recursion-ceiling.md), and **inherited, not
introduced**: the same file fails the same way against NAME's own shipped Python
spec. Two facts are logged rather than acted on:

- The Python gap is real and an instructor demonstrating `nn` in Python will hit
  it. Lowering the depth to something Python survives was considered and
  rejected — it would edit course material to paper over a known repo-wide issue
  and would empty the file's name of meaning.
- **The performance contrast `nn` seems to promise is not observable.** Calling
  `.nth(1000,natno)` twice is no faster under NEED than under NAME (measured in
  Java: both about a second, dominated by build time). See
  [Validated Mechanics](#validated-mechanics) for why. A reader who assumes `nn`
  demonstrates the value of memoization should know that it does not.

`nn`, `natno`, and `seq` are near-duplicates of one another, differing in
lookup depth and commentary. All three are kept: consolidating them would delete
existing course material during what is otherwise a port.

## Bookkeeping (in the same commits as the work)

- File a NEED issue with `bin/issues/new.bash migrate-need-to-plcc-ng feat` and
  add its roadmap entry in the same commit; close it with
  `bin/issues/close.bash` as the branch's final commit.
- **No `src/Env/` work this phase** — no port, no deletion.
- Delete the old flat old-PLCC files
  `src/NEED/{grammar,code,prim,envRef,val,ref}` once the three targets pass.
  None collides with a new path (`src/NEED/grammar` versus
  `src/NEED/grammar.plcc`), so this deletion comes at the end — the NAME and REF
  ordering, not SET's.
- Log NEED entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change:
  - the `VAR` → `SYMBOL` token rename and `var` → `symbol` field rename;
  - `$run()` → `_run()` returning a string instead of printing;
  - `ThunkRef` memoizing, with the null sentinel;
  - `ValRORef` and the `LitExp`/`ProcExp` switch, including the observable that
    `let p=proc(t) set t=9 in .p(11)` now raises
    `cannot modify a read-only reference` where NAME returns `9`;
  - the new `ERROR` token and `ErrorPrim`;
  - `apply` taking a `List<Ref>` **and** an `Env`, plus the new
    `formals/args number mismatch` arity check, neither of which pre-migration
    NEED had;
  - the `tests/let/` → `tests/thunk-forced-once/` rename and its upgrade to the
    seven-use program;
  - the `Prog/nn` Python gap and its non-observable performance premise;
  - **the Jensen device diverging under call-by-need**, with the reason and the
    note that it is correct semantics;
  - and the NEED-versus-NAME contrast table from
    [Validated Mechanics](#validated-mechanics), which is lecture material in
    its own right.
- The implementation plan lands under [dev-docs/plans/](../plans/) (via
  writing-plans).

### Expected test counts

Measured on this branch with a full `bin/test.bash` run at design time, counted
with `grep -c` over the whole run rather than derived from NAME's numbers.

The suite today is **119 tests: 115 passing and 4 failing** — `NEED let`,
`OBJ class`, `TYPE0 boolean`, and `TYPE1 proc-types`, every failure a
`plccmk: command not found` from a language still on old PLCC.

After this phase: **130 tests** — 119, minus NEED's 1 old test, plus 12
(4 cases × 3 targets) — **127 passing and 3 failing**, the same
`command not found` set minus NEED.

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after. As in NAME's phase there is no retro-fix touching
already-passing languages, so a V-prefixed, SET, REF, or NAME failure would be a
genuine regression rather than expected churn.

## Noted for Later Phases

- **Phase 3 closes here.** TYPE0, TYPE1 (Phase 4), and OBJ (Phase 5) all use
  `envRef`; after four consecutive zero-touch reuses the variant should be
  treated as settled, and any need to change it in Phase 4 or 5 read as a signal
  that something else is wrong.
- **OBJ's fork should be diffed against `src/Env/envRef/<target>/env.plcc`**,
  the ported canonical shape — not against any per-language flat file, all of
  which are gone from the working tree by the end of this phase and survive only
  in git history.
- **`ErrorPrim` is the first grammar production added by a Phase 3 language.**
  The pattern — one token, one `<Prim>` alternative, one class block, and no JS
  `:import` because the class is grammar-derived — is the template for TYPE0's
  and TYPE1's own additions.

## Out of Scope

- TYPE0, TYPE1, and OBJ.
- Error-path and diagnostic tests, including `ValRORef`'s throw and
  `ErrorPrim`'s `user-defined error`.
- Any test, `Prog/` file, or workaround for the Jensen-device divergence — see
  [The Jensen Device Diverges](#the-jensen-device-diverges).
- Making `let` lazy, or any other extension of call-by-need beyond operands — a
  language change, not a port.
- Issue [#16](../issues/016-cross-target-integer-divergence.md), issue
  [#19](../issues/019-python-recursion-ceiling.md), and issue
  [#22](../issues/022-plcc-rep-parses-each-source-independently.md) — all
  repo-wide and inherited.
- Any unification of the Env variants, or of the per-language
  `Val`/`IntVal`/`Prim`/`Ref` duplication — ruled out repo-wide by the
  overarching design.

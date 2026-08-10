# plcc-ng Migration — TYPE0 Design

This is a focused design of record for the TYPE0 phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [REF design](2026-08-04-plcc-ng-ref-design.md), and through REF
on the [SET design](2026-08-04-plcc-ng-set-design.md), whose `envRef` port TYPE0
reuses unchanged. This document captures only the decisions and porting
subtleties specific to TYPE0, settled in brainstorming on 2026-08-06.

## Goal

Port TYPE0 (`REF + type declarations, but no type checking`) to plcc-ng: one
`src/TYPE0/grammar.plcc` plus three target `spec.plcc`s (Python, Java,
JavaScript). The phase closes when all three targets pass their bats suite.

TYPE0 opens **Phase 4**. It is the first migrated language with a genuine
boolean type, and the first whose grammar carries syntax the evaluator never
reads.

## TYPE0 Descends From REF, Not From NEED

NEED is the most recently ported language, but TYPE0 does **not** build on it.
`src/TYPE0/code` uses eager `ValRef` operands with no `ThunkRef` and no
`ValRORef`: TYPE0 forks REF *before* the NAME/NEED laziness branch. Its own
header comment says so — "Language REF with type declarations (but no type
checking)" — and the code confirms it.

An implementer should therefore start from `src/REF/`'s three shipped
`spec.plcc`s and apply the delta below, **not** from NEED's. Copying NEED's
would silently import call-by-need semantics that TYPE0 does not have.

## Validated Mechanics

The complete TYPE0 delta was spiked against the installed CLI in **all three
targets** before this document was written — REF's three shipped `spec.plcc`s
plus the four-part patch of [Semantics](#semantics--a-four-part-delta-over-ref),
run under `plcc-rep`. This is why the document commits to decisions rather than
flagging risks, and why every expected output below is measured rather than
predicted.

All three targets produced **byte-identical** output on every program. The REF
column is measured too, against REF's own shipped specs, rather than predicted
from how an untyped language ought to behave:

| program | TYPE0 | REF |
|---|---|---|
| `<=?(3,3)` | `true` | parse error — no `LEP` token |
| `<?(1,2)` `>?(1,2)` `>=?(1,2)` `=?(2,2)` `<>?(1,2)` | `true` `false` `false` `true` `true` | parse error — no such tokens |
| `zero?(0)` / `zero?(1)` | `true` / `false` | `1` / `0` |
| `true` / `false` | `true` / `false` | parse error — no `TRUE`/`FALSE` token |
| `if true then 1 else 2` | `1` | parse error |
| `if 1 then 1 else 2` | `boolean expression expected` | `1` |
| `let f = proc(x:int):bool 5 in .f(3)` | `5` | parse error — no type syntax |
| `let g = proc(x:int):int true in .g(3)` | `true` | parse error |
| `let f = proc(x:int, g:[int,int=>bool]):bool .g(x,x) in .f(3, proc(a:int,b:int):bool <=?(a,b))` | `true` | parse error |
| `let p = proc():[=>int] proc():int 7 in .p()` | `proc` | parse error |
| `let x = 1 in { set x = 9 ; x }` | `9` | `9` |
| `letrec f = proc(n:int):int if zero?(n) then 1 else *(n, .f(sub1(n))) in .f(5)` | `120` | `120`, untyped |

Three findings deserve a second look.

### plcc-ng resolves tokens by longest match, not by declaration order

This was the phase's largest risk and it turned out to be a non-issue. TYPE0's
pre-migration lexical section declares `IN 'in'` **before** `INT 'int'`, and
`EQUALS '='` **before** `RARROW '=>'`. Under a first-match-wins scanner both
break: `int` would scan as `IN` followed by a stray `t`, and `=>` as `EQUALS`
followed by an unmatched `>`.

Measured against `plcc-scan` with exactly that declaration order:

```
-:1:1 INT 'int'
-:1:5 IN 'in'
-:1:8 EQUALS '='
-:1:10 RARROW '=>'
-:1:13 LTP '<?'
-:1:16 LEP '<=?'
-:1:20 SYMBOL 'intx'
```

Longest match wins, so **the pre-migration token order carries over unchanged**.
No reordering is needed, and none should be introduced: reordering to "fix" a
problem that does not exist would be an unexplained diff against the original
file, and a future reader would have no way to tell why.

The rule that keywords must still precede `SYMBOL` is unaffected — that one is
about `SYMBOL`'s pattern being *equally* long, not longer.

### The type grammar is LL(1)-clean as written

`<TypeExp>` is mutually recursive with `<TypeExps>` through `ProcTypeExp`, which
is a shape no previously migrated language has. It needed no factoring.
Confirmed with `plcc-parse` on a nested proc type, on empty `<Formals>`, and on
an empty `<TypeExps>` (`[=>int]`), all of which parse.

### `Formals` yields parallel `symbolList` and `typeExpList`

Adding `COLON <TypeExp>` to the `<Formals>` repeating rule gives the generated
class a second list alongside the first, in the same way `<LetDecls>`'s
`symbolList`/`expList` pair already does. `ProcVal.apply`'s existing
`formals.symbolList` keeps working with **no change at all**, and
`Formals:init`'s duplicate check likewise.

## Grammar — REF's File Plus a Delta

`src/TYPE0/grammar.plcc` is `src/REF/grammar.plcc` with eight edits:

1. The header comment becomes:

   ```
   # Language TYPE0
   #   Language REF with type declarations (but no type checking)
   ```

2. Fourteen new tokens, each in its pre-migration position and all before
   `token SYMBOL`:
   - six relational operators — `LTP '<\?'`, `LEP '<=\?'`, `GTP '>\?'`,
     `GEP '>=\?'`, `EQP '=\?'`, `NEP '<>\?'`;
   - four for type syntax — `LBRACK '\['`, `RBRACK '\]'`, `COLON ':'`,
     `RARROW '=>'`;
   - four keywords — `BOOL 'bool'`, `INT 'int'`, `TRUE 'true'`, `FALSE 'false'`.

3. `VAR` → `SYMBOL`, the standing repo-wide rename (`var` → `symbol`,
   `varList` → `symbolList`).

4. Five new type productions:

   ```
   <TypeExp:PrimTypeExp>   ::= <PrimType>
   <TypeExp:ProcTypeExp>   ::= LBRACK <TypeExps> RARROW <TypeExp> RBRACK
   <PrimType:BoolPrimType> ::= BOOL
   <PrimType:IntPrimType>  ::= INT
   <TypeExps>              **= <TypeExp> +COMMA
   ```

5. `<Proc>` gains a return-type annotation and `<Formals>` a per-formal one:

   ```
   <Proc>    ::= PROC LPAREN <Formals> RPAREN COLON <TypeExp> <Exp>
   <Formals> **= <SYMBOL> COLON <TypeExp> +COMMA
   ```

6. `<Exp:TrueExp> ::= TRUE` and `<Exp:FalseExp> ::= FALSE`, placed after
   `<Exp:LitExp>` as in the pre-migration file.

7. Six new `<Prim>` alternatives — `LTPrim`, `LEPrim`, `GTPrim`, `GEPrim`,
   `EQPrim`, `NEPrim` — after `ZeropPrim`.

8. **`BoolPrimtype` → `BoolPrimType`.** The pre-migration file spells this one
   alternative with a lowercase `t` while its sibling is `IntPrimType`; TYPE1's
   grammar already spells it `BoolPrimType`. Nothing in TYPE0's semantics
   references the name — the class gets no semantic block at all — so the fix
   costs a generated class name and removes a gratuitous TYPE0/TYPE1
   disagreement in a course that teaches the two back to back.

The camelCase `<Exp:testExp>`/`<Exp:trueExp>`/`<Exp:falseExp>` alt-names carry
over untouched; issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md)
was fixed in plcc-ng 2.0.0 and the lowercase workaround must not be
reintroduced.

**TYPE0 gets its own grammar file rather than `%include`ing REF's**, for the
reason every language since REF has given: a reader working through the TYPE0
appendix should find TYPE0's syntax in TYPE0's directory. Here the argument is
strongest yet — TYPE0's grammar genuinely differs from REF's in fourteen new
tokens, thirteen new productions, and two changed ones.

## The Type Nonterminals Carry No Semantics At All

`TypeExp`, `PrimTypeExp`, `ProcTypeExp`, `PrimType`, `BoolPrimType`,
`IntPrimType`, and `TypeExps` get **zero `%%%` blocks** in all three
`spec.plcc`s. They are generated, they are populated by the parser, and nothing
ever reads them. Confirmed working in Python, Java, and JavaScript: a
grammar-derived class with no semantic block needs no block, and no placeholder.

This is TYPE0's entire thesis stated structurally. Types are syntax the parser
accepts and the evaluator ignores, which is why
`let f = proc(x:int):bool 5 in .f(3)` returns `5` rather than complaining. That
is the feature, not a gap, and an implementer must not be tempted to add a
`toString` or a validity check "while we're here" — doing so would start
building TYPE1 inside TYPE0.

## The `envRef` Reuse

Each `spec.plcc` opens with `%include ../../Env/envRef/<target>/env.plcc`,
**unchanged**. There is no Env work in this phase and no `src/Env/` deletion —
SET removed the flat `src/Env/envRef` when it ported the directory.

TYPE0's own pre-migration flat `src/TYPE0/envRef` is already the canonical
`void checkDuplicates` shape Phase 3 ported (verified: it is in the majority-shape
row of the overarching design's table). Nothing about it needs reconciling; it is
deleted with the rest of TYPE0's old-PLCC sources and nothing is carried forward
from it.

This is `envRef`'s **fourth consecutive zero-touch reuse** — by REF, NAME, NEED,
and now TYPE0. NEED's design asked that the variant be treated as settled after
four, and that any need to change it in Phase 4 or 5 be read as a signal that
something else is wrong. TYPE0 needed no change, so that standard holds going
into OBJ.

## Semantics — A Four-Part Delta Over REF

Every REF semantic class is reused. The delta is confined to four places, all
four of which follow from one fact: **TYPE0 has a real boolean type, and REF
does not.** A fifth change, `LetDecls:init`, is unrelated to booleans and is
covered separately [below](#letdeclsinit-is-added).

### 1. `BoolVal` is a new free-standing `Val` subclass

```python
BoolVal
%%%
from Val import Val


class BoolVal(Val):

    def __init__(self, val):
        self.val = val

    def isTrue(self):
        return self.val

    def boolVal(self):
        return self

    def __str__(self):
        return "true" if self.val else "false"
%%%
```

Java is the same class with `public boolean val;` and
`public String toString() { return "" + val; }`; JavaScript with a
`constructor(val) { super(); this.val = val; }` and
`toString() { return String(this.val); }`.

**Python's `__str__` is the one place the three targets cannot share an idiom,
and it is the most likely thing in this phase to get subtly wrong.** Java's
`"" + val` and JavaScript's `String(this.val)` both produce lowercase `true` /
`false` natively. Python's `str(True)` produces `True`, so the explicit
conditional is load-bearing: without it Python alone prints capitalised booleans
and every one of the four test cases fails in that target only, on output text
rather than on logic.

The block goes **after `IntVal`**, matching the order of the pre-migration flat
`src/TYPE0/val`. Block order in the spec has no effect on generated code, so
this is fidelity rather than necessity.

### 2. Booleans become strict

Three coordinated changes to `Val` and `IntVal`:

- **`Val.isTrue()` throws** `boolean expression expected`, where REF's returns
  `true`.
- **`Val.boolVal()` is added** and throws `<self>: not a Bool`, mirroring the
  existing `intVal()`.
- **`IntVal` loses its `isTrue()` override** entirely, so an integer inherits
  the throwing one.

Together these make `if` reject anything that is not a `BoolVal`:
`if 1 then 1 else 2` raises `boolean expression expected` in TYPE0 where REF
returns `1`. This is pre-migration TYPE0's own behaviour, not a change
introduced by the port, but it is the sharpest REF↔TYPE0 contrast and belongs in
the course-material log.

### 3. `ZeropPrim` returns a boolean

`return BoolVal(i0 == 0)` replaces REF's `return IntVal(1 if i0 == 0 else 0)`,
and its `:import` switches `IntVal` → `BoolVal` in Python and JavaScript. This
is the only *existing* prim whose result type changes.

### 4. `TrueExp`, `FalseExp`, and six relational prims

`TrueExp` and `FalseExp` each `eval` to a `BoolVal` and stringify to `true` /
`false`. The six relational prims follow the shape of REF's existing binary
prims exactly — arity check, two `intVal().val` extractions, one comparison —
differing only in returning a `BoolVal`:

```python
LEPrim
%%%
def __str__(self):
    return "<=?"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return BoolVal(i0 <= i1)
%%%
```

Per-target notes, each confirmed live rather than inferred:

- **Java's prims take `Val [] va`, not a list.** REF's Java spec uses the array
  form (`va.length`, `va[0]`) while its Python and JavaScript specs use lists.
  The six new prims must follow their own target's existing shape, not the
  Python snippet above transliterated.
- **JavaScript's `EQPrim` and `NEPrim` use `===` and `!==`**, matching the
  strict-equality idiom REF's JavaScript spec already uses.
- **JavaScript `:import` blocks on the new grammar-derived classes name only
  `BoolVal`.** `TrueExp`, `FalseExp`, and all six prims are grammar-derived, so
  plcc-ng auto-injects
  `const { Node, Token, LanguageError } = require('./runtime/base');` into their
  generated files; naming `LanguageError` explicitly fails with
  `Identifier 'LanguageError' has already been declared`. Only the free-standing
  `BoolVal` needs explicit requires — `const { Val } = require('./Val');` and a
  closing `module.exports = { BoolVal };`.
- **Java needs no `:import` at all** for any part of the delta — same-directory,
  package-less classes.
- **Python needs a `:import` on every one of the eight new classes** plus the
  changed `ZeropPrim`, since the per-file import rule admits no file-wide
  import. Omitting one produces a `NameError` in that single generated file.

### `LetDecls:init` is added

Pre-migration TYPE0 has **no** `LetDecls:init`, so `let x = 1 x = 2 in x`
quietly returns `1`. It is the only file in the repository missing that check.
Every ported language with a `<LetDecls>` rule has it — all eight of them,
V3–V6, SET, REF, NAME, NEED (V0–V2 have no `let`) — and so do both still-unported
ones: `src/TYPE1/code:386-390` and `src/OBJ/code:485-489` carry byte-identical
calls.

The obvious hypothesis, that TYPE1 subsumes the check into type checking and
TYPE0's omission is a deliberate rung in the progression, was **checked and is
false**. TYPE1 keeps the plain parse-time
`Env.checkDuplicates(varList, " in let/letrec LHS identifiers")` verbatim; its
type machinery (`TypeEnv`, `addTypeBindings`, `evalType`) is separate and never
detects a duplicate left-hand-side identifier. TYPE0's omission is drift from an
older REF fork, not a property of the language.

So the port **adds it**, in REF's exact form:

```python
LetDecls:init
%%%
Env.checkDuplicates(self.symbolList, " in let/letrec LHS identifiers")
%%%
```

Observable change from pre-migration TYPE0: `let x = 1 x = 2 in x` raises
`duplicate ID x in let/letrec LHS identifiers` where it previously returned `1`.
Logged in [course-material-impact.md](../course-material-impact.md).

### `boolVal()` is kept although nothing in TYPE0 calls it

TYPE0 does no type checking, so `Val.boolVal()` and `BoolVal.boolVal()` are dead
code within TYPE0 itself.

They are **not** trimmed the way Phase 3 trimmed `checkDuplicates`'s dead
`Set<String>` return. That trim was correct because no caller anywhere in `src/`
used the value. This one is different: it has a confirmed consumer exactly one
phase out. `src/TYPE1/prim:247-282` calls `boolVal()` in `AndPrim`, `OrPrim`,
and `NotPrim`. Dropping it here only means TYPE1 re-adds it, against a `Val`
shape the two languages otherwise share.

The distinction is worth stating plainly because "drop the dead code" is the
lesson the reader carries out of Phase 3, and applying it by reflex here would
be wrong.

### `apply` keeps its `Env` parameter

Carried forward from SET's convergence decision, as `apply(args, env)` over a
list of `Ref`s. The parameter is read by nothing — `ProcVal` uses the
environment it captured at definition time — and **it must not be removed as
dead code.** It is the seam for a homework assignment in which students
reimplement `proc` with dynamic scoping, resolving free variables in the
*calling* environment. With the parameter in place that assignment is a small
edit inside `ProcVal.apply`; without it, a signature change rippling through
every call site.

The pre-migration flat `src/TYPE0/val` declares `apply(List<Ref> refList)` with
no `Env`, and its `ProcVal.apply` has no formals/args count check. Neither
absence carries forward; the ported shape is REF's, already converged across
SET, REF, NAME, and NEED, and the count check produces
`formals/args number mismatch` in all three targets.

### What does not change

`Program`, `Define`, `Eval`, `Exp.eval`/`Exp.evalRef`, `VarExp`, `IfExp`,
`PrimappExp`, `LetExp`, `LetrecExp`, `LetDecls`'s `addBindings` and
`addLetrecBindings`, `Proc`, `Formals:init`, `SeqExp`, `SetExp`, `AppExp`,
`Rands` (both `evalRands` and `evalRandsRef`), the seven inherited `Prim`
subclasses other than `ZeropPrim`, and the bodies of `IntVal`, `Ref`, `ValRef`,
and `ProcVal`.

`Val.toArray` is dropped, as it was in every migrated language before this one —
the three targets use their own list types.

## Tests

`src/TYPE0/tests/<case>/`, each case a shared `TYPE0.input` + `TYPE0.expected`
(all three targets must produce identical output) plus one `TYPE0test.bats` with
three `@test` blocks, one per target directory, driven by `plcc-rep` — the same
shape V3–V6, SET, REF, NAME, and NEED use.

Four cases. Precedent is that a language tests what it adds and does not re-ship
its predecessor's suite; for TYPE0 that means booleans and type syntax, not
call-by-reference, which REF's suite already covers.

**Every expected output below was measured against all three targets** and is
byte-identical across them:

- **`relational-prims/`** — all six relational operators plus `zero?` both ways:

  ```
  <?(1,2)      →  true
  <=?(3,3)     →  true
  >?(1,2)      →  false
  >=?(1,2)     →  false
  =?(2,2)      →  true
  <>?(1,2)     →  true
  zero?(0)     →  true
  zero?(1)     →  false
  ```

- **`boolean-literals/`** — `true`, `false`, and both driving an `if`:
  → `true` `false` `1` `2`

- **`type-annotations-ignored/`** — a nested proc type in a formal, then empty
  formals with an empty proc type:

  ```
  let f = proc(x:int, g:[int,int=>bool]):bool .g(x,x)
  in  .f(3, proc(a:int,b:int):bool <=?(a,b))     →  true

  let p = proc():[=>int] proc():int 7 in .p()    →  proc
  ```

  This is the only coverage of `ProcTypeExp`, `TypeExps`, the empty-`TypeExps`
  case, and the `Formals` `typeExpList` — none of which any semantic block
  reads, which is precisely why they need a test that proves they parse.

- **`declared-type-not-checked/`** — `proc(x:int):bool 5` and
  `proc(x:int):int true`: → `5` `true`. TYPE0's whole reason to exist, pinned as
  a value rather than left as prose.

`relational-prims/` **is** TYPE0's existing `src/TYPE0/tests/boolean/` — ported
off the old `plccmk`/`rep -n` invocation, renamed for what it tests, and widened
from the single `<=?(3,3)` program to all six operators. The old name said
"boolean" while testing one comparison; the new one says what it covers.

**Not tested, deliberately.** `boolean expression expected` (from strict
`isTrue`), `<self>: not a Bool` (from `boolVal`), and
`duplicate ID x in let/letrec LHS identifiers` (from the new `LetDecls:init`)
are all error paths, excluded by the value-cases-only rule V3–V6, SET, REF,
NAME, and NEED all followed. The spike confirms each throws identically in all
three targets.

Magnitudes and depths stay small: the largest value anywhere is `120`, far below
the 32-bit Java `IntVal` overflow of issue
[#16](../issues/016-cross-target-integer-divergence.md), and no case recurses
deeply enough to approach the Python ceiling of issue
[#19](../issues/019-python-recursion-ceiling.md).

## Example Programs — None

TYPE0 ships **no `Prog/` directory**, matching its pre-migration state. It is
the only kept language in Phase 3 and later without example programs, and that
gap is pre-existing. Test inputs live in their own `tests/<case>/TYPE0.input`
files, the way REF's do. The migration's job is to port, not to author new
course material.

One measured fact is recorded here because TYPE1's phase will want it:
**TYPE1's `Prog/compose` and `Prog/count` run unmodified under TYPE0**, byte-identically
across all three targets, while its `Prog/fact` and `Prog/oe` do not — both use
`declare`, which is TYPE1-only. TYPE0's grammar is a strict subset of TYPE1's.
Copying those two files into `src/TYPE0/Prog/` was considered and rejected: they
are TYPE1's course material, nothing in TYPE0 needs them, and the NEED precedent
for cross-language copying applied only because a test required the file.

## Bookkeeping (in the same commits as the work)

- File a TYPE0 issue with `bin/issues/new.bash migrate-type0-to-plcc-ng feat`
  and add its roadmap entry in the same commit; close it with
  `bin/issues/close.bash` as the branch's final commit.
- **No `src/Env/` work this phase** — no port, no deletion.
- Delete the old flat old-PLCC files
  `src/TYPE0/{grammar,code,prim,envRef,val,ref}` once the three targets pass.
  None collides with a new path (`src/TYPE0/grammar` versus
  `src/TYPE0/grammar.plcc`), so this deletion comes at the end — the REF, NAME,
  and NEED ordering, not SET's.
- Log TYPE0 entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change:
  - the `VAR` → `SYMBOL` token rename and `var` → `symbol` field rename;
  - `$run()` → `_run()` returning a string instead of printing;
  - the `BoolPrimtype` → `BoolPrimType` grammar-symbol rename;
  - the new `LetDecls:init`, with the observable that `let x = 1 x = 2 in x`
    now raises `duplicate ID x in let/letrec LHS identifiers` where it returned
    `1`;
  - `apply` taking a `List<Ref>` **and** an `Env`, plus the new
    `formals/args number mismatch` arity check, neither of which pre-migration
    TYPE0 had;
  - `Val.toArray` dropped;
  - the `tests/boolean/` → `tests/relational-prims/` rename and its widening to
    all six operators;
  - and the **REF↔TYPE0 contrast table** from
    [Validated Mechanics](#validated-mechanics), which is lecture material in
    its own right. Two rows carry the weight: `if` now requires a genuine
    boolean (`if 1 then …` errors where REF returns `1`), and `zero?` returns
    `true`/`false` where REF returns `1`/`0`. Those are the two places a REF
    program stops behaving the same under TYPE0.

### Expected test counts

The suite today is **141 tests: 138 passing and 3 failing** — `OBJ class`,
`TYPE0 boolean`, and `TYPE1 proc-types`, every failure a
`plccmk: command not found` from a language still on old PLCC.

After this phase: **152 tests** — 141, minus TYPE0's 1 old test, plus 12
(4 cases × 3 targets) — **150 passing and 2 failing**, the same
`command not found` set minus TYPE0.

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after. There is no retro-fix in this phase touching
already-passing languages, so a V-prefixed, SET, REF, NAME, or NEED failure
would be a genuine regression rather than expected churn.

A plain `bin/test.bash` run now completes unaided in one invocation.

> **Amended 2026-08-10.** This section originally read "**130 tests: 127
> passing and 3 failing**" for the baseline and "**141 tests** … **139
> passing and 2 failing**" after the phase, measured using the split-`TMPDIR`
> workaround from issue
> [#31](../issues/031-suite-exhausts-disk-and-reports-spurious-failure.md)
> and a claim that "a plain `bin/test.bash` run exhausts the disk on this
> container." Both premises expired: #31 landed on `main` and added
> `bin/bats-tmpdir.bash`, a teardown that empties each passing test's
> `BATS_TEST_TMPDIR`, so peak disk is now one test's footprint rather than
> the whole suite's, and `bin/test.bash` completes on its own. The plan
> ([`f0fc522`](../plans/2026-08-06-plcc-ng-phase4-type0.md)) was corrected
> for this at the time; this design document was not, and drifted. The trap
> worth flagging: the stale after-phase figure, 141, is exactly the
> *current* baseline, so a reader running an untouched tree against the old
> text would see 141 tests and read it as success. The load-bearing
> invariant — the `command not found` count dropping by exactly 1 — did not
> change and is unaffected by this correction.

## Noted for Later Phases

- **TYPE1 is `TYPE0 + declare + and/or/not + type checking`.** Diffing the
  pre-migration `src/TYPE0/grammar` against `src/TYPE1/grammar` gives the whole
  syntactic delta: a `DECLARE` token and `<program>:Declare` production, three
  boolean-operator tokens with their `<prim>` alternatives, and `%include`s of
  `tenv` and `type`. TYPE1's grammar already spells `BoolPrimType`, so this
  phase's typo fix removes a delta rather than adding one.
- **`boolVal()` is already in place for TYPE1's `AndPrim`/`OrPrim`/`NotPrim`** —
  see [above](#boolval-is-kept-although-nothing-in-type0-calls-it).
- **The type nonterminals are where TYPE1 hangs its semantics.** TYPE0 leaves
  `TypeExp`, `PrimType`, and `TypeExps` with no semantic blocks; TYPE1 adds
  `evalType`-style methods to exactly those classes. An implementer reading
  TYPE0's specs should understand the empty classes as a deliberate placeholder
  for that, not as an oversight.
- **`envRef` has now been reused unchanged four consecutive times.** OBJ is the
  last user, and its fork should be diffed against
  `src/Env/envRef/<target>/env.plcc`, the ported canonical shape — not against
  any per-language flat file, all of which are gone from the working tree and
  survive only in git history.

## Out of Scope

- TYPE1 and OBJ.
- **Any type checking whatsoever.** Validating that a declared type matches an
  expression's actual type, that a `ProcTypeExp`'s arity matches its formals, or
  that a `TypeExp` is well-formed is TYPE1's phase, and adding any of it here
  would erase the distinction the two languages exist to teach.
- Any `toString`, `equals`, or other method on the type nonterminals — see
  [above](#the-type-nonterminals-carry-no-semantics-at-all).
- Error-path and diagnostic tests, including strict `isTrue`'s
  `boolean expression expected`, `boolVal`'s `not a Bool`, and
  `LetDecls:init`'s duplicate-ID message.
- Any `Prog/` directory for TYPE0, including copying TYPE1's `compose` and
  `count` — see [above](#example-programs--none).
- Reordering the lexical section — longest match makes it unnecessary, see
  [above](#plcc-ng-resolves-tokens-by-longest-match-not-by-declaration-order).
- Issue [#16](../issues/016-cross-target-integer-divergence.md), issue
  [#19](../issues/019-python-recursion-ceiling.md), issue
  [#22](../issues/022-plcc-rep-parses-each-source-independently.md), and issue
  [#31](../issues/031-suite-exhausts-disk-and-reports-spurious-failure.md) — all
  repo-wide and inherited.
- Any unification of the Env variants, or of the per-language
  `Val`/`IntVal`/`Prim`/`Ref` duplication — ruled out repo-wide by the
  overarching design.

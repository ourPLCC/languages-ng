# plcc-ng Migration — TYPE1 Design

This is a focused design of record for the TYPE1 phase. It **extends**, and
does not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [TYPE0 design](2026-08-06-plcc-ng-type0-design.md), whose three
shipped `spec.plcc`s are TYPE1's starting point, and through TYPE0 on the
[REF](2026-08-04-plcc-ng-ref-design.md) and [SET](2026-08-04-plcc-ng-set-design.md)
designs, whose `envRef` port TYPE1 reuses unchanged. This document captures only
the decisions and porting subtleties specific to TYPE1, settled in brainstorming
on 2026-08-10.

## Goal

Port TYPE1 (`TYPE0 + declare + and/or/not + strong type checking`) to plcc-ng:
one `src/TYPE1/grammar.plcc` plus three target `spec.plcc`s (Python, Java,
JavaScript). The phase closes when all three targets pass their bats suite.

TYPE1 closes **Phase 4**. It is the first migrated language that *rejects*
programs as its central feature, and the first whose semantics require a second
environment structure running in parallel with the value environment.

## Validated Mechanics

The **complete** TYPE1 port was spiked against the installed CLI in all three
targets before this document was written — TYPE0's three shipped `spec.plcc`s
plus the full delta below, run under `plcc-rep`. Every output quoted in this
document is measured, not predicted, and **all three targets produced
byte-identical output on every program**.

| program | TYPE1 output |
|---|---|
| `proc-types` (the existing test, verbatim) | `f:[=>int]` `y:int` `f:[=>int]` `y:int` `3` |
| `Prog/fact` | `fact:[int=>int]` `fact:[int=>int]` `120` |
| `Prog/oe` | `odd?:[int=>bool]` `even?:[int=>bool]` `odd?:[int=>bool]` `even?:[int=>bool]` |
| `Prog/compose` | `compose:[[int=>int],[int=>int]=>[int=>int]]` … `56` |
| `Prog/count` | `sum_factory:[=>[int=>int]]` … `1 4 9 16 25 0 1 4 9 16 25` |
| `and(true,false)` `or(true,false)` `not(true)` | `false` `true` `false` |
| `and(<?(1,2), not(false))` `or(zero?(1), >=?(3,3))` `not(=?(2,2))` | `true` `true` `false` |
| `let p = proc():[=>int] proc():int 7 in .p()` | `proc():int` |

**All four `Prog/` examples run unmodified**, which is the single strongest
signal that the port is faithful: they are the language's own course material,
they exercise `declare`, higher-order proc types, closures over mutable `let`
bindings, and mutual recursion, and none of them needed a character changed.

Three findings from the spike deserve their own sections:
[the `Type` singletons](#types-canonical-types-are-factory-methods-not-fields),
[Java's missing `ArrayList` import](#three-per-target-mechanics-found-live), and
[the four drift items](#four-places-where-the-pre-migration-files-drifted).

## TYPE1 Descends From TYPE0, Whose Port Is Ahead Of It

The pre-migration flat files in `src/TYPE1/` are a fork of *pre-migration*
TYPE0, not of the TYPE0 that Phase 4 actually shipped. The migration corrected
things in TYPE0 that TYPE1's fork never received, and TYPE1's own author
made changes that read as drift rather than design.

So the port starts from `src/TYPE0/`'s three shipped `spec.plcc`s and applies
the delta below. It does **not** transliterate `src/TYPE1/{code,prim,val,ref}`,
which would silently re-import four regressions.

Diffing the two pre-migration grammars gives the whole syntactic delta, exactly
as TYPE0's design predicted, and TYPE0's `BoolPrimtype` → `BoolPrimType` typo
fix means that delta is already zero rather than one more thing to reconcile.

## Grammar — TYPE0's File Plus Five Edits

`src/TYPE1/grammar.plcc` is `src/TYPE0/grammar.plcc` with:

1. The header comment becomes:

   ```
   # Language TYPE1
   #   Language TYPE0 with strong type checking
   ```

2. Four new tokens, each in its pre-migration position and all before
   `token SYMBOL`: `ANDOP 'and'`, `OROP 'or'`, `NOTOP 'not'`, and
   `DECLARE 'declare'`.

3. A new first program alternative:

   ```
   <Program:Declare>       ::= DECLARE <SYMBOL> COLON <TypeExp>
   ```

4. Three new `<Prim>` alternatives — `AndPrim`, `OrPrim`, `NotPrim` — after
   `NEPrim`.

5. **`#!trace` is dropped.** It is an old-PLCC debug directive with no plcc-ng
   meaning.

Everything else is inherited unchanged: the `VAR` → `SYMBOL` rename, the
camelCase `<Exp:testExp>`/`<Exp:trueExp>`/`<Exp:falseExp>` alt-names, and the
whole type sub-grammar. The `%include tenv` / `%include type` lines do **not**
carry over — those files' contents become semantic blocks in each `spec.plcc`.

TYPE0's finding that plcc-ng resolves tokens by **longest match, not
declaration order** continues to hold, and now covers `and`/`or`/`not` against
`SYMBOL`: an identifier beginning `orange` scans as `SYMBOL`, not `OROP`
followed by `ange`. No reordering is needed and none should be introduced.

`<Program:Declare>` is LL(1)-clean as written — `DECLARE`, `DEFINE`, and the
`<Exp>` first-set are disjoint. Confirmed with `plcc-parse`.

## `envRef` Reuse — The Fifth In A Row

Each `spec.plcc` opens with `%include ../../Env/envRef/<target>/env.plcc`,
**unchanged**. There is no Env work in this phase and no `src/Env/` deletion.

TYPE1's own pre-migration flat `src/TYPE1/envRef` is byte-identical to
pre-migration TYPE0's (verified with `diff`), i.e. the canonical `void
checkDuplicates` shape Phase 3 ported. Nothing needs reconciling; it is deleted
with the rest of TYPE1's old-PLCC sources.

This is `envRef`'s **fifth consecutive zero-touch reuse** — REF, NAME, NEED,
TYPE0, TYPE1. NEED's design asked that the variant be treated as settled after
four and that any need to change it in Phase 4 or 5 be read as a signal that
something else is wrong. TYPE1 needed no change, so that standard holds going
into OBJ, the last user.

## Nine New Free-Standing Classes

`Type`, `IntType`, `BoolType`, `ProcType`, `TypeEnv`, `TypeEnvNode`,
`TypeEnvNull`, `TypeBinding`, and `TypeBindings` are added to each of the three
`spec.plcc`s as free-standing `%%%` blocks.

The `TypeEnv` family is a near-mirror of `envRef`'s
`Env`/`EnvNode`/`EnvNull`/`Binding`/`Bindings`, which gives it a validated shape
to follow — including the deferred-import trick in `initTypeEnv` and
`extendTypeEnv`. It is *not* factored into a shared `src/Env/` variant: it is a
type environment, used by one language, and the overarching design rules out
unifying environment structures beyond faithful porting.

Two deliberate simplifications against the original `tenv`: `TypeEnv.toString(int n)`
and its two overrides are dropped (a debug helper with no callers), and
`TypeBindings` keeps only the two constructors that are actually used.

### `Type`'s canonical types are factory methods, not fields

This was the phase's largest technical risk. The original publishes eight shared
instances as static finals:

```java
public static final IntType  intType  = new IntType();
public static final ProcType ii_i = compile("ii>i");   // and five more
```

In Java that is fine — static initialization tolerates forward references
between classes. In Python and JavaScript it is a hard problem. plcc-ng emits
one file per free-standing class, so `Type`, `IntType`, `BoolType`, and
`ProcType` are four separate modules; `IntType.py` must import `Type` to
subclass it, and a class *attribute* is evaluated when the class body runs, so
`Type` would have to import `IntType` at module scope. The resulting cycle
succeeds or fails depending on which module loads first. Co-locating the four
classes in one block would dodge it, but Java forbids two public classes in one
file.

**The canonical types become static factory methods with deferred imports** —
the same fix `Env.initEnv()` already uses, and validated live in all three
targets:

```python
class Type:

    @staticmethod
    def intType():
        from IntType import IntType
        return IntType()

    @staticmethod
    def ii_b():
        from ProcType import ProcType
        return ProcType([Type.intType(), Type.intType()], Type.boolType())
```

Call sites become `Type.intType()` and `Type.ii_b()`.

**Java adopts the same shape** even though only Python and JavaScript need it.
Java could keep `public static final IntType intType`, but then Java would read
`Type.intType` where the other two read `Type.intType()`, in about twenty call
sites across the prims and the `evalType` methods — a divergence the
single-textbook rule exists to prevent. Java's version costs a fresh allocation
per call, which is harmless and gets a comment on the class saying why the
`static final`s are gone.

**Identity was never load-bearing.** The original already mixes shared and fresh
instances — `LitExp.evalType` returns the shared `Type.intType` while
`BoolPrimType.toType()` returns `new BoolType()` — because `checkEquals` is
structural equality on stateless objects. Nothing can tell the difference.

**`compile` and `decodeType` are dropped.** They exist only to make those six
field initializers terse. Once the fields are methods, each signature is one
readable line, and the string DSL is ~25 lines per target buying nothing —
including a `null` sentinel for `'>'` that ports awkwardly to three languages.
This is the same trimming applied to `Val.toArray` in Python/JavaScript, to
`checkDuplicates`'s dead `Set<String>` return in Phase 3, and to `Bindings`'s
unused constructors.

### Three Java-isms that Python and JavaScript cannot express

The rule: **Java converges on anything visible at a call site; it keeps an
overload only where the overload is standing in for a default argument.** The
shipped `Bindings` port is the precedent for the second half — Java has two
constructors where Python and JavaScript have one with defaults, and every call
site reads identically in all three.

| Java-ism | Resolution |
|---|---|
| instance `checkEquals(Type)` **and** `static checkEquals(Type,Type)` | **Drop the static in all three targets.** Its four call sites become `t1.checkEquals(t2)`, which is all the static ever did. |
| `checkProcType()` **and** `checkProcType(ProcType)` | **Drop the 0-arg one in all three targets** and fold its message into `procType()`. Its sole call site was immediately followed by `procType()`, which already threw on the same input, so `AppExp.evalType` becomes one call instead of two and keeps the better message. |
| `TypeBindings`' four constructors | **Java keeps two**, Python/JavaScript use `TypeBindings(idList=None, typeList=None)`. This *is* the default-argument case, and mirrors `Bindings` exactly. The capacity and `List<TypeBinding>` overloads have no callers and go. |

`TypeBindings` takes token lists and reads `.lexeme`, mirroring `Bindings`. That
deletes the `List<String> stringVarList` conversion loop from
`LetDecls.addTypeBindings` and makes it read in parallel with `addBindings`. In
`addLetrecTypeBindings` the same loop is already dead in the original — built
and never read.

## Four Places Where The Pre-Migration Files Drifted

Diffing pre-migration TYPE0 against pre-migration TYPE1 turns up four
differences. Three are resolved in favour of the shipped TYPE0 shape; one is
resolved in favour of TYPE1's own design.

### 1. `Val.isTrue()` raises

The lineage across four consecutive languages:

| Language | `Val.isTrue()` | `IntVal.isTrue()` |
|---|---|---|
| SET, REF, NAME, NEED (shipped) | `return True` | `return self.val != 0` |
| TYPE0 (shipped) | raises `boolean expression expected` | *no override* |
| TYPE1 (pre-migration) | `return false` | *no override* |

Three different answers in three consecutive languages is the tell. The
untyped languages are coherent; TYPE0 deliberately breaks that when it
introduces a real boolean type; TYPE1's `false` is neither.

**The port keeps TYPE0's raise.** The body is unreachable in any well-typed
program — `IfExp.evalType` rejects `if 1 then …` at type-check time, before
`eval` runs — so no test can distinguish the two. What changes is the behaviour
when the type checker is *wrong*, which in a course where students extend the
type checker is the normal case: a raise names the failure, `return false`
silently takes the else branch and produces a plausible wrong answer.

### 2. The prim arity guards are kept

Pre-migration TYPE1 deletes every prim's runtime arity guard and, in the same
edit, gives each prim a `definedType()`. `PrimappExp.evalType` then checks arity
statically via `Type.checkEqualTypes`, which raises `argument number mismatch`.
That is a coherent trade, not drift — and the static check is strictly stronger,
catching `+(1)` in a branch that never executes.

**The port keeps the guards anyway**, for three reasons. `definedType()` is
exactly what a student edits in a type-checker assignment, and getting it wrong
without a guard yields an `IndexError` in Python, an
`ArrayIndexOutOfBoundsException` in Java, and a
`TypeError: Cannot read properties of undefined` in JavaScript — three
different unhelpful crashes instead of one clean language error. It is
consistent with item 1. And it is the zero-edit path: TYPE1's specs are built
from TYPE0's, so keeping the guards means not touching them.

The pedagogical point — that the type checker gets there first — is made in
prose, not by deleting the net underneath it.

### 3. `ProcVal.apply`'s formals/args check is kept

Pre-migration TYPE1 has no count check, but neither did pre-migration TYPE0: the
check is something the *migration* introduced, and it is byte-identical in all
five shipped predecessors (`SET`, `REF`, `NAME`, `NEED`, `TYPE0`). Dropping it
would not be fidelity to TYPE1; it would be a fresh divergence from five shipped
languages in the one method the textbook walks through for each of them.
`AppExp.evalType` subsumes it statically, exactly as in item 2.

### 4. Call-by-reference is restored

`AppExp.eval` builds its operands via `rands.evalRandsRef(env)` in both
languages, but the implementations differ:

```python
# TYPE0 (shipped)
def evalRandsRef(self, env):
    return [e.evalRef(env) for e in self.expList]
```
```java
// TYPE1 (pre-migration)
for (Exp e : expList)
    refList.add(new ValRef(e.eval(env)));   // always a fresh cell
```

`Exp.evalRef`'s default already *is* `new ValRef(eval(env))`, and the only
override is `VarExp`'s, which returns the variable's own cell from the
environment. So TYPE1's rewrite changes exactly one case: **passing a variable
to a procedure no longer aliases it** — the entire content of REF, the language
this branch of the sequence is named after.

Two things mark it as accidental. `Exp.evalRef` and `VarExp.evalRef` are still
defined in TYPE1 and are called by nothing; a deliberate move to call-by-value
would have deleted them. And the type checker has no opinion here — `evalType`
never models references, so nothing about adding types motivates the change.

**The port restores TYPE0's `evalRandsRef`.** Measured, all three targets:

```
declare a : int          a:int
define a = 1             a:int
define g = proc(x:int):int set x = 5     g:[int=>int]
.g(a)                    5
a                        5
```

#### Call-by-reference is type safe here, and that is worth teaching

With aliasing, `.g(a)` hands `g` the cell holding `a`, so every write `g` can
make through that cell must produce a value `a`'s declared type still accepts.
Two checks compose to guarantee it:

1. `AppExp.evalType` requires `checkEqualTypes(pt.paramTypeList, argTypeList)` —
   formal and argument types must be **exactly equal**.
2. `SetExp.evalType` requires `varType.checkEquals(expType)` — a `set` on the
   formal must write that same type.

So the only values that can reach `a`'s cell are of `a`'s own type.

This works because type equality is **invariant**: `IntType.checkIntType` and
`BoolType.checkBoolType` are empty bodies, and `ProcType.checkProcType` recurses
invariantly on both the return type and the parameter types — no subtyping, no
variance anywhere. Reference parameters are precisely the feature that goes
unsound the moment variance is added.

That is the pedagogical payoff of restoring it. It gives a concrete answer to
"why must `[int=>int]` match *exactly* rather than merely be compatible?" Under
call-by-value that strictness looks gratuitous; under call-by-reference it is
load-bearing.

Two supporting facts, both checked: `set` is the only mutation path
(`ValRef.setRef` is reached only from `SetExp.eval`; `Define` creates fresh
bindings and raises on a duplicate rather than overwriting; `letrec` builds new
refs), and the type and value environments are extended in lockstep by
`LetExp`, `LetrecExp`, and `Proc`/`ProcVal`, so a `set` checked against one
binding cannot resolve to a different one at runtime.

## Semantics — The Delta Over TYPE0

### The top level

`Program` gains a second static beside `env`, and all three program
alternatives change. `_run()` **returns** a string in every target — the
original's `System.out.println` becomes a return in each success branch.

```python
Program
%%%
env = Env.initEnv()
tenv = TypeEnv.initTypeEnv()
%%%

Declare
%%%
def _run(self):
    tenv = Program.tenv
    sym = self.symbol.lexeme
    try:
        tenv.applyTypeEnv(sym)
    except LanguageError:
        varType = self.typeExp.toType()
        tenv.add(TypeBinding(sym, varType))
        return f"{sym}:{varType}"
    raise LanguageError(f"{sym}: duplicate variable declaration")
%%%

Eval
%%%
def _run(self):
    self.exp.evalType(Program.tenv)     # type check first
    return str(self.exp.eval(Program.env))
%%%
```

`Define._run()` keeps its two-nested-`try` structure — declared-and-defined,
declared-not-yet-defined, and neither — returning `sym:type` in each success
branch and raising on a redefinition.

Exception-based control flow around `applyTypeEnv` is faithful and stays. It is
teaching material about environments, and `EnvNull`/`TypeEnvNull` are the only
things that throw inside those `try` blocks.

**`Program.tenv` persists across `plcc-rep`'s read loop**, the same way
`Program.env` does — confirmed live, since the `proc-types` test is five
statements each depending on the previous one's effect.

### The fan-out

`evalType` is added to `Exp` (abstract) and its 12 subclasses; `toType()` fills
the seven type nonterminals TYPE0 deliberately left with no semantic blocks;
`Proc` gains `evalType()`; `Formals` gains `formalTypeList()`,
`declaredTypeBindings()`, and `toString()`; `LetDecls` gains `addTypeBindings`
and `addLetrecTypeBindings`; `Rands` gains `evalTypeRands`. All 16 prims gain
`definedType()`, and `AndPrim`/`OrPrim`/`NotPrim` are new — they call
`boolVal()`, which TYPE0 kept in `Val` specifically for this phase.

`Proc.definedType()` is **dropped**: it exists in the original but has no
callers (`PrimappExp.evalType` calls `prim.definedType()`, never `proc`'s).

`ProcVal` gains a `returnTypeExp` field and a real `toString()` —
`proc(x:int,g:[int,int=>bool]):bool` where TYPE0 printed bare `proc`. Faithful
to TYPE1 and observable, so it is logged as course-material impact.

### Three per-target mechanics, found live

- **Java grammar-derived classes get `List` auto-injected but not `ArrayList`.**
  `LetDecls`, `Rands`, `Formals`, and `TypeExps` each need their own
  `:import` block containing `import java.util.ArrayList;`. TYPE0's Java spec
  already does this for `LetDecls` and `Rands`; `Formals` and `TypeExps` are new
  in this phase because their TYPE1 methods build lists. Omitting one is a
  compile error, not a silent failure.
- **Java needs a `Prim` block** declaring both abstract methods:
  `public abstract Val apply(Val [] va);` and
  `public abstract ProcType definedType();`. TYPE0's Java spec has the first;
  the second is new. Python and JavaScript need no `Prim` block, matching TYPE0.
- **JavaScript has no typed `catch`.** `Declare` and `Define` guard their
  handlers with `if (!(e instanceof LanguageError)) throw e;` so a real
  `TypeError` is not swallowed as "no binding found". This is one extra line per
  handler in one target, and gets a comment saying why.

`Val.toArray` is **kept in Java**, where prims take `Val []`; Python and
JavaScript pass lists and have no `toArray`. This mirrors TYPE0 exactly and is
not new divergence.

Python's per-file import rule is unchanged from TYPE0: every class naming a
free-standing class needs its own `:import`, and all 16 prims now need
`from Type import Type`. JavaScript's rule is unchanged too — grammar-derived
classes must not re-require `Node`, `Token`, or `LanguageError`, while the nine
new free-standing classes need explicit requires and a `module.exports`.

### What does not change

`IntVal`, `BoolVal`, `Ref`, `ValRef`, the `Env` family, `LetDecls:init`,
`Formals:init`, `SeqExp.eval`, `SetExp.eval`, `LetExp.eval`, `LetrecExp.eval`,
`AppExp.eval`, `Rands.evalRands`, and the `eval`/`toString` of all 13 inherited
prims.

`LetDecls:init` in particular needs no work: TYPE1 already has the duplicate
check that pre-migration TYPE0 was missing, and TYPE0's port added.

## Tests

`src/TYPE1/tests/<case>/`, each case a shared `TYPE1.input` + `TYPE1.expected`
plus one `TYPE1test.bats` with three `@test` blocks, one per target directory,
driven by `plcc-rep` — the same shape every language since V3 uses.

### The value-cases-only rule gets a scoped exception

Every earlier language's suite tests what the language *computes*. TYPE1's
contribution is what it *refuses*, and a value-only suite cannot reach it. All
seven of these could be deleted and a value-only suite would still pass:

| Check | Original site |
|---|---|
| `checkBoolType(Type.boolType())` on the `if` test | `IfExp.evalType` |
| `checkEquals(trueExpType, falseExpType)` | `IfExp.evalType` |
| `checkEqualTypes(pt.paramTypeList, argTypeList)` | `PrimappExp.evalType`, `AppExp.evalType` |
| `checkEquals(varType, expType)` on `set` | `SetExp.evalType` |
| `checkEquals(declaredReturnType, expType)` | `Proc.evalType` |
| `checkEquals(lhsVarType, rhsExpType)` | `Define._run` |
| `procType()` on a non-procedure | `AppExp.evalType` |

TYPE1 does have partial teeth earlier languages lacked — `Declare` and `Define`
print the inferred type, so a wholly no-op `evalType` would be caught by
`proc-types` — but that only exercises inference on top-level definitions, never
rejection.

**The exception is scoped to type errors**, the feature under test. Inherited
runtime diagnostics (`attempt to divide by zero`, `no binding for x`,
`duplicate ID`, `not an Int`, `formals/args number mismatch`) stay excluded, as
in every phase since V3 — their languages already own them.

Error cases need **no harness change**. Measured in all three targets: a
language error goes to **stdout**, `plcc-rep` exits **0**, and evaluation
**continues to the next expression**. So the existing
`RESULT="$(plcc-rep < input)"` shape captures error text, and error lines can
sit in the same input file as value lines.

### The five cases

| Case | Kind | Covers |
|---|---|---|
| `proc-types/` | value | the existing case, ported off `plccmk`/`rep -n` to three `plcc-rep` blocks; input and expected unchanged |
| `boolean-ops/` | value | `and`, `or`, `not`, alone and composed with relational prims |
| `declare-define/` | value | `declare`-then-`define`, mutual recursion, and the printed `sym:type` lines |
| `call-by-reference/` | value | pins the aliasing restored above, so it cannot be silently dropped again |
| `type-errors/` | error | the seven rejection sites |

`type-errors/` is one directory rather than seven, since `plcc-rep` continues
after an error and a single input reads as a checklist. Measured output, all
three targets byte-identical:

```
if 1 then 1 else 2              type mismatch: int != bool
if true then 1 else false       type mismatch: bool != int
+(1,true)                       type mismatch: bool != int
+(1)                            argument number mismatch
.1(2)                           int: attempt to apply a non-procedure
let x = 1 in set x = true       type mismatch: bool != int
proc(x:int):bool 5              type mismatch: int != bool
declare b : int                 b:int
define b = true                 type mismatch: bool != int
```

Magnitudes stay small — the largest value anywhere is `120`, far below the
32-bit Java `IntVal` overflow of issue
[#16](../issues/016-cross-target-integer-divergence.md) — and no case recurses
deeply enough to approach the Python ceiling of issue
[#19](../issues/019-python-recursion-ceiling.md).

### Expected test counts

**Measured baseline (2026-08-10, this worktree): 152 tests, 150 passing and 2
failing** — `not ok 28 OBJ class` and `not ok 68 TYPE1 proc-types`, both
`plccmk: command not found` from a language still on old PLCC.

After this phase: **166 tests** — 152, minus TYPE1's 1 old test, plus 15
(5 cases × 3 targets) — **165 passing and 1 failing**, the sole remaining
failure being `OBJ class`.

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after. Nothing in this phase touches an already-passing
language, so any V-prefixed, SET, REF, NAME, NEED, or TYPE0 failure would be a
genuine regression.

Per the overarching design's own warning, a future phase must recompute this
baseline fresh rather than copying and decrementing it — TYPE0's design drifted
on exactly this and needed an amendment.

## Example Programs

TYPE1 ships its four `Prog/` examples (`compose`, `count`, `fact`, `oe`)
**unchanged**. All four were measured running byte-identically in all three
targets. Every migrated language kept its `Prog/` directory and no bats test
references one; these are course material carried forward, not test fixtures.

`src/TYPE1/J/EO.java` also stays. It is a Java illustration of mutual recursion
accompanying `Prog/oe`, it predates the migration, and issue
[#15](../issues/015-gitignore-java-pattern-shadows-source-dirs.md) treats it as a
real tracked source file. It is the repository's only `J/` directory, which is a
pre-existing oddity, not something this phase should resolve.

## Bookkeeping (in the same commits as the work)

- File a TYPE1 issue with `bin/issues/new.bash migrate-type1-to-plcc-ng feat`
  and add its roadmap entry in the same commit; close it with
  `bin/issues/close.bash` as the branch's final commit.
- **No `src/Env/` work this phase** — no port, no deletion.
- Delete the old flat old-PLCC files
  `src/TYPE1/{grammar,code,prim,envRef,val,ref,tenv,type}` once the three
  targets pass. None collides with a new path (`src/TYPE1/grammar` versus
  `src/TYPE1/grammar.plcc`), so this deletion comes at the end — the REF, NAME,
  NEED, and TYPE0 ordering, not SET's.
- Log TYPE1 entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change:
  - the `VAR` → `SYMBOL` token rename and `var` → `symbol` field rename;
  - `$run()` → `_run()` returning a string instead of printing;
  - `Type.intType` → `Type.intType()` and the six signature constants likewise,
    with `compile`/`decodeType` gone;
  - `Type.checkEquals(a, b)` → `a.checkEquals(b)`, and `checkProcType()` folded
    into `procType()`;
  - `Val.isTrue()` raising `boolean expression expected` where pre-migration
    TYPE1 returned `false`;
  - the retained prim arity guards and the added `formals/args number mismatch`
    check, neither of which pre-migration TYPE1 had;
  - **call-by-reference restored**, with the observable that `.g(a)` where `g`
    does `set x = 5` mutates the caller's `a` — plus the invariant-equality
    soundness argument, which is lecture material in its own right;
  - `ProcVal.toString()` now printing the full proc type (`proc():int`) where
    TYPE0 printed `proc`;
  - the new `type-errors/` test case and the scoped exception to the
    value-cases-only rule.

## Noted for Later Phases

- **OBJ is the last language and the last `envRef` user.** Its fork should be
  diffed against `src/Env/envRef/<target>/env.plcc`, the ported canonical shape
  — not against any per-language flat file, all of which are gone from the
  working tree and survive only in git history.
- **The `Type`/`TypeEnv` hierarchies are TYPE1-only.** OBJ does no type
  checking, so nothing here needs to be generalized for it.
- **The factory-method pattern is the general answer** to any later class that
  wants to publish instances of its own subclasses as constants. Static fields
  work in Java and are load-order-fragile in Python and JavaScript; a static
  method with a deferred import is uniform.
- **Error-path tests are now known to be free.** Language errors reach stdout,
  exit status stays 0, and evaluation continues. Any later phase that wants
  them needs no harness work — only a reason that its feature is rejection
  rather than computation.

## Out of Scope

- OBJ.
- Any change to `envRef` or to `src/Env/`.
- Factoring `TypeEnv` into a shared `src/Env/` variant, or unifying it with the
  value-environment classes — ruled out repo-wide by the overarching design.
- Error-path tests other than type errors — divide-by-zero, unbound
  identifiers, duplicate IDs, `not an Int`, and `formals/args number mismatch`
  all belong to languages that already shipped.
- Type inference, subtyping, or any relaxation of `checkEquals`'s exact
  structural equality. The invariance is load-bearing for call-by-reference
  soundness; see [above](#call-by-reference-is-type-safe-here-and-that-is-worth-teaching).
- Issue [#16](../issues/016-cross-target-integer-divergence.md), issue
  [#19](../issues/019-python-recursion-ceiling.md), issue
  [#22](../issues/022-plcc-rep-parses-each-source-independently.md), and issue
  [#27](../issues/027-use-spec-flag-instead-of-copying-tree.md) — all repo-wide
  and inherited.
- Any unification of the per-language `Val`/`IntVal`/`Prim`/`Ref` duplication —
  ruled out repo-wide by the overarching design.

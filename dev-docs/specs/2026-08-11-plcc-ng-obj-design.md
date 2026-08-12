# plcc-ng Migration — OBJ Design

This is a focused design of record for the OBJ phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [SET design](2026-08-04-plcc-ng-set-design.md), whose three
shipped `spec.plcc`s are OBJ's starting point and whose `envRef` port OBJ reuses
unchanged, and it carries forward the factory-method finding from the
[TYPE1 design](2026-08-10-plcc-ng-type1-design.md). This document captures only
the decisions and porting subtleties specific to OBJ, settled in brainstorming
on 2026-08-11.

## Goal

Port OBJ (`SET + lists, characters, strings, classes, and objects`) to plcc-ng:
one `src/OBJ/grammar.plcc` plus three target `spec.plcc`s (Python, Java,
JavaScript). The phase closes when all three targets pass their bats suite.

OBJ closes **Phase 5**, and with it the whole migration. It is the last language
in the keep list, the last of `envRef`'s seven users, and — measured — the
**only** remaining test in the repository that still invokes old PLCC's
`plccmk`. When this phase lands, `src/` contains no old-PLCC sources at all.

OBJ is also the largest language by a wide margin: 30 `Exp` alternatives, 24
prims, 5 `:init` blocks, and 14 free-standing classes per target on top of the 5
inherited through `%include`.

## Validated Mechanics

Seven mechanics were unknown going in, and all seven were measured against the
installed CLI before this document was written. Six were clean. The seventh
changed the design and gets [its own section](#the-stdout-protocol-finding).

Unlike TYPE1, this phase did **not** spike a complete three-target port. That is
a deliberate, recorded scope choice: the unknowns are spiked and measured, and
the bulk transliteration belongs to the implementation plan. Every output quoted
below is measured. Claims elsewhere in this document that rest on shipped
precedent rather than a fresh measurement are marked as such.

### 1. Empty alternatives work, and the grammar converts wholesale

`<Ext:Ext0> ::=` and `<Loc:SimpleLoc> ::=` are accepted, and the whole converted
grammar is LL(1)-clean with no reordering. Measured, `plcc-parse` on
`define c = class static x = 3 static f = proc(t) t end`:

```
Define
  SYMBOL 'c'
  ClassExp
    ClassDecl
      Ext0 (empty)
      Statics
        SYMBOL 'x'
        SYMBOL 'f'
        LitExp
          LIT '3'
        ProcExp
          Proc
            Formals
              SYMBOL 't'
            VarExp
              SYMBOL 't'
      Fields
      Methods
```

`SimpleLoc (empty)` appears the same way in a `set y = …` tree.

**Amended (2026-08-11, during Task 2): the first sentence above is wrong,
and the measurement that produced it could not have caught the problem.**
`<Ext:Ext0> ::=` is accepted, but the parse table plcc-ng 2.0.1 builds for
`Ext` has entries for `EXTENDS` and `STATIC` only. `class field x end`,
`class method m = proc() 1 end`, and `class end` all fail with
`unexpected 'FIELD', no production for 'Ext'`.

The cause is a plcc-ng FOLLOW-set defect, filed as issue
[#38](../issues/038-plcc-ng-follow-set-omits-nullable-tail.md):
`build_follow_sets.py` adds FIRST of the *single* next symbol and then
skips to the "entire remainder nullable" case, never walking forward
through nullable symbols in between. `<Statics>` is nullable, so
`FOLLOW(Ext)` came out `{STATIC}` rather than
`{STATIC, FIELD, METHOD, END}` — and the predict set of an empty
alternative *is* FOLLOW. `plcc-ll1` reports `is_ll1: true` with no
conflicts the whole time, so nothing warned.

The example measured above, `class static x = 3 static f = proc(t) t end`,
is the one class shape that cannot expose this: `STATIC` is exactly the
single token the truncated FOLLOW set retained. The lesson generalises
past this bug — when validating an empty alternative, the case worth
measuring is the one where the *following* nullable nonterminal is
actually empty.

`src/OBJ/grammar.plcc` worked around it by splitting the class body out:

```
<ClassDecl>      ::= CLASS <Ext> <ClassBody>
<ClassBody>      ::= <Statics> <Fields> <Methods> END
```

`build_first_sets` *does* walk the nullable prefix correctly, so
`FIRST(ClassBody) = {STATIC, FIELD, METHOD, END}` and `<Ext>` sat next to
a correctly computed set. The accepted language was unchanged; the tree
gained one node and `ClassDecl.eval` reached through `self.classBody`.

**Resolved 2026-08-12 — the workaround is no longer in the grammar.**
plcc-ng 2.0.2 contains the upstream fix (`ourPLCC/plcc-ng` issue #188),
so the split was reverted on the issue
[#6](../issues/006-multi-capture-alt-name-case-mismatch.md) precedent and
issue [#38](../issues/038-plcc-ng-follow-set-omits-nullable-tail.md) was
closed. The shipped grammar is back to the single production this document
originally specified:

```
<ClassDecl>      ::= CLASS <Ext> <Statics> <Fields> <Methods> END
```

and all three targets' `ClassDecl.eval` read `statics` / `fields` /
`methods` directly. The workaround is described above in the past tense
because the *reasoning* remains the useful part — it is the worked example
of how a truncated FOLLOW set presents, and how to structure around one if
a similar defect appears in a future plcc-ng release.

`<Loc:SimpleLoc>` is unaffected: `FOLLOW(Loc) = {SYMBOL}` is correct,
because the symbol following `<Loc>` in `<Exp:SetExp>` is not nullable.

### 2. `<Mangle> **=` generates the parallel lists its `eval` needs

`<Mangle> **= RANGLE <Exp> LPAREN <Rands> RPAREN` is a repeating rule with two
captures and no separator. The generated class is exactly what
`Mangle.eval` already iterates:

```python
class Mangle(_plcc.Node):
    _fields = ["expList", "randsList"]
    def __init__(self, expList, randsList): ...
```

Measured on `!<o>m(1)>n(2,3)!>`, the tree carries two `VarExp`s followed by two
`Rands`, confirming the lists are parallel and in source order.

### 3. Token ties resolve to the earlier-declared token

TYPE0 established longest-match. OBJ needs the tie-breaking rule as well,
because its `SYMBOL` regex is far broader than the V-languages'
(`[A-Za-z\&\?\$][\w\?\&\$]*` rather than `[A-Za-z][\w?]*`) and therefore matches
`add`, `rest`, `first`, `len`, `list?`, `nil?`, `zero?` and friends at *equal*
length to their keyword tokens. Measured with `plcc-scan`:

| input | token |
|---|---|
| `add` | `ADDLISTOP` |
| `add1` | `ADD1OP` |
| `addx` | `SYMBOL` |
| `rest` / `rests` | `RESTOP` / `SYMBOL` |
| `len` / `lens` | `LENOP` / `SYMBOL` |
| `list?` / `listy` | `LISTP` / `SYMBOL` |
| `$x`, `&y`, `?z` | `SYMBOL` |

The rule is **earlier declaration wins at equal length**. Every keyword in OBJ's
grammar is declared before `SYMBOL`, so all 24 collisions land correctly with no
reordering. The broad leading character class survives intact, which matters:
`$`, `&`, and `?` are legal identifier starts in OBJ and appear in its examples.

### 4. Double-quoted token patterns are accepted

`token CHR "'."` works. Every shipped spec uses single quotes, so this was
unvalidated; OBJ needs double quotes because the pattern contains an apostrophe.

### 5. Generated classes are constructible by hand

`Methods.addMethodBindings` builds `ProcExp` and `LetDecls` instances directly
rather than receiving them from the parser. Both generated constructors accept
it:

```python
class ProcExp(Exp):   def __init__(self, proc): ...
class LetDecls(...):  def __init__(self, symbolList, expList): ...
```

Note the field is `symbolList`, not `varList` — a consequence of the repo-wide
`VAR` → `SYMBOL` rename, and the one edit `addMethodBindings` needs.

### 6. Factory methods reach the grammar-derived `Program`

TYPE1 established static factory methods with deferred imports as the general
answer to load-order fragility. OBJ's hardest case goes one step further:
`EnvClass.envClass()` is a *free-standing* class that must read `Program.env`, a
*grammar-derived* class. Measured working in Python — `@` evaluated to
`class:TOP-ENV` — so the pattern holds across that boundary.

## The stdout Protocol Finding

**`plcc-rep` runs the generated program as a subprocess and uses its stdout as a
private, line-oriented JSON channel.** Reading
`plcc/cmd/rep.py::_read_response` in the installed package, each response line is
JSON-parsed; a line that fails to parse is printed verbatim and the loop reads
on.

That yields a precise rule, measured both ways:

| semantic action writes | result |
|---|---|
| text **ending in a newline** | tolerated — printed verbatim, then the real result record is read. `display 7` → `7` then `nil`, exit 0 |
| text **not ending in a newline** | merges with the following JSON result line. The merged line is unparseable, so it is printed (destroying the result record), then `readline()` blocks forever — **deadlock, no diagnostic** |

Measured in Python and JavaScript, via stdin *and* via a SOURCE file: exit 124
under `timeout`, no output, no error message.

This is fatal to a literal port. `display`, `display#`, `putc`, and `puts` are
all partial-line writers by design — emitting a newline is what the separate
`newline` expression is for. And the newline-terminated case only works through
the unparseable-line fallback, which is an accident of the implementation, not a
supported output channel.

### The fix: buffer into `Program`, fold into `_run()`'s return

`Program` gains an `out` list beside `env`. The six output expressions
(`display`, `display#`, `newline`, `putc`, `puts`, `@@`) append to it. **Both**
`_run()` implementations reset it, evaluate, and return the joined buffer
followed by what they would otherwise have returned — the value's string for
`Eval`, the defined symbol for `Define`. `Define` needs this too, since a
`define`'s right-hand side can itself produce output.

```python
Program
%%%
env = Env.initEnv()
out = []
%%%

Eval
%%%
def _run(self):
    Program.out = []
    v = self.exp.eval(Program.env)
    return "".join(Program.out) + str(v)
%%%
```

This reproduces old PLCC's interleaving exactly, keeps output on stdout where
`bin/test.bash`'s `RESULT="$(plcc-rep < input)"` captures it, and never writes a
partial line. Measured **byte-identical in all three targets**:

| input | output |
|---|---|
| `display 7` | `7nil` |
| `display 1` | `1nil` |
| `newline` | *(blank line)* then `nil` |
| `[1,2,3]` | `[1,2,3]` |

Routing output to stderr also avoids the deadlock and was measured working, but
is the wrong answer: `bin/test.bash` captures stdout only, so every `display`
would vanish from the suite and the `strings-chars/` case would have nothing to
assert.

### Two issues filed upstream

Per the overarching design's Defect Tracking process, both are filed in **this**
repository with `**Target:** ourPLCC/plcc-ng`, and neither is reported publicly
upstream without explicit confirmation.

1. **Bug** — a partial line written to stdout by a semantic action deadlocks
   `plcc-rep` with no diagnostic. A hang with no message is the worst available
   failure mode for a student who puts a `print` in a semantic action.
2. **Enhancement** — semantic actions have no supported way to emit
   user-visible output, nor to end the session cleanly. Both are missing record
   kinds. `_render_record` already dispatches on `record['kind']`
   (`result` / `error` / `specification_error`, else a hard error), so the shape
   of the fix is a new kind handled there plus a hook in each target runtime for
   `_run` to emit it. The issue carries this sketch so it is actionable rather
   than a complaint.

## `exit` Ships With A Documented Divergence

`ExitExp.eval` calls `System.exit(0)`. Under old PLCC, `rep` *was* the process,
so this was a clean quit with status 0. Under plcc-ng the generated program is a
subprocess, so the exit closes the pipe mid-protocol. Measured:

```
$ printf 'display 1\nexit\ndisplay 2\n' | plcc-rep
1nil                                          # stdout
plcc-rep: interpreter exited unexpectedly     # stderr
$ echo $?
1
```

OBJ's **language semantics are unchanged**: evaluation stops, nothing after
`exit` runs, and output already flushed by earlier statements survives. What
changed is the tool framing — a deliberate quit now reads as a crash.

**It ships as-is.** The obvious rework — raising a condition that `_run()`
catches — cannot work, because `plcc-rep` owns the read loop and OBJ has no way
to say "stop reading." A catch could only end that one statement and let
evaluation continue, which would genuinely change what `exit` means. Trading a
cosmetic status code for a real semantic change is the wrong direction, and it
is the same reasoning that kept `Val.isTrue()` raising in TYPE1.

The correct fix is the protocol extension in enhancement issue 2 above. OBJ does
not block on it: that is the pattern issue
[#6](../issues/006-multi-capture-alt-name-case-mismatch.md) set, where a
workaround shipped, plcc-ng 2.0.0 fixed the root cause, and the workaround was
then reverted. When a clean-exit record kind lands, `ExitExp` becomes a two-line
change and the impact-log entry gets a `Superseded` note.

The cost is contained: `exit` is used by **zero** example programs and zero
tests (verified with `grep`). It gets a comment in each spec explaining the
status code, an impact-log entry, and it stays out of the bats suite — a
nonzero exit cannot sit inside `RESULT="$(plcc-rep < input)"`.

## OBJ Descends From SET

OBJ's header declares it "Language SET with lists, characters, strings, classes,
and objects," and its `AppExp.eval` uses call-by-value `rands.evalRands(env)` —
the SET branch, not the REF/TYPE0 branch with `evalRandsRef`. So the port starts
from `src/SET/`'s three shipped `spec.plcc`s and adds four feature clusters:
lists/characters/strings, classes/objects, output expressions, and environment
reflection (`@`, `@@`, `!@`, `<v>e`, `!<o>m(a)!>`).

It does **not** transliterate `src/OBJ/{code,prim,val,ref}` in isolation, which
would re-import whatever the shipped SET port already corrected.

## Grammar — A Wholesale Conversion

`src/OBJ/grammar.plcc` is the existing `src/OBJ/grammar` converted in full —
measured accepted and LL(1)-clean, all 30 `Exp` alternatives, 24 prims, both
empty alternatives, and `<Mangle>`. The edits are exactly the repo-wide
conventions, and nothing else:

1. `token` / `skip` keyword on each lexical line.
2. Nonterminals capitalized (`<exp>` → `<Exp>`, `<program>` → `<Program>`), and
   alternative names moved inside the angle brackets
   (`<program>:Define` → `<Program:Define>`).
3. `VAR` → `SYMBOL`, so fields become `symbol` / `symbolList`. `SYMBOL` keeps
   **OBJ's own** broader regex `[A-Za-z\&\?\$][\w\?\&\$]*`, not the
   `[A-Za-z][\w?]*` the V-languages use.
4. Multi-capture alt-names in camelCase: `<Exp:testExp>`, `<Exp:trueExp>`,
   `<Exp:falseExp>`, `<Exp:vExp>`, `<Exp:eExp>`. The lowercase workaround for
   issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md) was fixed
   in plcc-ng 2.0.0 and must not be reintroduced.

The `%include code` / `prim` / `envRef` / `val` / `listVal` / `listPrim` /
`class` / `ref` lines do not carry over; those files' contents become semantic
blocks in each `spec.plcc`. `src/OBJ/FILES` is a stale manifest naming an `env`
file that no longer exists and is deleted with the rest.

## `envRef` — The Sixth And Final Zero-Touch Reuse

Each `spec.plcc` opens with `%include ../../Env/envRef/<target>/env.plcc`,
**unchanged**. There is no `src/Env/` work in this phase and no deletion.

The overarching design's 2026-08-04 correction predicted OBJ's fork would be
purely additive against the canonical `void checkDuplicates` shape, and a diff
against the ported `src/Env/envRef/<target>/env.plcc` confirms it: a
`reservedIDS` array plus a loop rejecting `self`, `myclass`, `superclass`,
`this`, and `super`. No signature difference.

NEED's design asked that the variant be treated as settled after four
consecutive zero-touch reuses, and that any need to change it in Phase 4 or 5 be
read as a signal that something else is wrong. TYPE1 needed no change and
neither does OBJ. SET ported the variant; REF, NAME, NEED, TYPE0, TYPE1, and now
OBJ reused it without a character changed. The variant retires untouched after
six consecutive zero-touch reuses across seven users.

### The reserved-ID check is kept, in a free-standing `Reserved` class

The overarching design left open "whether the reserved-ID check is still
wanted." It is, and dropping it would introduce three silent-wrong-answer paths.
`Bindings.add` appends and `Bindings.lookup` returns the **first** match, so:

| user writes | what happens without the check |
|---|---|
| `field self` | `StdClass.makeObject` adds user fields *before* binding `super`/`self`/`this`, so the user's field wins every lookup and silently displaces the real `self` inside every method |
| `method self` | methods sit in a `letrec` layer above the fields, shadowing the real `self` |
| `static myclass` | `myclass` is bound into `staticBindings` before `addStaticBindings` runs, so the user's static is silently unreachable |

None raises; each produces a plausible wrong answer. That is exactly the failure
mode TYPE1's `Val.isTrue()` decision ruled against.

**Placement:** the canonical `Env` stays untouched and the check moves to a
free-standing `Reserved` class. The five `:init` blocks — `Formals`,
`LetDecls`, `Methods`, `Fields`, `Statics` — call both:

```python
Env.checkDuplicates(self.symbolList, " in proc formals")
Reserved.check(self.symbolList)
```

Two calls per site rather than one, deliberately: this is the "documented,
explicit extension of the canonical `envRef`" the overarching design asked for,
in place of the current silent copy-paste divergence. A wrapper that called
through would restore the invisibility.

## Canonical Instances Become Factory Methods

TYPE1's pattern, applied to OBJ's statics. Static fields work in Java and are
load-order fragile in Python and JavaScript, where plcc-ng emits one class per
file; a static method with a deferred import is uniform across all three.

| original | ported | note |
|---|---|---|
| `Val.nil` | `Val.nil()` | identity never load-bearing — `isNil()` is a method and nothing compares by reference |
| `ListVal.empty` | `ListVal.empty()` | same; `isTrue()` distinguishes empty lists |
| `EnvClass.envClass` | `EnvClass.envClass()` | still returns the same `Program.env` object, so the singleton's actual purpose survives. Measured across the free-standing → grammar-derived boundary |

Java adopts the same shape even though only Python and JavaScript need it, so
every call site reads identically in all three targets — the single-textbook
rule, and the same decision TYPE1 made for `Type.intType()`.

## `Val.apply` Keeps Its `env` Parameter

SET's shipped signature is `apply(args, env)`. The `env` argument is unused by
`ProcVal.apply` and is **deliberate** — a seam for a dynamic-scoping exercise —
and must not be trimmed as dead weight. OBJ's `apply(List<Val>)` gains it at
both call sites, `AppExp.eval` and `Mangle.eval`. `Prim.apply(args)` stays
env-less, as in SET.

## Five Deliberate Trims

Every language-visible feature ports. These five have zero references anywhere
in OBJ and are dropped; each is recoverable from git history and restorable in a
few lines per target, with no grammar change and no LL(1) recheck.

| trim | evidence |
|---|---|
| `src/OBJ/list` (105 lines) | not `%include`d by the grammar at all — superseded by `listVal`, and not part of the build today |
| `ValRORef` / `setRORef` | defined in `src/OBJ/ref`, referenced nowhere; nothing constructs a read-only ref |
| `Val.zero` | declared, never read |
| `Env.empty` | used only inside `initEnv`; canonical `envRef` already inlines `EnvNull()` there, so keeping it would re-diverge from six languages |
| `Bindings(int capacity)`, `Bindings(List<Binding>)` | zero callers; already trimmed in the shipped `envRef` |

This is the same trimming applied to `checkDuplicates`'s dead `Set<String>`
return in Phase 3 and to `compile`/`decodeType` in Phase 4. It is recorded here
so a future reader knows the omissions were deliberate.

## Per-Target Mechanics

All inherited from TYPE0 and TYPE1; this phase introduces no new per-target
rule. Stated as projections from shipped precedent, not fresh measurements,
except where noted above:

- **Java** — `List` is auto-injected into grammar-derived classes but
  `ArrayList` is not, so each grammar-derived class that *constructs* one needs
  its own `:import` block with `import java.util.ArrayList;`. Reading the
  sources, that is at least `Rands` (`evalRands`) and `Methods`
  (`addMethodBindings`); the plan should add them wherever `javac` demands
  rather than working from this list, since omitting one is a hard compile
  error and not a silent failure. A `Prim` block declares
  `public abstract Val apply(Val [] va);`. `Val.toArray` is kept here and only
  here, since Java prims take `Val []`. Java needs no `:import` for
  same-directory classes.
- **Python** — every class naming a free-standing class needs its own
  `:import`; there is no file-wide import.
- **JavaScript** — free-standing classes need explicit `require`s and a
  `module.exports`; grammar-derived classes must **not** re-require `Node`,
  `Token`, or `LanguageError`, which are auto-injected.

One Java-ism worth noting for the plan: Java requires *every* `Exp` subclass to
implement an abstract `eval`, so a partially-implemented spec that runs fine in
Python and JavaScript fails to compile in Java. Hit live during the spike; it
means Java is the target that catches an incomplete port first.

### Class inventory

Fourteen free-standing classes per target — `Val`, `IntVal`, `NilVal`,
`ProcVal`, `ListVal`, `ListNode`, `ListNull`, `ClassVal`, `EnvClass`,
`StdClass`, `ObjectVal`, `Ref`, `ValRef`, `Reserved` — plus the five inherited
through `%include` (`Env`, `EnvNode`, `EnvNull`, `Binding`, `Bindings`). The
method additions `src/OBJ/listVal` makes to `Val` (`listNode`, `listVal`,
`isList`) merge into the single `Val` block rather than becoming a second one.

## Tests

`src/OBJ/tests/<case>/`, each case a shared `OBJ.input` + `OBJ.expected` plus one
`OBJtest.bats` with three `@test` blocks, one per target directory, driven by
`plcc-rep` — the same shape every language since V3 uses.

OBJ ships **one** 8-line test case today, the thinnest coverage in the
repository for the largest language. Seven cases replace it:

| case | kind | covers |
|---|---|---|
| `class/` | value | the existing case, ported off `plccmk`/`rep -n`; input and expected unchanged |
| `objects/` | value | `new`, fields, methods, `self` / `this`, `set <this>x = …` |
| `inheritance/` | value | `extends`, `super`, field shadowing, statics |
| `lists/` | value | `[…]` literals and all nine list prims |
| `strings-chars/` | value | `'c`, `"…"` as char lists, `puts`, `putc`, `display`, `display#`, `newline` |
| `env-ops/` | value | `@`, `!@`, `<v>e`, and the `!<o>m(a)>n(b)!>` chain |
| `errors/` | error | reserved IDs, duplicate IDs, `error` / `perror` |

`strings-chars/` is the case that pins the buffered-output mechanism, so a
regression to direct printing shows up as a deadlock in the suite rather than
silently.

Two deliberate exclusions. `@@` dumps the whole environment, so testing it would
turn `Env`'s `toString` into a pinned interface across three targets and make
any future `Env` change a test break. `exit` returns a nonzero status and so
cannot sit inside `RESULT="$(plcc-rep < input)"`.

Error cases need no harness change: TYPE1 measured that a language error goes to
stdout, `plcc-rep` exits 0, and evaluation continues to the next expression.

### Expected test counts

**Measured baseline (2026-08-11, this worktree): 166 tests, 165 passing and 1
failing** — `not ok 28 OBJ class`, `plccmk: command not found`. Suite exit 1.

This was measured, not carried forward, per the overarching design's own
warning. Two traps it avoids: TYPE1's design projected 166, which is right by
coincidence, since `bin/` gained tests afterward; and a static count of `@test`
lines gives 174, because some `@test` lines live inside heredoc fixtures in
`bin/tests/` rather than being real tests.

After this phase: **186 tests, 186 passing, 0 failing** — 166, minus OBJ's 1 old
test, plus 21 (7 cases × 3 targets).

The load-bearing invariants are the deltas, not the totals: the
`plccmk: command not found` count must drop to **zero**, and no test that passed
before may fail after. Nothing in this phase touches an already-passing
language, so any V-prefixed, SET, REF, NAME, NEED, TYPE0, or TYPE1 failure is a
genuine regression.

## Example Programs

OBJ ships 56 example files across four directories — `Prog/` (43), `PPP/` (7),
`Examples/` (7), `BST/` (2) — where every other language has one. All four stay
where they are: they are course material, instructors may link to their paths,
and TYPE1's `J/` precedent says a pre-existing structural oddity is not this
phase's to resolve.

**All 56 are run under a throwaway script across all three targets, asserting
byte-identity.** Any example that cannot run is diagnosed and recorded in this
document rather than quietly skipped.

One constraint bounds what that verification proves: **old PLCC is not installed
in this devcontainer**, so unlike a normal port there is no pre-migration oracle
to diff against. "Runs unmodified" can only be judged by cross-target
byte-identity plus reading the source for intent. Cross-target identity across
56 programs remains a strong signal — OBJ has more surface area than any other
language, and three independent implementations agreeing is hard to achieve by
accident.

`BST/123` and `PPP/shape` are the two worth watching: the first nests
`class extends let … in class …` three deep and reads `<!@>t` at each level; the
second exercises inheritance, `super`, field shadowing, and both message-send
forms.

### Results (measured 2026-08-12)

The throwaway script (`/tmp/obj-examples.sh`, per Task 5 of the implementation
plan) ran every file in `Prog/`, `Examples/`, `PPP/`, and `BST/` through
`plcc-rep` under all three targets and compared stdout byte-for-byte.

**Correction to the count above:** the per-directory tally in this section
(`43 + 7 + 7 + 2`) is **59**, not 56 — `find Prog Examples PPP BST -maxdepth 1
-type f | wc -l` confirms 59 regular files. The "56" figure predates this
measurement and was never re-added; the individual directory counts it sits
next to were already correct.

**58 of 59 ran byte-identical across Python, Java, and JavaScript. Zero
diverged. One exited nonzero on one target:**

| file | python | java | js | cause |
|---|---|---|---|---|
| `Prog/oe` | exit 1, `RecursionError: maximum recursion depth exceeded` | exit 0, `1` | exit 0, `1` | known issue [#19](../issues/019-python-recursion-ceiling.md) (Python recursion ceiling) |

`Prog/oe` defines mutually-recursive statics `odd?`/`even?` and calls
`.<c>even?(1000)` — about 1,000 language-level calls, comfortably inside
issue #19's measured Java/JavaScript ceiling (~2,800) but well past its
measured Python ceiling (~330). Java and JavaScript both return `1`,
matching the mathematical answer (`even?(1000)` is true), so the two targets
that complete agree with each other; Python is not wrong, it just runs out
of interpreter stack first, exactly as #19 describes. This is not a porting
defect — it is not fixed, and `Prog/oe` is left unmodified per the brief.

No other file needed input the harness does not supply and none is a bare
fragment that failed to run — `BST/123`, `Prog/List(1)`, and `Prog/String(1)`
(flagged in the brief as possibly editor backups or non-standalone fragments)
all ran to completion and produced byte-identical output on all three
targets, so they are counted as `ok` rather than as exceptions.

Cross-target identity across 58 of 59 programs, with the sole exception fully
attributed to an already-tracked, already-understood inherited issue, is the
fidelity evidence this phase set out to gather: three independent
implementations, transliterated separately from `src/SET/`'s shipped port,
agree on every example except where CPython's own stack depth is the limiting
factor rather than anything in the port.

## Bookkeeping (in the same commits as the work)

- File the OBJ issue with `bin/issues/new.bash migrate-obj-to-plcc-ng feat` and
  add its roadmap entry in the same commit; close it with
  `bin/issues/close.bash` as the branch's final commit.
- File the two `**Target:** ourPLCC/plcc-ng` issues described
  [above](#two-issues-filed-upstream), type `chore`, with roadmap entries.
- **No `src/Env/` work this phase** — no port, no deletion.
- Delete the old flat old-PLCC files
  `src/OBJ/{grammar,code,prim,envRef,val,ref,class,list,listVal,listPrim,FILES}`
  once the three targets pass. None collides with a new path
  (`src/OBJ/grammar` versus `src/OBJ/grammar.plcc`), so this deletion comes at
  the end — the REF, NAME, NEED, TYPE0, and TYPE1 ordering, not SET's.
- Log OBJ entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change:
  - the `VAR` → `SYMBOL` token rename and `var` → `symbol` field rename;
  - `$run()` → `_run()` returning a string instead of printing;
  - `Program.initEnv` → `Program.env`, matching the six shipped predecessors;
  - `Val.nil` → `Val.nil()`, `ListVal.empty` → `ListVal.empty()`, and
    `EnvClass.envClass` → `EnvClass.envClass()`;
  - `Val.apply(valList)` → `Val.apply(valList, env)`;
  - **buffered output** — `display`, `display#`, `newline`, `putc`, `puts`, and
    `@@` now accumulate into `Program.out` and are emitted by `_run()`, because
    a partial line written to stdout deadlocks `plcc-rep`. Observable behaviour
    is unchanged; the mechanism is not, and it is the thing a student extending
    OBJ with a new output form must know;
  - **`exit`** now ends `plcc-rep` with `interpreter exited unexpectedly` on
    stderr and status 1, where old PLCC's `rep` ended cleanly;
  - the reserved-ID check moving from `Env.checkDuplicates` to a `Reserved`
    class called explicitly at five sites;
  - the seven-case test suite replacing the single `class` case.

## What This Phase Unblocks But Does Not Do

- Issue [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) (CI) is
  explicitly "deferred until every language has migrated." That becomes true
  here, so #12 is actionable immediately after this phase.
- Issue [#27](../issues/027-use-spec-flag-instead-of-copying-tree.md) states
  "the 3 legacy `plccmk` languages still need `relocate`." That is already stale
   — measured, exactly **one** `.bats` file still references `plccmk`
  (`src/OBJ/tests/class/OBJtest.bats`) — and after this phase it is zero, so
  `relocate` could be retired entirely rather than coexisting. Also worth
  recording there before anyone builds on it: `plcc-rep -s` is **sticky**, i.e.
  remembered for subsequent runs in the same directory, which was observed live
  during this phase's spike.

## Out of Scope

- Any change to `envRef` or to `src/Env/`.
- Implementing the plcc-ng protocol extension. It is filed upstream with a
  design sketch; OBJ does not block on it.
- Consolidating or deduplicating the four example directories.
- Reporting either plcc-ng issue publicly outside this repository without
  explicit confirmation, per the Defect Tracking process.
- Any unification of the per-language `Val`/`IntVal`/`Prim`/`Ref` duplication —
  ruled out repo-wide by the overarching design.
- Issues [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md),
  [#16](../issues/016-cross-target-integer-divergence.md),
  [#19](../issues/019-python-recursion-ceiling.md),
  [#22](../issues/022-plcc-rep-parses-each-source-independently.md), and
  [#27](../issues/027-use-spec-flag-instead-of-copying-tree.md) — all repo-wide
  and inherited.

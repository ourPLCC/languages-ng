# plcc-ng Phase 3 — SET Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port SET (`V6 + references/set`) to plcc-ng in Python, Java, and JavaScript, and port the shared `envRef` Env variant that REF, NAME, and NEED will reuse.

**Architecture:** SET is V6 plus one token, one grammar production, and one level of indirection: bindings hold a `Ref` rather than a `Val`, so `set` can mutate a binding in place. Each target gets `src/SET/<target>/spec.plcc`, all three `%include`ing one `src/SET/grammar.plcc` and one `src/Env/envRef/<target>/env.plcc`. A preliminary task retro-fits Java's `Prim.apply` in V1–V6 to the array shape so all three targets index operands alike.

**Tech Stack:** plcc-ng (`plcc-rep`), bats (`bin/test.bash`), Python 3, Java, Node.js.

**Design of record:** [dev-docs/specs/2026-08-04-plcc-ng-set-design.md](../specs/2026-08-04-plcc-ng-set-design.md). Read it before Task 1.

## Global Constraints

- **Work in the existing worktree** `/workspaces/languages-ng/.claude/worktrees/spec-envref-correction`, branch `worktree-spec-envref-correction`. Do not create a new worktree.
- **Baseline, measured 2026-08-04:** `bin/test.bash` gives **70 tests, 63 passing, 7 failing**. The 7 failures are NAME, NEED, OBJ, REF, SET, TYPE0, TYPE1 — all `plccmk: command not found`. Count with `grep -c '^ok '` and `grep -c '^not ok '` over the **whole** run, never a `tail`.
- **No test that passes may start failing.** Task 1 touches six passing languages; a `V`-prefixed failure means a regression.
- **`apply` keeps its `Env` parameter** in every target — `apply(args, env)` / `apply(List<Val> args, Env e)`. It is unread at runtime. It is the seam for a dynamic-scoping homework assignment. **Never remove it as dead code.**
- **`checkDuplicates` returns void.** Do not port the `Set<String>` shape from the flat `src/Env/envRef` or from `src/REF/envRef`.
- **Grammar conventions, unchanged from V0–V6:** identifier token is `SYMBOL` (never `VAR`); nonterminals are PascalCase; multi-capture alt-names are camelCase (`<Exp:testExp>`), not the obsolete lowercase workaround.
- **Course-material impact entries go in the same commit as the change they describe**, under the relevant language heading in [dev-docs/course-material-impact.md](../course-material-impact.md). Never batch them.
- **Never assign issue numbers by hand.** Use `bin/issues/new.bash` and `bin/issues/close.bash`.
- Every target's `spec.plcc` writes build artifacts to a `plcc-ng/` subdirectory; `.gitignore` already covers `plcc-ng/` and `__pycache__/`. Never commit them.

---

### Task 1: Java `Prim.apply(Val[] va)` retro-fix for V1–V6

Java currently reads `args.get(0)` / `args.size()` where Python and JavaScript read `args[0]` / `len(args)` / `args.length`. Restoring the array makes all three targets read alike. Behaviorally inert — verified at design time against V6's full suite.

**Files:**
- Modify: `src/V1/java/spec.plcc`, `src/V2/java/spec.plcc`, `src/V3/java/spec.plcc`, `src/V4/java/spec.plcc`, `src/V5/java/spec.plcc`, `src/V6/java/spec.plcc`
- Modify: `dev-docs/course-material-impact.md`
- Create: `dev-docs/issues/0NN-migrate-set-to-plcc-ng.md` (number assigned by the script)
- Modify: `dev-docs/roadmap.md`
- Test: the existing suite — `bin/test.bash`

**Interfaces:**
- Consumes: nothing.
- Produces: `Val.toArray(List<Val>) -> Val[]` as a public static on Java's `Val` in V1–V6, and `Prim.apply(Val[] va)` as the Java prim signature. Task 3 writes SET's Java spec in this same shape.

- [ ] **Step 1: File the SET issue and its roadmap entry**

```bash
cd /workspaces/languages-ng/.claude/worktrees/spec-envref-correction
bin/issues/new.bash migrate-set-to-plcc-ng feat
```

Fill in the issue body describing the SET port (grammar, three targets, the `envRef` port shared with REF/NAME/NEED, four test cases), and add the matching bullet to the **Open Issues → Feat** section of `dev-docs/roadmap.md`. Leave `**Target:**` at its default (`languages-ng`) — this is our own work, not a plcc-ng defect.

- [ ] **Step 2: Capture the baseline**

```bash
bin/test.bash > /tmp/baseline.txt 2>&1
grep -c '^ok ' /tmp/baseline.txt      # expect 63
grep -c '^not ok ' /tmp/baseline.txt  # expect 7
```

Expected: `63` and `7`. If either differs, **stop** — the plan's counts are stale and every later task's expectation is wrong.

- [ ] **Step 3: Commit the issue and roadmap entry**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): file SET migration issue, update roadmap"
```

- [ ] **Step 4: Add `Val.toArray` to each of V1–V6's Java `Val`**

In each `src/V{1..6}/java/spec.plcc`, inside the `Val` block, add the static helper as the first member of the class. V6's `Val` block becomes:

```java
Val
%%%
import java.util.List;
import runtime.LanguageError;

public abstract class Val {

    public static Val [] toArray(List<Val> valList) {
        int n = valList.size();
        return valList.toArray(new Val[n]);
    }

    public Val apply(List<Val> args, Env e) {
        throw new LanguageError("Cannot apply " + this);
    }

    public boolean isTrue() {
        return true;
    }

    public IntVal intVal() {
        throw new LanguageError(this + ": not an Int");
    }
}
%%%
```

V1–V5's `Val` blocks differ in their other members (V1 and V2 have no `apply` at all — they have no procs). Add only `toArray`, changing nothing else. `import java.util.List;` is already present in every one of them because `apply` or another member needs it; if a given `Val` block lacks it, add it.

- [ ] **Step 5: Convert the `Prim` signatures in each of V1–V6**

In each `src/V{1..6}/java/spec.plcc`:

- The abstract declaration in the `Prim` block:

```java
Prim
%%%
public abstract Val apply(Val [] va);
%%%
```

- Each of the seven concrete prims (`AddPrim`, `SubPrim`, `MulPrim`, `DivPrim`, `Add1Prim`, `Sub1Prim`, `ZeropPrim`). `AddPrim` in full:

```java
AddPrim
%%%
public String toString() {
    return "+";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new IntVal(i0 + i1);
}
%%%
```

The mechanical rule for the other six: `public Val apply(List<Val> args) {` → `public Val apply(Val [] va) {`; `args.size() != N` → `va.length != N`; `args.get(0)` → `va[0]`; `args.get(1)` → `va[1]`. Change nothing else — not the messages, not the `IntVal` construction, not `DivPrim`'s divide-by-zero guard.

- [ ] **Step 6: Convert `PrimappExp.eval` in each of V1–V6**

```java
PrimappExp
%%%
public Val eval(Env env) {
    List<Val> args = rands.evalRands(env);
    Val [] va = Val.toArray(args);
    return prim.apply(va);
}

public String toString() {
    return prim + "(" + rands + ")";
}
%%%
```

V1's and V2's `PrimappExp` blocks have the same `eval` but may differ in `toString`; leave `toString` alone.

Do **not** touch `src/V0/java/spec.plcc`. V0's semantic section is `toString()`s only and has no `Prim.apply`.

Do **not** touch any Python or JavaScript spec. Their lists and arrays already index natively.

- [ ] **Step 7: Run the full suite**

```bash
bin/test.bash > /tmp/after-task1.txt 2>&1
grep -c '^ok ' /tmp/after-task1.txt      # expect 63
grep -c '^not ok ' /tmp/after-task1.txt  # expect 7
grep '^not ok ' /tmp/after-task1.txt
```

Expected: **70 tests, 63 passing, 7 failing**, unchanged from baseline, and the 7 failures are still exactly NAME, NEED, OBJ, REF, SET, TYPE0, TYPE1. Any `V`-prefixed failure is a regression in this task — fix it before committing.

- [ ] **Step 8: Add the course-material impact entries**

Add one entry under **each** of the `## V1` … `## V6` headings in `dev-docs/course-material-impact.md`. Same text under each, with the language name adjusted:

```markdown
- Java's `Prim.apply` now takes `Val [] va` rather than `List<Val> args`,
  with `Val.toArray` restoring the array from the list in
  `PrimappExp.eval`. Operand access is `va[0]` / `va.length`, matching
  Python's `args[0]` / `len(args)` and JavaScript's `args[0]` /
  `args.length`. Course material walking through a primitive's `apply` can
  now use one indexing idiom across all three target appendices instead of
  Java's `args.get(0)` / `args.size()`.
```

- [ ] **Step 9: Commit**

```bash
git add src/V1 src/V2 src/V3 src/V4 src/V5 src/V6 dev-docs/course-material-impact.md
git commit -m "refactor(V1-V6): Java Prim.apply takes Val[] to match Python/JS indexing"
```

---

### Task 2: `envRef` (Python) + SET grammar + SET Python target

Delivers the shared grammar, the Python `envRef`, the Python `spec.plcc`, and all four test cases with their Python `@test` blocks.

**Files:**
- Delete: `src/Env/envRef` (the flat old-PLCC file — it occupies the path the new directory needs)
- Create: `src/Env/envRef/python/env.plcc`
- Create: `src/SET/grammar.plcc`
- Create: `src/SET/python/spec.plcc`
- Modify: `src/SET/tests/let/SETtest.bats` (replace the old `plccmk`/`rep` invocation)
- Create: `src/SET/tests/counter/SET.input`, `.../SET.expected`, `.../SETtest.bats`
- Create: `src/SET/tests/formal-is-a-copy/SET.input`, `.../SET.expected`, `.../SETtest.bats`
- Create: `src/SET/tests/define-then-set/SET.input`, `.../SET.expected`, `.../SETtest.bats`
- Modify: `dev-docs/course-material-impact.md`
- Test: `bats --recursive src/SET/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: nothing from Task 1 (that task is Java-only).
- Produces:
  - `src/SET/grammar.plcc`, `%include`d by all three targets.
  - `src/Env/envRef/python/env.plcc` exposing `Env.checkDuplicates(symbolList, msg="")` (returns `None`), `Env.initEnv()`, `Env.lookup(sym) -> Binding|None`, `Env.applyEnvRef(sym) -> Ref`, `Env.applyEnv(sym) -> Val`, `Env.extendEnvRef(bindings) -> Env`, `Env.add(binding) -> Env`, `Binding(id, ref)` with fields `.id`/`.ref`, `Bindings(idList=None, refList=None)` with `.lookup`/`.add`/`.size`.
  - `Ref.valsToRefs(valList) -> list[ValRef]`, `Ref.deRef() -> Val`, `Ref.setRef(v) -> Val`, `ValRef(val)` — defined inside `src/SET/python/spec.plcc`, per language, not shared.
  - The four test case directories, which Tasks 3 and 4 append `@test` blocks to.

- [ ] **Step 1: Delete the flat `src/Env/envRef` and write the four test cases**

The flat file must go first — it sits exactly where `src/Env/envRef/` must be created.

```bash
git rm src/Env/envRef
```

Then create the three new case directories. `src/SET/tests/let/` already has `SET.input` and `SET.expected`; leave both exactly as they are.

`src/SET/tests/counter/SET.input` (from `src/SET/Prog/g`):

```
let
  g = let count = 0 in proc() set count = add1(count)
in
  { .g() ; .g() ; .g() }
```

`src/SET/tests/counter/SET.expected`:

```
3
```

`src/SET/tests/formal-is-a-copy/SET.input`:

```
let
    x = 3
    p = proc(t) set t = add1(t)
in
    { .p(x) ; x }
```

`src/SET/tests/formal-is-a-copy/SET.expected`:

```
3
```

`src/SET/tests/define-then-set/SET.input`:

```
define x = 1
set x = 2
x
```

`src/SET/tests/define-then-set/SET.expected`:

```
x
2
2
```

- [ ] **Step 2: Write the four bats files, Python block only**

Replace `src/SET/tests/let/SETtest.bats` entirely with:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/let/SET.input)"
  expected_output=$(< "../tests/let/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Create the other three the same way, substituting the case name in both the `@test` description and the two paths. `src/SET/tests/counter/SETtest.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET counter (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/counter/SET.input)"
  expected_output=$(< "../tests/counter/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

`src/SET/tests/formal-is-a-copy/SETtest.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET formal-is-a-copy (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/formal-is-a-copy/SET.input)"
  expected_output=$(< "../tests/formal-is-a-copy/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

`src/SET/tests/define-then-set/SETtest.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "SET define-then-set (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/define-then-set/SET.input)"
  expected_output=$(< "../tests/define-then-set/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 3: Run the SET tests to verify they fail**

```bash
bats --recursive src/SET/tests
```

Expected: 4 tests, all FAIL — `cd python` has no directory to enter, since `src/SET/python/` does not exist yet.

- [ ] **Step 4: Write `src/Env/envRef/python/env.plcc`**

```python
Env
%%%
from Bindings import Bindings
from runtime.base import LanguageError

# Environment-related classes
#
# envRef is envVal with one level of indirection: a Binding holds a Ref
# rather than a Val, so a binding's value can be mutated in place by
# `set`. applyEnvRef is the primitive; applyEnv is derived from it.
#
# checkDuplicates returns None. That is the majority shape across the
# seven languages that use envRef, and no caller anywhere in src/ uses a
# return value from it. Do not restore the Set-returning variant that the
# old flat src/Env/envRef and src/REF/envRef carried.


class Env:

    @staticmethod
    def checkDuplicates(symbolList, msg=""):
        seen = set()
        for sym in symbolList:
            s = sym.lexeme
            if s in seen:
                raise LanguageError("duplicate ID " + s + msg)
            seen.add(s)

    @staticmethod
    def initEnv():
        from EnvNode import EnvNode
        from EnvNull import EnvNull
        return EnvNode(Bindings(), EnvNull())

    def lookup(self, sym):
        raise NotImplementedError

    def applyEnvRef(self, sym):
        raise NotImplementedError

    def applyEnv(self, sym):
        return self.applyEnvRef(sym).deRef()

    def extendEnvRef(self, bindings):
        from EnvNode import EnvNode
        return EnvNode(bindings, self)

    def add(self, binding):
        raise NotImplementedError
%%%

EnvNode
%%%
from Env import Env


class EnvNode(Env):

    def __init__(self, bindings, env):
        self.bindings = bindings
        self.env = env

    def lookup(self, sym):
        return self.bindings.lookup(sym)

    def applyEnvRef(self, sym):
        b = self.bindings.lookup(sym)
        if b is None:
            return self.env.applyEnvRef(sym)
        return b.ref

    def add(self, binding):
        self.bindings.add(binding)
        return self

    def __str__(self):
        return f"{self.bindings}----\n{self.env}"
%%%

EnvNull
%%%
from Env import Env
from runtime.base import LanguageError


class EnvNull(Env):

    def applyEnvRef(self, sym):
        raise LanguageError("no binding for " + sym)

    def lookup(self, sym):
        return None

    def add(self, binding):
        raise LanguageError("no bindings to add to")

    def __str__(self):
        return "\n"
%%%

Binding
%%%
class Binding:

    def __init__(self, id, ref):
        self.id = id
        self.ref = ref

    def __str__(self):
        return f"[{self.id}:{self.ref.deRef()}]"
%%%

Bindings
%%%
from Binding import Binding
from runtime.base import LanguageError


class Bindings:

    def __init__(self, idList=None, refList=None):
        self.bindingList = []
        if idList is not None:
            if refList is None or len(idList) != len(refList):
                raise LanguageError("list sizes mismatch")
            for sym, r in zip(idList, refList):
                self.bindingList.append(Binding(sym.lexeme, r))

    def lookup(self, sym):
        for b in self.bindingList:
            if sym == b.id:
                return b
        return None

    def add(self, binding):
        self.bindingList.append(binding)

    def size(self):
        return len(self.bindingList)

    def __str__(self):
        s = ""
        for b in self.bindingList:
            s += f"{b}\n"
        return s
%%%
```

- [ ] **Step 5: Write `src/SET/grammar.plcc`**

Copy `src/V6/grammar.plcc` and make exactly two additions — `token SET 'set'` after `token PROC 'proc'`, and the `SetExp` production after `SeqExp`:

```
# Language SET
#   Language V6 with references/set
skip WHITESPACE '\s+'
skip COMMENT '%.*'
token LIT '\d+'
token LPAREN '\('
token RPAREN '\)'
token COMMA ','
token ADDOP '\+'
token SUBOP '\-'
token MULOP '\*'
token DIVOP '/'
token ADD1OP 'add1'
token SUB1OP 'sub1'
token ZEROP 'zero\?'
token IF 'if'
token THEN 'then'
token ELSE 'else'
token LET 'let'
token LETREC 'letrec'
token DEFINE 'define'
token IN 'in'
token EQUALS '='
token PROC 'proc'
token SET 'set'
token DOT '\.'
token LBRACE '\{'
token RBRACE '\}'
token SEMI ';'
token SYMBOL '[A-Za-z][\w?]*'
%
<Program:Define> ::= DEFINE <SYMBOL> EQUALS <Exp>
<Program:Eval>   ::= <Exp>
<Exp:LitExp>     ::= <LIT>
<Exp:VarExp>     ::= <SYMBOL>
<Exp:IfExp>      ::= IF <Exp:testExp> THEN <Exp:trueExp> ELSE <Exp:falseExp>
<Exp:PrimappExp> ::= <Prim> LPAREN <Rands> RPAREN
<Exp:LetExp>     ::= LET <LetDecls> IN <Exp>
<Exp:LetrecExp>  ::= LETREC <LetDecls> IN <Exp>
<Exp:ProcExp>    ::= <Proc>
<Exp:AppExp>     ::= DOT <Exp> LPAREN <Rands> RPAREN
<Exp:SeqExp>     ::= LBRACE <Exp> <SeqExps> RBRACE
<Exp:SetExp>     ::= SET <SYMBOL> EQUALS <Exp>
<SeqExps>        **= SEMI <Exp>
<Proc>           ::= PROC LPAREN <Formals> RPAREN <Exp>
<Formals>        **= <SYMBOL> +COMMA
<LetDecls>       **= <SYMBOL> EQUALS <Exp>
<Rands>          **= <Exp> +COMMA
<Prim:AddPrim>   ::= ADDOP
<Prim:SubPrim>   ::= SUBOP
<Prim:MulPrim>   ::= MULOP
<Prim:DivPrim>   ::= DIVOP
<Prim:Add1Prim>  ::= ADD1OP
<Prim:Sub1Prim>  ::= SUB1OP
<Prim:ZeropPrim> ::= ZEROP
```

- [ ] **Step 6: Write `src/SET/python/spec.plcc`**

Start from a copy of `src/V6/python/spec.plcc`, then apply the six changes below. Every other block — `IntVal`, `Eval`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`, `LetrecExp`, `ProcExp`, `Proc`, `Formals`, `AppExp`, `SeqExp`, `Rands`, `Val`, and all seven `Prim`s — is copied verbatim.

**(a)** The `%include` line:

```
%include ../../Env/envRef/python/env.plcc
```

**(b)** Insert `Ref` and `ValRef` blocks between `IntVal` and `ProcVal`:

```python
Ref
%%%
class Ref:

    @staticmethod
    def valsToRefs(valList):
        from ValRef import ValRef
        return [ValRef(v) for v in valList]

    def deRef(self):
        raise NotImplementedError

    def setRef(self, v):
        raise NotImplementedError
%%%

ValRef
%%%
from Ref import Ref


class ValRef(Ref):

    def __init__(self, val):
        self.val = val

    def deRef(self):
        return self.val

    def setRef(self, v):
        self.val = v
        return v

    def __str__(self):
        return str(self.val)
%%%
```

**(c)** Replace the `ProcVal` block. Note `apply` keeps its `env` parameter:

```python
ProcVal
%%%
from Bindings import Bindings
from Ref import Ref
from Val import Val
from runtime.base import LanguageError


class ProcVal(Val):

    def __init__(self, formals, body, env):
        self.formals = formals
        self.body = body
        self.env = env

    def apply(self, args, env):
        if len(self.formals.symbolList) != len(args):
            raise LanguageError("formals/args number mismatch")
        refList = Ref.valsToRefs(args)
        bindings = Bindings(self.formals.symbolList, refList)
        nenv = self.env.extendEnvRef(bindings)
        return self.body.eval(nenv)

    def __str__(self):
        return "proc"
%%%
```

**(d)** Replace the `Define:import` and `Define` blocks:

```python
Define:import
%%%
from Binding import Binding
from ValRef import ValRef
%%%

Define
%%%
def _run(self):
    env = Program.env
    s = self.symbol.lexeme
    val = self.exp.eval(env)
    ref = ValRef(val)
    b = env.lookup(s)
    if b is not None:
        b.ref = ref
    else:
        env.add(Binding(s, ref))
    return s
%%%
```

**(e)** Replace the `LetDecls:import` and `LetDecls` blocks. `LetDecls:init` is unchanged:

```python
LetDecls:import
%%%
from Env import Env
from Binding import Binding
from Bindings import Bindings
from Ref import Ref
from ValRef import ValRef
%%%

LetDecls:init
%%%
Env.checkDuplicates(self.symbolList, " in let/letrec LHS identifiers")
%%%

LetDecls
%%%
def addBindings(self, env):
    valList = [e.eval(env) for e in self.expList]
    refList = Ref.valsToRefs(valList)
    bindings = Bindings(self.symbolList, refList)
    return env.extendEnvRef(bindings)

def addLetrecBindings(self, env):
    env = env.extendEnvRef(Bindings())
    for sym, e in zip(self.symbolList, self.expList):
        val = e.eval(env)
        env.add(Binding(sym.lexeme, ValRef(val)))
    return env

def __str__(self):
    return " ...LetDecls... "
%%%
```

**(f)** Add a `SetExp` block immediately after `SeqExp`:

```python
SetExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    ref = env.applyEnvRef(self.symbol.lexeme)
    return ref.setRef(v)

def __str__(self):
    return " ...SetExp... "
%%%
```

- [ ] **Step 7: Run the SET tests to verify they pass**

```bash
bats --recursive src/SET/tests
```

Expected: 4 tests, all PASS.

If a test fails, run the case by hand for the real error — bats swallows it:

```bash
cd src/SET/python && plcc-rep < ../tests/counter/SET.input
```

- [ ] **Step 8: Run `Prog/g` against the Python target**

```bash
cd src/SET/python && plcc-rep < ../Prog/g
```

Expected: `3`. This is the same program as `tests/counter/`, run as a program rather than through bats.

- [ ] **Step 9: Run the full suite**

```bash
bin/test.bash > /tmp/after-task2.txt 2>&1
grep -c '^ok ' /tmp/after-task2.txt      # expect 67
grep -c '^not ok ' /tmp/after-task2.txt  # expect 6
grep '^not ok ' /tmp/after-task2.txt
```

Expected: **73 tests, 67 passing, 6 failing**. The old `SET let` failure is gone; the remaining 6 are NAME, NEED, OBJ, REF, TYPE0, TYPE1.

- [ ] **Step 10: Add the course-material impact entries**

Add a `## SET` heading to `dev-docs/course-material-impact.md`, after `## V6` (headings go in migration order), with these entries:

```markdown
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
```

- [ ] **Step 11: Commit**

```bash
git add src/Env src/SET dev-docs/course-material-impact.md
git commit -m "feat(SET): port envRef and SET to plcc-ng (python)"
```

---

### Task 3: `envRef` (Java) + SET Java target

**Files:**
- Create: `src/Env/envRef/java/env.plcc`
- Create: `src/SET/java/spec.plcc`
- Modify: all four `src/SET/tests/*/SETtest.bats` (append a Java `@test`)
- Test: `bats --recursive src/SET/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/SET/grammar.plcc` and the four test cases from Task 2; the `Val.toArray` / `Prim.apply(Val [] va)` shape from Task 1.
- Produces: `src/Env/envRef/java/env.plcc` exposing `Env.checkDuplicates(List<Token>, String)` and `(List<Token>)` returning `void`, `Env.initEnv()`, `abstract Binding lookup(String)`, `abstract Ref applyEnvRef(String)`, `Val applyEnv(String)`, `Env extendEnvRef(Bindings)`, `abstract Env add(Binding)`; `Binding(String id, Ref ref)`; `Bindings()` and `Bindings(List<Token> idList, List<Ref> refList)`. Plus `Ref.valsToRefs(List<Val>) -> List<Ref>` and `ValRef` inside `src/SET/java/spec.plcc`.

- [ ] **Step 1: Append a Java `@test` to each of the four bats files**

Append to `src/SET/tests/let/SETtest.bats`:

```bash

@test "SET let (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/let/SET.input)"
  expected_output=$(< "../tests/let/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append the same block to the other three, substituting the case name in the description and both paths — `counter`, `formal-is-a-copy`, `define-then-set`.

- [ ] **Step 2: Run the SET tests to verify the new ones fail**

```bash
bats --recursive src/SET/tests
```

Expected: 8 tests — the 4 Python ones PASS, the 4 Java ones FAIL (`cd java`: no such directory).

- [ ] **Step 3: Write `src/Env/envRef/java/env.plcc`**

```java
Env
%%%
import java.util.*;
import runtime.Token;
import runtime.LanguageError;

// Environment-related classes
//
// envRef is envVal with one level of indirection: a Binding holds a Ref
// rather than a Val, so a binding's value can be mutated in place by
// `set`. applyEnvRef is the primitive; applyEnv is derived from it.
//
// checkDuplicates returns void. That is the majority shape across the
// seven languages that use envRef, and no caller anywhere in src/ uses a
// return value from it. Do not restore the Set-returning variant that the
// old flat src/Env/envRef and src/REF/envRef carried.
//
// This is a free-standing class in the default package, so it must import
// runtime.Token explicitly (grammar-derived classes get it auto-injected).

public abstract class Env {

    public static void checkDuplicates(List<Token> symbolList, String msg) {
        Set<String> seen = new HashSet<String>();
        for (Token sym : symbolList) {
            String s = sym.lexeme;
            if (seen.contains(s))
                throw new LanguageError("duplicate ID " + s + msg);
            seen.add(s);
        }
    }

    public static void checkDuplicates(List<Token> symbolList) {
        checkDuplicates(symbolList, "");
    }

    public static Env initEnv() {
        return new EnvNode(new Bindings(), new EnvNull());
    }

    public abstract Binding lookup(String sym);

    public abstract Ref applyEnvRef(String sym);

    public Val applyEnv(String sym) {
        return applyEnvRef(sym).deRef();
    }

    public Env extendEnvRef(Bindings bindings) {
        return new EnvNode(bindings, this);
    }

    public abstract Env add(Binding b);
}
%%%

EnvNode
%%%
public class EnvNode extends Env {

    public Bindings bindings;
    public Env env;

    public EnvNode(Bindings bindings, Env env) {
        this.bindings = bindings;
        this.env = env;
    }

    public Binding lookup(String sym) {
        return bindings.lookup(sym);
    }

    public Ref applyEnvRef(String sym) {
        Binding b = bindings.lookup(sym);
        if (b == null)
            return env.applyEnvRef(sym);
        return b.ref;
    }

    public Env add(Binding b) {
        bindings.add(b);
        return this;
    }

    public String toString() {
        return bindings.toString() + "----\n" + env;
    }
}
%%%

EnvNull
%%%
import runtime.LanguageError;

public class EnvNull extends Env {

    public Ref applyEnvRef(String sym) {
        throw new LanguageError("no binding for " + sym);
    }

    public Binding lookup(String sym) {
        return null;
    }

    public Env add(Binding b) {
        throw new LanguageError("no bindings to add to");
    }

    public String toString() {
        return "\n";
    }
}
%%%

Binding
%%%
public class Binding {

    public String id;
    public Ref ref;

    public Binding(String id, Ref ref) {
        this.id = id;
        this.ref = ref;
    }

    public String toString() {
        return "[" + id + ":" + ref.deRef() + "]";
    }
}
%%%

Bindings
%%%
import java.util.*;
import runtime.Token;
import runtime.LanguageError;

public class Bindings {

    public List<Binding> bindingList;

    public Bindings() {
        bindingList = new ArrayList<Binding>();
    }

    public Bindings(List<Token> idList, List<Ref> refList) {
        if (idList.size() != refList.size())
            throw new LanguageError("list sizes mismatch");
        bindingList = new ArrayList<Binding>(idList.size());
        for (int i = 0; i < idList.size(); i++)
            bindingList.add(new Binding(idList.get(i).lexeme, refList.get(i)));
    }

    public Binding lookup(String sym) {
        for (Binding b : bindingList)
            if (sym.equals(b.id))
                return b;
        return null;
    }

    public void add(Binding b) {
        bindingList.add(b);
    }

    public int size() {
        return bindingList.size();
    }

    public String toString() {
        String s = "";
        for (Binding b : bindingList)
            s += b + "\n";
        return s;
    }
}
%%%
```

- [ ] **Step 4: Write `src/SET/java/spec.plcc`**

Start from a copy of `src/V6/java/spec.plcc` **as Task 1 left it** (array-shaped prims), then apply the six changes below. Every other block is copied verbatim. Java free-standing classes are same-directory and package-less, so none of them needs an `:import` block.

**(a)** The `%include` line:

```
%include ../../Env/envRef/java/env.plcc
```

**(b)** Insert `Ref` and `ValRef` blocks between `IntVal` and `ProcVal`:

```java
Ref
%%%
import java.util.ArrayList;
import java.util.List;

public abstract class Ref {

    public static List<Ref> valsToRefs(List<Val> valList) {
        List<Ref> refList = new ArrayList<Ref>(valList.size());
        for (Val v : valList)
            refList.add(new ValRef(v));
        return refList;
    }

    public abstract Val deRef();

    public abstract Val setRef(Val v);
}
%%%

ValRef
%%%
public class ValRef extends Ref {

    public Val val;

    public ValRef(Val val) {
        this.val = val;
    }

    public Val deRef() {
        return val;
    }

    public Val setRef(Val v) {
        val = v;
        return v;
    }

    public String toString() {
        return val.toString();
    }
}
%%%
```

**(c)** Replace the `ProcVal` block. `apply` keeps its `Env e` parameter:

```java
ProcVal
%%%
import java.util.List;
import runtime.LanguageError;

public class ProcVal extends Val {

    public Formals formals;
    public Exp body;
    public Env env;

    public ProcVal(Formals formals, Exp body, Env env) {
        this.formals = formals;
        this.body = body;
        this.env = env;
    }

    public Val apply(List<Val> args, Env e) {
        if (formals.symbolList.size() != args.size())
            throw new LanguageError("formals/args number mismatch");
        List<Ref> refList = Ref.valsToRefs(args);
        Bindings bindings = new Bindings(formals.symbolList, refList);
        Env nenv = env.extendEnvRef(bindings);
        return body.eval(nenv);
    }

    public String toString() {
        return "proc";
    }
}
%%%
```

**(d)** Replace the `Define` block:

```java
Define
%%%
public String _run() {
    Env env = Program.env;
    String s = symbol.lexeme;
    Val val = exp.eval(env);
    Ref ref = new ValRef(val);
    Binding b = env.lookup(s);
    if (b != null)
        b.ref = ref;
    else
        env.add(new Binding(s, ref));
    return s;
}
%%%
```

**(e)** Replace the `LetDecls` block. `LetDecls:import` (`import java.util.ArrayList;`) and `LetDecls:init` are unchanged:

```java
LetDecls
%%%
public Env addBindings(Env env) {
    List<Val> valList = new ArrayList<Val>(expList.size());
    for (Exp e : expList)
        valList.add(e.eval(env));
    List<Ref> refList = Ref.valsToRefs(valList);
    Bindings bindings = new Bindings(symbolList, refList);
    return env.extendEnvRef(bindings);
}

public Env addLetrecBindings(Env env) {
    env = env.extendEnvRef(new Bindings());
    for (int i = 0; i < symbolList.size(); i++) {
        Val val = expList.get(i).eval(env);
        env.add(new Binding(symbolList.get(i).lexeme, new ValRef(val)));
    }
    return env;
}

public String toString() {
    return " ...LetDecls... ";
}
%%%
```

**(f)** Add a `SetExp` block immediately after `SeqExp`:

```java
SetExp
%%%
public Val eval(Env env) {
    Val v = exp.eval(env);
    Ref ref = env.applyEnvRef(symbol.lexeme);
    return ref.setRef(v);
}

public String toString() {
    return " ...SetExp... ";
}
%%%
```

- [ ] **Step 5: Run the SET tests to verify they pass**

```bash
bats --recursive src/SET/tests
```

Expected: 8 tests, all PASS.

- [ ] **Step 6: Run `Prog/g` against the Java target**

```bash
cd src/SET/java && plcc-rep < ../Prog/g
```

Expected: `3`.

- [ ] **Step 7: Run the full suite**

```bash
bin/test.bash > /tmp/after-task3.txt 2>&1
grep -c '^ok ' /tmp/after-task3.txt      # expect 71
grep -c '^not ok ' /tmp/after-task3.txt  # expect 6
```

Expected: **77 tests, 71 passing, 6 failing**.

- [ ] **Step 8: Commit**

```bash
git add src/Env src/SET
git commit -m "feat(SET): add Java target and envRef/java"
```

---

### Task 4: `envRef` (JavaScript) + SET JavaScript target

**Files:**
- Create: `src/Env/envRef/javascript/env.plcc`
- Create: `src/SET/javascript/spec.plcc`
- Modify: all four `src/SET/tests/*/SETtest.bats` (append a JavaScript `@test`)
- Test: `bats --recursive src/SET/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/SET/grammar.plcc` and the four test cases from Task 2.
- Produces: `src/Env/envRef/javascript/env.plcc` exporting `{ Env }`, `{ EnvNode }`, `{ EnvNull }`, `{ Binding }`, `{ Bindings }` with the same member names as the other two targets; `{ Ref }` and `{ ValRef }` inside `src/SET/javascript/spec.plcc`.

- [ ] **Step 1: Append a JavaScript `@test` to each of the four bats files**

Append to `src/SET/tests/let/SETtest.bats`:

```bash

@test "SET let (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/let/SET.input)"
  expected_output=$(< "../tests/let/SET.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append the same block to the other three, substituting the case name in the description and both paths.

- [ ] **Step 2: Run the SET tests to verify the new ones fail**

```bash
bats --recursive src/SET/tests
```

Expected: 12 tests — 8 PASS, the 4 JavaScript ones FAIL.

- [ ] **Step 3: Write `src/Env/envRef/javascript/env.plcc`**

```javascript
Env
%%%
const { Bindings } = require('./Bindings');
const { LanguageError } = require('./runtime/base');

// Environment-related classes
//
// envRef is envVal with one level of indirection: a Binding holds a Ref
// rather than a Val, so a binding's value can be mutated in place by
// `set`. applyEnvRef is the primitive; applyEnv is derived from it.
//
// checkDuplicates returns nothing. That is the majority shape across the
// seven languages that use envRef, and no caller anywhere in src/ uses a
// return value from it.

class Env {

    static checkDuplicates(symbolList, msg = "") {
        const seen = new Set();
        for (const sym of symbolList) {
            const s = sym.lexeme;
            if (seen.has(s))
                throw new LanguageError("duplicate ID " + s + msg);
            seen.add(s);
        }
    }

    static initEnv() {
        const { EnvNode } = require('./EnvNode');
        const { EnvNull } = require('./EnvNull');
        return new EnvNode(new Bindings(), new EnvNull());
    }

    lookup(sym) {
        throw new Error("not implemented");
    }

    applyEnvRef(sym) {
        throw new Error("not implemented");
    }

    applyEnv(sym) {
        return this.applyEnvRef(sym).deRef();
    }

    extendEnvRef(bindings) {
        const { EnvNode } = require('./EnvNode');
        return new EnvNode(bindings, this);
    }

    add(binding) {
        throw new Error("not implemented");
    }
}

module.exports = { Env };
%%%

EnvNode
%%%
const { Env } = require('./Env');

class EnvNode extends Env {

    constructor(bindings, env) {
        super();
        this.bindings = bindings;
        this.env = env;
    }

    lookup(sym) {
        return this.bindings.lookup(sym);
    }

    applyEnvRef(sym) {
        const b = this.bindings.lookup(sym);
        if (b === null)
            return this.env.applyEnvRef(sym);
        return b.ref;
    }

    add(binding) {
        this.bindings.add(binding);
        return this;
    }

    toString() {
        return `${this.bindings}----\n${this.env}`;
    }
}

module.exports = { EnvNode };
%%%

EnvNull
%%%
const { Env } = require('./Env');
const { LanguageError } = require('./runtime/base');

class EnvNull extends Env {

    applyEnvRef(sym) {
        throw new LanguageError("no binding for " + sym);
    }

    lookup(sym) {
        return null;
    }

    add(binding) {
        throw new LanguageError("no bindings to add to");
    }

    toString() {
        return "\n";
    }
}

module.exports = { EnvNull };
%%%

Binding
%%%
class Binding {

    constructor(id, ref) {
        this.id = id;
        this.ref = ref;
    }

    toString() {
        return `[${this.id}:${this.ref.deRef()}]`;
    }
}

module.exports = { Binding };
%%%

Bindings
%%%
const { Binding } = require('./Binding');
const { LanguageError } = require('./runtime/base');

class Bindings {

    constructor(idList, refList) {
        this.bindingList = [];
        if (idList !== undefined) {
            if (refList === undefined || idList.length !== refList.length)
                throw new LanguageError("list sizes mismatch");
            for (let i = 0; i < idList.length; i++)
                this.bindingList.push(new Binding(idList[i].lexeme, refList[i]));
        }
    }

    lookup(sym) {
        for (const b of this.bindingList)
            if (sym === b.id)
                return b;
        return null;
    }

    add(binding) {
        this.bindingList.push(binding);
    }

    size() {
        return this.bindingList.length;
    }

    toString() {
        let s = "";
        for (const b of this.bindingList)
            s += `${b}\n`;
        return s;
    }
}

module.exports = { Bindings };
%%%
```

- [ ] **Step 4: Write `src/SET/javascript/spec.plcc`**

Start from a copy of `src/V6/javascript/spec.plcc`, then apply the six changes below. Every other block is copied verbatim.

**Watch the JavaScript import rule:** grammar-derived classes get `const { Node, Token, LanguageError } = require('./runtime/base');` auto-injected, so an explicit `:import` for any of those three on a grammar-derived class is a hard `Identifier 'X' has already been declared`. Free-standing classes (`Ref`, `ValRef`, `Val`, `IntVal`, `ProcVal`, and everything from `env.plcc`) get no auto-injection and must require what they use.

**(a)** The `%include` line:

```
%include ../../Env/envRef/javascript/env.plcc
```

**(b)** Insert `Ref` and `ValRef` blocks between `IntVal` and `ProcVal`:

```javascript
Ref
%%%
class Ref {

    static valsToRefs(valList) {
        const { ValRef } = require('./ValRef');
        return valList.map(v => new ValRef(v));
    }

    deRef() {
        throw new Error("not implemented");
    }

    setRef(v) {
        throw new Error("not implemented");
    }
}

module.exports = { Ref };
%%%

ValRef
%%%
const { Ref } = require('./Ref');

class ValRef extends Ref {

    constructor(val) {
        super();
        this.val = val;
    }

    deRef() {
        return this.val;
    }

    setRef(v) {
        this.val = v;
        return v;
    }

    toString() {
        return `${this.val}`;
    }
}

module.exports = { ValRef };
%%%
```

**(c)** Replace the `ProcVal` block. `apply` keeps its `env` parameter:

```javascript
ProcVal
%%%
const { Val } = require('./Val');
const { Bindings } = require('./Bindings');
const { Ref } = require('./Ref');
const { LanguageError } = require('./runtime/base');

class ProcVal extends Val {

    constructor(formals, body, env) {
        super();
        this.formals = formals;
        this.body = body;
        this.env = env;
    }

    apply(args, env) {
        if (this.formals.symbolList.length !== args.length)
            throw new LanguageError("formals/args number mismatch");
        const refList = Ref.valsToRefs(args);
        const bindings = new Bindings(this.formals.symbolList, refList);
        const nenv = this.env.extendEnvRef(bindings);
        return this.body.eval(nenv);
    }

    toString() {
        return "proc";
    }
}

module.exports = { ProcVal };
%%%
```

**(d)** Replace the `Define:import` and `Define` blocks:

```javascript
Define:import
%%%
const { Binding } = require('./Binding');
const { ValRef } = require('./ValRef');
%%%

Define
%%%
_run() {
    const env = Program.env;
    const s = this.symbol.lexeme;
    const val = this.exp.eval(env);
    const ref = new ValRef(val);
    const b = env.lookup(s);
    if (b !== null)
        b.ref = ref;
    else
        env.add(new Binding(s, ref));
    return s;
}
%%%
```

**(e)** Replace the `LetDecls:import` and `LetDecls` blocks. `LetDecls:init` is unchanged:

```javascript
LetDecls:import
%%%
const { Env } = require('./Env');
const { Binding } = require('./Binding');
const { Bindings } = require('./Bindings');
const { Ref } = require('./Ref');
const { ValRef } = require('./ValRef');
%%%

LetDecls:init
%%%
Env.checkDuplicates(this.symbolList, " in let/letrec LHS identifiers");
%%%

LetDecls
%%%
addBindings(env) {
    const valList = this.expList.map(e => e.eval(env));
    const refList = Ref.valsToRefs(valList);
    const bindings = new Bindings(this.symbolList, refList);
    return env.extendEnvRef(bindings);
}

addLetrecBindings(env) {
    env = env.extendEnvRef(new Bindings());
    for (let i = 0; i < this.symbolList.length; i++) {
        const val = this.expList[i].eval(env);
        env.add(new Binding(this.symbolList[i].lexeme, new ValRef(val)));
    }
    return env;
}

toString() {
    return " ...LetDecls... ";
}
%%%
```

**(f)** Add a `SetExp` block immediately after `SeqExp`:

```javascript
SetExp
%%%
eval(env) {
    const v = this.exp.eval(env);
    const ref = env.applyEnvRef(this.symbol.lexeme);
    return ref.setRef(v);
}

toString() {
    return " ...SetExp... ";
}
%%%
```

`SetExp` is grammar-derived and uses no free-standing class by name, so it needs no `:import` block.

- [ ] **Step 5: Run the SET tests to verify they pass**

```bash
bats --recursive src/SET/tests
```

Expected: 12 tests, all PASS.

- [ ] **Step 6: Run `Prog/g` against the JavaScript target**

```bash
cd src/SET/javascript && plcc-rep < ../Prog/g
```

Expected: `3`.

- [ ] **Step 7: Run the full suite**

```bash
bin/test.bash > /tmp/after-task4.txt 2>&1
grep -c '^ok ' /tmp/after-task4.txt      # expect 75
grep -c '^not ok ' /tmp/after-task4.txt  # expect 6
grep '^not ok ' /tmp/after-task4.txt
```

Expected: **81 tests, 75 passing, 6 failing** — NAME, NEED, OBJ, REF, TYPE0, TYPE1.

- [ ] **Step 8: Commit**

```bash
git add src/Env src/SET
git commit -m "feat(SET): add JavaScript target and envRef/javascript"
```

---

### Task 5: Remove SET's old-PLCC files and close the issue

**Files:**
- Delete: `src/SET/grammar`, `src/SET/code`, `src/SET/prim`, `src/SET/envRef`, `src/SET/val`, `src/SET/ref`
- Modify: `dev-docs/issues/0NN-migrate-set-to-plcc-ng.md` and `dev-docs/roadmap.md` (both via `bin/issues/close.bash`)
- Test: `bin/test.bash`, `bin/issues/check.bash`

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: nothing later tasks depend on. This is the last task of the phase.

- [ ] **Step 1: Confirm nothing still references the old flat files**

```bash
grep -rn "%include code\|%include prim\|%include envRef\|%include val\|%include ref" src/SET/
```

Expected: matches only inside `src/SET/grammar`, the old-PLCC file about to be deleted. If anything under `src/SET/{python,java,javascript}/` matches, **stop** — a new spec is including an old file.

Note that `src/REF/`, `src/NAME/`, and `src/NEED/` each `%include` their **own** `envRef`, not SET's, so this deletion cannot break them.

- [ ] **Step 2: Delete the old-PLCC files**

```bash
git rm src/SET/grammar src/SET/code src/SET/prim src/SET/envRef src/SET/val src/SET/ref
```

`src/SET/Prog/g` and everything under `src/SET/tests/` stay.

- [ ] **Step 3: Run the full suite**

```bash
bin/test.bash > /tmp/after-task5.txt 2>&1
grep -c '^ok ' /tmp/after-task5.txt      # expect 75
grep -c '^not ok ' /tmp/after-task5.txt  # expect 6
grep '^not ok ' /tmp/after-task5.txt
```

Expected: **81 tests, 75 passing, 6 failing**, unchanged from Task 4. The 6 failures are NAME, NEED, OBJ, REF, TYPE0, TYPE1 — all still `plccmk: command not found`.

Compare against the Task 1 baseline: the `command not found` count dropped by **exactly 1** (SET), and no test that passed before is failing now.

- [ ] **Step 4: Commit the deletion**

```bash
git add -A src/SET
git commit -m "chore(SET): remove the old old-PLCC spec files"
```

- [ ] **Step 5: Close the issue**

```bash
bin/issues/close.bash <NN>
bin/issues/check.bash
```

Expected: `check.bash` reports no inconsistencies.

- [ ] **Step 6: Commit the close**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): close issue <NN> (migrate SET to plcc-ng), update roadmap"
```

---

## Notes for the Rest of Phase 3

- REF's grammar is byte-identical to SET's. Copy `src/SET/grammar.plcc` unchanged.
- `src/Env/envRef/<target>/env.plcc` is done and shared — REF `%include`s it and changes nothing. Delete the flat `src/REF/envRef` with REF's other old files; do **not** port its `Set<String>` `checkDuplicates`.
- The semantic delta is `evalRef`: a new method on `Exp` (default: wrap `eval` in a fresh `ValRef`), overridden on `VarExp` to return `env.applyEnvRef(...)` — the binding's own `Ref`, not a copy. `Rands` gains `evalRandsRef`, and `AppExp`/`ProcVal` switch to ref lists. `ProcVal.apply` becomes `apply(refList, env)` — **keep the `env` parameter**.
- `src/SET/tests/formal-is-a-copy/` is the same program REF ships with `4` instead of `3`. Reuse it under a name that fits REF, and keep SET's copy.
- **NAME has a wrinkle SET does not.** `src/NAME/code`'s `Define` has its `System.out.println(id)` **commented out** — a silent define, where SET, REF, and NEED all print the name. plcc-ng requires `_run()` to return a string, so NAME cannot port that literally. NAME's phase decides between returning `""` and matching the other three; don't discover it while debugging an off-by-one expected file.

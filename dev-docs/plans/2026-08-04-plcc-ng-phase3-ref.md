# plcc-ng Phase 3 — REF Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port REF (`SET + call-by-reference semantics`) to plcc-ng in Python, Java, and JavaScript.

**Architecture:** REF adds **no syntax at all** to SET — `src/REF/grammar.plcc` is SET's file with a changed header comment. Each target's `spec.plcc` is a copy of SET's with a five-method delta: `Exp` gains a default `evalRef` that wraps `eval` in a fresh `ValRef`; `VarExp` overrides it to return the binding's own `Ref` via `applyEnvRef`; `Rands` gains `evalRandsRef`; `AppExp` calls it; and `Val`/`ProcVal.apply` take a list of `Ref`s instead of `Val`s. The shared `src/Env/envRef/<target>/env.plcc` is `%include`d **unchanged** — this phase touches nothing under `src/Env/`.

**Tech Stack:** plcc-ng (`plcc-rep`), bats (`bin/test.bash`), Python 3, Java, Node.js.

**Design of record:** [dev-docs/specs/2026-08-04-plcc-ng-ref-design.md](../specs/2026-08-04-plcc-ng-ref-design.md). Read it before Task 1.

## Global Constraints

- **Work in the existing worktree** `/workspaces/languages-ng/.claude/worktrees/ref-migration`, branch `worktree-ref-migration`. Do not create a new worktree. Do not `cd` to the main checkout.
- **Baseline, measured 2026-08-04:** `bin/test.bash` gives **84 tests, 78 passing, 6 failing**. The 6 failures are NAME, NEED, OBJ, REF, TYPE0, TYPE1 — all `plccmk: command not found`. Count with `grep -c '^ok '` and `grep -c '^not ok '` over the **whole** run, never a `tail`.
- **No test that passes may start failing.** Unlike SET's phase there is no retro-fix touching already-passing languages, so a `V`-prefixed or `SET` failure means a genuine regression, not expected churn.
- **`apply` keeps its `Env` parameter** in every target — `apply(args, env)` / `apply(List<Ref> args, Env e)`. It is unread at runtime. It is the seam for a dynamic-scoping homework assignment. **Never remove it as dead code.**
- **`Ref.valsToRefs` stays on `Ref`** even though `ProcVal` stops calling it — `LetDecls.addBindings` still does. Only the *import* comes out of `ProcVal`.
- **Do not touch `src/Env/`.** SET already ported `envRef` and deleted the flat file. REF `%include`s the result and changes nothing. In particular, do **not** port the `Set<String>` `checkDuplicates` from `src/REF/envRef` — that file is deleted, not migrated.
- **Grammar conventions, unchanged from V0–V6 and SET:** identifier token is `SYMBOL` (never `VAR`); nonterminals are PascalCase; multi-capture alt-names are camelCase (`<Exp:testExp>`), not the obsolete lowercase workaround.
- **Course-material impact entries go in the same commit as the change they describe**, under a `## REF` heading in [dev-docs/course-material-impact.md](../course-material-impact.md), added after the existing `## SET` section. Never batch them.
- **Never assign issue numbers by hand.** Use `bin/issues/new.bash` and `bin/issues/close.bash`.
- Every target's `spec.plcc` writes build artifacts to a `plcc-ng/` subdirectory; `.gitignore` already covers `plcc-ng/`, `__pycache__/`, and `*.class`. Never commit them.

---

### Task 1: File the REF issue and confirm the baseline

Pure bookkeeping plus the gate that every later task's expected counts depend on.

**Files:**
- Create: `dev-docs/issues/0NN-migrate-ref-to-plcc-ng.md` (number assigned by the script)
- Modify: `dev-docs/roadmap.md`
- Test: the existing suite — `bin/test.bash`

**Interfaces:**
- Consumes: nothing.
- Produces: the issue number `NN`, referenced by Task 6's `bin/issues/close.bash <NN>`.

- [ ] **Step 1: File the issue**

```bash
cd /workspaces/languages-ng/.claude/worktrees/ref-migration
bin/issues/new.bash migrate-ref-to-plcc-ng feat
```

Note the number it prints — that is `NN` for the rest of this plan. Fill in the issue's `## Description` with the REF port: no grammar delta, the five-method `evalRef` semantic delta, three targets, four test cases, and the `Prog/` consolidation. Leave `target:` at its default (`this repo`) — this is our own work, not a plcc-ng defect.

- [ ] **Step 2: Add the roadmap entry**

Add a bullet to the **Open Issues → Feat** section of `dev-docs/roadmap.md`, matching the shape of the entries already there (bold link, em-dash title, one indented continuation line).

- [ ] **Step 3: Capture the baseline**

```bash
bin/test.bash > /tmp/ref-baseline.txt 2>&1
grep -c '^ok ' /tmp/ref-baseline.txt      # expect 78
grep -c '^not ok ' /tmp/ref-baseline.txt  # expect 6
grep '^not ok ' /tmp/ref-baseline.txt
```

Expected: `78` and `6`, and the six failures are NAME, NEED, OBJ, REF, TYPE0, TYPE1. If any of that differs, **stop** — the plan's counts are stale and every later task's expectation is wrong.

- [ ] **Step 4: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): file REF migration issue, update roadmap"
```

---

### Task 2: Grammar + Python target + all four test cases

Delivers `src/REF/grammar.plcc`, the Python `spec.plcc`, and all four test cases with their **Python** `@test` blocks. Tasks 3 and 4 append the Java and JavaScript blocks to the same `.bats` files.

**Files:**
- Create: `src/REF/grammar.plcc`
- Create: `src/REF/python/spec.plcc`
- Rename: `src/REF/tests/let/` → `src/REF/tests/nonvar-arg-is-a-copy/` (keeping `REF.input` and `REF.expected` byte-for-byte)
- Modify: `src/REF/tests/nonvar-arg-is-a-copy/REFtest.bats` (replace the old `plccmk`/`rep` invocation)
- Create: `src/REF/tests/formal-is-a-ref/{REF.input,REF.expected,REFtest.bats}`
- Create: `src/REF/tests/alias-two-formals/{REF.input,REF.expected,REFtest.bats}`
- Create: `src/REF/tests/captured-ref/{REF.input,REF.expected,REFtest.bats}`
- Modify: `dev-docs/course-material-impact.md`
- Test: `bats --recursive src/REF/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `NN` from Task 1 (not used until Task 6).
- Produces:
  - `src/REF/grammar.plcc`, `%include`d by all three targets.
  - `src/REF/python/spec.plcc` defining `Exp.evalRef(env) -> Ref`, `VarExp.evalRef(env) -> Ref`, `Rands.evalRandsRef(env) -> list[Ref]`, and `ProcVal.apply(args, env)` where `args` is a `list[Ref]`.
  - The four test case directories, which Tasks 3 and 4 append `@test` blocks to.

- [ ] **Step 1: Create the grammar**

```bash
cp src/SET/grammar.plcc src/REF/grammar.plcc
```

Then change only the two header lines at the top of `src/REF/grammar.plcc`, from:

```
# Language SET
#   Language V6 with references/set
```

to:

```
# Language REF
#   Language SET + call-by-reference semantics
```

Nothing else in the file changes. Confirm:

```bash
diff <(tail -n +3 src/SET/grammar.plcc) <(tail -n +3 src/REF/grammar.plcc)
```

Expected: no output. If there is any, you edited something you shouldn't have.

- [ ] **Step 2: Rename the existing test case and write the three new ones**

The existing `src/REF/tests/let/` **is** the `nonvar-arg-is-a-copy` case — same program, renamed for what it actually tests. Keep its two data files exactly as they are:

```bash
git mv src/REF/tests/let src/REF/tests/nonvar-arg-is-a-copy
```

Verify the data files are what this plan expects (`REF.input` ends without a trailing newline; that is fine and `$(< file)` strips it either way):

```bash
cat src/REF/tests/nonvar-arg-is-a-copy/REF.input
cat src/REF/tests/nonvar-arg-is-a-copy/REF.expected
```

Expected input:

```
let
    x = 3
    p = proc(t) set t = add1(t)
in
    { .p(+(x,0)) ; x }
```

Expected expected: `3`

Now create the three new cases.

`src/REF/tests/formal-is-a-ref/REF.input`:

```
let
    x = 3
    p = proc(t) set t = add1(t)
in
    { .p(x) ; x }
```

`src/REF/tests/formal-is-a-ref/REF.expected`:

```
4
```

`src/REF/tests/alias-two-formals/REF.input`:

```
let
    x = 1
    f = proc(a,b) { set a = 9 ; b }
in
    { .f(x,x) ; x }
```

`src/REF/tests/alias-two-formals/REF.expected`:

```
9
```

`src/REF/tests/captured-ref/REF.input`:

```
define x = 0
define g = proc(t) proc() set t = add1(t)
define h = .g(x)
.h()
.h()
x
```

`src/REF/tests/captured-ref/REF.expected`:

```
x
g
h
1
2
2
```

- [ ] **Step 3: Write the four `.bats` files with their Python block only**

Each file gets exactly one `@test` for now. `src/REF/tests/formal-is-a-ref/REFtest.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "REF formal-is-a-ref (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/formal-is-a-ref/REF.input)"
  expected_output=$(< "../tests/formal-is-a-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Write the same file for the other three cases, substituting the case name in **both** the `@test` description and the two paths. For `nonvar-arg-is-a-copy` this **replaces** the old `plccmk`/`rep` body entirely — do not keep the old `@test`.

- [ ] **Step 4: Run the tests to verify they fail**

```bash
bats --recursive src/REF/tests
```

Expected: 4 tests, all failing — there is no `src/REF/python/` yet, so `cd python` fails.

- [ ] **Step 5: Create the Python target**

```bash
mkdir -p src/REF/python
cp src/SET/python/spec.plcc src/REF/python/spec.plcc
```

Now apply the five-method delta. **Edit 1** — in the `ProcVal` block, drop the now-unused `Ref` import and stop wrapping the arguments. Change:

```python
from Bindings import Bindings
from Ref import Ref
from Val import Val
```

to:

```python
from Bindings import Bindings
from Val import Val
```

and change:

```python
        refList = Ref.valsToRefs(args)
        bindings = Bindings(self.formals.symbolList, refList)
```

to:

```python
        bindings = Bindings(self.formals.symbolList, args)
```

Leave the arity check and the `env` parameter exactly as they are.

**Edit 2** — insert two new blocks immediately **before** the existing `LitExp:import` block:

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

**Edit 3** — in the `VarExp` block, add `evalRef` between `eval` and `__str__`:

```python
VarExp
%%%
def eval(self, env):
    return env.applyEnv(self.symbol.lexeme)

def evalRef(self, env):
    return env.applyEnvRef(self.symbol.lexeme)

def __str__(self):
    return self.symbol.lexeme
%%%
```

**Edit 4** — in the `Rands` block, add `evalRandsRef` after `evalRands`. `evalRands` itself does **not** change; primitives still take `Val`s:

```python
Rands
%%%
def evalRands(self, env):
    return [e.eval(env) for e in self.expList]

def evalRandsRef(self, env):
    return [e.evalRef(env) for e in self.expList]

def __str__(self):
    return ",".join(str(e) for e in self.expList)
%%%
```

**Edit 5** — in the `AppExp` block, switch to ref operands. `PrimappExp` is untouched:

```python
AppExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    args = self.rands.evalRandsRef(env)
    return v.apply(args, env)

def __str__(self):
    return " ...AppExp... "
%%%
```

**Both `%include` lines are already correct and need no edit.** `%include ../grammar.plcc` now resolves to REF's own grammar, because the copied file sits at the same relative depth; and `%include ../../Env/envRef/python/env.plcc` points at the shared Env variant SET already ported. Confirm both are present and unmodified:

```bash
head -5 src/REF/python/spec.plcc
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
bats --recursive src/REF/tests
```

Expected: 4 tests, 4 passing.

If a test fails, run the case by hand for the real error — bats swallows it:

```bash
cd src/REF/python && plcc-rep < ../tests/formal-is-a-ref/REF.input; cd ../../..
```

- [ ] **Step 7: Sanity-check the SET contrast**

The whole point of REF is that one program gives a different answer than it does under SET. Confirm both directions:

```bash
cd src/REF/python && plcc-rep < ../tests/formal-is-a-ref/REF.input; cd ../../..
cd src/SET/python && plcc-rep < ../tests/formal-is-a-copy/SET.input; cd ../../..
```

Expected: `4` from REF, `3` from SET, on byte-identical input files. If REF gives `3`, Edit 1 or Edit 3 did not take.

- [ ] **Step 8: Run the full suite**

```bash
bin/test.bash > /tmp/ref-after-task2.txt 2>&1
grep -c '^ok ' /tmp/ref-after-task2.txt      # expect 82
grep -c '^not ok ' /tmp/ref-after-task2.txt  # expect 5
grep '^not ok ' /tmp/ref-after-task2.txt
```

Expected: **87 tests, 82 passing, 5 failing**. The 5 failures are NAME, NEED, OBJ, TYPE0, TYPE1 — REF has dropped off the `command not found` list. Compare against `/tmp/ref-baseline.txt`: no test that passed before may be failing now.

- [ ] **Step 9: Add the course-material impact entries**

Add a `## REF` section to `dev-docs/course-material-impact.md`, after the existing `## SET` section:

```markdown
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
- `src/REF/tests/formal-is-a-ref/` is byte-identical to SET's
  `tests/formal-is-a-copy/` and expects **`4`** where SET expects `3`.
  Diffing the two expected files is the shortest possible demonstration of
  what REF adds.
- The old `src/REF/tests/let/` is now `tests/nonvar-arg-is-a-copy/`. Same
  program, renamed for what it tests. Any handout citing the path needs
  updating.
```

- [ ] **Step 10: Commit**

```bash
git add src/REF/grammar.plcc src/REF/python src/REF/tests dev-docs/course-material-impact.md
git commit -m "feat(REF): port REF to plcc-ng (grammar + python), add four test cases"
```

---

### Task 3: Java target

Adds `src/REF/java/spec.plcc` and a Java `@test` block to each of the four `.bats` files.

**Files:**
- Create: `src/REF/java/spec.plcc`
- Modify: `src/REF/tests/{formal-is-a-ref,nonvar-arg-is-a-copy,alias-two-formals,captured-ref}/REFtest.bats`
- Test: `bats --recursive src/REF/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/REF/grammar.plcc` and the four test case directories from Task 2.
- Produces: `src/REF/java/spec.plcc` with `Exp.evalRef(Env) -> Ref`, `VarExp.evalRef(Env) -> Ref`, `Rands.evalRandsRef(Env) -> List<Ref>`, `Val.apply(List<Ref>, Env) -> Val`.

- [ ] **Step 1: Add the Java `@test` block to each `.bats` file**

Append to `src/REF/tests/formal-is-a-ref/REFtest.bats`:

```bash
@test "REF formal-is-a-ref (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/formal-is-a-ref/REF.input)"
  expected_output=$(< "../tests/formal-is-a-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Do the same for the other three cases, substituting the case name in the `@test` description and both paths.

- [ ] **Step 2: Run the tests to verify the new ones fail**

```bash
bats --recursive src/REF/tests
```

Expected: 8 tests — the 4 Python ones passing, the 4 Java ones failing (no `src/REF/java/` yet).

- [ ] **Step 3: Create the Java target**

```bash
mkdir -p src/REF/java
cp src/SET/java/spec.plcc src/REF/java/spec.plcc
```

Apply the delta. Java needs **no** import changes anywhere — its classes are same-directory and package-less.

**Edit 1** — in the `Val` block, the base `apply` takes refs:

```java
    public Val apply(List<Ref> args, Env e) {
        throw new LanguageError("Cannot apply " + this);
    }
```

`Val.toArray` stays exactly as it is — `PrimappExp` still uses it.

**Edit 2** — in the `ProcVal` block, take refs and stop wrapping. Keep the explanatory comment above the method and keep the `Env e` parameter:

```java
    public Val apply(List<Ref> args, Env e) {
        if (formals.symbolList.size() != args.size())
            throw new LanguageError("formals/args number mismatch");
        Bindings bindings = new Bindings(formals.symbolList, args);
        Env nenv = env.extendEnvRef(bindings);
        return body.eval(nenv);
    }
```

**Edit 3** — the existing `Exp` block gains `evalRef` beside its abstract `eval`:

```java
Exp
%%%
public abstract Val eval(Env env);

public Ref evalRef(Env env) {
    return new ValRef(eval(env));
}
%%%
```

**Edit 4** — `VarExp` overrides it:

```java
VarExp
%%%
public Val eval(Env env) {
    return env.applyEnv(symbol.lexeme);
}

public Ref evalRef(Env env) {
    return env.applyEnvRef(symbol.lexeme);
}

public String toString() {
    return symbol.lexeme;
}
%%%
```

**Edit 5** — `Rands` gains `evalRandsRef`; `evalRands` is unchanged:

```java
public List<Ref> evalRandsRef(Env env) {
    List<Ref> refList = new ArrayList<Ref>(expList.size());
    for (Exp e : expList)
        refList.add(e.evalRef(env));
    return refList;
}
```

**Edit 6** — `AppExp.eval` switches to refs. `PrimappExp` is untouched, including its `Val [] va = Val.toArray(args);` line:

```java
public Val eval(Env env) {
    Val v = exp.eval(env);
    List<Ref> args = rands.evalRandsRef(env);
    return v.apply(args, env);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
bats --recursive src/REF/tests
```

Expected: 8 tests, 8 passing.

If Java fails to compile, run it by hand for the real error:

```bash
cd src/REF/java && plcc-rep < ../tests/formal-is-a-ref/REF.input; cd ../../..
```

- [ ] **Step 5: Run the full suite**

```bash
bin/test.bash > /tmp/ref-after-task3.txt 2>&1
grep -c '^ok ' /tmp/ref-after-task3.txt      # expect 86
grep -c '^not ok ' /tmp/ref-after-task3.txt  # expect 5
```

Expected: **91 tests, 86 passing, 5 failing** — the same 5 as Task 2.

- [ ] **Step 6: Commit**

```bash
git add src/REF/java src/REF/tests
git commit -m "feat(REF): add Java target"
```

---

### Task 4: JavaScript target

Adds `src/REF/javascript/spec.plcc` and a JavaScript `@test` block to each of the four `.bats` files. This is the target whose `Exp:import` was the design's main open risk; it was spiked clean, but run it attentively.

**Files:**
- Create: `src/REF/javascript/spec.plcc`
- Modify: `src/REF/tests/{formal-is-a-ref,nonvar-arg-is-a-copy,alias-two-formals,captured-ref}/REFtest.bats`
- Test: `bats --recursive src/REF/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/REF/grammar.plcc` and the four test case directories from Task 2.
- Produces: `src/REF/javascript/spec.plcc` with `Exp.evalRef(env)`, `VarExp.evalRef(env)`, `Rands.evalRandsRef(env)`, `ProcVal.apply(args, env)` over refs. Completes the language.

- [ ] **Step 1: Add the JavaScript `@test` block to each `.bats` file**

Append to `src/REF/tests/formal-is-a-ref/REFtest.bats`:

```bash
@test "REF formal-is-a-ref (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/formal-is-a-ref/REF.input)"
  expected_output=$(< "../tests/formal-is-a-ref/REF.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Do the same for the other three cases, substituting the case name in the `@test` description and both paths.

- [ ] **Step 2: Run the tests to verify the new ones fail**

```bash
bats --recursive src/REF/tests
```

Expected: 12 tests — 8 passing, the 4 JavaScript ones failing.

- [ ] **Step 3: Create the JavaScript target**

```bash
mkdir -p src/REF/javascript
cp src/SET/javascript/spec.plcc src/REF/javascript/spec.plcc
```

Apply the delta. **Edit 1** — in the `ProcVal` block, drop the now-unused `Ref` require and stop wrapping. Change:

```javascript
const { Bindings } = require('./Bindings');
const { Ref } = require('./Ref');
const { LanguageError } = require('./runtime/base');
```

to:

```javascript
const { Bindings } = require('./Bindings');
const { LanguageError } = require('./runtime/base');
```

Careful: `const { Ref } = require('./Ref');` appears **twice** in this file — once in `ProcVal` and once in `ValRef`, which extends `Ref`. Only the `ProcVal` one comes out.

Then change:

```javascript
        const refList = Ref.valsToRefs(args);
        const bindings = new Bindings(this.formals.symbolList, refList);
```

to:

```javascript
        const bindings = new Bindings(this.formals.symbolList, args);
```

**Edit 2** — insert two new blocks immediately **before** the existing `LitExp:import` block:

```javascript
Exp:import
%%%
const { ValRef } = require('./ValRef');
%%%

Exp
%%%
evalRef(env) {
    return new ValRef(this.eval(env));
}
%%%
```

`Exp` is a grammar-derived class, so plcc-ng already auto-injects `{ Node, Token, LanguageError }` into its file. Requiring `ValRef` is fine; requiring any of those three would fail with `Identifier 'X' has already been declared`.

**Edit 3** — `VarExp` overrides it:

```javascript
VarExp
%%%
eval(env) {
    return env.applyEnv(this.symbol.lexeme);
}

evalRef(env) {
    return env.applyEnvRef(this.symbol.lexeme);
}

toString() {
    return this.symbol.lexeme;
}
%%%
```

**Edit 4** — `Rands` gains `evalRandsRef`; `evalRands` is unchanged:

```javascript
evalRandsRef(env) {
    return this.expList.map(e => e.evalRef(env));
}
```

**Edit 5** — `AppExp.eval` switches to refs; `PrimappExp` is untouched:

```javascript
eval(env) {
    const v = this.exp.eval(env);
    const args = this.rands.evalRandsRef(env);
    return v.apply(args, env);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
bats --recursive src/REF/tests
```

Expected: 12 tests, 12 passing.

If JavaScript fails to load, run it by hand — a circular-require or redeclaration error shows up here and is invisible through bats:

```bash
cd src/REF/javascript && plcc-rep < ../tests/formal-is-a-ref/REF.input; cd ../../..
```

- [ ] **Step 5: Run the full suite**

```bash
bin/test.bash > /tmp/ref-after-task4.txt 2>&1
grep -c '^ok ' /tmp/ref-after-task4.txt      # expect 90
grep -c '^not ok ' /tmp/ref-after-task4.txt  # expect 5
grep '^not ok ' /tmp/ref-after-task4.txt
```

Expected: **95 tests, 90 passing, 5 failing** — the plan's final numbers. The 5 failures are NAME, NEED, OBJ, TYPE0, TYPE1, all `plccmk: command not found`. Against the Task 1 baseline the `command not found` count has dropped by **exactly 1**.

- [ ] **Step 6: Commit**

```bash
git add src/REF/javascript src/REF/tests
git commit -m "feat(REF): add JavaScript target"
```

---

### Task 5: Consolidate the example programs into `Prog/`

Folds `Stuff/` into `Prog/`, fixes `oe`'s syntax error, and verifies all nine programs against all three targets. No test-count change — `Prog/` is not driven by bats.

**Files:**
- Rename: `src/REF/Stuff/counter{1,2,3,4,5}` → `src/REF/Prog/counter{1,2,3,4,5}`
- Delete: `src/REF/Stuff/factory` (byte-identical duplicate of `src/REF/Prog/factory`)
- Rename: `src/REF/oe` → `src/REF/Prog/oe`, with its syntax error fixed
- Modify: `dev-docs/course-material-impact.md`
- Test: manual runs against all three targets

**Interfaces:**
- Consumes: all three targets from Tasks 2–4.
- Produces: `src/REF/Prog/` holding nine programs; `src/REF/Stuff/` gone.

- [ ] **Step 1: Confirm `Stuff/factory` really is a duplicate before deleting it**

```bash
diff src/REF/Stuff/factory src/REF/Prog/factory && echo IDENTICAL
```

Expected: `IDENTICAL`. If it prints a diff, **stop** and keep both under distinct names — the design's premise was that they are the same file.

- [ ] **Step 2: Move the counters in and drop the duplicate**

```bash
git mv src/REF/Stuff/counter1 src/REF/Prog/counter1
git mv src/REF/Stuff/counter2 src/REF/Prog/counter2
git mv src/REF/Stuff/counter3 src/REF/Prog/counter3
git mv src/REF/Stuff/counter4 src/REF/Prog/counter4
git mv src/REF/Stuff/counter5 src/REF/Prog/counter5
git rm src/REF/Stuff/factory
```

`src/REF/Stuff/` should now be gone. Confirm:

```bash
ls src/REF
```

Expected: no `Stuff` entry.

- [ ] **Step 3: Move `oe` into `Prog/` and fix its syntax error**

```bash
git mv src/REF/oe src/REF/Prog/oe
```

As shipped, the `odd?` line has an unbalanced `{` and the file does not parse. Change:

```
define odd? = proc(t) { if zero?(t) then false else .even?(sub1(t))
```

to:

```
define odd? = proc(t) if zero?(t) then false else .even?(sub1(t))
```

The finished `src/REF/Prog/oe`:

```
define true = 1
define false = 0
define odd? = proc(t) if zero?(t) then false else .even?(sub1(t))
define even? = proc(t) if zero?(t) then true else .odd?(sub1(t))
```

- [ ] **Step 4: Run every program against all three targets**

Do not assume these still work — that is the whole reason this step exists.

Four of the nine programs only define things, so they need calls appended or they print nothing worth checking. `factory` and `xx` already call themselves.

```bash
for t in python java javascript; do
  echo "===== $t"
  S=src/REF/$t/spec.plcc
  for p in counter1 counter2 counter3 counter4 counter5; do
    echo "--- $p"
    { cat src/REF/Prog/$p; printf '\n.counter()\n.counter()\n.counter()\n'; } \
      | plcc-rep -s $S 2>&1 | tr '\n' ' '; echo
  done
  echo "--- double"
  { cat src/REF/Prog/double; printf '.double(5,0)\n.ddd(5)\n'; } \
    | plcc-rep -s $S 2>&1 | tr '\n' ' '; echo
  echo "--- oe"
  { cat src/REF/Prog/oe; printf '.odd?(5)\n.even?(5)\n'; } \
    | plcc-rep -s $S 2>&1 | tr '\n' ' '; echo
  for p in factory xx; do
    echo "--- $p"
    plcc-rep -s $S < src/REF/Prog/$p 2>&1 | tr '\n' ' '; echo
  done
done
```

The `tr` collapses each program's output onto one line so it lines up with the table below. Never pipe these through `tail` — `factory` alone produces 15 lines.

`-s` is verified to work from the repo root, and `%include` inside each `spec.plcc` resolves relative to that file, so no `cd` is needed. The remembered-spec behaviour in `plcc-rep --help` is per-directory and will not leak into the bats runs.

Expected, identical in all three targets. Note that a `define` echoes the name it binds, so those lines are part of the output:

| program | full output |
|---|---|
| `counter1` + three `.counter()` calls | `counter 1 1 1` |
| `counter2` + three calls | `counter 1 2 3` |
| `counter3` | **parse error** — `plcc-parser-table: -:4:3: error: unexpected 'DEFINE', no production for 'Exp'` |
| `counter4` + three calls | `counter 1 2 3` |
| `counter5` + three calls | `counter 1 2 3` |
| `double` + `.double(5,0)` / `.ddd(5)` | `double ddd 10 10` |
| `factory` | `sum_factory reset_sum sum 0 1 4 9 16 25 0 0 1 4 9 16 25` |
| `xx` | `x g h1 h2 1 2 3 4 0 1 2 3 4 x 5 6 7 8 99` |
| `oe` + `.odd?(5)` / `.even?(5)` | `true false odd? even? 1 0` |

(Shown space-separated; the real output is one value per line.)

`counter1`'s `1 1 1` and `counter3`'s parse error are **expected and correct** — both are deliberate "here is what does not work" steps in the five-program progression. Do not repair them.

- [ ] **Step 5: Add the course-material impact entries**

Append to the `## REF` section of `dev-docs/course-material-impact.md`:

```markdown
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
```

- [ ] **Step 6: Commit**

```bash
git add -A src/REF dev-docs/course-material-impact.md
git commit -m "refactor(REF): consolidate example programs into Prog/, fix oe"
```

---

### Task 6: Remove REF's old-PLCC files and close the issue

**Files:**
- Delete: `src/REF/grammar`, `src/REF/code`, `src/REF/prim`, `src/REF/envRef`, `src/REF/val`, `src/REF/ref`
- Modify: `dev-docs/issues/0NN-migrate-ref-to-plcc-ng.md`, `dev-docs/roadmap.md` (both via `close.bash`)
- Test: `bin/test.bash`, `bin/issues/check.bash`

**Interfaces:**
- Consumes: `NN` from Task 1; all three targets from Tasks 2–4.
- Produces: nothing later depends on.

- [ ] **Step 1: Confirm nothing still includes the old files**

```bash
grep -rn "%include code\|%include prim\|%include envRef\|%include val\|%include ref" src/REF/
```

Expected: matches only inside `src/REF/grammar`, the old-PLCC file about to be deleted. If anything under `src/REF/{python,java,javascript}/` matches, **stop** — a new spec is including an old file.

Note that `src/NAME/`, `src/NEED/`, `src/TYPE0/`, `src/TYPE1/`, and `src/OBJ/` each `%include` their **own** `envRef`, not REF's, so this deletion cannot break them.

- [ ] **Step 2: Delete the old-PLCC files**

```bash
git rm src/REF/grammar src/REF/code src/REF/prim src/REF/envRef src/REF/val src/REF/ref
```

There is no path collision here — `src/REF/grammar` and `src/REF/grammar.plcc` are different names — which is why this comes at the end rather than the beginning, unlike SET's `envRef`. Everything under `src/REF/Prog/` and `src/REF/tests/` stays.

- [ ] **Step 3: Run the full suite**

```bash
bin/test.bash > /tmp/ref-after-task6.txt 2>&1
grep -c '^ok ' /tmp/ref-after-task6.txt      # expect 90
grep -c '^not ok ' /tmp/ref-after-task6.txt  # expect 5
grep '^not ok ' /tmp/ref-after-task6.txt
```

Expected: **95 tests, 90 passing, 5 failing**, unchanged from Task 4. The 5 failures are NAME, NEED, OBJ, TYPE0, TYPE1 — all still `plccmk: command not found`.

Compare against the Task 1 baseline: the `command not found` count dropped by **exactly 1** (REF), and no test that passed before is failing now.

- [ ] **Step 4: Commit the deletion**

```bash
git add -A src/REF
git commit -m "chore(REF): remove the old old-PLCC spec files"
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
git commit -m "docs(issues): close issue <NN> (migrate REF to plcc-ng), update roadmap"
```

---

## Notes for the Rest of Phase 3

- **NAME is a one-method rewrite of REF.** `Exp.evalRef` returns `new ThunkRef(this, env)` instead of `new ValRef(eval(env))`, and `LitExp` and `ProcExp` override it back to the `ValRef` form. `ThunkRef` is a new `Ref` subclass whose `deRef` evaluates its captured expression and whose `setRef` throws. `VarExp.evalRef`, `Rands.evalRandsRef`, `AppExp`, and the `apply(List<Ref>, Env)` signatures are inherited from REF unchanged. Copy REF's three `spec.plcc`s, not SET's.
- **NAME's `Define` prints nothing.** `src/NAME/code` has `// System.out.println(id);` commented out, where SET, REF, and NEED all print the name. plcc-ng requires `_run()` to return a string, so NAME cannot port that literally — decide between returning `""` and matching the other three, and don't discover it while debugging an off-by-one expected file.
- **NAME's `evalRandsRef` names its loop variable `e` where REF's names it `exp`.** Cosmetic; don't chase it.
- `src/Env/envRef/<target>/env.plcc` remains shared and untouched. NAME and NEED `%include` it and change nothing, exactly as REF did. Delete each language's flat `envRef` with its other old files; never port the `Set<String>` `checkDuplicates`.
- `src/REF/tests/formal-is-a-ref/` is the same program as SET's `formal-is-a-copy/`. NEED will want its own copy of this contrast too.

# plcc-ng Phase 3 — NAME Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port NAME (`REF + call-by-name semantics`) to plcc-ng in Python, Java, and JavaScript.

**Architecture:** NAME adds **no syntax at all** to REF — `src/NAME/grammar.plcc` is REF's file with a changed header comment. Each target's `spec.plcc` is a copy of REF's with a four-part delta: a new free-standing `ThunkRef` subclass of `Ref` whose `deRef` re-evaluates a captured expression every time and whose `setRef` throws; `Exp.evalRef` rewritten to return a `ThunkRef` instead of a `ValRef`; `LitExp` and `ProcExp` overriding `evalRef` back to REF's `ValRef` form; and the Python/JavaScript `:import` blocks that follow. The shared `src/Env/envRef/<target>/env.plcc` is `%include`d **unchanged** — this phase touches nothing under `src/Env/`.

**Tech Stack:** plcc-ng (`plcc-rep`), bats (`bin/test.bash`), Python 3, Java, Node.js.

**Design of record:** [dev-docs/specs/2026-08-05-plcc-ng-name-design.md](../specs/2026-08-05-plcc-ng-name-design.md). Read it before Task 1.

## Global Constraints

- **Work in the existing worktree** `/workspaces/languages-ng/.claude/worktrees/migrate-name`, branch `worktree-migrate-name`. Do not create a new worktree. Do not `cd` to the main checkout.
- **Baseline, measured 2026-08-05:** `bin/test.bash` gives **105 tests, 100 passing, 5 failing**. The 5 failures are NAME, NEED, OBJ, TYPE0, TYPE1 — all `plccmk: command not found`. Count with `grep -c '^ok '` and `grep -c '^not ok '` over the **whole** run, never a `tail`.
- **No test that passes may start failing.** As in REF's phase there is no retro-fix touching already-passing languages, so a `V`-prefixed, `SET`, or `REF` failure means a genuine regression, not expected churn.
- **`Define` returns the defined name** — `return s` in Python/JavaScript, `return s;` in Java, exactly as REF does. The pre-migration `src/NAME/code` has `// System.out.println(id);` commented out. **Do not port that suppression**, and do not "restore fidelity" by returning `""`. This was decided in brainstorming; the design records why. Every expected file in this plan assumes the name is printed.
- **`apply` keeps its `Env` parameter** in every target — `apply(args, env)` / `apply(List<Ref> args, Env e)`. It is unread at runtime. It is the seam for a dynamic-scoping homework assignment. **Never remove it as dead code.** The pre-migration `src/NAME/val` declares `apply(List<Ref> refList)` with no `Env`; that shape is not carried forward.
- **`VarExp.evalRef` is inherited from REF unchanged.** It is what keeps a bare variable operand call-by-*reference* rather than by-name, and deleting or thunking it silently breaks `set` through a formal. Likewise `Rands.evalRandsRef`, `AppExp`, `SetExp`, and both `LetDecls` methods are untouched — **`let` stays eager**; call-by-name is a rule about operands only.
- **Do not touch `src/Env/`.** SET ported `envRef` and deleted the flat file; REF reused it unchanged; NAME reuses it unchanged again. In particular, do **not** port anything out of `src/NAME/envRef` — that file is deleted in Task 6, not migrated. (It already *is* the canonical `void checkDuplicates` shape, so there is nothing in it to want.)
- **Grammar conventions, unchanged from V0–V6, SET, and REF:** identifier token is `SYMBOL` (never `VAR`); nonterminals are PascalCase; multi-capture alt-names are camelCase (`<Exp:testExp>`), not the obsolete lowercase workaround.
- **Course-material impact entries go in the same commit as the change they describe**, under a `## NAME` heading in [dev-docs/course-material-impact.md](../course-material-impact.md), added after the existing `## REF` section. Never batch them.
- **Never assign issue numbers by hand.** Use `bin/issues/new.bash` and `bin/issues/close.bash`.
- Every target's `spec.plcc` writes build artifacts to a `plcc-ng/` subdirectory; `.gitignore` already covers `plcc-ng/`, `__pycache__/`, and `*.class`. Never commit them.

---

### Task 1: File the NAME issue and confirm the baseline

Pure bookkeeping plus the gate that every later task's expected counts depend on.

**Files:**
- Create: `dev-docs/issues/0NN-migrate-name-to-plcc-ng.md` (number assigned by the script)
- Modify: `dev-docs/roadmap.md`
- Test: the existing suite — `bin/test.bash`

**Interfaces:**
- Consumes: nothing.
- Produces: the issue number `NN`, referenced by Task 6's `bin/issues/close.bash <NN>`.

- [ ] **Step 1: File the issue**

```bash
cd /workspaces/languages-ng/.claude/worktrees/migrate-name
bin/issues/new.bash migrate-name-to-plcc-ng feat
```

Note the number it prints — that is `NN` for the rest of this plan. Fill in the issue's `## Description` with the NAME port: no grammar delta, the four-part `ThunkRef`/`evalRef` semantic delta, three targets, five test cases, no `Prog/` consolidation, and the `Define`-returns-the-name decision. Add a `## Notes` section pointing at the design doc and listing what is out of scope (NEED, TYPE0, TYPE1, OBJ; error-path tests; issues #16, #19, #22). Leave `target:` at its default (`this repo`) — this is our own work, not a plcc-ng defect.

- [ ] **Step 2: Add the roadmap entry**

Add an entry to the **Open Issues** section of `dev-docs/roadmap.md`, under a `### Feat` heading. That heading does **not** exist today — the roadmap's contract is that a type group exists only while it has open entries, and `close.bash` removed the last one. Create it, placed alphabetically among the existing `### Chore`, `### Docs`, and `### Test` headings (so: Chore, Docs, **Feat**, Test). Use this exact two-line format, which the scripts parse:

```markdown
- **[#0NN](issues/0NN-migrate-name-to-plcc-ng.md) — migrate-name-to-plcc-ng**
  Port NAME (REF + call-by-name semantics) to plcc-ng in Python, Java, and JavaScript: zero grammar delta, a four-part `ThunkRef`/`evalRef` semantic delta over REF, and five value-only test cases.
```

- [ ] **Step 3: Verify the issue bookkeeping is consistent**

Run: `bin/issues/check.bash`
Expected: exit status 0, no output about drift. If it complains, fix the roadmap entry's format before continuing — `close.bash` in Task 6 parses the same shape.

- [ ] **Step 4: Capture the baseline**

```bash
bin/test.bash > /tmp/name-baseline.txt 2>&1
grep -c '^ok ' /tmp/name-baseline.txt      # expect 100
grep -c '^not ok ' /tmp/name-baseline.txt  # expect 5
grep '^not ok ' /tmp/name-baseline.txt
```

Expected: `100` and `5`, and the five failures are NAME, NEED, OBJ, TYPE0, TYPE1. If any of that differs, **stop** — the plan's counts are stale and every later task's expectation is wrong.

- [ ] **Step 5: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): file NAME migration issue, update roadmap"
```

---

### Task 2: Grammar + Python target + all five test cases

Delivers `src/NAME/grammar.plcc`, the Python `spec.plcc`, and all five test cases with their **Python** `@test` blocks. Tasks 3 and 4 append the Java and JavaScript blocks to the same `.bats` files.

**Files:**
- Create: `src/NAME/grammar.plcc`
- Create: `src/NAME/python/spec.plcc`
- Rename: `src/NAME/tests/let-proc/` → `src/NAME/tests/operand-evaluated-at-use/` (keeping `NAME.input` and `NAME.expected` byte-for-byte)
- Modify: `src/NAME/tests/operand-evaluated-at-use/NAMEtest.bats` (replace the old `plccmk`/`rep -n` invocation)
- Create: `src/NAME/tests/thunk-reevaluated-per-use/{NAME.input,NAME.expected,NAMEtest.bats}`
- Create: `src/NAME/tests/unused-arg-not-evaluated/{NAME.input,NAME.expected,NAMEtest.bats}`
- Create: `src/NAME/tests/jensen-device/{NAME.input,NAME.expected,NAMEtest.bats}`
- Create: `src/NAME/tests/by-name-terminates/{NAME.input,NAME.expected,NAMEtest.bats}`
- Modify: `dev-docs/course-material-impact.md`
- Test: `bats --recursive src/NAME/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `NN` from Task 1 (not used until Task 6).
- Produces:
  - `src/NAME/grammar.plcc`, `%include`d by all three targets.
  - `src/NAME/python/spec.plcc` defining a free-standing `ThunkRef(exp, env)` with `deRef()` and `setRef(v)`, plus `Exp.evalRef(env) -> Ref` returning a `ThunkRef`, and `LitExp.evalRef(env) -> Ref` / `ProcExp.evalRef(env) -> Ref` returning a `ValRef`.
  - The five test case directories, which Tasks 3 and 4 append `@test` blocks to.

- [ ] **Step 1: Create the grammar**

```bash
cp src/REF/grammar.plcc src/NAME/grammar.plcc
```

Then change only the two header lines at the top of `src/NAME/grammar.plcc`, from:

```
# Language REF
#   Language SET + call-by-reference semantics
```

to:

```
# Language NAME
#   Language REF with call-by-name semantics
```

Nothing else in the file changes. Confirm:

```bash
diff <(tail -n +3 src/REF/grammar.plcc) <(tail -n +3 src/NAME/grammar.plcc)
```

Expected: no output. If there is any, you edited something you shouldn't have.

- [ ] **Step 2: Rename the existing test case**

The existing `src/NAME/tests/let-proc/` **is** the `operand-evaluated-at-use` case — same program, renamed for what it actually tests. Keep its two data files exactly as they are; its expected value is already `7`.

```bash
git mv src/NAME/tests/let-proc src/NAME/tests/operand-evaluated-at-use
cat src/NAME/tests/operand-evaluated-at-use/NAME.expected
```

Expected: `7`. The directory's `NAMEtest.bats` comes along with the rename still holding its old `plccmk`/`rep -n` invocation; Step 4 overwrites it in place from the same template as the other four, so there is nothing to edit here.

- [ ] **Step 3: Create the four new test inputs**

Each is a copy of an existing `Prog/` program, so no transcription can go wrong:

```bash
mkdir -p src/NAME/tests/thunk-reevaluated-per-use \
         src/NAME/tests/unused-arg-not-evaluated \
         src/NAME/tests/jensen-device \
         src/NAME/tests/by-name-terminates
cp src/NAME/Prog/test         src/NAME/tests/thunk-reevaluated-per-use/NAME.input
cp src/NAME/Prog/divideByZero src/NAME/tests/unused-arg-not-evaluated/NAME.input
cp src/NAME/Prog/jensen       src/NAME/tests/jensen-device/NAME.input
cp src/NAME/Prog/looper       src/NAME/tests/by-name-terminates/NAME.input
```

Then write the four expected files. These are the measured outputs from the design's spike, not predictions:

`src/NAME/tests/thunk-reevaluated-per-use/NAME.expected`:

```
10
```

`src/NAME/tests/unused-arg-not-evaluated/NAME.expected`:

```
11
```

`src/NAME/tests/jensen-device/NAME.expected`:

```
while
55
```

`src/NAME/tests/by-name-terminates/NAME.expected`:

```
p
g
8
```

The `while`, `p`, and `g` lines are `Define._run()` returning the defined name — see the Global Constraints. A missing first line means someone ported the commented-out `println`.

- [ ] **Step 4: Write the five `.bats` files with their Python block only**

Each `src/NAME/tests/<case>/NAMEtest.bats` gets exactly this content, with `<case>` replaced by that directory's name. This is REF's shape verbatim, with `REF` swapped for `NAME`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NAME <case> (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/<case>/NAME.input)"
  expected_output=$(< "../tests/<case>/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

So `src/NAME/tests/jensen-device/NAMEtest.bats` reads:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NAME jensen-device (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/jensen-device/NAME.input)"
  expected_output=$(< "../tests/jensen-device/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

and the other four are the same file with `jensen-device` replaced by `operand-evaluated-at-use`, `thunk-reevaluated-per-use`, `unused-arg-not-evaluated`, and `by-name-terminates`. `relocate` copies the whole `src/` tree into the test's tmpdir and lands you in `src/NAME/`, which is why the paths are `../tests/...` after the `cd python`.

- [ ] **Step 5: Run the tests to verify they fail**

Run: `bats --recursive src/NAME/tests`
Expected: 5 tests, all failing — there is no `python/` directory yet, so the `cd python` fails. If any test *passes* here, the assertion is not running; stop and find out why before writing the implementation.

- [ ] **Step 6: Create the Python target**

```bash
mkdir -p src/NAME/python
cp src/REF/python/spec.plcc src/NAME/python/spec.plcc
```

The file's two `%include` lines need **no** change. `%include ../grammar.plcc` resolves relative to the spec file, so from `src/NAME/python/` it already picks up NAME's own grammar rather than REF's, and `%include ../../Env/envRef/python/env.plcc` is the shared Env variant NAME reuses unchanged. Make **four** edits and nothing else:

**(a) Insert a `ThunkRef` block between the existing `Ref` block and the existing `ValRef` block.** Find the line `ValRef` that begins the `ValRef` block and insert immediately above it:

```
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

`deRef` re-evaluates on **every** call — the missing memoization is what makes this NAME and not NEED. Do not add a cache.

**(b) Rewrite the `Exp:import` and `Exp` blocks.** Replace:

```
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

with:

```
Exp:import
%%%
from ThunkRef import ThunkRef
%%%

Exp
%%%
# this covers all but a LitExp, ProcExp, and VarExp
def evalRef(self, env):
    return ThunkRef(self, env)
%%%
```

**(c) Give `LitExp` an `evalRef` override.** Replace:

```
LitExp:import
%%%
from IntVal import IntVal
%%%

LitExp
%%%
def eval(self, env):
    return IntVal(self.lit.lexeme)

def __str__(self):
    return self.lit.lexeme
%%%
```

with:

```
LitExp:import
%%%
from IntVal import IntVal
from ValRef import ValRef
%%%

LitExp
%%%
def eval(self, env):
    return IntVal(self.lit.lexeme)

def evalRef(self, env):
    return ValRef(self.eval(env))

def __str__(self):
    return self.lit.lexeme
%%%
```

**(d) Give `ProcExp` an `evalRef` override and a new `:import` block.** Replace:

```
ProcExp
%%%
def eval(self, env):
    return self.proc.makeClosure(env)

def __str__(self):
    return " ...ProcExp... "
%%%
```

with:

```
ProcExp:import
%%%
from ValRef import ValRef
%%%

ProcExp
%%%
def eval(self, env):
    return self.proc.makeClosure(env)

def evalRef(self, env):
    return ValRef(self.eval(env))

def __str__(self):
    return " ...ProcExp... "
%%%
```

The `:import` block is not optional. Each generated class file gets only its own imports, so without it `ProcExp` fails with `NameError: name 'ValRef' is not defined` — and only when a `proc` is passed as an operand, which no other test would catch.

Verify the whole edit is exactly these four changes and nothing else:

```bash
diff src/REF/python/spec.plcc src/NAME/python/spec.plcc
```

Expected: four hunks — the inserted `ThunkRef` block, the `Exp:import`/`Exp` rewrite, the `LitExp` addition, and the `ProcExp` addition. Anything else is an accident; revert it.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `bats --recursive src/NAME/tests`
Expected: 5 tests, 5 passing.

If `jensen-device` or `by-name-terminates` hangs instead of failing, the `Exp.evalRef` rewrite did not take — under `ValRef` semantics both programs diverge, which is the whole point of shipping them.

- [ ] **Step 8: Sanity-check the REF contrast**

The point of NAME is that it disagrees with REF. Confirm it does, rather than assuming:

Each `cd` is wrapped in a subshell so a failing `plcc-rep` cannot leave you in the wrong directory for the next command:

```bash
P='let x=1 f=proc(t,u) {set t=add1(t); u} in .f(x,+(x,5))'
( cd src/REF/python  && echo "$P" | plcc-rep )
( cd src/NAME/python && echo "$P" | plcc-rep )
```

Expected: `6` from REF, `7` from NAME. Identical answers mean the thunk is being forced at call time and the port is wrong even though the tests may pass for another reason.

Then confirm the inherited REF behavior still holds:

```bash
( cd src/NAME/python && echo 'let x=3 p=proc(t) set t=add1(t) in {.p(x); x}' | plcc-rep )
( cd src/NAME/python && echo 'let p=proc(t) set t=9 in .p(+(1,1))' | plcc-rep )
```

Expected: `4` (a bare variable operand is still by-reference — `VarExp.evalRef` untouched), then `cannot modify a read-only expression` (`ThunkRef.setRef`).

- [ ] **Step 9: Run the full suite**

```bash
bin/test.bash > /tmp/name-task2.txt 2>&1
grep -c '^ok ' /tmp/name-task2.txt      # expect 105
grep -c '^not ok ' /tmp/name-task2.txt  # expect 4
grep '^not ok ' /tmp/name-task2.txt
```

Expected: **109 tests, 105 passing, 4 failing.** That is the baseline's 105 tests, minus NAME's 1 old test, plus 5 new Python tests. The 4 remaining failures are NEED, OBJ, TYPE0, TYPE1 — all `plccmk: command not found`. Any `V`-prefixed, `SET`, or `REF` failure is a regression; stop and fix it.

- [ ] **Step 10: Add the course-material impact entries**

Append a `## NAME` section to `dev-docs/course-material-impact.md`, after the existing `## REF` section, matching the prose style of the sections already there. Cover, one bullet each:

- The `VAR` → `SYMBOL` token rename and the `var` → `symbol` field rename, the standing convention since V0 — `VarExp` reads `env.applyEnv(self.symbol.lexeme)`.
- `$run()` → `_run()`, which **returns** its output string rather than printing it.
- `Define` now printing the defined name, where pre-migration NAME printed nothing (`// System.out.println(id);` was commented out). `Prog/{jensen,sumsq,countdown,looper}` each gain a leading line naming what they define. Explain that plcc-ng's `_run()` must return a string, so "print nothing" was not available, and that the alternative — returning `""` — prints a blank line rather than nothing.
- `ThunkRef`, a new `Ref` subclass beside `ValRef`, whose `deRef` re-evaluates its captured expression on every use and whose `setRef` raises `cannot modify a read-only expression`.
- `Exp.evalRef` returning a `ThunkRef`, with `LitExp` and `ProcExp` overriding back to `ValRef`, and `VarExp` keeping REF's `applyEnvRef` override. Note that this three-way split is the whole of call-by-name and is worth a slide of its own.
- `apply` taking a `List<Ref>` **and** an `Env` (the dynamic-scoping homework seam), where pre-migration NAME's `apply(List<Ref>)` had no `Env`, and `ProcVal.apply` now raising `formals/args number mismatch` on an arity error.
- The `tests/let-proc/` → `tests/operand-evaluated-at-use/` rename.

- [ ] **Step 11: Commit**

```bash
git add src/NAME/grammar.plcc src/NAME/python src/NAME/tests dev-docs/course-material-impact.md
git commit -m "feat(NAME): port grammar and Python target to plcc-ng

Refs #NN"
```

Replace `NN` with the number from Task 1.

---

### Task 3: Java target

Appends the Java `@test` block to each of the five `.bats` files and creates `src/NAME/java/spec.plcc`.

**Files:**
- Create: `src/NAME/java/spec.plcc`
- Modify: all five `src/NAME/tests/<case>/NAMEtest.bats`
- Test: `bats --recursive src/NAME/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/NAME/grammar.plcc` and the five test case directories from Task 2.
- Produces: `src/NAME/java/spec.plcc` with the same class and method names as the Python target — `ThunkRef(Exp exp, Env env)`, `Val deRef()`, `Val setRef(Val v)`, `Ref evalRef(Env env)` on `Exp`, `LitExp`, and `ProcExp`.

- [ ] **Step 1: Add the Java `@test` block to each `.bats` file**

Append to each `src/NAME/tests/<case>/NAMEtest.bats`, after the existing Python block, with `<case>` replaced by that directory's name:

```bash

@test "NAME <case> (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/<case>/NAME.input)"
  expected_output=$(< "../tests/<case>/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

The `.input` and `.expected` files are shared — all three targets must produce identical output. Do not create per-target expected files.

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `bats --recursive src/NAME/tests`
Expected: 10 tests — 5 passing (python) and 5 failing (java, no `java/` directory yet).

- [ ] **Step 3: Create the Java target**

```bash
mkdir -p src/NAME/java
cp src/REF/java/spec.plcc src/NAME/java/spec.plcc
```

Make **four** edits and nothing else. Java needs no import changes at all — same-directory, package-less classes reference each other directly — so there is no Java counterpart to the Python `:import` work.

**(a) Insert a `ThunkRef` block between the existing `Ref` block and the existing `ValRef` block.** Immediately above the line `ValRef` that begins the `ValRef` block:

```
ThunkRef
%%%
import runtime.LanguageError;

public class ThunkRef extends Ref {

    public Exp exp;
    public Env env;

    public ThunkRef(Exp exp, Env env) {
        this.exp = exp;
        this.env = env;
    }

    public Val deRef() {
        return exp.eval(env);
    }

    public Val setRef(Val v) {
        throw new LanguageError("cannot modify a read-only expression");
    }

    public String toString() {
        return "thunk";
    }
}
%%%

```

**(b) Rewrite the `Exp` block.** Replace:

```
Exp
%%%
public abstract Val eval(Env env);

public Ref evalRef(Env env) {
    return new ValRef(eval(env));
}
%%%
```

with:

```
Exp
%%%
public abstract Val eval(Env env);

// this covers all but a LitExp, ProcExp, and VarExp
public Ref evalRef(Env env) {
    return new ThunkRef(this, env);
}
%%%
```

**(c) Give `LitExp` an `evalRef` override.** In the `LitExp` block, replace:

```
public Val eval(Env env) {
    return new IntVal(lit.lexeme);
}
```

with:

```
public Val eval(Env env) {
    return new IntVal(lit.lexeme);
}

public Ref evalRef(Env env) {
    return new ValRef(eval(env));
}
```

**(d) Give `ProcExp` an `evalRef` override.** In the `ProcExp` block, replace:

```
public Val eval(Env env) {
    return proc.makeClosure(env);
}
```

with:

```
public Val eval(Env env) {
    return proc.makeClosure(env);
}

public Ref evalRef(Env env) {
    return new ValRef(eval(env));
}
```

Verify:

```bash
diff src/REF/java/spec.plcc src/NAME/java/spec.plcc
```

Expected: four hunks — the inserted `ThunkRef` block, the `Exp` rewrite, the `LitExp` addition, and the `ProcExp` addition.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats --recursive src/NAME/tests`
Expected: 10 tests, 10 passing.

- [ ] **Step 5: Confirm Java agrees with Python character-for-character**

```bash
( cd src/NAME/java   && plcc-rep < ../Prog/jensen ) > /tmp/name-java-jensen.txt
( cd src/NAME/python && plcc-rep < ../Prog/jensen ) > /tmp/name-python-jensen.txt
diff /tmp/name-java-jensen.txt /tmp/name-python-jensen.txt
```

Expected: no output.

- [ ] **Step 6: Run the full suite**

```bash
bin/test.bash > /tmp/name-task3.txt 2>&1
grep -c '^ok ' /tmp/name-task3.txt      # expect 110
grep -c '^not ok ' /tmp/name-task3.txt  # expect 4
```

Expected: **114 tests, 110 passing, 4 failing** (NEED, OBJ, TYPE0, TYPE1).

- [ ] **Step 7: Commit**

```bash
git add src/NAME/java src/NAME/tests
git commit -m "feat(NAME): port Java target to plcc-ng

Refs #NN"
```

---

### Task 4: JavaScript target

Appends the JavaScript `@test` block to each of the five `.bats` files and creates `src/NAME/javascript/spec.plcc`.

**Files:**
- Create: `src/NAME/javascript/spec.plcc`
- Modify: all five `src/NAME/tests/<case>/NAMEtest.bats`
- Test: `bats --recursive src/NAME/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/NAME/grammar.plcc` and the five test case directories from Task 2.
- Produces: `src/NAME/javascript/spec.plcc` with the same class and method names as the other two targets, and `module.exports = { ThunkRef };`.

- [ ] **Step 1: Add the JavaScript `@test` block to each `.bats` file**

Append to each `src/NAME/tests/<case>/NAMEtest.bats`, after the Java block, with `<case>` replaced by that directory's name:

```bash

@test "NAME <case> (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/<case>/NAME.input)"
  expected_output=$(< "../tests/<case>/NAME.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `bats --recursive src/NAME/tests`
Expected: 15 tests — 10 passing (python, java) and 5 failing (javascript).

- [ ] **Step 3: Create the JavaScript target**

```bash
mkdir -p src/NAME/javascript
cp src/REF/javascript/spec.plcc src/NAME/javascript/spec.plcc
```

Make **four** edits and nothing else.

**(a) Insert a `ThunkRef` block between the existing `Ref` block and the existing `ValRef` block.** Immediately above the line `ValRef` that begins the `ValRef` block:

```
ThunkRef
%%%
const { Ref } = require('./Ref');
const { LanguageError } = require('./runtime/base');

class ThunkRef extends Ref {

    constructor(exp, env) {
        super();
        this.exp = exp;
        this.env = env;
    }

    deRef() {
        return this.exp.eval(this.env);
    }

    setRef(v) {
        throw new LanguageError("cannot modify a read-only expression");
    }

    toString() {
        return "thunk";
    }
}

module.exports = { ThunkRef };
%%%

```

`ThunkRef` is a **free-standing** class, so it gets no auto-injected requires and must require `LanguageError` itself. This is the opposite of the rule for grammar-derived classes, where an explicit `require` of `Node`, `Token`, or `LanguageError` fails with `Identifier 'X' has already been declared`.

**(b) Rewrite the `Exp:import` and `Exp` blocks.** Replace:

```
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

with:

```
Exp:import
%%%
const { ThunkRef } = require('./ThunkRef');
%%%

Exp
%%%
// this covers all but a LitExp, ProcExp, and VarExp
evalRef(env) {
    return new ThunkRef(this, env);
}
%%%
```

`Exp` is grammar-derived, so requiring only `ThunkRef` here is correct — `LanguageError` is already injected for it.

**(c) Give `LitExp` an `evalRef` override.** Replace:

```
LitExp:import
%%%
const { IntVal } = require('./IntVal');
%%%
```

with:

```
LitExp:import
%%%
const { IntVal } = require('./IntVal');
const { ValRef } = require('./ValRef');
%%%
```

and in the `LitExp` block, replace:

```
eval(env) {
    return new IntVal(this.lit.lexeme);
}
```

with:

```
eval(env) {
    return new IntVal(this.lit.lexeme);
}

evalRef(env) {
    return new ValRef(this.eval(env));
}
```

**(d) Give `ProcExp` an `evalRef` override and a new `:import` block.** Replace:

```
ProcExp
%%%
eval(env) {
    return this.proc.makeClosure(env);
}

toString() {
    return " ...ProcExp... ";
}
%%%
```

with:

```
ProcExp:import
%%%
const { ValRef } = require('./ValRef');
%%%

ProcExp
%%%
eval(env) {
    return this.proc.makeClosure(env);
}

evalRef(env) {
    return new ValRef(this.eval(env));
}

toString() {
    return " ...ProcExp... ";
}
%%%
```

Verify:

```bash
diff src/REF/javascript/spec.plcc src/NAME/javascript/spec.plcc
```

Expected: four hunks — the inserted `ThunkRef` block, the `Exp:import`/`Exp` rewrite, the `LitExp` changes, and the `ProcExp` changes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats --recursive src/NAME/tests`
Expected: 15 tests, 15 passing.

A `ReferenceError: ValRef is not defined` from `ProcExp` means the `ProcExp:import` block in (d) is missing. An `Identifier 'LanguageError' has already been declared` means you added a require for `Node`, `Token`, or `LanguageError` to a *grammar-derived* class — those three are auto-injected into every grammar-derived file, and only free-standing classes like `ThunkRef` may require them.

- [ ] **Step 5: Confirm all three targets agree character-for-character**

```bash
for t in python java javascript; do
  ( cd "src/NAME/$t" && plcc-rep < ../Prog/jensen ) > "/tmp/name-$t-jensen.txt"
done
diff /tmp/name-python-jensen.txt /tmp/name-java-jensen.txt
diff /tmp/name-python-jensen.txt /tmp/name-javascript-jensen.txt
```

Expected: no output from either `diff`.

- [ ] **Step 6: Run the full suite**

```bash
bin/test.bash > /tmp/name-task4.txt 2>&1
grep -c '^ok ' /tmp/name-task4.txt      # expect 115
grep -c '^not ok ' /tmp/name-task4.txt  # expect 4
grep '^not ok ' /tmp/name-task4.txt
```

Expected: **119 tests, 115 passing, 4 failing** — NEED, OBJ, TYPE0, TYPE1, all `plccmk: command not found`. This is the plan's final test shape; Tasks 5 and 6 must not change it.

- [ ] **Step 7: Commit**

```bash
git add src/NAME/javascript src/NAME/tests
git commit -m "feat(NAME): port JavaScript target to plcc-ng

Refs #NN"
```

---

### Task 5: Verify the example programs against all three targets

NAME's `Prog/` needs **no consolidation** — unlike REF there is no `Stuff/` directory, no loose top-level program, and no file with a syntax error. All eight programs are already in `src/NAME/Prog/`. This task runs them rather than assuming they still work, and records the NAME-versus-REF contrast as course material.

**Files:**
- Modify: `dev-docs/course-material-impact.md`
- Test: manual `plcc-rep` runs, then `bin/test.bash`

**Interfaces:**
- Consumes: all three `src/NAME/<target>/spec.plcc` from Tasks 2–4.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Confirm the directory really has nothing to consolidate**

```bash
ls src/NAME
```

Expected: `Prog`, `code`, `envRef`, `grammar`, `grammar.plcc`, `java`, `javascript`, `prim`, `python`, `ref`, `tests`, `val`. If there is a `Stuff/` directory or a loose program file, **stop** — the design says there is none, and the plan's claim that this task is verification-only is wrong.

- [ ] **Step 2: Run every program against all three targets**

```bash
for t in python java javascript; do
  echo "#### $t"
  for prog in countdown counter divideByZero jensen looper pppp sumsq test; do
    printf '  %-14s ' "$prog"
    ( cd "src/NAME/$t" && plcc-rep < "../Prog/$prog" ) | tr '\n' ' '
    echo
  done
done
```

Expected — identical in all three targets:

| program | expected output |
|---|---|
| `countdown` | `while 42` |
| `counter` | `1` |
| `divideByZero` | `11` |
| `jensen` | `while 55` |
| `looper` | `p g 8` |
| `pppp` | `7` |
| `sumsq` | `while 385` |
| `test` | `10` |

Two of these look like regressions and are not. `counter` gives `1`, not `4`, because the operand `let count=0 in proc() set count=add1(count)` is a thunk rebuilt on every one of `times4`'s four calls. `test` gives `10`, not `4`, because the thunk `set x=add1(x)` is forced seven times. Both are call-by-name working correctly. Do not "fix" either program.

- [ ] **Step 3: Measure the REF contrast**

```bash
for prog in pppp test counter divideByZero; do
  printf 'REF %-14s ' "$prog"
  ( cd src/REF/python && plcc-rep < "../../NAME/Prog/$prog" 2>&1 ) | tr '\n' ' '
  echo
done
```

Expected: `6`, `4`, `4`, and `attempt to divide by zero`.

Do **not** run `Prog/jensen` or `Prog/looper` against REF as part of the suite — under call-by-value both diverge (Python raises `RecursionError` after a long climb, and the other two targets may hang). That divergence is the finding, and it is already recorded in the design doc; there is nothing to measure again.

- [ ] **Step 4: Add the course-material impact entries**

Add to the `## NAME` section of `dev-docs/course-material-impact.md`:

- The NAME-versus-REF contrast table for `pppp` (`7` vs `6`), `test` (`10` vs `4`), `counter` (`1` vs `4`), and `divideByZero` (`11` vs a divide-by-zero error), noting that these are the same programs run against two shipped specs, so the contrast is a live demo rather than a claim.
- That `Prog/jensen` and `Prog/looper` **do not terminate** under call-by-value, which makes them the sharpest available demonstration that call-by-name is not merely a different answer but a different set of runnable programs.
- That `Prog/counter` reads like an ordinary counter and gives `1`, and `Prog/test` gives `10` — both correct, both surprising, and both worth pre-empting in a lecture before a student reports them as bugs.

- [ ] **Step 5: Run the full suite**

```bash
bin/test.bash > /tmp/name-task5.txt 2>&1
grep -c '^ok ' /tmp/name-task5.txt      # expect 115
grep -c '^not ok ' /tmp/name-task5.txt  # expect 4
```

Expected: unchanged from Task 4 — **119 tests, 115 passing, 4 failing**. This task adds no tests; a change here means a `plcc-rep` run left build artifacts somewhere it shouldn't.

- [ ] **Step 6: Check for stray build artifacts**

```bash
git status --porcelain
```

Expected: only `dev-docs/course-material-impact.md` as modified. `plcc-ng/`, `__pycache__/`, and `*.class` are gitignored, so they will not appear — but if any *other* path shows up, investigate before committing.

- [ ] **Step 7: Commit**

```bash
git add dev-docs/course-material-impact.md
git commit -m "docs: record NAME's example-program behavior and REF contrast

Refs #NN"
```

---

### Task 6: Remove NAME's old-PLCC files and close the issue

**Files:**
- Delete: `src/NAME/{grammar,code,prim,envRef,val,ref}`
- Modify: `dev-docs/issues/0NN-migrate-name-to-plcc-ng.md`, `dev-docs/roadmap.md` (both by script)
- Test: `bin/test.bash`

**Interfaces:**
- Consumes: `NN` from Task 1; a green suite from Task 5.
- Produces: nothing.

- [ ] **Step 1: Confirm nothing still references the old files**

Scope both greps to the **ported** artifacts. The flat `src/NAME/grammar` is itself the only file that `%include`s the other five, so a bare `grep -rn ... src/NAME/` would always match — in the very file being deleted — and the check would never pass:

```bash
PORTED="src/NAME/grammar.plcc src/NAME/python src/NAME/java src/NAME/javascript src/NAME/tests"
grep -rn '%include \(code\|prim\|envRef\|val\|ref\)$' $PORTED || echo "no old includes remain"
grep -rn 'plccmk\|rep -n' $PORTED || echo "no old invocations remain"
```

Expected: both print their "no ... remain" message. The `$` anchors the first pattern to a bare filename, so the ported specs' legitimate `%include ../../Env/envRef/<target>/env.plcc` does not match. If either grep finds something, a `.bats` file or spec was not fully ported; fix that before deleting anything.

- [ ] **Step 2: Delete the old-PLCC files**

```bash
git rm src/NAME/grammar src/NAME/code src/NAME/prim src/NAME/envRef src/NAME/val src/NAME/ref
```

`src/NAME/grammar` and `src/NAME/grammar.plcc` are different paths, so nothing collides and this deletion is safe to leave until now — unlike SET's `envRef`, which had to go first.

- [ ] **Step 3: Run the full suite**

```bash
bin/test.bash > /tmp/name-task6.txt 2>&1
grep -c '^ok ' /tmp/name-task6.txt      # expect 115
grep -c '^not ok ' /tmp/name-task6.txt  # expect 4
grep '^not ok ' /tmp/name-task6.txt
```

Expected: **119 tests, 115 passing, 4 failing** — NEED, OBJ, TYPE0, TYPE1. Deleting files that nothing reads must not move any number. If a count changed, something did still read them.

- [ ] **Step 4: Commit the deletion**

```bash
git commit -m "refactor(NAME): remove old-PLCC sources superseded by the plcc-ng port

Refs #NN"
```

- [ ] **Step 5: Close the issue**

```bash
bin/issues/close.bash NN
```

This fills in the issue's `closed` date, removes its Open Issues roadmap entry (and the `### Feat` heading, now that it is empty), and runs `bin/issues/check.bash`. Review the staged roadmap diff before committing — `close.bash` does not edit milestone prose, and this repo has seen it rewrite plan prose before (issue [#18](../issues/018-close-bash-rewrites-plan-prose.md)).

- [ ] **Step 6: Commit the close**

```bash
git status --porcelain   # expect only the two files close.bash staged
git commit -m "docs(issues): close issue NN (migrate NAME to plcc-ng), update roadmap"
```

This is the branch's final commit.

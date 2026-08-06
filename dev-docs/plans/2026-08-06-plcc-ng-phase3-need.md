# plcc-ng Phase 3 — NEED Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port NEED (`NAME + memoization`) to plcc-ng in Python, Java, and JavaScript.

**Architecture:** NEED is NAME plus three things. `src/NEED/grammar.plcc` is NAME's file with a changed header, a `token ERROR 'error'` line, and a `<Prim:ErrorPrim>` production — the only syntax delta among Phase 3's four languages. Each target's `spec.plcc` is a copy of NAME's with a five-hunk delta: `ThunkRef` gains a `val` field and a memoizing `deRef`; a new free-standing `ValRORef extends ValRef` throws on `setRef`; `LitExp.evalRef` and `ProcExp.evalRef` return `ValRORef` instead of `ValRef`, with the Python/JavaScript `:import` blocks that follow; and an `ErrorPrim` class block is appended. The shared `src/Env/envRef/<target>/env.plcc` is `%include`d **unchanged** — this phase touches nothing under `src/Env/`.

**Tech Stack:** plcc-ng (`plcc-rep`), bats (`bin/test.bash`), Python 3, Java, Node.js.

**Design of record:** [dev-docs/specs/2026-08-05-plcc-ng-need-design.md](../specs/2026-08-05-plcc-ng-need-design.md). Read it before Task 1.

## Global Constraints

- **Work in the existing worktree** `/workspaces/languages-ng/.claude/worktrees/migrate-NEED`, branch `worktree-migrate-NEED`. Do not create a new worktree. Do not `cd` to the main checkout.
- **Baseline, measured 2026-08-05:** `bin/test.bash` gives **119 tests, 115 passing, 4 failing**. The 4 failures are NEED, OBJ, TYPE0, TYPE1 — all `plccmk: command not found`. Count with `grep -c '^ok '` and `grep -c '^not ok '` over the **whole** run, never a `tail`.
- **No test that passes may start failing.** There is no retro-fix in this phase touching already-passing languages, so a `V`-prefixed, `SET`, `REF`, or `NAME` failure means a genuine regression, not expected churn.
- **The Jensen device diverges under call-by-need, and that is correct.** `test?` is memoized on first force, so the loop condition can never become false. NAME's `Prog/{jensen,sumsq,countdown}` die with `StackOverflowError` / `RangeError` / `RecursionError` under NEED. **Do not copy any of them into `src/NEED/Prog/`, do not write a test for the divergence, and do not "fix" the memoization to make them work.** It is documented in Task 5, and nowhere else.
- **`apply` keeps its `Env` parameter** in every target — `apply(args, env)` / `apply(List<Ref> args, Env e)`. It is unread at runtime. It is the seam for a dynamic-scoping homework assignment. **Never remove it as dead code.** The pre-migration `src/NEED/val` declares `apply(List<Ref> refList)` with no `Env` and no arity check; that shape is not carried forward. Copying NAME's spec, as every task below does, gets this right for free — the risk is "tidying" it afterwards.
- **`VarExp.evalRef` is inherited from NAME unchanged**, which is what keeps a bare variable operand call-by-*reference* and still assignable. Likewise `Exp.evalRef` still returns a `ThunkRef`, and `Rands.evalRandsRef`, `AppExp`, `SetExp`, and both `LetDecls` methods are untouched — **`let` stays eager**; call-by-need is a rule about operands only.
- **`ThunkRef` keeps the null sentinel in all three targets** (`if self.val is None` / `if (val == null)` / `if (this.val === null)`). Do not substitute a `forced` boolean. No `Val` is ever null, and the three targets mirror the Java reference shape by standing rule.
- **`Define` needs no decision.** NEED's `System.out.println(id)` is already uncommented in `src/NEED/code`, so the ported `Define` returns the defined name exactly as NAME's does. Every expected file in this plan assumes the name is printed.
- **Do not touch `src/Env/`.** SET ported `envRef`; REF and NAME reused it unchanged; NEED reuses it unchanged again. In particular, do **not** port anything out of `src/NEED/envRef` — that file is deleted in Task 6, not migrated. It is byte-identical to NAME's, which already *is* the canonical `void checkDuplicates` shape.
- **Grammar conventions, unchanged from V0–V6, SET, REF, and NAME:** identifier token is `SYMBOL` (never `VAR`); nonterminals are PascalCase; multi-capture alt-names are camelCase (`<Exp:testExp>`), not the obsolete lowercase workaround.
- **Expected files carry no trailing newline** — verified against all five of NAME's. Use `printf`, not `echo`. This is cosmetic (`$(< file)` and `$(...)` both strip trailing newlines, so a stray one would not fail a test), but match the convention.
- **Course-material impact entries go in the same commit as the change they describe**, under a `## NEED` heading in [dev-docs/course-material-impact.md](../course-material-impact.md), added after the existing `## NAME` section. Never batch them.
- **Never assign issue numbers by hand.** Use `bin/issues/new.bash` and `bin/issues/close.bash`.
- Every target's `spec.plcc` writes build artifacts to a `plcc-ng/` subdirectory; `.gitignore` already covers `plcc-ng/`, `__pycache__/`, and `*.class`. Never commit them.

---

### Task 1: File the NEED issue and confirm the baseline

Pure bookkeeping plus the gate that every later task's expected counts depend on.

**Files:**
- Create: `dev-docs/issues/0NN-migrate-need-to-plcc-ng.md` (number assigned by the script)
- Modify: `dev-docs/roadmap.md`
- Test: the existing suite — `bin/test.bash`

**Interfaces:**
- Consumes: nothing.
- Produces: the issue number `NN`, referenced by Task 6's `bin/issues/close.bash <NN>`.

- [ ] **Step 1: File the issue**

```bash
cd /workspaces/languages-ng/.claude/worktrees/migrate-NEED
bin/issues/new.bash migrate-need-to-plcc-ng feat
```

Note the number it prints — that is `NN` for the rest of this plan. Fill in the issue's `## Description` with the NEED port: a three-line grammar delta (`ERROR` token, `ErrorPrim` production, header comment), the five-hunk semantic delta over NAME, three targets, four test cases, and no `Prog/` consolidation. Add a `## Notes` section pointing at the design doc, recording that the Jensen device diverges under call-by-need by design, and listing what is out of scope (TYPE0, TYPE1, OBJ; error-path tests; issues #16, #19, #22). Leave `target:` at its default (`this repo`) — this is our own work, not a plcc-ng defect.

- [ ] **Step 2: Add the roadmap entry**

Add an entry to the **Open Issues** section of `dev-docs/roadmap.md`, under a `### Feat` heading. That heading does **not** exist today — the roadmap's contract is that a type group exists only while it has open entries, and `close.bash` removed the last one at the end of NAME's phase. Create it, placed alphabetically among the existing `### Chore`, `### Docs`, and `### Test` headings (so: Chore, Docs, **Feat**, Test). Use this exact two-line format, which the scripts parse:

```markdown
- **[#0NN](issues/0NN-migrate-need-to-plcc-ng.md) — migrate-need-to-plcc-ng**
  Port NEED (NAME + memoization) to plcc-ng in Python, Java, and JavaScript: an `ERROR` token and `ErrorPrim` production, a memoizing `ThunkRef`, a read-only `ValRORef`, and four value-only test cases.
```

- [ ] **Step 3: Verify the issue bookkeeping is consistent**

Run: `bin/issues/check.bash`
Expected: exit status 0, no output about drift. If it complains, fix the roadmap entry's format before continuing — `close.bash` in Task 6 parses the same shape.

- [ ] **Step 4: Capture the baseline**

```bash
bin/test.bash > /tmp/need-baseline.txt 2>&1
grep -c '^ok ' /tmp/need-baseline.txt      # expect 115
grep -c '^not ok ' /tmp/need-baseline.txt  # expect 4
grep '^not ok ' /tmp/need-baseline.txt
```

Expected: `115` and `4`, and the four failures are NEED, OBJ, TYPE0, TYPE1. If any of that differs, **stop** — the plan's counts are stale and every later task's expectation is wrong.

- [ ] **Step 5: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): file NEED migration issue, update roadmap"
```

---

### Task 2: Grammar + Python target + all four test cases

Delivers `src/NEED/grammar.plcc`, the Python `spec.plcc`, and all four test cases with their **Python** `@test` blocks. Tasks 3 and 4 append the Java and JavaScript blocks to the same `.bats` files.

**Files:**
- Create: `src/NEED/grammar.plcc`
- Create: `src/NEED/python/spec.plcc`
- Create: `src/NEED/Prog/counter` (copied from `src/NAME/Prog/counter`)
- Rename: `src/NEED/tests/let/` → `src/NEED/tests/thunk-forced-once/`, then replace its `NEED.input`
- Create: `src/NEED/tests/memoized-across-calls/{NEED.input,NEED.expected,NEEDtest.bats}`
- Create: `src/NEED/tests/unused-arg-not-evaluated/{NEED.input,NEED.expected,NEEDtest.bats}`
- Create: `src/NEED/tests/infinite-stream/{NEED.input,NEED.expected,NEEDtest.bats}`
- Modify: `src/NEED/tests/thunk-forced-once/NEEDtest.bats` (replace the old `plccmk`/`rep -n` invocation)
- Modify: `dev-docs/course-material-impact.md`
- Test: `bats --recursive src/NEED/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `NN` from Task 1 (not used until Task 6).
- Produces:
  - `src/NEED/grammar.plcc`, `%include`d by all three targets, defining the `ERROR` token and the `<Prim:ErrorPrim>` production.
  - `src/NEED/python/spec.plcc` defining a free-standing `ValRORef(val)` subclass of `ValRef` overriding `setRef(v)`; a `ThunkRef(exp, env)` whose `deRef()` memoizes into `self.val`; `LitExp.evalRef(env) -> Ref` and `ProcExp.evalRef(env) -> Ref` returning `ValRORef`; and an `ErrorPrim` with `apply(args)`.
  - The four test case directories, which Tasks 3 and 4 append `@test` blocks to.

- [ ] **Step 1: Create the grammar**

```bash
cp src/NAME/grammar.plcc src/NEED/grammar.plcc
```

Then make exactly three edits to `src/NEED/grammar.plcc`.

**(a)** Change the two header lines from:

```
# Language NAME
#   Language REF with call-by-name semantics
```

to:

```
# Language NEED
#   Language NAME with call-by-need instead of call-by-name semantics
```

**(b)** Add an `ERROR` token immediately after the `token SET 'set'` line:

```
token ERROR 'error'
```

It must sit above `token SYMBOL '[A-Za-z][\w?]*'`, whose pattern would otherwise swallow the word `error`. Anywhere among the keywords is fine; directly after `SET` matches the pre-migration flat `src/NEED/grammar`.

**(c)** Add the production immediately after `<Prim:ZeropPrim> ::= ZEROP`:

```
<Prim:ErrorPrim> ::= ERROR
```

`<Prim:ErrorPrim>` is sixteen characters, the same width as `<Prim:ZeropPrim>`, so a single space before `::=` keeps the column alignment the rest of the block uses.

Confirm the edit is exactly those three changes:

```bash
diff src/NAME/grammar.plcc src/NEED/grammar.plcc
```

Expected, character for character:

```
1,2c1,2
< # Language NAME
< #   Language REF with call-by-name semantics
---
> # Language NEED
> #   Language NAME with call-by-need instead of call-by-name semantics
25a26
> token ERROR 'error'
55a57
> <Prim:ErrorPrim> ::= ERROR
```

Anything else means you edited something you shouldn't have.

- [ ] **Step 2: Copy in the `counter` example program**

`memoized-across-calls/` runs NAME's `Prog/counter`, which NEED does not have a copy of:

```bash
cp src/NAME/Prog/counter src/NEED/Prog/counter
```

- [ ] **Step 3: Rename the existing test case and replace its input**

The existing `src/NEED/tests/let/` **is** the `thunk-forced-once` case — the same idea, renamed for what it tests, and upgraded from its three-use program to the seven-use program already sitting at `src/NEED/Prog/test`. That upgrade is the point: it is the same program NAME's `tests/thunk-reevaluated-per-use/` runs, so the NAME↔NEED contrast becomes one program with two different expected values.

```bash
git mv src/NEED/tests/let src/NEED/tests/thunk-forced-once
cp src/NEED/Prog/test src/NEED/tests/thunk-forced-once/NEED.input
diff <(grep -v '^[[:space:]]*$' src/NEED/tests/thunk-forced-once/NEED.input) \
     <(grep -v '^[[:space:]]*$' src/NAME/tests/thunk-reevaluated-per-use/NAME.input)
```

Expected: no output. If there is any, the two languages are no longer running the same program and the mirror-pair claim in the design is broken.

The comparison ignores blank lines on purpose: the two files are **not** byte-identical. NAME's carries one blank line after the `p = proc(t) …` binding that NEED's does not. Whitespace is `skip`ped by the lexer, so it changes nothing about what runs, and each language keeps its test input sourced from its own `Prog/` directory rather than reaching into its neighbour's. Do not "fix" either file to match the other.

The existing `NEED.expected` already reads `4` and is correct for the seven-use program too — the whole point is that the number does not depend on how many times the formal appears. Leave it alone. The directory's `NEEDtest.bats` comes along with the rename still holding its old `plccmk`/`rep -n` invocation; Step 5 overwrites it in place.

- [ ] **Step 4: Create the three new test cases**

```bash
mkdir -p src/NEED/tests/memoized-across-calls \
         src/NEED/tests/unused-arg-not-evaluated \
         src/NEED/tests/infinite-stream
cp src/NEED/Prog/counter src/NEED/tests/memoized-across-calls/NEED.input
cp src/NEED/Prog/natno   src/NEED/tests/infinite-stream/NEED.input
printf 'let p = proc(t,u) t in .p(11,error())\n' > src/NEED/tests/unused-arg-not-evaluated/NEED.input
```

Then write the three expected files. These are the measured outputs from the design's spike, identical in all three targets — `infinite-stream`'s was compared by md5 across the three, not by eye:

```bash
printf '4'  > src/NEED/tests/memoized-across-calls/NEED.expected
printf '11' > src/NEED/tests/unused-arg-not-evaluated/NEED.expected
printf 'pair\nfirst\nrest\nnth\nseq\nnatno\n0\n1\n2\n100' \
            > src/NEED/tests/infinite-stream/NEED.expected
```

The `pair`/`first`/`rest`/`nth`/`seq`/`natno` lines are `Define._run()` returning each defined name, six `define`s before the four expression results. A missing block of names means someone suppressed `Define`'s return value.

- [ ] **Step 5: Write the four `.bats` files with their Python block only**

Each `src/NEED/tests/<case>/NEEDtest.bats` gets exactly this content, with `<case>` replaced by that directory's name. This is NAME's shape verbatim, with `NAME` swapped for `NEED`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NEED <case> (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/<case>/NEED.input)"
  expected_output=$(< "../tests/<case>/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

So `src/NEED/tests/infinite-stream/NEEDtest.bats` reads:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "NEED infinite-stream (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/infinite-stream/NEED.input)"
  expected_output=$(< "../tests/infinite-stream/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

and the other three are the same file with `infinite-stream` replaced by `thunk-forced-once`, `memoized-across-calls`, and `unused-arg-not-evaluated`. `relocate` copies the whole `src/` tree into the test's tmpdir and lands you in `src/NEED/`, which is why the paths are `../tests/...` after the `cd python`.

- [ ] **Step 6: Run the tests to verify they fail**

Run: `bats --recursive src/NEED/tests`
Expected: 4 tests, all failing — there is no `python/` directory yet, so the `cd python` fails. If any test *passes* here, the assertion is not running; stop and find out why before writing the implementation.

- [ ] **Step 7: Create the Python target**

```bash
mkdir -p src/NEED/python
cp src/NAME/python/spec.plcc src/NEED/python/spec.plcc
```

The file's two `%include` lines need **no** change. `%include ../grammar.plcc` resolves relative to the spec file, so from `src/NEED/python/` it already picks up NEED's own grammar rather than NAME's, and `%include ../../Env/envRef/python/env.plcc` is the shared Env variant NEED reuses unchanged. Make **five** edits and nothing else.

**(a) Make `ThunkRef.deRef` memoize.** In the existing `ThunkRef` block, replace:

```
    def __init__(self, exp, env):
        self.exp = exp
        self.env = env

    def deRef(self):
        return self.exp.eval(self.env)
```

with:

```
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
```

This one method is the whole of call-by-need. `setRef` and `__str__` in the same block are unchanged.

**(b) Insert a `ValRORef` block between the existing `ValRef` block and the existing `ProcVal` block.** Find the line `ProcVal` that begins the `ProcVal` block and insert immediately above it:

```
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

It inherits `__init__`, `deRef`, and `__str__` from `ValRef`; only `setRef` differs.

**(c) Point `LitExp` at `ValRORef`.** Replace:

```
LitExp:import
%%%
from IntVal import IntVal
from ValRef import ValRef
%%%
```

with:

```
LitExp:import
%%%
from IntVal import IntVal
from ValRORef import ValRORef
%%%
```

and in the `LitExp` block, replace:

```
def evalRef(self, env):
    return ValRef(self.eval(env))
```

with:

```
def evalRef(self, env):
    return ValRORef(self.eval(env))  # a literal is read-only
```

**(d) Point `ProcExp` at `ValRORef`.** Replace:

```
ProcExp:import
%%%
from ValRef import ValRef
%%%
```

with:

```
ProcExp:import
%%%
from ValRORef import ValRORef
%%%
```

and in the `ProcExp` block, replace:

```
def evalRef(self, env):
    return ValRef(self.eval(env))
```

with:

```
def evalRef(self, env):
    return ValRORef(self.eval(env))  # read-only
```

Two warnings about (c) and (d). The `evalRef` body being replaced is **textually identical in both blocks** — `return ValRef(self.eval(env))` appears once in `LitExp` and once in `ProcExp` — so a search-and-replace that stops at the first match leaves `ProcExp` on the old behavior, and only a `proc` passed as an operand would catch it. And the import must change in both. Each generated class file gets only its own imports, so leaving `from ValRef import ValRef` in place gives `NameError: name 'ValRORef' is not defined` in that one file.

**(e) Append `ErrorPrim` at the end of the file**, after the closing `%%%` of the `ZeropPrim` block:

```

ErrorPrim:import
%%%
from runtime.base import LanguageError
%%%

ErrorPrim
%%%
def __str__(self):
    return "error"

def apply(self, args):
    raise LanguageError("user-defined error")
%%%
```

`apply` takes `args` and ignores it — `error()` throws regardless of how it is called, matching the pre-migration flat `src/NEED/prim`.

Verify the whole edit is exactly these five changes and nothing else:

```bash
diff src/NAME/python/spec.plcc src/NEED/python/spec.plcc
```

Expected: hunks for the `ThunkRef` memoization, the inserted `ValRORef` block, the `LitExp` import and override, the `ProcExp` import and override, and the appended `ErrorPrim`. Anything else is an accident; revert it.

- [ ] **Step 8: Run the tests to verify they pass**

Run: `bats --recursive src/NEED/tests`
Expected: 4 tests, 4 passing.

If `thunk-forced-once` gives `10` instead of `4`, edit (a) did not take and the thunk is still re-evaluating. If `unused-arg-not-evaluated` fails to parse, edit (c) of Step 1 — the `<Prim:ErrorPrim>` production — is missing from the grammar.

- [ ] **Step 9: Sanity-check the NAME contrast**

The point of NEED is that it disagrees with NAME. Confirm it does, rather than assuming. Each `cd` is wrapped in a subshell so a failing `plcc-rep` cannot leave you in the wrong directory for the next command:

```bash
( cd src/NAME/python && plcc-rep < ../Prog/test )
( cd src/NEED/python && plcc-rep < ../Prog/test )
```

Expected: `10` from NAME, `4` from NEED. Identical answers mean the memoization is not taking effect and the port is wrong even though the tests may pass for another reason.

Then confirm `ValRORef` fires and inherited NAME behavior still holds:

```bash
( cd src/NEED/python && echo 'let p = proc(t) set t=9 in .p(11)' | plcc-rep )
( cd src/NEED/python && echo 'let x=3 p=proc(t) set t=add1(t) in {.p(x); x}' | plcc-rep )
( cd src/NEED/python && echo 'error()' | plcc-rep )
```

Expected: `cannot modify a read-only reference` (NAME gives `9` here), then `4` (a bare variable operand is still by-reference — `VarExp.evalRef` untouched), then `user-defined error`.

- [ ] **Step 10: Run the full suite**

```bash
bin/test.bash > /tmp/need-task2.txt 2>&1
grep -c '^ok ' /tmp/need-task2.txt      # expect 119
grep -c '^not ok ' /tmp/need-task2.txt  # expect 3
grep '^not ok ' /tmp/need-task2.txt
```

Expected: **122 tests, 119 passing, 3 failing.** That is the baseline's 119 tests, minus NEED's 1 old test, plus 4 new Python tests. The 3 remaining failures are OBJ, TYPE0, TYPE1 — all `plccmk: command not found`. Any `V`-prefixed, `SET`, `REF`, or `NAME` failure is a regression; stop and fix it.

- [ ] **Step 11: Add the course-material impact entries**

Append a `## NEED` section to `dev-docs/course-material-impact.md`, after the existing `## NAME` section, matching the prose style of the sections already there. Cover, one bullet each:

- The `VAR` → `SYMBOL` token rename and the `var` → `symbol` field rename, the standing convention since V0 — `VarExp` reads `env.applyEnv(self.symbol.lexeme)`.
- `$run()` → `_run()`, which **returns** its output string rather than printing it.
- `ThunkRef` now memoizing: a `val` field initialized to null and a `deRef` that evaluates once and caches. Note that this single method is the entire difference between NAME and NEED, and that `Prog/test` therefore gives `4` under NEED where it gives `10` under NAME.
- `ValRORef`, a new read-only `ValRef` subclass, returned by `LitExp.evalRef` and `ProcExp.evalRef` where NAME returned a plain `ValRef`. Give the observable: `let p = proc(t) set t=9 in .p(11)` now raises `cannot modify a read-only reference`, where NAME returns `9`. `VarExp.evalRef` is unchanged, so assigning through a bare variable formal still works.
- The new `ERROR` token and `ErrorPrim` production — NEED's only syntax delta from NAME — whose `apply` raises `user-defined error` regardless of its arguments.
- `apply` taking a `List<Ref>` **and** an `Env` (the dynamic-scoping homework seam), where pre-migration NEED's `apply(List<Ref>)` had no `Env`, and `ProcVal.apply` now raising `formals/args number mismatch` on an arity error, which pre-migration NEED did not check.
- The `tests/let/` → `tests/thunk-forced-once/` rename, and that its input was upgraded to the seven-use `Prog/test` so it is byte-identical to NAME's `thunk-reevaluated-per-use/` input — the same program, `4` under NEED and `10` under NAME.

- [ ] **Step 12: Commit**

```bash
git add src/NEED/grammar.plcc src/NEED/python src/NEED/tests src/NEED/Prog/counter dev-docs/course-material-impact.md
git commit -m "feat(NEED): port grammar and Python target to plcc-ng

Refs #NN"
```

Replace `NN` with the number from Task 1.

---

### Task 3: Java target

Appends the Java `@test` block to each of the four `.bats` files and creates `src/NEED/java/spec.plcc`.

**Files:**
- Create: `src/NEED/java/spec.plcc`
- Modify: all four `src/NEED/tests/<case>/NEEDtest.bats`
- Test: `bats --recursive src/NEED/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/NEED/grammar.plcc` and the four test case directories from Task 2.
- Produces: `src/NEED/java/spec.plcc` with the same class and method names as the Python target — `ValRORef(Val val)` extending `ValRef` with `Val setRef(Val v)`, a `ThunkRef` field `public Val val`, `Ref evalRef(Env env)` on `LitExp` and `ProcExp`, and `ErrorPrim.apply(Val [] va)`.

- [ ] **Step 1: Add the Java `@test` block to each `.bats` file**

Append to each `src/NEED/tests/<case>/NEEDtest.bats`, after the existing Python block, with `<case>` replaced by that directory's name:

```bash

@test "NEED <case> (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/<case>/NEED.input)"
  expected_output=$(< "../tests/<case>/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

The `.input` and `.expected` files are shared — all three targets must produce identical output. Do not create per-target expected files.

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `bats --recursive src/NEED/tests`
Expected: 8 tests — 4 passing (python) and 4 failing (java, no `java/` directory yet).

- [ ] **Step 3: Create the Java target**

```bash
mkdir -p src/NEED/java
cp src/NAME/java/spec.plcc src/NEED/java/spec.plcc
```

Make **five** edits and nothing else. Java needs no `:import` work anywhere in this task — same-directory, package-less classes reference each other directly, and its shipped spec carries only two `:import` blocks in total, both for `java.util`.

**(a) Make `ThunkRef.deRef` memoize.** In the existing `ThunkRef` block, replace:

```
    public Exp exp;
    public Env env;

    public ThunkRef(Exp exp, Env env) {
        this.exp = exp;
        this.env = env;
    }

    public Val deRef() {
        return exp.eval(env);
    }
```

with:

```
    public Exp exp;
    public Env env;
    public Val val;

    public ThunkRef(Exp exp, Env env) {
        this.exp = exp;
        this.env = env;
        this.val = null; // memoized
    }

    // implements call-by-need:
    // evaluate the expression, if needed, and memoize the result
    public Val deRef() {
        if (val == null)
            val = exp.eval(env);
        return val;
    }
```

**(b) Insert a `ValRORef` block between the existing `ValRef` block and the existing `ProcVal` block.** Immediately above the line `ProcVal` that begins the `ProcVal` block:

```
# read-only value
ValRORef
%%%
import runtime.LanguageError;

public class ValRORef extends ValRef {

    public ValRORef(Val val) {
        super(val);
    }

    public Val setRef(Val v) {
        throw new LanguageError("cannot modify a read-only reference");
    }
}
%%%

```

`ValRORef` is a **free-standing** class, so it needs its own `import runtime.LanguageError;` — the same reason the neighbouring `ThunkRef` block has one. It does not need to import `ValRef` or `Val`: those are package-less classes in the same generated directory.

**(c) Point `LitExp` at `ValRORef`.** In the `LitExp` block, replace:

```
public Ref evalRef(Env env) {
    return new ValRef(eval(env));
}
```

with:

```
public Ref evalRef(Env env) {
    return new ValRORef(eval(env)); // a literal is read-only
}
```

**(d) Point `ProcExp` at `ValRORef`.** In the `ProcExp` block, replace:

```
public Ref evalRef(Env env) {
    return new ValRef(eval(env));
}
```

with:

```
public Ref evalRef(Env env) {
    return new ValRORef(eval(env)); // read-only
}
```

Edits (c) and (d) are textually identical replacements in two different blocks. Do both — a search-and-replace that stops at the first match leaves `ProcExp` on the old behavior, and only a `proc` passed as an operand would catch it.

**(e) Append `ErrorPrim` at the end of the file**, after the closing `%%%` of the `ZeropPrim` block:

```

ErrorPrim
%%%
public String toString() {
    return "error";
}

public Val apply(Val [] va) {
    throw new LanguageError("user-defined error");
}
%%%
```

No `:import` block. `ErrorPrim` is grammar-derived, and its sibling `Prim` subclasses in this same file already reference `LanguageError` without one.

Verify:

```bash
diff src/NAME/java/spec.plcc src/NEED/java/spec.plcc
```

Expected: hunks for the `ThunkRef` memoization, the inserted `ValRORef` block, the `LitExp` override, the `ProcExp` override, and the appended `ErrorPrim`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats --recursive src/NEED/tests`
Expected: 8 tests, 8 passing.

- [ ] **Step 5: Confirm Java agrees with Python character-for-character**

```bash
( cd src/NEED/java   && plcc-rep < ../Prog/natno ) > /tmp/need-java-natno.txt
( cd src/NEED/python && plcc-rep < ../Prog/natno ) > /tmp/need-python-natno.txt
diff /tmp/need-java-natno.txt /tmp/need-python-natno.txt
```

Expected: no output.

- [ ] **Step 6: Run the full suite**

```bash
bin/test.bash > /tmp/need-task3.txt 2>&1
grep -c '^ok ' /tmp/need-task3.txt      # expect 123
grep -c '^not ok ' /tmp/need-task3.txt  # expect 3
```

Expected: **126 tests, 123 passing, 3 failing** (OBJ, TYPE0, TYPE1).

- [ ] **Step 7: Commit**

```bash
git add src/NEED/java src/NEED/tests
git commit -m "feat(NEED): port Java target to plcc-ng

Refs #NN"
```

---

### Task 4: JavaScript target

Appends the JavaScript `@test` block to each of the four `.bats` files and creates `src/NEED/javascript/spec.plcc`.

**Files:**
- Create: `src/NEED/javascript/spec.plcc`
- Modify: all four `src/NEED/tests/<case>/NEEDtest.bats`
- Test: `bats --recursive src/NEED/tests`, then `bin/test.bash`

**Interfaces:**
- Consumes: `src/NEED/grammar.plcc` and the four test case directories from Task 2.
- Produces: `src/NEED/javascript/spec.plcc` with the same class and method names as the other two targets, and `module.exports = { ValRORef };`.

- [ ] **Step 1: Add the JavaScript `@test` block to each `.bats` file**

Append to each `src/NEED/tests/<case>/NEEDtest.bats`, after the Java block, with `<case>` replaced by that directory's name:

```bash

@test "NEED <case> (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/<case>/NEED.input)"
  expected_output=$(< "../tests/<case>/NEED.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 2: Run the tests to verify the new ones fail**

Run: `bats --recursive src/NEED/tests`
Expected: 12 tests — 8 passing (python, java) and 4 failing (javascript).

- [ ] **Step 3: Create the JavaScript target**

```bash
mkdir -p src/NEED/javascript
cp src/NAME/javascript/spec.plcc src/NEED/javascript/spec.plcc
```

Make **five** edits and nothing else.

**(a) Make `ThunkRef.deRef` memoize.** In the existing `ThunkRef` block, replace:

```
    constructor(exp, env) {
        super();
        this.exp = exp;
        this.env = env;
    }

    deRef() {
        return this.exp.eval(this.env);
    }
```

with:

```
    constructor(exp, env) {
        super();
        this.exp = exp;
        this.env = env;
        this.val = null; // memoized
    }

    // implements call-by-need:
    // evaluate the expression, if needed, and memoize the result
    deRef() {
        if (this.val === null)
            this.val = this.exp.eval(this.env);
        return this.val;
    }
```

Use `===`, not `==`. Loose equality would also treat `undefined` as unforced, which happens to be harmless here but diverges from the Java and Python shapes for no reason.

**(b) Insert a `ValRORef` block between the existing `ValRef` block and the existing `ProcVal` block.** Immediately above the line `ProcVal` that begins the `ProcVal` block:

```
# read-only value
ValRORef
%%%
const { ValRef } = require('./ValRef');
const { LanguageError } = require('./runtime/base');

class ValRORef extends ValRef {

    setRef(v) {
        throw new LanguageError("cannot modify a read-only reference");
    }
}

module.exports = { ValRORef };
%%%

```

`ValRORef` is a **free-standing** class, so it gets no auto-injected requires and must require both `ValRef` and `LanguageError` itself, and export itself. This is the opposite of the rule for grammar-derived classes, where an explicit `require` of `Node`, `Token`, or `LanguageError` fails with `Identifier 'X' has already been declared`.

**(c) Point `LitExp` at `ValRORef`.** Replace:

```
LitExp:import
%%%
const { IntVal } = require('./IntVal');
const { ValRef } = require('./ValRef');
%%%
```

with:

```
LitExp:import
%%%
const { IntVal } = require('./IntVal');
const { ValRORef } = require('./ValRORef');
%%%
```

and in the `LitExp` block, replace:

```
evalRef(env) {
    return new ValRef(this.eval(env));
}
```

with:

```
evalRef(env) {
    return new ValRORef(this.eval(env)); // a literal is read-only
}
```

**(d) Point `ProcExp` at `ValRORef`.** Replace:

```
ProcExp:import
%%%
const { ValRef } = require('./ValRef');
%%%
```

with:

```
ProcExp:import
%%%
const { ValRORef } = require('./ValRORef');
%%%
```

and in the `ProcExp` block, replace:

```
evalRef(env) {
    return new ValRef(this.eval(env));
}
```

with:

```
evalRef(env) {
    return new ValRORef(this.eval(env)); // read-only
}
```

As in the Python target, the `evalRef` body being replaced is **textually identical in both blocks** — `return new ValRef(this.eval(env));` appears once in `LitExp` and once in `ProcExp`. A search-and-replace that stops at the first match leaves `ProcExp` on the old behavior, which only a `proc` passed as an operand would catch. Do both.

**(e) Append `ErrorPrim` at the end of the file**, after the closing `%%%` of the `ZeropPrim` block:

```

ErrorPrim
%%%
toString() {
    return "error";
}

apply(args) {
    throw new LanguageError("user-defined error");
}
%%%
```

**No `:import` block, deliberately.** `ErrorPrim` is grammar-derived, so plcc-ng auto-injects `const { Node, Token, LanguageError } = require('./runtime/base');` into its generated file. Adding an explicit require for `LanguageError` here fails with `Identifier 'LanguageError' has already been declared`. Its sibling `ZeropPrim` in this same file throws `LanguageError` with no require, for exactly this reason.

Verify:

```bash
diff src/NAME/javascript/spec.plcc src/NEED/javascript/spec.plcc
```

Expected: hunks for the `ThunkRef` memoization, the inserted `ValRORef` block, the `LitExp` import and override, the `ProcExp` import and override, and the appended `ErrorPrim`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats --recursive src/NEED/tests`
Expected: 12 tests, 12 passing.

A `ReferenceError: ValRORef is not defined` from `LitExp` or `ProcExp` means the matching `:import` block in (c) or (d) still requires `ValRef`. An `Identifier 'LanguageError' has already been declared` means you gave `ErrorPrim` an `:import` block in (e) — delete it.

- [ ] **Step 5: Confirm all three targets agree character-for-character**

```bash
for t in python java javascript; do
  ( cd "src/NEED/$t" && plcc-rep < ../Prog/natno ) > "/tmp/need-$t-natno.txt"
done
diff /tmp/need-python-natno.txt /tmp/need-java-natno.txt
diff /tmp/need-python-natno.txt /tmp/need-javascript-natno.txt
```

Expected: no output from either `diff`.

- [ ] **Step 6: Run the full suite**

```bash
bin/test.bash > /tmp/need-task4.txt 2>&1
grep -c '^ok ' /tmp/need-task4.txt      # expect 127
grep -c '^not ok ' /tmp/need-task4.txt  # expect 3
grep '^not ok ' /tmp/need-task4.txt
```

Expected: **130 tests, 127 passing, 3 failing** — OBJ, TYPE0, TYPE1, all `plccmk: command not found`. This is the plan's final test shape; Tasks 5 and 6 must not change it.

- [ ] **Step 7: Commit**

```bash
git add src/NEED/javascript src/NEED/tests
git commit -m "feat(NEED): port JavaScript target to plcc-ng

Refs #NN"
```

---

### Task 5: Verify the example programs and record the Jensen divergence

NEED's `Prog/` needs **no consolidation** — every program is already in `src/NEED/Prog/`, and `counter` was copied in during Task 2. This task runs all nine rather than assuming they work, and records as course material the two findings that a later reader would otherwise try to "fix": the Jensen device diverging, and `Prog/nn`'s Python ceiling.

**Files:**
- Modify: `dev-docs/course-material-impact.md`
- Test: manual `plcc-rep` runs, then `bin/test.bash`

**Interfaces:**
- Consumes: all three `src/NEED/<target>/spec.plcc` from Tasks 2–4.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Confirm the directory really has nothing to consolidate**

```bash
ls src/NEED
ls src/NEED/Prog
```

Expected from the first: `Prog`, `code`, `envRef`, `grammar`, `grammar.plcc`, `java`, `javascript`, `prim`, `python`, `ref`, `tests`, `val`. Expected from the second: exactly `counter`, `fib`, `jeh`, `looper`, `natno`, `nn`, `seq`, `squares`, `test`. If there is a `Stuff/` directory or a loose program file, **stop** — the design says there is none, and the plan's claim that this task is verification-only is wrong.

- [ ] **Step 2: Run every program against all three targets**

```bash
for t in python java javascript; do
  echo "#### $t"
  for prog in counter fib jeh looper natno nn seq squares test; do
    printf '  %-10s ' "$prog"
    ( cd "src/NEED/$t" && plcc-rep < "../Prog/$prog" 2>&1 ) | tr '\n' ' '
    echo
  done
done
```

Expected — identical in all three targets, except `nn` under Python:

| program | expected output |
|---|---|
| `counter` | `4` |
| `fib` | `pair first rest nth fib fibonacci 55` |
| `jeh` | `pair first rest nth fib fibonacci recmult addall f` |
| `looper` | `p g 8` |
| `natno` | `pair first rest nth seq natno 0 1 2 100` |
| `nn` | `pair first rest nth seq natno 0 1 2 1000 1000` |
| `seq` | `pair first rest nth seq natno 0 1 2 100` |
| `squares` | `pair first rest nth sseq squares 10000` |
| `test` | `4` |

Two of these need explaining before someone reports them as bugs.

`jeh` produces only its `define` names and no result. That is correct: every one of its example applications is commented out in the source. It is how the file stands pre-migration, not a porting artifact.

**`nn` under Python stops after `0 1 2` with `Specification error: RecursionError: maximum recursion depth exceeded`.** This is expected. `.nth(1000,natno)` is a thousand levels of language-level recursion, and each level costs several Python interpreter frames — issue [#19](../issues/019-python-recursion-ceiling.md), repo-wide and **inherited, not introduced**. Confirm that for yourself rather than taking the plan's word for it:

```bash
( cd src/NAME/python && plcc-rep < ../../NEED/Prog/nn 2>&1 ) | tail -2
```

Expected: the same `RecursionError`. NAME's shipped Python spec fails on the same file the same way, which is what makes this inherited rather than a NEED regression. **Do not lower the program's depth to make Python pass.**

- [ ] **Step 3: Measure the NAME contrast**

```bash
for prog in test counter; do
  printf 'NAME %-8s ' "$prog"
  ( cd src/NAME/python && plcc-rep < "../../NEED/Prog/$prog" 2>&1 ) | tr '\n' ' '
  echo
done
```

Expected: `10` for `test` and `1` for `counter`, against NEED's `4` for both. These are the two memoization discriminators, and they move in opposite directions — `test` falls because the side effect runs once instead of seven times, `counter` rises because the counter is built once instead of four times.

- [ ] **Step 4: Confirm the Jensen device diverges, in all three targets**

This is the phase's most important finding, and it is worth seeing rather than trusting:

```bash
for t in python java javascript; do
  printf '%-11s ' "$t"
  ( cd "src/NEED/$t" && plcc-rep < ../../NAME/Prog/jensen 2>&1 ) | tail -2 | tr '\n' ' '
  echo
done
```

Expected: `while` followed by a stack-exhaustion error — `RecursionError` under Python, `StackOverflowError` under Java, `RangeError: Maximum call stack size exceeded` under JavaScript. NAME's own spec gives `while 55` on the same file.

**This is correct call-by-need semantics.** The `while` loop re-forces `test?` on every iteration; memoizing it freezes the condition at its first value, so the loop cannot terminate. Do not copy `jensen`, `sumsq`, or `countdown` into `src/NEED/Prog/`, do not write a test for this, and do not weaken the memoization to make them run.

- [ ] **Step 5: Add the course-material impact entries**

Add to the `## NEED` section of `dev-docs/course-material-impact.md`:

- **The Jensen device does not terminate under call-by-need.** Give the mechanism (a memoized `test?` freezes the loop condition), name the three programs (`Prog/{jensen,sumsq,countdown}` in `src/NAME/`), give the three per-target error names, and state plainly that this is correct semantics rather than a defect. Note the pedagogical point: NAME gains the ability to express a loop that call-by-value cannot, and NEED gives it back — the pair is a lecture in itself.
- The NEED-versus-NAME contrast for `Prog/test` (`4` vs `10`) and `Prog/counter` (`4` vs `1`), noting that these are the same programs run against two shipped specs, so the contrast is a live demo rather than a claim, and that the two numbers move in opposite directions for the same reason.
- **`Prog/nn` runs in Java and JavaScript but not Python**, hitting issue #19's recursion ceiling at `.nth(1000,natno)`. Say that it is inherited — NAME's Python spec fails identically — so an instructor should either demo it in Java/JavaScript or pick a shallower lookup.
- **`Prog/nn`'s premise does not hold.** It calls `.nth(1000,natno)` twice, which looks like a demonstration that memoization pays off, and it is not one: measured in Java, NAME and NEED take the same time, because `nth` walks each level of the list exactly once and no thunk is ever forced twice. The programs where memoization is observable are `test` and `counter`, not the streams.
- That `jeh` prints only its `define` names because its example applications are all commented out, so an empty-looking result is not a porting bug.

- [ ] **Step 6: Run the full suite**

```bash
bin/test.bash > /tmp/need-task5.txt 2>&1
grep -c '^ok ' /tmp/need-task5.txt      # expect 127
grep -c '^not ok ' /tmp/need-task5.txt  # expect 3
```

Expected: unchanged from Task 4 — **130 tests, 127 passing, 3 failing**. This task adds no tests; a change here means a `plcc-rep` run left build artifacts somewhere it shouldn't.

- [ ] **Step 7: Check for stray build artifacts**

```bash
git status --porcelain
```

Expected: only `dev-docs/course-material-impact.md` as modified. `plcc-ng/`, `__pycache__/`, and `*.class` are gitignored, so they will not appear — but if any *other* path shows up, investigate before committing.

- [ ] **Step 8: Commit**

```bash
git add dev-docs/course-material-impact.md
git commit -m "docs: record NEED's example-program behavior and the Jensen divergence

Refs #NN"
```

---

### Task 6: Remove NEED's old-PLCC files and close the issue

**Files:**
- Delete: `src/NEED/{grammar,code,prim,envRef,val,ref}`
- Modify: `dev-docs/issues/0NN-migrate-need-to-plcc-ng.md`, `dev-docs/roadmap.md` (both by script)
- Test: `bin/test.bash`

**Interfaces:**
- Consumes: `NN` from Task 1; a green suite from Task 5.
- Produces: nothing.

- [ ] **Step 1: Confirm nothing still references the old files**

Scope both greps to the **ported** artifacts. The flat `src/NEED/grammar` is itself the only file that `%include`s the other five, so a bare `grep -rn ... src/NEED/` would always match — in the very file being deleted — and the check would never pass:

```bash
PORTED="src/NEED/grammar.plcc src/NEED/python src/NEED/java src/NEED/javascript src/NEED/tests"
grep -rn '%include \(code\|prim\|envRef\|val\|ref\)$' $PORTED || echo "no old includes remain"
grep -rn 'plccmk\|rep -n' $PORTED || echo "no old invocations remain"
```

Expected: both print their "no ... remain" message. The `$` anchors the first pattern to a bare filename, so the ported specs' legitimate `%include ../../Env/envRef/<target>/env.plcc` does not match — verified. If either grep finds something, a `.bats` file or spec was not fully ported; fix that before deleting anything.

- [ ] **Step 2: Delete the old-PLCC files**

```bash
git rm src/NEED/grammar src/NEED/code src/NEED/prim src/NEED/envRef src/NEED/val src/NEED/ref
```

`src/NEED/grammar` and `src/NEED/grammar.plcc` are different paths, so nothing collides and this deletion is safe to leave until now — unlike SET's `envRef`, which had to go first.

- [ ] **Step 3: Run the full suite**

```bash
bin/test.bash > /tmp/need-task6.txt 2>&1
grep -c '^ok ' /tmp/need-task6.txt      # expect 127
grep -c '^not ok ' /tmp/need-task6.txt  # expect 3
grep '^not ok ' /tmp/need-task6.txt
```

Expected: **130 tests, 127 passing, 3 failing** — OBJ, TYPE0, TYPE1. Deleting files that nothing reads must not move any number. If a count changed, something did still read them.

- [ ] **Step 4: Commit the deletion**

```bash
git commit -m "refactor(NEED): remove old-PLCC sources superseded by the plcc-ng port

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
git commit -m "docs(issues): close issue NN (migrate NEED to plcc-ng), update roadmap"
```

This is the branch's final commit, and it closes Phase 3.

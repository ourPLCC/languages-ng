# plcc-ng Migration — Phase 2 (V6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port V6's grammar and Python/Java/JavaScript semantics to `plcc-ng`. V6 is `V5 + top-level define`: one new token, a `<Program>` that splits into two alternatives, and one new entry-point method per alternative. Everything else is V5 verbatim. **This closes Phase 2** — V6 is the last of the V-series.

**Architecture:** Each target's `spec.plcc` starts as a **verbatim copy** of the corresponding V5 `spec.plcc` and gains exactly one edit: the `Program` block loses its `_run()` and is followed by new `Define` and `Eval` blocks. `src/Env/envVal/<target>/env.plcc` is reused **unchanged** for the fourth consecutive language — everything `define` needs (`EnvNode.lookup`, `EnvNode.add`, an assignable `Binding.val`, and an `initEnv()` that returns a mutable node) is already in the port.

**Tech Stack:** `plcc-ng` CLI (`plcc-scan`, `plcc-parse`, `plcc-rep`), `bats-core` (via `bin/test.bash`), bash, Python 3.12+, Java JDK 21+, Node.js 18+. All already available in this devcontainer.

**Design of record:** [dev-docs/specs/2026-08-03-plcc-ng-v6-design.md](../specs/2026-08-03-plcc-ng-v6-design.md), which extends the [V5 design](../specs/2026-07-31-plcc-ng-v5-design.md) and the overarching [migration design](../specs/2026-07-22-plcc-ng-migration-design.md).

**Working directory:** this branch's worktree, `.claude/worktrees/plcc-ng-v6`. Run every command from there. Do not `cd` to the main checkout.

**No spike task.** The overarching design flagged one unvalidated mechanic for V6 — whether `plcc-rep` preserves state across programs in one run. It was resolved live during design, in all three targets: **it does.** Every code block in this plan was additionally run against the real `Prog/` inputs during planning and produced the exact output recorded here. Nothing in this plan is transcribed or predicted.

**Task ordering differs from V4/V5 deliberately.** Those plans wrote their bats tests last. This one writes them in Task 4, *before* any semantics, so each target task has a real red-to-green gate and the pass count climbs by exactly 4 per target. Expected counts are given at every step.

## Global Constraints

- Scope is V6 only, plus the two explicitly-scoped cross-cutting tasks (Task 2's V5 back-fix and Task 10's design correction). Do not touch `src/V0`–`src/V4`, `src/SET`, `src/REF`, `src/NAME`, `src/NEED`, `src/TYPE0`, `src/TYPE1`, or `src/OBJ`.
- **`src/Env/envVal/**` is read-only in this plan.** V6 reuses it byte-for-byte. If something looks like it needs an `envVal` change, stop and report.
- Follow the conventions V0–V5 established: capitalized nonterminals, the identifier token named `SYMBOL` captured as `symbol` (`symbolList` in list positions), camelCase `IfExp` alt-names (`testExp`/`trueExp`/`falseExp`), and a `_run()` that **returns** a string — never prints. Returning `None`/`void` is a hard `Specification error`.
- Everything V6 inherits from V5 — `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`, `LetrecExp`, `ProcExp`, `Proc`, `Formals`, `LetDecls`, `AppExp`, `SeqExp`, `Rands`, `Val`, `IntVal`, `ProcVal`, and all seven `Prim` subclasses — is copied from `src/V5/<target>/spec.plcc` **verbatim, after Task 2 lands**. Task 2 exists precisely so that "verbatim" has no exceptions.
- **Token keys via `.lexeme`, never `.toString()`.** Runtime errors raise `LanguageError`, never the old `PLCCException`.
- `Define._run()` returns the **name**, not the value. Its Java original ends in `System.out.println(s)` and returns `void`; that cannot be ported literally.
- `Define` uses `env.lookup(s)`, **not** `env.applyEnv(s)` — faithful to the original's "only look at local bindings". At top level the two are observationally identical (`Program.env`'s parent is `EnvNull`), so no test distinguishes them. Do not "simplify" it to `applyEnv`.
- Structural fidelity across targets: method names (`eval`, `_run`, `lookup`, `add`, `applyEnv`, `extendEnv`, `makeClosure`) stay identical across Python, Java, and JavaScript.
- JavaScript: grammar-derived classes get `Node`/`Token`/`LanguageError` auto-injected — never add an `:import` for those three names on them. A grammar-derived subclass also gets its **base class** auto-injected, so `Define`/`Eval` never need to import `Program`.
- Java needs no `:import` blocks for same-directory, package-less classes. `Define` needs none at all.
- Every test case gets one shared `V6.input` / `V6.expected` pair, asserted by one `@test` block per target in a single `.bats` file. Value cases only — no error-path test.
- Keep every test's recursion depth and integer magnitude small — issues [#16](../issues/016-cross-target-integer-divergence.md) and [#19](../issues/019-python-recursion-ceiling.md) are live. Every expected value in this plan was measured; do not scale any of them up.
- Any change affecting course material gets logged in [dev-docs/course-material-impact.md](../course-material-impact.md), in the same commit that makes the change — under `## V6`, except Task 2's V5 half, which goes under V5's existing heading.
- Never run bare `git stash` / `git stash pop` — the stash stack is shared with other worktrees.

## Baseline

Measured on this branch before any task runs:

```
$ bin/test.bash 2>&1 | grep -c '^ok'      # 51
$ bin/test.bash 2>&1 | grep -c '^not ok'  # 8
```

**59 tests: 51 passing, 8 failing.** Every failure is a `plccmk: command not found` from a language still on old PLCC: NAME, NEED, OBJ, REF, SET, TYPE0, TYPE1, V6.

Target on completion: **70 tests, 63 passing, 7 failing.** The load-bearing invariant is the delta — the `command not found` count drops by **exactly 1**, and no test that passed before may fail after. Because V6 closes Phase 2, a surviving `V`-prefixed failure means something regressed.

---

## Task 1: File the V6 issue

**Files:**
- Create: `dev-docs/issues/021-migrate-v6-to-plcc-ng.md` (id assigned by the script)
- Modify: `dev-docs/roadmap.md`, `dev-docs/issues/.next-id.txt`

**Interfaces:**
- Produces: issue id `21`, consumed by Task 11's `bin/issues/close.bash 21`.

- [ ] **Step 1: Generate the issue file**

Run: `bin/issues/new.bash migrate-v6-to-plcc-ng feat`

This reads `dev-docs/issues/.next-id.txt` (currently `21`), creates the file from the template with today's date, and increments the counter. Expected path: `dev-docs/issues/021-migrate-v6-to-plcc-ng.md`.

**Issue files never move.** Status is the `closed` frontmatter field; Task 11 fills it in. Do not create or reference a `done/` directory — that split was retired (commit `d56a4e9`). Never assign an id by hand.

- [ ] **Step 2: Fill in the issue's Description and Notes**

Edit the generated file. Replace the `## Description` body with the text below and **delete the entire `## Steps to Reproduce` section** (this is not a bug report):

```markdown
## Description

Port V6's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V6 is
V5 + top-level define: it adds the DEFINE token and splits <Program>
into Define and Eval alternatives. A define mutates a single Program-level
environment node that persists across every program in one plcc-rep run,
so a redefinition is visible through closures that already captured that
node. It reuses the envVal Env variant and every other V5 class without
modification.

This is the last language in Phase 2.

## Notes

See [dev-docs/specs/2026-08-03-plcc-ng-v6-design.md](../specs/2026-08-03-plcc-ng-v6-design.md)
and [dev-docs/plans/2026-08-03-plcc-ng-phase2-v6.md](../plans/2026-08-03-plcc-ng-phase2-v6.md).
```

- [ ] **Step 3: Add the roadmap entry**

Edit `dev-docs/roadmap.md`. Per [issue-conventions.md](../issue-conventions.md), the entry goes under `## Open Issues` beneath the `###` heading matching the issue's type — `Feat`, which does **not** currently exist, so create the group. Place it **before** the existing `### Chore` group; that is the order the roadmap used when a `Feat` group last existed (commit `25c247f`: Feat, Chore, Docs).

Use this exact two-line format (the `bin/issues/` scripts parse it):

```markdown
### Feat

- **[#21](issues/021-migrate-v6-to-plcc-ng.md) — Migrate V6 to plcc-ng**
  Ports V6's grammar and Java semantics to plcc-ng and adds Python and JavaScript semantics. V6 is V5 + top-level define, reusing envVal and every other V5 class unchanged; the only new semantics are the Define/Eval split of <Program> and their two _run() methods. Last language in Phase 2.
```

- [ ] **Step 4: Verify consistency**

Run: `bin/issues/check.bash`
Expected: exits 0, no `FAIL:` lines.

- [ ] **Step 5: Commit**

```bash
git add dev-docs/issues/021-migrate-v6-to-plcc-ng.md dev-docs/issues/.next-id.txt dev-docs/roadmap.md
git commit -m "docs(issues): file 021 - migrate V6 to plcc-ng"
```

---

## Task 2: Back-fix V5 to the shared placeholder/toString shape

V6 and all seven languages still to be ported (`SET`, `REF`, `NAME`, `NEED`, `TYPE0`, `TYPE1`, `OBJ`) spell their placeholder `toString()`s identically as `" ...ClassName... "`, and all of them give `LetrecExp` and `ProcExp` one. **V5 is the only outlier** — it has three different spacings and is missing both methods.

This task lands **first** so that Tasks 5–7 can copy V5 verbatim with no exceptions. Behaviorally inert: no test prints an `Exp`, so the suite must be unchanged at 51 passing after this task.

**Files:**
- Modify: `src/V5/python/spec.plcc`, `src/V5/java/spec.plcc`, `src/V5/javascript/spec.plcc`
- Modify: `dev-docs/course-material-impact.md`

**Interfaces:**
- Produces: `src/V5/<target>/spec.plcc` in the canonical shape, copied verbatim by Tasks 5, 6, and 7.

- [ ] **Step 1: Normalize the four placeholder strings in Python**

In `src/V5/python/spec.plcc`, make exactly these four replacements:

| line | from | to |
|---|---|---|
| 134 | `    return "... LetExp ..."` | `    return " ...LetExp... "` |
| 171 | `    return "... LetDecls ..."` | `    return " ...LetDecls... "` |
| 209 | `    return " ... AppExp ..."` | `    return " ...AppExp... "` |
| 221 | `    return " ... SeqExp ... "` | `    return " ...SeqExp... "` |

- [ ] **Step 2: Add the two missing `__str__` methods in Python**

In `src/V5/python/spec.plcc`, the `LetrecExp` block currently reads:

```
LetrecExp
%%%
def eval(self, env):
    env = self.letDecls.addLetrecBindings(env)
    return self.exp.eval(env)
%%%
```

Replace it with:

```
LetrecExp
%%%
def eval(self, env):
    env = self.letDecls.addLetrecBindings(env)
    return self.exp.eval(env)

def __str__(self):
    return " ...LetrecExp... "
%%%
```

The `ProcExp` block currently reads:

```
ProcExp
%%%
def eval(self, env):
    return self.proc.makeClosure(env)
%%%
```

Replace it with:

```
ProcExp
%%%
def eval(self, env):
    return self.proc.makeClosure(env)

def __str__(self):
    return " ...ProcExp... "
%%%
```

- [ ] **Step 3: Apply the same six changes to Java**

In `src/V5/java/spec.plcc`:

| line | from | to |
|---|---|---|
| 158 | `    return "... LetExp ...";` | `    return " ...LetExp... ";` |
| 200 | `    return "... LetDecls ...";` | `    return " ...LetDecls... ";` |
| 232 | `    return " ... AppExp ...";` | `    return " ...AppExp... ";` |
| 246 | `    return " ... SeqExp ... ";` | `    return " ...SeqExp... ";` |

Then extend the two blocks:

```
LetrecExp
%%%
public Val eval(Env env) {
    env = letDecls.addLetrecBindings(env);
    return exp.eval(env);
}

public String toString() {
    return " ...LetrecExp... ";
}
%%%
```

```
ProcExp
%%%
public Val eval(Env env) {
    return proc.makeClosure(env);
}

public String toString() {
    return " ...ProcExp... ";
}
%%%
```

- [ ] **Step 4: Apply the same six changes to JavaScript**

In `src/V5/javascript/spec.plcc`:

| line | from | to |
|---|---|---|
| 162 | `    return "... LetExp ...";` | `    return " ...LetExp... ";` |
| 204 | `    return "... LetDecls ...";` | `    return " ...LetDecls... ";` |
| 246 | `    return " ... AppExp ...";` | `    return " ...AppExp... ";` |
| 260 | `    return " ... SeqExp ... ";` | `    return " ...SeqExp... ";` |

Then extend the two blocks:

```
LetrecExp
%%%
eval(env) {
    env = this.letDecls.addLetrecBindings(env);
    return this.exp.eval(env);
}

toString() {
    return " ...LetrecExp... ";
}
%%%
```

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

- [ ] **Step 5: Verify V5 still passes**

Run: `bin/test.bash 2>&1 | grep -c '^ok'`
Expected: `51` — unchanged. This change is inert; if the count moved, something else broke.

Run: `bin/test.bash 2>&1 | grep '^not ok'`
Expected: exactly the 8 baseline failures (NAME, NEED, OBJ, REF, SET, TYPE0, TYPE1, V6), no V5 entries.

- [ ] **Step 6: Log the course-material impact — and correct the bullet this contradicts**

`dev-docs/course-material-impact.md` currently carries this bullet under `## V5` (around line 147), which **this task makes false**:

```markdown
- `LetrecExp` has **no** `toString()`. The original has none, and the
  port does not invent one (same treatment as V4's `ProcExp`).
```

Replace that bullet in place with:

```markdown
- `LetrecExp` and `ProcExp` **do** have placeholder `toString()`/`__str__`
  methods, returning `" ...LetrecExp... "` and `" ...ProcExp... "`.
  *(Corrected: V5 originally shipped without them, on the grounds that
  the pre-migration source had none. That was true of V5 alone — V6 and
  all seven languages of Phases 3-5 have both — so V5 was brought into
  line rather than left as the outlier.)*
```

Then append, still under `## V5`:

```markdown
- V5's four placeholder strings were normalized to the
  `" ...ClassName... "` spelling every other language uses.
  `"... LetExp ..."`, `"... LetDecls ..."`, `" ... AppExp ..."`, and
  `" ... SeqExp ... "` — three different spacings — became
  `" ...LetExp... "`, `" ...LetDecls... "`, `" ...AppExp... "`, and
  `" ...SeqExp... "`. No observable output changed: nothing in the test
  suite prints an `Exp`. Slides quoting the old spellings should be
  updated, but no result differs.
```

- [ ] **Step 7: Commit**

```bash
git add src/V5 dev-docs/course-material-impact.md
git commit -m "refactor(V5): converge placeholder toStrings on the shared shape

V5 was the only kept language missing LetrecExp/ProcExp toString() and
the only one with inconsistent placeholder spacing. Aligns it with V6
and the seven languages of Phases 3-5 so V6 can copy it verbatim.

Behaviorally inert - no test prints an Exp."
```

---

## Task 3: Create the shared V6 grammar

**Files:**
- Create: `src/V6/grammar.plcc`

**Interfaces:**
- Produces: `src/V6/grammar.plcc`, `%include`d by all three `spec.plcc` files in Tasks 5–7. Generated field names that later tasks rely on: `Define.symbol`, `Define.exp`, `Eval.exp`.

- [ ] **Step 1: Create the grammar file**

Create `src/V6/grammar.plcc` with exactly this content. It is `src/V5/grammar.plcc` with a changed header comment, one added token, and `<Program>` split into two alternatives:

```
# Language V6
#   Language V5 + top-level define
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

Notes on what is deliberately **not** carried from the pre-migration `src/V6/grammar`:
- The token is `SYMBOL`, not `VAR` — the JS reserved-word fix, adopted repo-wide.
- `IfExp` alt-names are camelCase (`testExp`), not the lowercase workaround the overarching design still describes; issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md) was fixed in plcc-ng 2.0.0.
- The stale header comment about `?` in variable names (that widening happened at V4) is dropped, matching V5.

- [ ] **Step 2: Verify the grammar scans and the new token is recognized**

```bash
cd src/V6 && printf 'define x=2\n' | plcc-scan -s grammar.plcc
```

Expected — note `define` scans as `DEFINE`, not as a `SYMBOL`, and `defined` would stay one `SYMBOL` (maximal munch, established at V5):

```
-:1:1 DEFINE 'define'
-:1:8 SYMBOL 'x'
-:1:9 EQUALS '='
-:1:10 LIT '2'
```

- [ ] **Step 3: Verify both `<Program>` alternatives parse**

```bash
cd src/V6 && printf 'define x=2\n' | plcc-parse -s grammar.plcc | head -5
cd src/V6 && printf '+(3,4)\n'    | plcc-parse -s grammar.plcc | head -5
```

Expected: both produce a parse tree with no error. The first is rooted at `Define`, the second at `Eval`. Any `no production for 'Program'` or LL(1) complaint means the split was mistyped — stop and report.

- [ ] **Step 4: Log the course-material impact**

Add a `## V6` heading to the end of `dev-docs/course-material-impact.md` (it does not exist yet — this task creates it, and Tasks 5 and 8 append under it), with:

```markdown
## V6

- New token `DEFINE 'define'`, declared directly after `LETREC`.
- `<Program>` is no longer a single production. It splits into two
  alternatives, `<Program:Define> ::= DEFINE <SYMBOL> EQUALS <Exp>` and
  `<Program:Eval> ::= <Exp>`, so a V6 "program" is now one *or* the
  other and a source file is a sequence of them. Course material that
  describes `<program> ::= <exp>` for V6 needs both alternatives.
- Same `SYMBOL`/`symbol` convention as V0-V5: the pre-migration V6
  grammar's `VAR` token is named `SYMBOL` in the port, so `Define`'s
  generated field is `symbol`, not `var`.
```

- [ ] **Step 5: Commit**

```bash
git add src/V6/grammar.plcc dev-docs/course-material-impact.md
git commit -m "feat(V6): add shared plcc-ng grammar

V5's grammar plus the DEFINE token and a <Program> split into Define
and Eval alternatives. LL(1)-safe: DEFINE is not in FIRST(<Exp>)."
```

---

## Task 4: Replace the V6 bats test with the four new cases

Written **before** any semantics so the following three tasks each have a red-to-green gate.

**Files:**
- Delete: `src/V6/tests/define/V6test.bats` (replaced in place)
- Modify: `src/V6/tests/define/V6test.bats`
- Create: `src/V6/tests/define-then-use/{V6.input,V6.expected,V6test.bats}`
- Create: `src/V6/tests/redefine/{V6.input,V6.expected,V6test.bats}`
- Create: `src/V6/tests/capture-copy/{V6.input,V6.expected,V6test.bats}`
- Unchanged: `src/V6/tests/define/V6.input`, `src/V6/tests/define/V6.expected`

**Interfaces:**
- Consumes: `src/V6/grammar.plcc` from Task 3.
- Produces: 12 `@test` blocks (4 cases × 3 targets), each `cd`-ing into `python/`, `java/`, or `javascript/` and running `plcc-rep` against a shared expected file.

- [ ] **Step 1: Rewrite the existing `define` test**

`src/V6/tests/define/V6.input` and `V6.expected` are **kept as-is** — the input already exercises exactly what it should (two mutually recursive procedures defined as separate top-level programs, so `even?` names `odd?` before `odd?` exists). Only the `.bats` file changes, from the old `plccmk`/`rep` invocation to three `plcc-rep` blocks.

Replace the whole of `src/V6/tests/define/V6test.bats` with:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V6 define (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/define/V6.input)"
  expected_output=$(< "../tests/define/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/define/V6.input)"
  expected_output=$(< "../tests/define/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/define/V6.input)"
  expected_output=$(< "../tests/define/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For reference, the retained files hold:

```
                     V6.input                          V6.expected
define even? = proc(x)                                 even?
    if zero?(x) then 1 else .odd?(sub1(x))             odd?
define odd? = proc(x)                                  0
    if zero?(x) then 0 else .even?(sub1(x))            1
.even?(11) % => 0
.odd?(11) % => 1
```

- [ ] **Step 2: Create the `define-then-use` case**

`src/V6/tests/define-then-use/V6.input` — taken from `Prog/inits`:

```
define x=10
+(x,4)
```

`src/V6/tests/define-then-use/V6.expected`:

```
x
14
```

`src/V6/tests/define-then-use/V6test.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V6 define-then-use (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/define-then-use/V6.input)"
  expected_output=$(< "../tests/define-then-use/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define-then-use (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/define-then-use/V6.input)"
  expected_output=$(< "../tests/define-then-use/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 define-then-use (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/define-then-use/V6.input)"
  expected_output=$(< "../tests/define-then-use/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

This is the only case that pairs a `Define` program with a bare `Eval` program, and the minimal proof that a binding made by one program is visible to the next.

- [ ] **Step 3: Create the `redefine` case**

`src/V6/tests/redefine/V6.input` — taken from `Prog/x`, comments retained (they are skipped tokens and they document intent):

```
define x=2
define f = proc() x
.f() % evaluates to 2
define x=3
.f() % evaluates to 3
```

`src/V6/tests/redefine/V6.expected` — **five lines, not two.** Every `Define` program emits its own name:

```
x
f
2
x
3
```

`src/V6/tests/redefine/V6test.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V6 redefine (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/redefine/V6.input)"
  expected_output=$(< "../tests/redefine/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 redefine (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/redefine/V6.input)"
  expected_output=$(< "../tests/redefine/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 redefine (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/redefine/V6.input)"
  expected_output=$(< "../tests/redefine/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

This is the case that proves a redefinition reaches a closure that already exists — `f` captured the top-level node, and `define x=3` assigns through the very `Binding` object `f` sees.

- [ ] **Step 4: Create the `capture-copy` case**

`src/V6/tests/capture-copy/V6.input` — taken from `Prog/xx`:

```
define x=2
define f = let x=x in proc() x
.f() % evaluates to 2
define x=3
.f() % still evaluates to 2
```

`src/V6/tests/capture-copy/V6.expected` — identical to `redefine`'s except the last line:

```
x
f
2
x
2
```

`src/V6/tests/capture-copy/V6test.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V6 capture-copy (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/capture-copy/V6.input)"
  expected_output=$(< "../tests/capture-copy/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 capture-copy (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/capture-copy/V6.input)"
  expected_output=$(< "../tests/capture-copy/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V6 capture-copy (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/capture-copy/V6.input)"
  expected_output=$(< "../tests/capture-copy/V6.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

`redefine` and `capture-copy` are a matched pair and should be read together — the `let` extends a *new* node holding its own `Binding`, which no later top-level `define` can reach. Separately each looks arbitrary; together they are the point of V6.

- [ ] **Step 5: Run the suite and confirm all 12 fail**

Run: `bin/test.bash 2>&1 | grep -c '^ok'`
Expected: `51` — unchanged from baseline.

Run: `bin/test.bash 2>&1 | grep -c '^not ok'`
Expected: `19` — the 7 remaining `command not found` languages plus the 12 new V6 blocks.

Run: `bin/test.bash 2>&1 | grep -c '^not ok.*V6'`
Expected: `12`. They fail because `src/V6/python/`, `java/`, and `javascript/` do not exist yet, so `cd python` fails. That is the correct red state.

Total is now **70 tests**, which is the final count — Tasks 5–7 only move tests from failing to passing.

- [ ] **Step 6: Commit**

```bash
git add src/V6/tests
git commit -m "test(V6): port define test to plcc-rep and add three cases

Adds define-then-use, redefine, and capture-copy. The latter two are a
matched pair: a redefinition reaches a closure that captured the
top-level node, but not one that captured a let-bound copy.

All 12 blocks fail until the three targets land."
```

---

## Task 5: Add V6 Python semantics

**Files:**
- Create: `src/V6/python/spec.plcc`

**Interfaces:**
- Consumes: `src/V6/grammar.plcc` (Task 3); `src/V5/python/spec.plcc` in its Task-2 shape; `src/Env/envVal/python/env.plcc` (read-only).
- Produces: `Define._run()` and `Eval._run()`, each returning `str`.

- [ ] **Step 1: Copy V5's Python spec verbatim**

```bash
mkdir -p src/V6/python
cp src/V5/python/spec.plcc src/V6/python/spec.plcc
```

- [ ] **Step 2: Point the include at V6's grammar**

The copied file's first line is `%include ../grammar.plcc`. That is already correct — it resolves relative to the file containing the directive, so it now picks up `src/V6/grammar.plcc`. **No edit needed.** The `%include ../../Env/envVal/python/env.plcc` line is likewise correct and unchanged.

- [ ] **Step 3: Split the `Program` block**

The copied file contains this block:

```
Program
%%%
env = Env.initEnv()

def _run(self):
    return str(self.exp.eval(Program.env))
%%%
```

Replace it with the following. The preceding `Program:import` block (`from Env import Env`) stays exactly as it is — `Program` still names `Env` for `initEnv()`.

```
Program
%%%
env = Env.initEnv()
%%%

Define:import
%%%
from Binding import Binding
%%%

Define
%%%
def _run(self):
    env = Program.env
    s = self.symbol.lexeme
    val = self.exp.eval(env)
    b = env.lookup(s)
    if b is not None:
        b.val = val
    else:
        env.add(Binding(s, val))
    return s
%%%

Eval
%%%
def _run(self):
    return str(self.exp.eval(Program.env))
%%%
```

Three things to leave alone:
- `Define:import` needs **only** `Binding`. It never names `Env` directly (`Program.env` reaches it through the auto-injected base class), and adding an unnecessary import here is the kind of drift Task 2 just removed.
- `Eval` needs **no** `:import` block at all.
- `env.lookup(s)`, not `env.applyEnv(s)` — see Global Constraints.

- [ ] **Step 4: Verify against all four test inputs by hand**

```bash
cd src/V6/python
for c in define define-then-use redefine capture-copy; do
  echo "--- $c"; plcc-rep < ../tests/$c/V6.input
done
```

Expected, exactly:

```
--- define
even?
odd?
0
1
--- define-then-use
x
14
--- redefine
x
f
2
x
3
--- capture-copy
x
f
2
x
2
```

- [ ] **Step 5: Run the suite**

Run: `bin/test.bash 2>&1 | grep -c '^ok'`
Expected: `55` — baseline 51 plus Python's 4.

Run: `bin/test.bash 2>&1 | grep -c '^not ok'`
Expected: `15` — 7 `command not found` plus the 8 still-missing Java/JavaScript blocks.

- [ ] **Step 6: Log the course-material impact**

These are language-level facts, logged with the first target that implements them rather than repeated three times. Append under the `## V6` heading created in Task 3:

```markdown
- `Program` no longer has a `_run()`. It keeps only the shared
  `env = Env.initEnv()`, and `Define` and `Eval` each get their own
  `_run()`. The environment is created **once per `plcc-rep` process**
  and shared by every program in the run.
- `Define._run()` **returns the defined name**, not the value. The
  pre-migration Java ended in `System.out.println(s)` and returned
  `void`; under plcc-ng an entry point must return its output as a
  string. Same observable output, different mechanism - worth a note
  wherever the Java source is shown.
- `define` is implemented by **mutating a single environment node**, the
  same mechanism V5's `letrec` uses, hoisted to the top level. A new
  name is `add`ed to that node; an existing name has its `Binding.val`
  **reassigned in place**. `define` never extends or replaces the
  environment.
- Two consequences worth showing on a slide, both demonstrated by files
  already in `src/V6/Prog/`:
  - A redefinition **reaches closures that already exist**, because the
    assignment goes through the very `Binding` object the closure holds.
    `Prog/x`: `.f()` gives `2`, then `define x=3`, then `.f()` gives `3`.
  - A closure over a **`let`-bound copy is immune**, because `let`
    extends a new node with its own `Binding`. `Prog/xx`: `.f()` gives
    `2` both before and after `define x=3`.
- A `define` right-hand side may name a procedure defined **later**, as
  the shipped `define` test does with `even?`/`odd?` - the closure
  captured the node, and the later binding lands in that same node.
- `Define` looks names up with `env.lookup(s)` (local bindings only),
  not `env.applyEnv(s)`. Faithful to the original, but note that at top
  level the two are indistinguishable: the environment's parent is
  `EnvNull`, so no program can tell them apart.
- V6's `LetrecExp`/`ProcExp` `toString()`s and its `" ...ClassName... "`
  placeholder spellings match its pre-migration source exactly - no
  change on that axis. (V5's needed correcting; V6's did not.)
```

- [ ] **Step 7: Commit**

```bash
git add src/V6/python/spec.plcc dev-docs/course-material-impact.md
git commit -m "feat(V6): add Python semantics

Program keeps the shared static env and loses _run(); Define and Eval
each get one. Define mutates the top-level node in place and returns
the defined name."
```

---

## Task 6: Add V6 Java semantics

**Files:**
- Create: `src/V6/java/spec.plcc`

**Interfaces:**
- Consumes: `src/V6/grammar.plcc` (Task 3); `src/V5/java/spec.plcc` in its Task-2 shape.
- Produces: `Define._run()` and `Eval._run()`, each `public String`.

- [ ] **Step 1: Copy V5's Java spec verbatim**

```bash
mkdir -p src/V6/java
cp src/V5/java/spec.plcc src/V6/java/spec.plcc
```

- [ ] **Step 2: Split the `Program` block**

The copied file contains:

```
Program
%%%
public static Env env = Env.initEnv();

public String _run() {
    return exp.eval(env).toString();
}
%%%
```

Replace it with:

```
Program
%%%
public static Env env = Env.initEnv();
%%%

Define
%%%
public String _run() {
    Env env = Program.env;
    String s = symbol.lexeme;
    Val val = exp.eval(env);
    Binding b = env.lookup(s);
    if (b != null)
        b.val = val;
    else
        env.add(new Binding(s, val));
    return s;
}
%%%

Eval
%%%
public String _run() {
    return exp.eval(env).toString();
}
%%%
```

Notes:
- **No `:import` blocks at all.** Java's free-standing classes (`Env`, `Binding`, `Val`) are same-directory and package-less, so `Define` references them with no import. Do not add one.
- `Eval`'s bare `env` resolves to the inherited `Program.env` static; `Define` shadows it with a local for readability, matching the Java original.
- The original's closing `System.out.println(s)` becomes `return s`.

- [ ] **Step 3: Verify against all four test inputs by hand**

```bash
cd src/V6/java
for c in define define-then-use redefine capture-copy; do
  echo "--- $c"; plcc-rep < ../tests/$c/V6.input
done
```

Expected: byte-for-byte identical to Task 5 Step 4's output.

- [ ] **Step 4: Run the suite**

Run: `bin/test.bash 2>&1 | grep -c '^ok'`
Expected: `59` — 55 plus Java's 4.

Run: `bin/test.bash 2>&1 | grep -c '^not ok'`
Expected: `11` — 7 `command not found` plus the 4 still-missing JavaScript blocks.

- [ ] **Step 5: Commit**

```bash
git add src/V6/java/spec.plcc
git commit -m "feat(V6): add Java semantics

Program keeps the shared static env and loses _run(); Define and Eval
each get one. Define's original println becomes a returned string, per
the plcc-ng 2.0.0 entry-point contract."
```

---

## Task 7: Add V6 JavaScript semantics

**Files:**
- Create: `src/V6/javascript/spec.plcc`

**Interfaces:**
- Consumes: `src/V6/grammar.plcc` (Task 3); `src/V5/javascript/spec.plcc` in its Task-2 shape.
- Produces: `Define._run()` and `Eval._run()`, each returning a string.

- [ ] **Step 1: Copy V5's JavaScript spec verbatim**

```bash
mkdir -p src/V6/javascript
cp src/V5/javascript/spec.plcc src/V6/javascript/spec.plcc
```

- [ ] **Step 2: Split the `Program` block**

The copied file contains:

```
Program
%%%
static env = Env.initEnv();

_run() {
    return String(this.exp.eval(Program.env));
}
%%%
```

Replace it with:

```
Program
%%%
static env = Env.initEnv();
%%%

Define:import
%%%
const { Binding } = require('./Binding');
%%%

Define
%%%
_run() {
    const env = Program.env;
    const s = this.symbol.lexeme;
    const val = this.exp.eval(env);
    const b = env.lookup(s);
    if (b !== null)
        b.val = val;
    else
        env.add(new Binding(s, val));
    return s;
}
%%%

Eval
%%%
_run() {
    return String(this.exp.eval(Program.env));
}
%%%
```

Notes:
- The preceding `Program:import` (`const { Env } = require('./Env');`) stays exactly as it is.
- `Define:import` requires **only** `Binding`. It does not name `Env`, and it must **not** require `Node`, `Token`, `LanguageError`, or `Program` — grammar-derived classes get those and their base class auto-injected, and re-requiring them fails with `Identifier 'X' has already been declared`.
- `Eval` needs no `:import` block.
- `b !== null` — `EnvNode.lookup` returns `null`, not `undefined`, in the ported `envVal`.

- [ ] **Step 3: Verify against all four test inputs by hand**

```bash
cd src/V6/javascript
for c in define define-then-use redefine capture-copy; do
  echo "--- $c"; plcc-rep < ../tests/$c/V6.input
done
```

Expected: byte-for-byte identical to Task 5 Step 4's output.

- [ ] **Step 4: Run the suite — this is the green gate**

Run: `bin/test.bash 2>&1 | grep -c '^ok'`
Expected: `63`.

Run: `bin/test.bash 2>&1 | grep '^not ok'`
Expected: exactly 7 lines, all `plccmk: command not found` languages — NAME, NEED, OBJ, REF, SET, TYPE0, TYPE1. **No `V`-prefixed failure may remain.** If one does, Phase 2 has regressed; stop and report.

- [ ] **Step 5: Commit**

```bash
git add src/V6/javascript/spec.plcc
git commit -m "feat(V6): add JavaScript semantics

Completes V6 across all three targets and closes Phase 2 - every
remaining suite failure now belongs to Phases 3-5."
```

---

## Task 8: Verify the nine `Prog/` example programs

`Prog/` files are course artifacts: they stay where they are, but this phase **runs** them rather than assuming they still work. All nine were run in Python during design; this task covers all three targets.

**This step is load-bearing, not ceremonial.** None of the four test cases uses `letrec` or `{seq}`, and `src/V6/grammar.plcc` was newly written — a production accidentally dropped while creating it would slip past the entire suite. `Prog/dddd` is what catches that.

**Files:**
- Modify: none expected (see Step 3)
- Create: `dev-docs/issues/022-plcc-rep-parses-each-source-independently.md`
- Modify: `dev-docs/roadmap.md`, `dev-docs/issues/.next-id.txt`, `dev-docs/course-material-impact.md`

- [ ] **Step 1: Run the seven whole-program examples in every target**

```bash
for t in python java javascript; do
  echo "########## $t"
  cd src/V6/$t
  for p in dddd inits ivx pair util x xx; do
    echo "--- Prog/$p"; plcc-rep < ../Prog/$p
  done
  cd ../../..
done
```

Expected, identically in all three targets:

```
--- Prog/dddd
4
4
--- Prog/inits
x
14
--- Prog/ivx
i
v
x
--- Prog/pair
pair
--- Prog/util
pos?
neg?
lt?
le?
gt?
ge?
eq?
ne?
--- Prog/x
x
f
2
x
3
--- Prog/xx
x
f
2
x
2
```

`ivx`, `pair`, and `util` emit only names because they define without ever evaluating. `dddd` is two `letrec` programs and contains no `define` at all — it is the grammar canary described above.

- [ ] **Step 2: Confirm the `p1`/`p2` fragment behavior**

Run each of these as a self-contained command from the worktree root (they both `cd`, so do not chain them in one shell):

```bash
(cd src/V6/python && cat ../Prog/p1 ../Prog/p2 | plcc-rep)
```

Expected: `7`.

```bash
(cd src/V6/python && plcc-rep ../Prog/p1 ../Prog/p2)
```

Expected: two parse errors, because `plcc-rep` parses each `SOURCE` argument as its own independent stream:

```
plcc-parser-table: -:1:3: error: expected 'RPAREN', got end of file
plcc-parser-table: -:1:1: error: unexpected 'COMMA', no production for 'Program'
```

- [ ] **Step 3: Confirm no shrinking is needed**

Unlike V4 — whose `Prog/oe` and `Prog/fib` had to be shrunk for Python's recursion ceiling — every V6 example is small. If any run above hangs or raises a recursion error, **stop and report** rather than editing the example; the design asserts none is needed and a surprise here means something else is wrong.

- [ ] **Step 4: File the upstream-targeted issue**

Run: `bin/issues/new.bash plcc-rep-parses-each-source-independently docs`

Expected path: `dev-docs/issues/022-plcc-rep-parses-each-source-independently.md`.

Edit the generated file. Set the frontmatter `target` to the upstream repo — this is a plcc-ng behavior difference, not a defect in our `src/`:

```yaml
target: ourPLCC/plcc-ng
```

Replace the `## Description` body and keep `## Steps to Reproduce` (this one *is* a reproducible report):

```markdown
## Description

plcc-rep parses each SOURCE argument as an independent token stream, so
a program split across two files no longer parses. Old PLCC's `rep`
joined its file arguments into one stream. V6's Prog/p1 (`+(3`) and
Prog/p2 (`,4)`) are a course example that relies on the old behavior.

Not a defect in this repo's src/ — per-source parsing is arguably the
more sensible design — but it is a migration hazard worth documenting
upstream, and it silently changes what a course demonstration does.

## Steps to Reproduce

1. From `src/V6/python/`, with p1 containing `+(3` and p2 containing `,4)`:

   ```
   $ plcc-rep ../Prog/p1 ../Prog/p2
   plcc-parser-table: -:1:3: error: expected 'RPAREN', got end of file
   plcc-parser-table: -:1:1: error: unexpected 'COMMA', no production for 'Program'
   ```

2. Concatenating first works as expected:

   ```
   $ cat ../Prog/p1 ../Prog/p2 | plcc-rep
   7
   ```

## Notes

Found while porting V6. See
[dev-docs/specs/2026-08-03-plcc-ng-v6-design.md](../specs/2026-08-03-plcc-ng-v6-design.md).

Per issue-conventions.md, upstream-targeted issues stay in this repo and
are reported upstream manually, with explicit go-ahead. Nothing has been
filed externally.
```

- [ ] **Step 5: Add its roadmap entry**

Under the existing `### Docs` group in `dev-docs/roadmap.md`, after the `#19` entry:

```markdown
- **[#22](issues/022-plcc-rep-parses-each-source-independently.md) — plcc-rep parses each SOURCE argument independently**
  A program split across two files no longer parses, where old PLCC's `rep` joined its file arguments into one stream; V6's `Prog/p1`/`Prog/p2` course example depends on the old behavior and now needs `cat p1 p2 | plcc-rep`. Targeted at ourPLCC/plcc-ng, not reported externally yet.
```

- [ ] **Step 6: Log the course-material impact**

Append to `dev-docs/course-material-impact.md`, under the `## V6` heading created in Task 3:

```markdown
- `Prog/p1` + `Prog/p2` demonstrate a reader spanning file boundaries.
  The invocation changed: `rep Prog/p1 Prog/p2` no longer works, because
  plcc-rep parses each SOURCE argument as its own stream. Use
  `cat Prog/p1 Prog/p2 | plcc-rep` instead, which still yields `7`. Both
  files are unchanged; only the command demonstrating them differs.
  Tracked as issue #22.
```

- [ ] **Step 7: Verify and commit**

Run: `bin/issues/check.bash`
Expected: exits 0.

```bash
git add dev-docs/issues/022-plcc-rep-parses-each-source-independently.md \
        dev-docs/issues/.next-id.txt dev-docs/roadmap.md \
        dev-docs/course-material-impact.md
git commit -m "docs(issues): file 022 - plcc-rep parses each SOURCE independently

Found verifying V6's Prog/ examples. All nine run correctly in all three
targets; only the p1/p2 fragment pair needs a changed invocation."
```

---

## Task 9: Remove the old V6 old-PLCC files

**Files:**
- Delete: `src/V6/grammar`, `src/V6/code`, `src/V6/prim`, `src/V6/envVal`, `src/V6/val`

None collides with a new path (`src/V6/grammar` versus `src/V6/grammar.plcc`), which is why this comes at the end rather than up front — the same call V4 and V5 made.

- [ ] **Step 1: Confirm nothing references them**

Run: `grep -rn "plccmk\|%include code\|%include prim\|%include val\|%include envVal" src/V6/`
Expected: no output. The only former reference was the old `V6test.bats`, replaced in Task 4.

- [ ] **Step 2: Delete the five files**

```bash
git rm src/V6/grammar src/V6/code src/V6/prim src/V6/envVal src/V6/val
```

Note `src/V6/Prog/` is **not** deleted — those are course artifacts kept per Task 8.

- [ ] **Step 3: Confirm the suite is unchanged**

Run: `bin/test.bash 2>&1 | grep -c '^ok'`
Expected: `63` — unchanged from Task 7.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(V6): remove the old old-PLCC spec files

Superseded by grammar.plcc plus the three target spec.plcc files.
Prog/ is kept - those are course artifacts."
```

---

## Task 10: Correct the overarching migration design's stale addendum

The overarching [migration design](../specs/2026-07-22-plcc-ng-migration-design.md) has no reference to the [2.0.0 update](../specs/2026-07-27-plcc-ng-2.0.0-update-design.md) and carries four claims that are now false. Phase 3 fans out to seven languages whose implementers will read that document first, so this lands before then.

**Files:**
- Modify: `dev-docs/specs/2026-07-22-plcc-ng-migration-design.md`

- [ ] **Step 1: Correct the lowercase alt-name guidance**

Two bullets in the Phasing section (currently lines 38 and 43) tell the reader to spell `IfExp`'s alt-names entirely lowercase (`<Exp:testexp>`) to dodge issue #6. Append to each bullet:

```markdown
    **Superseded:** issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md) was fixed in plcc-ng 2.0.0 (see the [2.0.0 update design](2026-07-27-plcc-ng-2.0.0-update-design.md)). V3–V6 all ship camelCase `<Exp:testExp>`; the lowercase workaround was reverted and must not be reintroduced.
```

- [ ] **Step 2: Correct the `_run()` asymmetry claim**

Replace this addendum bullet (currently line 102):

```markdown
- **`_run()`'s contract differs by target, necessarily.** Python and Java should call `print()` / `System.out.println()` directly inside `_run()` (returning `None`/`void`). JavaScript's `_run()` must `return` the string instead — writing to stdout directly from JS `_run()` corrupts the output protocol per its own docs. This is an intentional, unavoidable asymmetry in the otherwise-uniform structure described above.
```

with:

```markdown
- **`_run()` returns a string in all three targets.** *(Corrected — this bullet originally described an asymmetry in which Python and Java printed and only JavaScript returned. That was true before the [2.0.0 update](2026-07-27-plcc-ng-2.0.0-update-design.md) and is now wrong.)* Returning `None` from Python's `_run()` is a hard `Specification error: TypeError: _run() must return a string, got NoneType`. The structure is uniform: `return` the output, never print it.
```

- [ ] **Step 3: Correct the Python-quoting claim**

Replace this addendum bullet (currently line 103):

```markdown
- **Returning a plain string from Python's `_run()` prints it with quotes** (e.g. `'hello'` instead of `hello`), contradicting the official quick-start example. Reproduced cleanly and isolated from any other code. Using `print()` instead of `return` avoids it entirely. Filed as a candidate upstream defect (see below).
```

with:

```markdown
- **~~Returning a plain string from Python's `_run()` prints it with quotes~~** — fixed upstream. Issue [#3](../issues/003-python-run-return-value-quoted.md) closed 2026-07-28; returning a plain string now prints it unquoted, as the quick-start example always showed. The `print()`-instead-of-`return` workaround this bullet recommended is now itself an error — see the bullet above.
```

- [ ] **Step 4: Correct the `VAR` rename guidance**

In the addendum bullet about the JavaScript reserved-word collision (currently line 104), the recommended fix is to rename the *capture* (`<VAR:name>`). Append:

```markdown
  **What was actually done:** the *token* was renamed to `SYMBOL` (captured as `symbol`, `symbolList` in list positions) rather than the capture being aliased. Every migrated language V0–V6 uses `SYMBOL`; Phases 3–5 should follow suit.
```

- [ ] **Step 5: Note the supersession at the top of the addendum**

Immediately after the addendum's opening paragraph ("The summary above undersold several concrete details…"), insert:

```markdown
**Read with the [2.0.0 update design](2026-07-27-plcc-ng-2.0.0-update-design.md) alongside this section.** These facts were validated against the plcc-ng release current in July 2026. Four of them were later superseded by the 2.0.0 update and are marked inline below. Anything here that a live run contradicts should be treated as stale and corrected in place, not worked around.
```

- [ ] **Step 6: Verify no links broke**

Run: `bin/issues/check.bash`
Expected: exits 0.

Manually confirm the three new relative links resolve from `dev-docs/specs/`:
`2026-07-27-plcc-ng-2.0.0-update-design.md`, `../issues/006-multi-capture-alt-name-case-mismatch.md`, `../issues/003-python-run-return-value-quoted.md`.

- [ ] **Step 7: Commit**

```bash
git add dev-docs/specs/2026-07-22-plcc-ng-migration-design.md
git commit -m "docs(specs): correct four stale claims in the migration addendum

The overarching design predates the 2.0.0 update and never referenced
it. Corrects the lowercase alt-name workaround, the _run() print/return
asymmetry, the Python string-quoting bug, and the VAR rename guidance -
each pointing at what superseded it.

Lands before Phase 3 fans out to seven languages."
```

---

## Task 11: Close the V6 issue

**Files:**
- Modify: `dev-docs/issues/021-migrate-v6-to-plcc-ng.md`, `dev-docs/roadmap.md`

- [ ] **Step 1: Final full-suite verification**

Run: `bin/test.bash 2>&1 | tee /tmp/v6-final.txt | tail -3`

Then count from the **whole** run, never a `tail` — V5's design got this wrong precisely by reading a tail window, and the seven non-V languages sort alphabetically *before* `V0`:

```bash
grep -c '^ok' /tmp/v6-final.txt      # expect 63
grep -c '^not ok' /tmp/v6-final.txt  # expect 7
grep '^not ok' /tmp/v6-final.txt     # expect NAME, NEED, OBJ, REF, SET, TYPE0, TYPE1
```

Expected: **70 tests, 63 passing, 7 failing.** Every failure a `plccmk: command not found`. No `V`-prefixed failure. If any of these three numbers differs, stop and report rather than closing.

- [ ] **Step 2: Confirm the tree is clean and Phase 2 is complete**

Run: `git status --short`
Expected: no output.

Run: `ls src/V6`
Expected: `Prog  grammar.plcc  java  javascript  python  tests` — no old flat files.

- [ ] **Step 3: Close the issue**

Run: `bin/issues/close.bash 21`

This fills in the issue's `closed` date, removes its Open Issues entry, removes the now-empty `### Feat` group, and stages both files. The issue file does **not** move. Issue #22 stays open — it is upstream-targeted and not resolved by this work.

- [ ] **Step 4: Review the staged roadmap diff**

Run: `git diff --cached dev-docs/roadmap.md`

Confirm the `#21` entry and the `### Feat` heading are both gone, and that the `### Chore` and `### Docs` groups — including the `#22` entry added in Task 8 — are untouched. Per [issue #20](../issues/020-close-bash-roadmap-awk-edge-cases.md), `close.bash`'s awk has two dormant edge cases around blank-line collapsing; neither fires against the roadmap's current shape, but eyeball the diff rather than trusting it blind.

- [ ] **Step 5: Verify consistency**

Run: `bin/issues/check.bash`
Expected: exits 0.

- [ ] **Step 6: Commit**

```bash
git commit -m "docs(issues): close issue 21 (migrate V6 to plcc-ng), update roadmap"
```

---

## Done

Phase 2 is complete. All seven V-series languages (V0–V6) run under plcc-ng in Python, Java, and JavaScript. The 7 remaining suite failures are Phases 3–5: SET, REF, NAME, NEED (Phase 3, introducing `envRef`), TYPE0, TYPE1 (Phase 4), and OBJ (Phase 5).

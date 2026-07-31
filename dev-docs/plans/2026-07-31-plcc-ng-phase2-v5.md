# plcc-ng Migration — Phase 2 (V5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port V5's grammar and Python/Java/JavaScript semantics to `plcc-ng`. V5 is `V4 + letrec`: one new token, one new production, one new `Exp` subclass (`LetrecExp`), one new `LetDecls` method (`addLetrecBindings`), and a one-word change to a `checkDuplicates` message. Everything else in V5 is byte-identical to V4.

**Architecture:** Each target's `spec.plcc` starts as a **verbatim copy** of the corresponding V4 `spec.plcc` and gains exactly three edits: a `LetrecExp` block, an `addLetrecBindings` method on `LetDecls`, and the changed `LetDecls:init` message (plus a `Binding` import in Python and JavaScript). `src/Env/envVal/<target>/env.plcc` is reused **unchanged** for the third consecutive language — both facilities `letrec` needs (`EnvNode.add(binding)` and the no-arg `Bindings()`) are already in the port.

**Tech Stack:** `plcc-ng` CLI (`plcc-scan`, `plcc-parse`, `plcc-rep`), `bats-core` (via `bin/test.bash`), bash, Python 3.12+, Java JDK 21+, Node.js 18+. All already available in this devcontainer (plcc-ng 2.0.1).

**Design of record:** [dev-docs/specs/2026-07-31-plcc-ng-v5-design.md](../specs/2026-07-31-plcc-ng-v5-design.md), which extends the [V4 design](../specs/2026-07-30-plcc-ng-v4-design.md) and the overarching [migration design](../specs/2026-07-22-plcc-ng-migration-design.md).

**Working directory:** this branch's worktree, `.claude/worktrees/feat-migrate-v5-to-plcc-ng`. Run every command from there. Do not `cd` to the main checkout.

**No spike task.** V0, V1, and V4 each opened with a spike because they introduced an unvalidated plcc-ng mechanic. V5 introduces none — no new arbno shape, no new capture pattern, no new class modifier. Its one plausible risk (`LETREC` declared after `LET`, with `let` a proper prefix of `letrec`) was resolved live during design: **plcc-ng's scanner is maximal-munch**, so `letrec` scans as `LETREC` regardless of declaration order and `letx` stays one `SYMBOL`. Task 2 re-confirms this in passing as part of verifying the real grammar.

## Global Constraints

- Scope is V5 only. Do not touch V6, `envRef`, or any language outside `src/V5/` (plus the shared `dev-docs/` bookkeeping files). **Do not touch `src/V4/`** — V5 keeps its own copies; nothing is refactored into a shared location.
- **`src/Env/envVal/**` is read-only in this plan.** V5 reuses it byte-for-byte. In particular, do **not** add the capacity-taking `Bindings(int)` constructor the old Java code calls — see the `addLetrecBindings` note in Task 3. If something looks like it needs an `envVal` change, stop and report.
- Follow the conventions V0–V4 established: capitalized nonterminals, the identifier token named `SYMBOL` captured as `symbol` (`symbolList` in list positions), camelCase `IfExp` alt-names (`testExp`/`trueExp`/`falseExp`), and a `_run()` that **returns** a string — never prints.
- Everything V5 inherits from V4 — `Program`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`, `ProcExp`, `Proc`, `Formals`, `AppExp`, `SeqExp`, `Rands`, `Val`, `IntVal`, `ProcVal`, and all seven `Prim` subclasses — is copied from `src/V4/<target>/spec.plcc` **verbatim**. The only V4 class that changes is `LetDecls`, which gains one method and a changed `:init` message.
- **Token keys via `.lexeme`, never `.toString()`.** Under plcc-ng a token's string form is the scan format (`source:line:col TOKEN 'lexeme'`). Runtime errors raise `LanguageError`, never the old `PLCCException`.
- V5's identifier regex stays V4's `[A-Za-z][\w?]*`. V5's old `grammar` file has a header comment claiming the `?` arrives at V5; that comment is **stale** (the widening happened at V4) and is not carried forward.
- `LetrecExp` gets **no** `toString()`/`__str__`. The original has none, and the port does not invent one — the same call V4 made for `ProcExp`. Do not "finish" it.
- Structural fidelity across targets: method names (`eval`, `addBindings`, `addLetrecBindings`, `checkDuplicates`, `extendEnv`, `applyEnv`, `add`) stay identical across Python, Java, and JavaScript.
- JavaScript: grammar-derived classes get `Node`/`Token`/`LanguageError` auto-injected — never add an `:import` for those three names on them. Requiring genuinely free-standing classes (`Env`, `Binding`, `Bindings`, `ProcVal`, `Val`) from a grammar-derived class is fine and required.
- Every test case gets one shared `V5.input` / `V5.expected` pair, asserted by one `@test` block per target in a single `.bats` file. Value cases only — no error-path test.
- Keep every test's recursion depth and integer magnitude small. Python's default 1,000-frame recursion limit (which forced V4 to shrink `Prog/oe`) and the 32-bit Java `IntVal` overflow of open issue [#16](../issues/016-cross-target-integer-divergence.md) are both live constraints. Every expected value in this plan was measured, not predicted — do not scale any of them up.
- Any change affecting course material gets logged in [dev-docs/course-material-impact.md](../course-material-impact.md) under a `## V5` heading, in the same commit that makes the change.
- Never run bare `git stash` / `git stash pop` — the stash stack is shared with other worktrees.

---

## Task 1: File the V5 issue

**Files:**
- Create: `dev-docs/issues/done/017-migrate-v5-to-plcc-ng.md` (id assigned by the script)
- Modify: `dev-docs/roadmap.md`, `dev-docs/issues/.next-id.txt`

- [ ] **Step 1: Generate the issue file**

Run: `bin/issues/new.bash migrate-v5-to-plcc-ng feat`

This reads `dev-docs/issues/.next-id.txt` (currently `17`), creates the file from the template with today's date, and increments the id. The script prints the path it created — expected `dev-docs/issues/done/017-migrate-v5-to-plcc-ng.md`. Use the printed path in the steps below; never assign an id by hand.

- [ ] **Step 2: Fill in the issue's Description and Notes**

Edit the generated file. Replace the `## Description` body with the text below and **delete the entire `## Steps to Reproduce` section** (this is not a bug report):

```markdown
## Description

Port V5's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V5 is
V4 + letrec: it adds the LETREC token, the <Exp:LetrecExp> production,
and LetDecls.addLetrecBindings, which builds a recursive scope by
extending the environment with an empty Bindings and then mutating that
node as each right-hand side is evaluated. It reuses the envVal Env
variant and every other V4 class without modification. V6 is explicitly
out of scope.

## Notes

See [dev-docs/specs/2026-07-31-plcc-ng-v5-design.md](../specs/2026-07-31-plcc-ng-v5-design.md)
and [dev-docs/plans/2026-07-31-plcc-ng-phase2-v5.md](../plans/2026-07-31-plcc-ng-phase2-v5.md).
```

- [ ] **Step 3: Add the roadmap entry**

Edit `dev-docs/roadmap.md`. Per [issue-conventions.md](../issue-conventions.md), the entry goes under `## Open Issues` beneath the `###` heading matching the issue's type — `Feat`, which does **not** currently exist (V4's entry moved to `done/` when it closed), so create the group. Place it before the existing `### Chore` group. Use this exact two-line format (the `bin/issues/` scripts parse it):

```markdown
### Feat

- **[#17](issues/done/017-migrate-v5-to-plcc-ng.md) — Migrate V5 to plcc-ng**
  Ports V5's grammar and Java semantics to plcc-ng and adds Python and JavaScript semantics. V5 is V4 + letrec, reusing envVal and every other V4 class unchanged; the only new semantics are LetrecExp.eval and LetDecls.addLetrecBindings.
```

- [ ] **Step 4: Commit**

`bin/issues/new.bash` also bumps `dev-docs/issues/.next-id.txt` to `18`. That
bump ships in **this same commit** — leaving it uncommitted means the next
`new.bash` on any branch re-reads `17` and collides with the issue just filed,
and `bin/issues/check.bash` fails on a clean checkout (`next_id 17 not > max_id
17`) even though it passes against the dirty working tree.

```bash
git add dev-docs/issues/done/017-migrate-v5-to-plcc-ng.md dev-docs/roadmap.md dev-docs/issues/.next-id.txt
git commit -m "$(cat <<'EOF'
docs(issues): file 017 - migrate V5 to plcc-ng

Refs #17
EOF
)"
```

---

## Task 2: Create the shared V5 grammar

**Files:**
- Create: `src/V5/grammar.plcc`
- Modify: `dev-docs/course-material-impact.md`

**Interfaces:**
- Produces: nonterminals `Program`, `Exp` (alts `LitExp`/`VarExp`/`IfExp`/`PrimappExp`/`LetExp`/`LetrecExp`/`ProcExp`/`AppExp`/`SeqExp`), `Prim` (seven alts), `Rands`, `LetDecls`, `SeqExps`, `Proc`, `Formals`. The only new generated fields are `LetrecExp.letDecls` and `LetrecExp.exp`. Every V4 field is unchanged (`LetDecls.symbolList`/`.expList`, `Rands.expList`, `IfExp.testExp`/`.trueExp`/`.falseExp`, `Proc.formals`/`.exp`, `Formals.symbolList`, `SeqExps.expList`, `AppExp.exp`/`.rands`, `SeqExp.exp`/`.seqExps`, `ProcExp.proc`).

- [ ] **Step 1: Write `src/V5/grammar.plcc`**

This is V4's grammar with `token LETREC 'letrec'` inserted after `token LET 'let'`, and `<Exp:LetrecExp>` inserted after `<Exp:LetExp>`. Nothing else differs.

```text
# Language V5
#   Language V4 + letrec
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
token IN 'in'
token EQUALS '='
token PROC 'proc'
token DOT '\.'
token LBRACE '\{'
token RBRACE '\}'
token SEMI ';'
token SYMBOL '[A-Za-z][\w?]*'
%
<Program>        ::= <Exp>
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

Notes on the shape, so you don't "improve" it:
- `LETREC` sits after `LET` because that is V5's original token order. It is safe there: plcc-ng's scanner is longest-match, not first-declaration-match. Step 2 re-confirms this.
- `<LetDecls>` is shared by `LetExp` and `LetrecExp` — one nonterminal, two parents. That is what makes `addLetrecBindings` a second method on `LetDecls` rather than a new class.
- `SYMBOL` keeps V4's trailing-`?` widening. Do not narrow it back to V3's `[A-Za-z]\w*`.
- Do **not** copy V5's old `grammar` header comment about `?` in variable names — it is stale.

- [ ] **Step 2: Verify the grammar parses, and re-confirm maximal-munch scanning**

```bash
cd src/V5
echo 'letrec f = g in letx' | plcc-scan -s grammar.plcc
```

Expected — `letrec` is one `LETREC`, and `letx` is one `SYMBOL`:

```
-:1:1 LETREC 'letrec'
-:1:8 SYMBOL 'f'
-:1:10 EQUALS '='
-:1:12 SYMBOL 'g'
-:1:14 IN 'in'
-:1:17 SYMBOL 'letx'
```

If `letrec` instead splits into `LET` + `SYMBOL 'rec'`, the scanner is first-match rather than longest-match. That contradicts the measurement taken during design and would affect every language, not just V5: **stop**, file it with `bin/issues/new.bash scanner-not-longest-match chore` (set `**Target:** ourPLCC/plcc-ng`), record the exact output, and report back before continuing.

Then confirm `letrec` and `let` coexist as sibling `<Exp>` alternatives:

```bash
echo 'letrec fact = proc(x) if zero?(x) then 1 else *(x,.fact(sub1(x))) in .fact(5)' | plcc-parse -s grammar.plcc | head -5
echo 'let x = 4 in {add1(x); sub1(x); *(x, x)}' | plcc-parse -s grammar.plcc | head -3
```

Expected: the first prints a tree rooted `Program` → `LetrecExp` → `LetDecls`; the second prints `Program` → `LetExp` (V4's shape, unregressed). Neither may report an LL(1) conflict — if one does, stop and file an issue the same way.

Clean up and return to the worktree root:

```bash
rm -rf plcc-ng
cd ../..
```

- [ ] **Step 3: Log the course-material impact**

Add to `dev-docs/course-material-impact.md`, after the existing `## V4` section:

```markdown
## V5

- New token `LETREC 'letrec'` and one new production,
  `<Exp:LetrecExp> ::= LETREC <LetDecls> IN <Exp>`. `LetDecls` is shared
  with `LetExp` — `letrec` introduces no new nonterminal.
- Same `SYMBOL`/`symbol` convention as V0-V4. V5's old grammar carried a
  header comment claiming variable names "now can have a `?` in them" at
  V5; that comment was **stale** and is not carried forward — the
  widening to `[A-Za-z][\w?]*` already happened at V4. Course material
  that attributes the `?` to V5 should attribute it to V4.
- `LetrecExp` has **no** `toString()`. The original has none, and the
  port does not invent one (same treatment as V4's `ProcExp`).
```

- [ ] **Step 4: Commit**

```bash
git add src/V5/grammar.plcc dev-docs/course-material-impact.md
git commit -m "$(cat <<'EOF'
feat(V5): add plcc-ng grammar (lexical + syntactic sections)

V4 + letrec: adds the LETREC token and the <Exp:LetrecExp> production,
which reuses the existing <LetDecls> nonterminal. Everything else is
V4's grammar unchanged.

Refs #17
EOF
)"
```

---

## Task 3: Add V5 Python semantics

**Files:**
- Create: `src/V5/python/spec.plcc`

**Interfaces:**
- Consumes: `src/V5/grammar.plcc` (Task 2) and the unmodified `src/Env/envVal/python/env.plcc` — specifically `Env.checkDuplicates(symbolList, msg="")`, `Env.initEnv()`, `env.extendEnv(bindings)`, `env.applyEnv(symString)`, `env.add(binding)` (mutates the node in place), `Binding(idString, val)`, and `Bindings()` / `Bindings(idList, valList)`.
- Produces: `LetDecls.addLetrecBindings(env)` → `Env`; `LetrecExp.eval(env)` → `Val`.

- [ ] **Step 1: Copy V4's Python spec as the starting point**

```bash
mkdir -p src/V5/python
cp src/V4/python/spec.plcc src/V5/python/spec.plcc
```

Every V4 class is reused verbatim; the remaining steps only edit three blocks. The `%include ../grammar.plcc` and `%include ../../Env/envVal/python/env.plcc` lines at the top are already correct — the relative paths are identical from `src/V5/python/`.

- [ ] **Step 2: Add the `Binding` import to `LetDecls`**

In `src/V5/python/spec.plcc`, replace the whole `LetDecls:import` block with:

```text
LetDecls:import
%%%
from Env import Env
from Binding import Binding
from Bindings import Bindings
%%%
```

`Binding` is new here — V4's `addBindings` only ever constructed a whole `Bindings`, while `addLetrecBindings` adds one `Binding` at a time. There is no file-wide import in plcc-ng, so it must go on this specific class.

- [ ] **Step 3: Update the `LetDecls:init` message**

Replace the whole `LetDecls:init` block with:

```text
LetDecls:init
%%%
Env.checkDuplicates(self.symbolList, " in let/letrec LHS identifiers")
%%%
```

The wording change is faithful to the original V5 and is V5-local — V4 keeps `" in let LHS identifiers"`. Do not go change V4's.

- [ ] **Step 4: Add `addLetrecBindings` to `LetDecls`**

Replace the whole `LetDecls` block (the one with no `:` modifier) with:

```text
LetDecls
%%%
def addBindings(self, env):
    valList = [e.eval(env) for e in self.expList]
    bindings = Bindings(self.symbolList, valList)
    return env.extendEnv(bindings)

def addLetrecBindings(self, env):
    env = env.extendEnv(Bindings())
    for sym, e in zip(self.symbolList, self.expList):
        val = e.eval(env)
        env.add(Binding(sym.lexeme, val))
    return env

def __str__(self):
    return "... LetDecls ..."
%%%
```

Three things about `addLetrecBindings` that are deliberate, so you don't "correct" them:

1. **`Bindings()` with no arguments, not a capacity.** The old Java code calls `new Bindings(varList.size())`. The ported `envVal` has no capacity-taking constructor — capacity is a JVM `ArrayList` pre-allocation hint with no observable semantics, and Python has no equivalent. The empty `Bindings` produced here is exactly what the Java version produced. **Do not add a constructor to `envVal` for this.**
2. **Each right-hand side is evaluated in the already-extended `env`**, and the resulting binding is added to that same node via `env.add(...)`. This mutation is the whole mechanism: a `proc` right-hand side captures the env *object* while it is still empty, and later `add` calls make its siblings visible by the time anything is called. Recursion here comes from aliasing a mutable node, not from a fixpoint.
3. **The binding pass is eager and sequential**, so a non-`proc` forward reference fails (`letrec a = b b = 1 in a` → `no binding for b`). That is faithful to the original. Do **not** "fix" it into a two-pass placeholder-and-patch `letrec`.

- [ ] **Step 5: Add the `LetrecExp` block**

Insert immediately after the existing `LetExp` block and before `LetDecls:import`, so the semantic blocks follow the grammar's order:

```text
LetrecExp
%%%
def eval(self, env):
    env = self.letDecls.addLetrecBindings(env)
    return self.exp.eval(env)
%%%
```

No `__str__` — the original has none.

- [ ] **Step 6: Run the Python target end-to-end**

```bash
cd src/V5/python
echo 'letrec fact = proc(x) if zero?(x) then 1 else *(x,.fact(sub1(x))) in .fact(5)' | plcc-rep
```

Expected: `120`.

Then mutual recursion, nested/shadowing `letrec`, and a V4 regression check:

```bash
plcc-rep <<'EOF'
letrec
  even? = proc(x) if zero?(x) then 1 else .odd?(sub1(x))
  odd? = proc(x) if zero?(x) then 0 else .even?(sub1(x))
in
  .even?(10)
EOF
plcc-rep <<'EOF'
letrec
  f = proc(x) if zero?(x) then 100 else .f(sub1(x))
in
  +(.f(3), letrec f = proc(x) if zero?(x) then 7 else .f(sub1(x)) in .f(3))
EOF
echo 'let x = 4 in {add1(x); sub1(x); *(x, x)}' | plcc-rep
echo 'letrec a = 1 a = 2 in a' | plcc-rep
```

Expected, in order: `1`, `107`, `16`, `duplicate ID a in let/letrec LHS identifiers`. All four values were measured against a working prototype — a different result is a real defect, not a tolerance.

If any run raises `NameError: name 'Binding' is not defined`, Step 2's `:import` was not applied.

Clean up and return:

```bash
rm -rf plcc-ng __pycache__
cd ../../..
```

- [ ] **Step 7: Commit**

```bash
git add src/V5/python/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V5): add Python semantics

Reuses V4's classes and envVal unchanged; adds LetrecExp.eval and
LetDecls.addLetrecBindings, which builds a recursive scope by extending
the env with an empty Bindings and mutating that node as each RHS is
evaluated.

Refs #17
EOF
)"
```

---

## Task 4: Add V5 Java semantics

**Files:**
- Create: `src/V5/java/spec.plcc`

**Interfaces:**
- Consumes: `src/V5/grammar.plcc` (Task 2) and the unmodified `src/Env/envVal/java/env.plcc` — specifically `static void Env.checkDuplicates(List<Token> symbolList, String msg)`, `static Env Env.initEnv()`, `Env.extendEnv(Bindings)`, `Env.applyEnv(String)`, `Env.add(Binding)` (returns the node; the result is discarded), `Binding(String id, Val val)`, and `Bindings()` / `Bindings(List<Token> idList, List<Val> valList)`.
- Produces: `Env LetDecls.addLetrecBindings(Env env)`; `Val LetrecExp.eval(Env env)`.

- [ ] **Step 1: Copy V4's Java spec as the starting point**

```bash
mkdir -p src/V5/java
cp src/V4/java/spec.plcc src/V5/java/spec.plcc
```

- [ ] **Step 2: Update the `LetDecls:init` message**

In `src/V5/java/spec.plcc`, replace the whole `LetDecls:init` block with:

```text
LetDecls:init
%%%
Env.checkDuplicates(symbolList, " in let/letrec LHS identifiers");
%%%
```

- [ ] **Step 3: Add `addLetrecBindings` to `LetDecls`**

Replace the whole `LetDecls` block (the one with no `:` modifier) with:

```text
LetDecls
%%%
public Env addBindings(Env env) {
    List<Val> valList = new ArrayList<Val>(expList.size());
    for (Exp e : expList)
        valList.add(e.eval(env));
    Bindings bindings = new Bindings(symbolList, valList);
    return env.extendEnv(bindings);
}

public Env addLetrecBindings(Env env) {
    env = env.extendEnv(new Bindings());
    for (int i = 0; i < symbolList.size(); i++) {
        Val val = expList.get(i).eval(env);
        env.add(new Binding(symbolList.get(i).lexeme, val));
    }
    return env;
}

public String toString() {
    return "... LetDecls ...";
}
%%%
```

Leave the existing `LetDecls:import` block (`import java.util.ArrayList;`) exactly as it is. `Binding`, `Bindings`, `Env`, `Exp`, and `Val` are package-less classes in the same generated directory and need no import; `List` is already available.

The same three deliberate choices as Python apply here, and this is where the first is most tempting to undo:

1. **`new Bindings()`, not `new Bindings(symbolList.size())`.** The old Java code used the capacity form, which the ported `envVal` does not provide. Capacity is an `ArrayList` pre-allocation hint with no observable semantics. **Do not add the constructor to `envVal`.**
2. Each right-hand side is evaluated in the already-extended `env`, and `env.add(...)` mutates that same node — that aliasing is what makes recursion work. `Env.add` returns `Env`; discarding the result is correct, since `EnvNode.add` returns `this`.
3. The pass is eager and sequential, so a non-`proc` forward reference fails. That is faithful — do not restructure it into a two-pass `letrec`.

- [ ] **Step 4: Add the `LetrecExp` block**

Insert immediately after the existing `LetExp` block and before `LetDecls:import`:

```text
LetrecExp
%%%
public Val eval(Env env) {
    env = letDecls.addLetrecBindings(env);
    return exp.eval(env);
}
%%%
```

No `toString()` — the original has none. No `:import` — Java grammar-derived classes reference same-directory classes directly.

- [ ] **Step 5: Run the Java target end-to-end**

```bash
cd src/V5/java
echo 'letrec fact = proc(x) if zero?(x) then 1 else *(x,.fact(sub1(x))) in .fact(5)' | plcc-rep
plcc-rep <<'EOF'
letrec
  even? = proc(x) if zero?(x) then 1 else .odd?(sub1(x))
  odd? = proc(x) if zero?(x) then 0 else .even?(sub1(x))
in
  .even?(10)
EOF
plcc-rep <<'EOF'
letrec
  f = proc(x) if zero?(x) then 100 else .f(sub1(x))
in
  +(.f(3), letrec f = proc(x) if zero?(x) then 7 else .f(sub1(x)) in .f(3))
EOF
echo 'let x = 4 in {add1(x); sub1(x); *(x, x)}' | plcc-rep
echo 'letrec a = 1 a = 2 in a' | plcc-rep
```

Expected, in order: `120`, `1`, `107`, `16`, `duplicate ID a in let/letrec LHS identifiers`. These must match Python's exactly — the three targets are required to agree.

Clean up and return:

```bash
rm -rf plcc-ng
cd ../../..
```

- [ ] **Step 6: Commit**

```bash
git add src/V5/java/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V5): add Java semantics

Reuses V4's classes and envVal unchanged; adds LetrecExp.eval and
LetDecls.addLetrecBindings, which builds a recursive scope by extending
the env with an empty Bindings and mutating that node as each RHS is
evaluated.

Refs #17
EOF
)"
```

---

## Task 5: Add V5 JavaScript semantics

**Files:**
- Create: `src/V5/javascript/spec.plcc`

**Interfaces:**
- Consumes: `src/V5/grammar.plcc` (Task 2) and the unmodified `src/Env/envVal/javascript/env.plcc` — specifically `static Env.checkDuplicates(symbolList, msg = "")`, `static Env.initEnv()`, `env.extendEnv(bindings)`, `env.applyEnv(symString)`, `env.add(binding)` (mutates the node in place), `new Binding(idString, val)`, and `new Bindings()` / `new Bindings(idList, valList)`.
- Produces: `LetDecls.addLetrecBindings(env)` → `Env`; `LetrecExp.eval(env)` → `Val`.

- [ ] **Step 1: Copy V4's JavaScript spec as the starting point**

```bash
mkdir -p src/V5/javascript
cp src/V4/javascript/spec.plcc src/V5/javascript/spec.plcc
```

- [ ] **Step 2: Add the `Binding` require to `LetDecls`**

In `src/V5/javascript/spec.plcc`, replace the whole `LetDecls:import` block with:

```text
LetDecls:import
%%%
const { Env } = require('./Env');
const { Binding } = require('./Binding');
const { Bindings } = require('./Bindings');
%%%
```

`Env`, `Binding`, and `Bindings` are all free-standing classes, so requiring them from the grammar-derived `LetDecls` is correct and necessary. Do **not** add requires for `Node`, `Token`, or `LanguageError` — those are auto-injected into grammar-derived class files, and redeclaring one throws `Identifier 'X' has already been declared`.

- [ ] **Step 3: Update the `LetDecls:init` message**

Replace the whole `LetDecls:init` block with:

```text
LetDecls:init
%%%
Env.checkDuplicates(this.symbolList, " in let/letrec LHS identifiers");
%%%
```

- [ ] **Step 4: Add `addLetrecBindings` to `LetDecls`**

Replace the whole `LetDecls` block (the one with no `:` modifier) with:

```text
LetDecls
%%%
addBindings(env) {
    const valList = this.expList.map(e => e.eval(env));
    const bindings = new Bindings(this.symbolList, valList);
    return env.extendEnv(bindings);
}

addLetrecBindings(env) {
    env = env.extendEnv(new Bindings());
    for (let i = 0; i < this.symbolList.length; i++) {
        const val = this.expList[i].eval(env);
        env.add(new Binding(this.symbolList[i].lexeme, val));
    }
    return env;
}

toString() {
    return "... LetDecls ...";
}
%%%
```

The same three deliberate choices as Python and Java apply: `new Bindings()` with no capacity argument (**do not add one to `envVal`**); each right-hand side evaluated in the already-extended `env` with `env.add(...)` mutating that same node; and an eager, sequential pass whose non-`proc` forward-reference failure is faithful, not a bug to fix.

- [ ] **Step 5: Add the `LetrecExp` block**

Insert immediately after the existing `LetExp` block and before `LetDecls:import`:

```text
LetrecExp
%%%
eval(env) {
    env = this.letDecls.addLetrecBindings(env);
    return this.exp.eval(env);
}
%%%
```

No `toString()` — the original has none. No `:import` — `LetrecExp` references only its own fields.

- [ ] **Step 6: Run the JavaScript target end-to-end**

```bash
cd src/V5/javascript
echo 'letrec fact = proc(x) if zero?(x) then 1 else *(x,.fact(sub1(x))) in .fact(5)' | plcc-rep
plcc-rep <<'EOF'
letrec
  even? = proc(x) if zero?(x) then 1 else .odd?(sub1(x))
  odd? = proc(x) if zero?(x) then 0 else .even?(sub1(x))
in
  .even?(10)
EOF
plcc-rep <<'EOF'
letrec
  f = proc(x) if zero?(x) then 100 else .f(sub1(x))
in
  +(.f(3), letrec f = proc(x) if zero?(x) then 7 else .f(sub1(x)) in .f(3))
EOF
echo 'let x = 4 in {add1(x); sub1(x); *(x, x)}' | plcc-rep
echo 'letrec a = 1 a = 2 in a' | plcc-rep
```

Expected, in order: `120`, `1`, `107`, `16`, `duplicate ID a in let/letrec LHS identifiers`. These must match Python's and Java's exactly.

Clean up and return:

```bash
rm -rf plcc-ng
cd ../../..
```

- [ ] **Step 7: Commit**

```bash
git add src/V5/javascript/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V5): add JavaScript semantics

Reuses V4's classes and envVal unchanged; adds LetrecExp.eval and
LetDecls.addLetrecBindings, which builds a recursive scope by extending
the env with an empty Bindings and mutating that node as each RHS is
evaluated.

Refs #17
EOF
)"
```

---

## Task 6: Log the letrec semantics in the course-material impact log

**Files:**
- Modify: `dev-docs/course-material-impact.md`

This is its own task rather than folded into Tasks 3–5 because the entry describes one semantics implemented three times; writing it once, after all three targets agree, is what keeps it accurate. It still lands before any test work, so the log never lags the code by more than one task.

- [ ] **Step 1: Append to the `## V5` section**

Add these bullets to the end of the `## V5` section created in Task 2:

```markdown
- `letrec` is implemented by **mutation, not by a fixpoint**.
  `LetDecls.addLetrecBindings(env)` extends the environment with an
  *empty* `Bindings`, then evaluates each right-hand side **in that
  already-extended environment** and adds the resulting binding to that
  same node with `env.add(...)`. A `proc` right-hand side captures the
  env object while it still holds zero bindings; later additions to that
  same node are what make its siblings (and itself) visible by the time
  anything is called. This is worth showing explicitly on a slide — it
  is not the placeholder-and-patch `letrec` most textbooks present.
- A consequence worth stating in class: the binding pass is **eager and
  sequential**, so a right-hand side that *looks something up* can only
  see bindings to its left. `letrec f = proc(...) .g(...) g = proc(...)
  .f(...) in ...` works (neither side looks anything up while binding),
  but `letrec a = b b = 1 in a` fails with `no binding for b`. Faithful
  to the original V5, not a porting artifact.
- `LetDecls`' list fields are **`symbolList`** and **`expList`** (the
  original Java code's `varList`/`expList`). Course material walking
  through `addBindings` or `addLetrecBindings` should use `symbolList`.
- The duplicate-identifier message is now
  `duplicate ID <id> in let/letrec LHS identifiers` — V4 and earlier say
  `... in let LHS identifiers`. `LetDecls` is shared by both `let` and
  `letrec`, so the check covers both.
```

- [ ] **Step 2: Commit**

```bash
git add dev-docs/course-material-impact.md
git commit -m "$(cat <<'EOF'
docs(course-material-impact): record V5's letrec semantics

The mutation-based addLetrecBindings, its eager/sequential
forward-reference limitation, the symbolList field name, and the changed
duplicate-identifier message.

Refs #17
EOF
)"
```

---

## Task 7: Remove the old V5 old-PLCC files

**Files:**
- Delete: `src/V5/grammar`, `src/V5/code`, `src/V5/prim`, `src/V5/envVal`, `src/V5/val`

None of these collides with a path the new layout needs (`src/V5/grammar` vs `src/V5/grammar.plcc`), which is why the deletion comes here rather than up front. `src/V5/tests/` stays — it is handled in Task 8. V5 has no `Prog/` directory.

- [ ] **Step 1: Confirm nothing still references them**

```bash
grep -rn "include code\|include prim\|include envVal\|include val" src/V5/ || echo "no old %include references"
```

Expected: `no old %include references` (the only file that had them was `src/V5/grammar`, which is itself being deleted).

- [ ] **Step 2: Delete**

```bash
git rm src/V5/grammar src/V5/code src/V5/prim src/V5/envVal src/V5/val
```

- [ ] **Step 3: Verify the three targets still work after the deletion**

```bash
for t in python java javascript; do
  ( cd "src/V5/$t" && echo 'letrec fact = proc(x) if zero?(x) then 1 else *(x,.fact(sub1(x))) in .fact(5)' | plcc-rep && rm -rf plcc-ng __pycache__ )
done
```

Expected: `120` printed three times.

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore(V5): remove old PLCC grammar, code, prim, val, and envVal files

Superseded by grammar.plcc plus the three per-target spec.plcc files.

Refs #17
EOF
)"
```

---

## Task 8: Rewrite the V5 bats test and add two cases

**Files:**
- Modify: `src/V5/tests/letrec/V5test.bats`
- Create: `src/V5/tests/mutual-recursion/V5.input`, `src/V5/tests/mutual-recursion/V5.expected`, `src/V5/tests/mutual-recursion/V5test.bats`
- Create: `src/V5/tests/nested-letrec/V5.input`, `src/V5/tests/nested-letrec/V5.expected`, `src/V5/tests/nested-letrec/V5test.bats`

Three cases total. `letrec/` is the existing case, ported off `plccmk`/`rep` with its `V5.input`/`V5.expected` untouched. V5 has no `Prog/` directory to mine from, so the other two are hand-written. Every expected value below was measured against a working prototype, not predicted.

Trailing newlines in `.input`/`.expected` do not matter: both sides of the comparison go through `$(...)`, which strips them.

- [ ] **Step 1: Capture the current "command not found" baseline**

The old `src/V5/tests/letrec/V5test.bats` still calls `plccmk`/`rep`, so it currently fails as a `command not found`. Measure the count **now**, fresh — do not copy a number from an earlier phase's plan:

```bash
BASELINE_CNF=$(bin/test.bash 2>&1 | grep -c 'command not found'); echo "baseline=$BASELINE_CNF"
```

Expected: `2` (V5's single old test and V6's). After this task it must drop to exactly `1` — V6's alone.

- [ ] **Step 2: Rewrite `src/V5/tests/letrec/V5test.bats` for the three targets**

Replace the whole file with:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V5 letrec (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/letrec/V5.input)"
  expected_output=$(< "../tests/letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 letrec (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/letrec/V5.input)"
  expected_output=$(< "../tests/letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 letrec (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/letrec/V5.input)"
  expected_output=$(< "../tests/letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

The existing `src/V5/tests/letrec/V5.input` (`letrec fact = proc(x) if zero?(x) then 1 else *(x,.fact(sub1(x))) in .fact(5)`) and `V5.expected` (`120`) are **unchanged** — do not rewrite them. `.fact(5)` stays at 5: it is comfortably inside the 32-bit-safe range that issue #16 documents, and well inside Python's recursion limit.

- [ ] **Step 3: Write the `mutual-recursion` case**

This is the case that justifies `letrec` as a language feature. V4's `multi-formals/` had to simulate mutual recursion by passing the two procedures to each other as arguments; here they simply refer to each other by name, which works only because both closures alias the same mutated env node.

`src/V5/tests/mutual-recursion/V5.input`:
```
letrec
  even? = proc(x) if zero?(x) then 1 else .odd?(sub1(x))
  odd? = proc(x) if zero?(x) then 0 else .even?(sub1(x))
in
  .even?(10)
```

`src/V5/tests/mutual-recursion/V5.expected`:
```
1
```

`src/V5/tests/mutual-recursion/V5test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V5 mutual-recursion (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/mutual-recursion/V5.input)"
  expected_output=$(< "../tests/mutual-recursion/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 mutual-recursion (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/mutual-recursion/V5.input)"
  expected_output=$(< "../tests/mutual-recursion/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 mutual-recursion (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/mutual-recursion/V5.input)"
  expected_output=$(< "../tests/mutual-recursion/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

`.even?(10)` recurses 10 language-level calls deep — deliberately shallow, for the reason V4's `Prog/oe` had to be shrunk from 11000.

- [ ] **Step 4: Write the `nested-letrec` case**

An inner `letrec` shadows an outer binding of the same name, and both are recursive. The outer `f` counts down to `100`, the inner one to `7`; the sum proves the inner definition shadowed the outer inside its own body without disturbing the outer one, which is still live in the same expression.

`src/V5/tests/nested-letrec/V5.input`:
```
letrec
  f = proc(x) if zero?(x) then 100 else .f(sub1(x))
in
  +(.f(3), letrec f = proc(x) if zero?(x) then 7 else .f(sub1(x)) in .f(3))
```

`src/V5/tests/nested-letrec/V5.expected`:
```
107
```

`src/V5/tests/nested-letrec/V5test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V5 nested-letrec (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nested-letrec/V5.input)"
  expected_output=$(< "../tests/nested-letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 nested-letrec (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nested-letrec/V5.input)"
  expected_output=$(< "../tests/nested-letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V5 nested-letrec (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nested-letrec/V5.input)"
  expected_output=$(< "../tests/nested-letrec/V5.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 5: Run the V5 suite**

```bash
bats --recursive src/V5/tests
```

Expected: 9 tests, all passing (3 cases × 3 targets). If a Java case fails on a stale build, `rm -rf src/V5/*/plcc-ng` and rerun — `relocate` copies the whole `src/` tree into a tmpdir, so committed build artifacts would travel with it.

- [ ] **Step 6: Run the full suite and confirm no regression**

```bash
bin/test.bash 2>&1 | tail -20
NEW_CNF=$(bin/test.bash 2>&1 | grep -c 'command not found'); echo "now=$NEW_CNF baseline=$BASELINE_CNF"
```

Expected: **56 tests, 55 passing.** Every V0, V1, V2, V3, V4, and V5 test passes. `NEW_CNF` must be exactly `1` (`BASELINE_CNF - 1`) — V6's test, the only language left in this repo that still calls `plccmk`. No other failure mode is acceptable. If a V0–V4 test that passed before now fails, stop and report: V5 must not have touched anything shared.

- [ ] **Step 7: Commit**

```bash
git add src/V5/tests
git commit -m "$(cat <<'EOF'
test(V5): port the letrec test to plcc-rep and add two cases

Rewrites letrec/ for the three targets and adds mutual-recursion/ (the
case letrec actually buys over V4's self-application trick) and
nested-letrec/ (an inner letrec shadowing an outer binding).

Refs #17
EOF
)"
```

---

## Task 9: Close the V5 issue

- [ ] **Step 1: Re-verify before closing**

```bash
bats --recursive src/V5/tests
```

Expected: 9/9 passing. Do not close on a stale result from Task 8 — run it again.

- [ ] **Step 2: Close the issue**

Run: `bin/issues/close.bash 17`

Expected: prints `closed: dev-docs/issues/done/017-migrate-v5-to-plcc-ng.md` and updates `dev-docs/roadmap.md` (removing the now-empty `### Feat` group).

- [ ] **Step 3: Verify bookkeeping consistency**

Run: `bin/issues/check.bash`

Expected: reports the roadmap consistent with `done/` and the open set. Issues #12, #13, and #16 remain open (all three deferred by design); any issue filed during Task 2 also remains open.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs(issues): close issue 17 (migrate V5 to plcc-ng), update roadmap"
```

---

## What's next

V5 confirms that `envVal` reuse survives a language that *mutates* the environment rather than only extending it, and that the shared `<LetDecls>` nonterminal can serve two parents with two different binding strategies.

V6 is next (`V5 + define`), and it is the last of the V-series. It is also the riskiest so far: its `<Program>` grammar has two alternatives (`Define`/`Eval`), and `define` mutates a `Program`-level environment that later reads **in the same `plcc-rep` run** must see. V4's `closure/` case already showed that `plcc-rep` evaluates multiple programs from one stdin stream; what remains unvalidated is whether `Program`-level state *persists* across those parses in one process. Per the overarching design, V6's phase should spike exactly that before committing to a full port. Per the phase-by-phase discipline, V6 is deliberately **not** planned yet; return once V5 is merged.

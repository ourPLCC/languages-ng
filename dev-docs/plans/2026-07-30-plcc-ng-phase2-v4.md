# plcc-ng Migration — Phase 2 (V4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port V4's grammar and Python/Java/JavaScript semantics to `plcc-ng`. V4 is `V3 + procedures and the sequence operator`: same `envVal`, same seven `Prim`s, same `Val`/`IntVal` (plus one new method), plus the `ProcExp`/`AppExp`/`SeqExp`/`Proc`/`Formals`/`SeqExps` productions, the `ProcVal` closure class, and their semantics in all three targets. Also: verify and (where needed) shrink V4's `Prog/` example programs, the first such directory the migration has met.

**Architecture:** V4 reuses `src/Env/envVal/<target>/env.plcc` **unchanged** — V3 ported it and deliberately kept `checkDuplicates` and the two-list `Bindings(idList, valList)` constructor precisely because V4's `Formals:init` and `ProcVal.apply` need them. Each target's `spec.plcc` starts as a copy of the corresponding V3 `spec.plcc` and gains: `Val.apply` (base, throws), a free-standing `ProcVal` closure class, and semantics for `ProcExp`, `Proc`, `AppExp`, `SeqExp`, and `Formals:init`. Nothing else in V3's semantics changes.

**Tech Stack:** `plcc-ng` CLI (`plcc-scan`, `plcc-parse`, `plcc-rep`), `bats-core` (via `bin/test.bash`), bash, Python 3.12+, Java JDK 21+, Node.js 18+. All already available in this devcontainer (plcc-ng 2.0.1).

**Design of record:** [dev-docs/specs/2026-07-30-plcc-ng-v4-design.md](../specs/2026-07-30-plcc-ng-v4-design.md), which extends the [V3 design](../specs/2026-07-28-plcc-ng-v3-design.md) and the overarching [migration design](../specs/2026-07-22-plcc-ng-migration-design.md).

**Working directory:** this branch's worktree, `.claude/worktrees/feat-014-migrate-v4-to-plcc-ng`. Run every command from there. Do not `cd` to the main checkout.

## Global Constraints

- Scope is V4 only. Do not touch V5, V6, `envRef`, or any language outside `src/V4/` (plus the shared `dev-docs/` bookkeeping files).
- **`src/Env/envVal/**` is read-only in this plan.** V4 reuses it byte-for-byte. If something looks like it needs an `envVal` change, stop and report — it almost certainly means the V4-side code is wrong.
- Follow the conventions V0–V3 established: capitalized nonterminals, the identifier token named `SYMBOL` captured as `symbol` (`symbolList` in list positions), camelCase `IfExp` alt-names (`testExp`/`trueExp`/`falseExp`), and a `_run()` that **returns** a string — never prints.
- Everything V4 inherits from V3 — `Program`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`, `LetDecls`, `Rands`, `IntVal`, `Exp`, `Prim`, and all seven `Prim` subclasses — is copied from `src/V3/<target>/spec.plcc` **verbatim**. The only V3 class that changes is `Val`, which gains one method.
- **Token keys via `.lexeme`, never `.toString()`.** Under plcc-ng a token's string form is the scan format (`source:line:col TOKEN 'lexeme'`). Runtime errors raise `LanguageError`, never the old `PLCCException`.
- V4's identifier regex is `[A-Za-z][\w?]*` — wider than V3's `[A-Za-z]\w*`. This is deliberate and load-bearing (`Prog/oe` names procedures `even?`/`odd?`). Do not "fix" it back to V3's.
- The `toString()` bodies for `AppExp` (`" ... AppExp ..."`) and `SeqExp` (`" ... SeqExp ... "`) are the original course material's placeholder stubs. Reproduce them **verbatim, including the leading and trailing spaces**. Do not tidy them, and do not add a `toString()` to `ProcExp` (the original has none).
- Structural fidelity across targets: method names (`eval`, `apply`, `makeClosure`, `evalRands`, `addBindings`, `checkDuplicates`, `extendEnv`, `applyEnv`) stay identical across Python, Java, and JavaScript.
- `Val.apply(args, env)` keeps its `env` parameter even though nothing in V4, V5, or V6 reads it. It is part of the signature the course material shows.
- JavaScript: grammar-derived classes get `Node`/`Token`/`LanguageError` auto-injected — never add an `:import` for those three names on them. Requiring genuinely free-standing classes (`Env`, `Bindings`, `ProcVal`, `Val`) from a grammar-derived class is fine and required.
- Every test case gets one shared `V4.input` / `V4.expected` pair, asserted by one `@test` block per target in a single `.bats` file. Value cases only — no error-path test (duplicate formals, arity mismatch, applying a non-procedure).
- Any change affecting course material gets logged in [dev-docs/course-material-impact.md](../course-material-impact.md) under a `## V4` heading, in the same commit that makes the change.
- Never run bare `git stash` / `git stash pop` — the stash stack is shared with other worktrees.

---

## Task 1: File the V4 issue

**Files:**
- Create: `dev-docs/issues/done/014-migrate-v4-to-plcc-ng.md` (id assigned by the script)
- Modify: `dev-docs/roadmap.md`

- [ ] **Step 1: Generate the issue file**

Run: `bin/issues/new.bash migrate-v4-to-plcc-ng feat`

This reads `dev-docs/issues/.next-id.txt` (currently `14`), creates the file from the template with today's date, and increments the id. The script prints the path it created — expected `dev-docs/issues/done/014-migrate-v4-to-plcc-ng.md`. Use the printed path in the steps below; never assign an id by hand.

- [ ] **Step 2: Fill in the issue's Description and Notes**

Edit the generated file. Replace the `## Description` body with the text below and **delete the entire `## Steps to Reproduce` section** (this is not a bug report):

```markdown
## Description

Port V4's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V4 is
V3 + procedures and the sequence operator: it adds the ProcExp/AppExp/
SeqExp productions, the Proc/Formals/SeqExps nonterminals, and the
ProcVal closure class, reusing the envVal Env variant V3 introduced
without modification. It is also the first migrated language with a
Prog/ directory of example programs, so this issue also verifies those
against all three targets. V5-V6 are explicitly out of scope.

## Notes

See [dev-docs/specs/2026-07-30-plcc-ng-v4-design.md](../specs/2026-07-30-plcc-ng-v4-design.md)
and [dev-docs/plans/2026-07-30-plcc-ng-phase2-v4.md](../plans/2026-07-30-plcc-ng-phase2-v4.md).
```

- [ ] **Step 3: Add the roadmap entry**

Edit `dev-docs/roadmap.md`. Per [issue-conventions.md](../issue-conventions.md), the entry goes under `## Open Issues` beneath the `###` heading matching the issue's type — `Feat`, which does not exist yet, so create the group. Place it before the existing `### Chore` group. Use this exact two-line format (the `bin/issues/` scripts parse it):

```markdown
### Feat

- **[#14](issues/done/014-migrate-v4-to-plcc-ng.md) — Migrate V4 to plcc-ng**
  Ports V4's grammar and Java semantics to plcc-ng and adds Python and JavaScript semantics. V4 is V3 + procedures (proc/application, closures) and the sequence operator, reusing envVal unchanged. Also verifies V4's Prog/ example programs against all three targets.
```

- [ ] **Step 4: Commit**

`bin/issues/new.bash` also bumps `dev-docs/issues/.next-id.txt` to `15`. That
bump ships in **this same commit** — leaving it uncommitted means the next
`new.bash` on any branch re-reads `14` and collides with the issue just filed,
and `bin/issues/check.bash` fails on a clean checkout (`next_id 14 not > max_id
14`) even though it passes against the dirty working tree.

```bash
git add dev-docs/issues/done/014-migrate-v4-to-plcc-ng.md dev-docs/roadmap.md dev-docs/issues/.next-id.txt
git commit -m "$(cat <<'EOF'
docs(issues): file 014 - migrate V4 to plcc-ng

Refs #14
EOF
)"
```

---

## Task 2: Create the shared V4 grammar and spike the two novel mechanics

**Files:**
- Create: `src/V4/grammar.plcc`
- Modify: `dev-docs/course-material-impact.md`

**Interfaces:**
- Produces: nonterminals `Program`, `Exp` (alts `LitExp`/`VarExp`/`IfExp`/`PrimappExp`/`LetExp`/`ProcExp`/`AppExp`/`SeqExp`), `Prim` (seven alts), `Rands`, `LetDecls`, `SeqExps`, `Proc`, `Formals`. Generated fields: `ProcExp.proc`; `AppExp.exp` and `.rands`; `SeqExp.exp` and `.seqExps`; `SeqExps.expList` (list of `Exp`); `Proc.formals` and `.exp`; `Formals.symbolList` (list of `SYMBOL` tokens). V3's fields are unchanged (`LetDecls.symbolList`/`.expList`, `Rands.expList`, `IfExp.testExp`/`.trueExp`/`.falseExp`).

This task is deliberately also the **spike** the design calls for: the real grammar contains both novel mechanics, so verifying it with `plcc-parse` validates them without a throwaway scratch file.

- [ ] **Step 1: Write `src/V4/grammar.plcc`**

```text
# Language V4
#   Language V3 + procedure definition/application and the sequence operator
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
- Every keyword token (`ADD1OP`, `SUB1OP`, `ZEROP`, `IF`, `THEN`, `ELSE`, `LET`, `IN`, `PROC`) is declared **before** `SYMBOL`, whose `[A-Za-z][\w?]*` pattern also matches those literals. Declaration order is what makes the keyword win.
- `SYMBOL` now admits a trailing `?`, so it overlaps `ZEROP` (`zero\?`) for the exact input `zero?`. Step 3 verifies the tie resolves in `ZEROP`'s favor.
- `<SeqExps> **= SEMI <Exp>` is a zero-or-more rule whose body **begins** with a non-capturing terminal and declares no separator. `{a; b; c}` therefore parses as `SeqExp` with `exp = a` and `seqExps.expList = [b, c]`.
- `<Formals> **= <SYMBOL> +COMMA` and `<Rands> **= <Exp> +COMMA` both use a declared separator, so `proc()` / `.f()` with zero formals/arguments are legal.

- [ ] **Step 2: Verify the sequence expression parses (the arbno leading-terminal spike)**

```bash
cd src/V4
echo '{1; 2; 3}' | plcc-parse -s grammar.plcc
```

Expected: a clean parse tree rooted at `Program` → `SeqExp`, whose direct `LitExp` child is `1` and whose `SeqExps` groups `2` and `3` into `expList`:

```
Program
  SeqExp
    LitExp
      LIT '1' [-:1:2]
    SeqExps
      LitExp
        LIT '2' [-:1:5]
      LitExp
        LIT '3' [-:1:8]
```

It MUST NOT print `unexpected 'SEMI'` or `no production for 'Exp'` — that is the [issue #10](../issues/010-plcc-ng-arbno-drops-mid-body-terminal.md) symptom in leading position, which would mean 2.0.1's fix did not cover it. If it does, **stop**: file an issue with `bin/issues/new.bash arbno-drops-leading-body-terminal chore` (set `**Target:** ourPLCC/plcc-ng`), record the exact output, and report back. Do not restructure the grammar around it — V3 set the precedent of keeping the faithful shape and waiting for the upstream fix.

If `plcc-parse` reports a genuine LL(1) conflict on any rule, stop and file an issue the same way.

- [ ] **Step 3: Verify the widened SYMBOL still loses to `zero?` (the token-overlap spike)**

```bash
echo '.proc(even?, odd?) zero?(even?) (0, 1)' | plcc-scan -s grammar.plcc
```

Expected in the token stream: `even?` and `odd?` each scan as a **single** `SYMBOL` token (lexeme `even?`, `odd?`), and `zero?` scans as `ZEROP`, not as `SYMBOL`. Confirm by eye that no line reads `SYMBOL 'zero?'` and that there is no `SYMBOL 'even'` followed by a separate token for the `?`.

Then check the keyword-prefix case, where a keyword is a proper prefix of an identifier:

```bash
echo 'let inx = 1 in inx' | plcc-parse -s grammar.plcc
```

Expected: a clean `LetExp` binding a single `SYMBOL 'inx'`. If instead `inx` splits into `IN` + `SYMBOL 'x'`, the scanner is first-match rather than longest-match — that is a real finding: file it (`bin/issues/new.bash scanner-not-longest-match chore`, `**Target:** ourPLCC/plcc-ng`), note it in the issue, and report back before continuing, since it would affect every language, not just V4.

Then verify the whole grammar still handles V3's constructs:

```bash
echo 'let three = 2 four = 5 in +(three, four)' | plcc-parse -s grammar.plcc
```

Expected: a clean `LetExp` parse, same shape V3 produces.

Clean up and return to the worktree root:

```bash
rm -rf plcc-ng
cd ../..
```

- [ ] **Step 4: Log the course-material impact**

Add to `dev-docs/course-material-impact.md`, after the existing `## V3` section:

```markdown
## V4

- Same `SYMBOL`/`symbol` convention as V0-V3, but V4 **widens** the
  identifier pattern to `[A-Za-z][\w?]*` so a name may end in `?`. This
  is a real V4 language feature carried over from the original grammar,
  not migration drift — `Prog/oe` names its procedures `even?` and
  `odd?`. (V5's old grammar carries a comment claiming the `?` arrives
  at V5; that comment is stale — the widening is already V4's.)
- New productions: `<Exp:ProcExp> ::= <Proc>`,
  `<Exp:AppExp> ::= DOT <Exp> LPAREN <Rands> RPAREN`,
  `<Exp:SeqExp> ::= LBRACE <Exp> <SeqExps> RBRACE`,
  `<SeqExps> **= SEMI <Exp>`,
  `<Proc> ::= PROC LPAREN <Formals> RPAREN <Exp>`, and
  `<Formals> **= <SYMBOL> +COMMA`.
- `Formals`' list field is **`symbolList`** (`self.formals.symbolList` /
  `formals.symbolList` / `this.formals.symbolList`), not the original
  Java code's `varList`. Course material walking through `ProcVal.apply`
  or the `proc` formals duplicate-check should use `symbolList`.
- `SeqExp` reads its trailing expressions from `seqExps.expList`; the
  first expression is the separate field `exp`. `{a; b; c}` evaluates
  `a` first and yields the value of `c`.
```

- [ ] **Step 5: Commit**

```bash
git add src/V4/grammar.plcc dev-docs/course-material-impact.md
git commit -m "$(cat <<'EOF'
feat(V4): add plcc-ng grammar (lexical + syntactic sections)

V3 + proc/application and the sequence operator: adds PROC/DOT/LBRACE/
RBRACE/SEMI tokens, widens SYMBOL to allow a trailing '?', and adds the
ProcExp/AppExp/SeqExp/Proc/Formals/SeqExps productions.

Refs #14
EOF
)"
```

---

## Task 3: Add V4 Python semantics

**Files:**
- Create: `src/V4/python/spec.plcc`

**Interfaces:**
- Consumes: `src/V4/grammar.plcc` (Task 2) and the unmodified `src/Env/envVal/python/env.plcc` — specifically `Env.checkDuplicates(symbolList, msg="")`, `Env.initEnv()`, `env.extendEnv(bindings)`, `env.applyEnv(symString)`, and `Bindings(idList, valList)` (keyed by each id's `.lexeme`).
- Produces: `Val.apply(args, env)` (base, raises), `ProcVal(formals, body, env)` with `.apply(args, env)`, `Proc.makeClosure(env)` → `ProcVal`.

- [ ] **Step 1: Copy V3's Python spec as the starting point**

```bash
mkdir -p src/V4/python
cp src/V3/python/spec.plcc src/V4/python/spec.plcc
```

Every V3 class is reused verbatim; the remaining steps only add to this file. The `%include ../grammar.plcc` and `%include ../../Env/envVal/python/env.plcc` lines at the top are already correct — the relative paths are identical from `src/V4/python/`.

- [ ] **Step 2: Add `apply` to `Val`**

In `src/V4/python/spec.plcc`, replace the whole `Val` block with:

```text
Val
%%%
from runtime.base import LanguageError


class Val:

    def apply(self, args, env):
        raise LanguageError(f"Cannot apply {self}")

    def isTrue(self):
        return True

    def intVal(self):
        raise LanguageError(f"{self}: not an Int")
%%%
```

- [ ] **Step 3: Add the `ProcVal` free-standing class**

Insert immediately after the `IntVal` block (so the three `Val` classes sit together):

```text
ProcVal
%%%
from Bindings import Bindings
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
        bindings = Bindings(self.formals.symbolList, args)
        nenv = self.env.extendEnv(bindings)
        return self.body.eval(nenv)

    def __str__(self):
        return "proc"
%%%
```

`ProcVal` extends the captured `self.env`, **not** the caller's `env` — that is what makes it a closure rather than dynamic scoping. It needs no import for `Formals` or `Exp`: Python is duck-typed and only ever reads `.symbolList` off one and calls `.eval()` on the other.

- [ ] **Step 4: Add the procedure and sequence semantics**

Insert after the existing `LetDecls` block and before the `Rands` block:

```text
ProcExp
%%%
def eval(self, env):
    return self.proc.makeClosure(env)
%%%

Proc:import
%%%
from ProcVal import ProcVal
%%%

Proc
%%%
def makeClosure(self, env):
    return ProcVal(self.formals, self.exp, env)
%%%

Formals:import
%%%
from Env import Env
%%%

Formals:init
%%%
Env.checkDuplicates(self.symbolList, " in proc formals")
%%%

AppExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    args = self.rands.evalRands(env)
    return v.apply(args, env)

def __str__(self):
    return " ... AppExp ..."
%%%

SeqExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    for e in self.seqExps.expList:
        v = e.eval(env)
    return v

def __str__(self):
    return " ... SeqExp ... "
%%%
```

`ProcExp` gets no `__str__` — the original has none. The `AppExp`/`SeqExp` stubs keep their leading/trailing spaces exactly as written.

- [ ] **Step 5: Run the Python target end-to-end**

```bash
cd src/V4/python
echo '.proc(x) +(x,3) (5)' | plcc-rep
```

Expected: `8`.

Then the sequence expression and a closure:

```bash
echo 'let x = 4 in {add1(x); sub1(x); *(x, x)}' | plcc-rep
echo 'let p = let y = 1 in proc(x) +(x,y) in .p(.p(.p(3)))' | plcc-rep
```

Expected: `16`, then `6`.

If any run raises `NameError: name 'X' is not defined`, a class is missing its `:import` block — add it for that specific class (there is no file-wide import).

Clean up and return:

```bash
rm -rf plcc-ng __pycache__
cd ../../..
```

- [ ] **Step 6: Commit**

```bash
git add src/V4/python/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V4): add Python semantics

Reuses V3's classes and envVal unchanged; adds Val.apply, the ProcVal
closure class, and ProcExp/Proc/Formals/AppExp/SeqExp semantics.

Refs #14
EOF
)"
```

---

## Task 4: Add V4 Java semantics

**Files:**
- Create: `src/V4/java/spec.plcc`

**Interfaces:**
- Consumes: `src/V4/grammar.plcc` (Task 2) and the unmodified `src/Env/envVal/java/env.plcc` — specifically `static void Env.checkDuplicates(List<Token> symbolList, String msg)`, `static Env Env.initEnv()`, `Env.extendEnv(Bindings)`, `Env.applyEnv(String)`, and `Bindings(List<Token> idList, List<Val> valList)`.
- Produces: `Val.apply(List<Val> args, Env e)` (base, throws), `ProcVal(Formals formals, Exp body, Env env)`, `Proc.makeClosure(Env env)` → `Val`.

- [ ] **Step 1: Copy V3's Java spec as the starting point**

```bash
mkdir -p src/V4/java
cp src/V3/java/spec.plcc src/V4/java/spec.plcc
```

- [ ] **Step 2: Add `apply` to `Val`**

Replace the whole `Val` block with:

```text
Val
%%%
import java.util.List;
import runtime.LanguageError;

public abstract class Val {

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

`java.util.List` is a new import here — V3's `Val` did not need it. Free-standing classes are emitted verbatim and get no auto-injected imports, so it must be written out.

- [ ] **Step 3: Add the `ProcVal` free-standing class**

Insert immediately after the `IntVal` block:

```text
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
        Bindings bindings = new Bindings(formals.symbolList, args);
        Env nenv = env.extendEnv(bindings);
        return body.eval(nenv);
    }

    public String toString() {
        return "proc";
    }
}
%%%
```

`ProcVal` extends the captured field `env`, not the parameter `e` — `e` is unused by design. `Formals`, `Exp`, `Env`, and `Bindings` are all package-less classes in the same generated directory, so they need no import.

- [ ] **Step 4: Add the procedure and sequence semantics**

Insert after the existing `LetDecls` block and before the `Rands` block:

```text
ProcExp
%%%
public Val eval(Env env) {
    return proc.makeClosure(env);
}
%%%

Proc
%%%
public Val makeClosure(Env env) {
    return new ProcVal(formals, exp, env);
}
%%%

Formals:init
%%%
Env.checkDuplicates(symbolList, " in proc formals");
%%%

AppExp
%%%
public Val eval(Env env) {
    Val v = exp.eval(env);
    List<Val> args = rands.evalRands(env);
    return v.apply(args, env);
}

public String toString() {
    return " ... AppExp ...";
}
%%%

SeqExp
%%%
public Val eval(Env env) {
    Val v = exp.eval(env);
    for (Exp e : seqExps.expList)
        v = e.eval(env);
    return v;
}

public String toString() {
    return " ... SeqExp ... ";
}
%%%
```

No `:import` blocks anywhere in the Java target: grammar-derived classes reference same-directory classes directly, and `java.util.List` is already available in them (V3's `PrimappExp` uses `List<Val>` with no import of its own).

- [ ] **Step 5: Run the Java target end-to-end**

```bash
cd src/V4/java
echo '.proc(x) +(x,3) (5)' | plcc-rep
echo 'let x = 4 in {add1(x); sub1(x); *(x, x)}' | plcc-rep
echo 'let p = let y = 1 in proc(x) +(x,y) in .p(.p(.p(3)))' | plcc-rep
```

Expected: `8`, `16`, `6`.

Clean up and return:

```bash
rm -rf plcc-ng
cd ../../..
```

- [ ] **Step 6: Commit**

```bash
git add src/V4/java/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V4): add Java semantics

Reuses V3's classes and envVal unchanged; adds Val.apply, the ProcVal
closure class, and ProcExp/Proc/Formals/AppExp/SeqExp semantics.

Refs #14
EOF
)"
```

---

## Task 5: Add V4 JavaScript semantics

**Files:**
- Create: `src/V4/javascript/spec.plcc`

**Interfaces:**
- Consumes: `src/V4/grammar.plcc` (Task 2) and the unmodified `src/Env/envVal/javascript/env.plcc` — specifically `static Env.checkDuplicates(symbolList, msg = "")`, `static Env.initEnv()`, `env.extendEnv(bindings)`, `env.applyEnv(symString)`, and `new Bindings(idList, valList)`.
- Produces: `Val.apply(args, env)` (base, throws), `ProcVal(formals, body, env)` exported as `module.exports = { ProcVal }`, `Proc.makeClosure(env)` → `ProcVal`.

- [ ] **Step 1: Copy V3's JavaScript spec as the starting point**

```bash
mkdir -p src/V4/javascript
cp src/V3/javascript/spec.plcc src/V4/javascript/spec.plcc
```

- [ ] **Step 2: Add `apply` to `Val`**

Replace the whole `Val` block with:

```text
Val
%%%
const { LanguageError } = require('./runtime/base');

class Val {

    apply(args, env) {
        throw new LanguageError(`Cannot apply ${this}`);
    }

    isTrue() {
        return true;
    }

    intVal() {
        throw new LanguageError(`${this}: not an Int`);
    }
}

module.exports = { Val };
%%%
```

- [ ] **Step 3: Add the `ProcVal` free-standing class**

Insert immediately after the `IntVal` block:

```text
ProcVal
%%%
const { Val } = require('./Val');
const { Bindings } = require('./Bindings');
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
        const bindings = new Bindings(this.formals.symbolList, args);
        const nenv = this.env.extendEnv(bindings);
        return this.body.eval(nenv);
    }

    toString() {
        return "proc";
    }
}

module.exports = { ProcVal };
%%%
```

`ProcVal` is free-standing, so it gets **no** auto-injected requires and must require `LanguageError` itself — the opposite of the rule for grammar-derived classes.

- [ ] **Step 4: Add the procedure and sequence semantics**

Insert after the existing `LetDecls` block and before the `Rands` block:

```text
ProcExp
%%%
eval(env) {
    return this.proc.makeClosure(env);
}
%%%

Proc:import
%%%
const { ProcVal } = require('./ProcVal');
%%%

Proc
%%%
makeClosure(env) {
    return new ProcVal(this.formals, this.exp, env);
}
%%%

Formals:import
%%%
const { Env } = require('./Env');
%%%

Formals:init
%%%
Env.checkDuplicates(this.symbolList, " in proc formals");
%%%

AppExp
%%%
eval(env) {
    const v = this.exp.eval(env);
    const args = this.rands.evalRands(env);
    return v.apply(args, env);
}

toString() {
    return " ... AppExp ...";
}
%%%

SeqExp
%%%
eval(env) {
    let v = this.exp.eval(env);
    for (const e of this.seqExps.expList)
        v = e.eval(env);
    return v;
}

toString() {
    return " ... SeqExp ... ";
}
%%%
```

`Proc` and `Formals` are grammar-derived, so they may require the free-standing `ProcVal`/`Env` — but must **not** require `Node`, `Token`, or `LanguageError` (auto-injected; redeclaring throws `Identifier 'X' has already been declared`). `AppExp` and `SeqExp` need no `:import` at all.

- [ ] **Step 5: Run the JavaScript target end-to-end**

```bash
cd src/V4/javascript
echo '.proc(x) +(x,3) (5)' | plcc-rep
echo 'let x = 4 in {add1(x); sub1(x); *(x, x)}' | plcc-rep
echo 'let p = let y = 1 in proc(x) +(x,y) in .p(.p(.p(3)))' | plcc-rep
```

Expected: `8`, `16`, `6`.

Clean up and return:

```bash
rm -rf plcc-ng
cd ../../..
```

- [ ] **Step 6: Commit**

```bash
git add src/V4/javascript/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V4): add JavaScript semantics

Reuses V3's classes and envVal unchanged; adds Val.apply, the ProcVal
closure class, and ProcExp/Proc/Formals/AppExp/SeqExp semantics.

Refs #14
EOF
)"
```

---

## Task 6: Remove the old V4 old-PLCC files

**Files:**
- Delete: `src/V4/grammar`, `src/V4/code`, `src/V4/prim`, `src/V4/envVal`, `src/V4/val`

Unlike `src/Env/envVal`, none of these collide with a path the new layout needs (`src/V4/grammar` vs `src/V4/grammar.plcc`), which is why the deletion comes here rather than up front. `src/V4/Prog/` and `src/V4/tests/` stay — they are handled in Tasks 7 and 8.

- [ ] **Step 1: Confirm nothing still references them**

```bash
grep -rn "include code\|include prim\|include envVal\|include val" src/V4/ || echo "no old %include references"
```

Expected: `no old %include references` (the only file that had them was `src/V4/grammar`, which is itself being deleted).

- [ ] **Step 2: Delete**

```bash
git rm src/V4/grammar src/V4/code src/V4/prim src/V4/envVal src/V4/val
```

- [ ] **Step 3: Verify the three targets still work after the deletion**

```bash
for t in python java javascript; do
  ( cd "src/V4/$t" && echo '.proc(x) +(x,3) (5)' | plcc-rep && rm -rf plcc-ng __pycache__ )
done
```

Expected: `8` printed three times.

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore(V4): remove old PLCC grammar, code, prim, val, and envVal files

Superseded by grammar.plcc plus the three per-target spec.plcc files.

Refs #14
EOF
)"
```

---

## Task 7: Verify and shrink the `Prog/` example programs

**Files:**
- Modify: `src/V4/Prog/oe`
- Modify: `src/V4/Prog/fib`
- Modify: `dev-docs/course-material-impact.md`

V4 is the first migrated language with example programs (V0–V3 have none). This task runs all six against all three targets. Two are shrunk in place because they cannot run everywhere as written: `oe` recurses ~11,000 language-level calls deep (past Python's 1,000-frame default limit, and each language-level call costs several interpreter frames), and `fib` computes `fib(30)` — roughly 2.7 million calls, minutes in Python.

- [ ] **Step 1: Shrink `src/V4/Prog/oe`**

Change only the final line's first argument, `11000` → `10`. The file becomes:

```text
let
  even? = proc(x, even?, odd?) if zero?(x) then 1 else .odd?(sub1(x), even?, odd?)
  odd? = proc(x, even?, odd?) if zero?(x) then 0 else .even?(sub1(x), even?, odd?)
in
  .even?(10, even?, odd?)
```

The output is unchanged (`1`) — 10 is even, just as 11000 was.

- [ ] **Step 2: Shrink `src/V4/Prog/fib`**

Change only the final line's argument, `30` → `10`. The file becomes:

```text
let
  fib = proc(x)
    let
      fibx = proc(f, x)
        if zero?(x)
        then 0
        else
          if zero?(-(x,1))
          then 1
          else
            +(.f(f,-(x,2)), .f(f,-(x,1)))
    in
      .fibx(fibx,x)
in
  .fib(10)
```

The output changes from `832040` to `55`.

- [ ] **Step 3: Run all six programs against all three targets**

```bash
for t in python java javascript; do
  echo "=== $t ==="
  for p in 11 11-nolet pp fact-acc oe fib; do
    printf '%-10s -> ' "$p"
    ( cd "src/V4/$t" && plcc-rep < "../Prog/$p" | tr '\n' ' ' )
    echo
  done
  ( cd "src/V4/$t" && rm -rf plcc-ng __pycache__ )
done
```

Expected, identically for all three targets:

| program    | expected output |
|------------|-----------------|
| `11`       | `11`            |
| `11-nolet` | `11`            |
| `pp`       | `6 6`  (two lines — the file holds two complete programs) |
| `fact-acc` | `120`           |
| `oe`       | `1`             |
| `fib`      | `55`            |

`pp` is the only one that yields two values: it contains two complete programs, so `plcc-rep` must read and evaluate both in one run. If it prints only `6`, or errors on the second program, that is a **finding, not a blocker** — record the exact output, file it with `bin/issues/new.bash plcc-rep-single-program-per-run chore` (set `**Target:** ourPLCC/plcc-ng`), and note in that issue that it also affects V6's `define`/`Eval` phase, which needs the same loop *plus* state persisting across it. Then continue; Task 8's `closure/` case has a documented fallback.

If any *other* program disagrees across targets, stop and report — the three semantic implementations must agree.

- [ ] **Step 4: Log the course-material impact**

Append to the `## V4` section of `dev-docs/course-material-impact.md`:

```markdown
- `Prog/oe` and `Prog/fib` are **shrunk** so every shipped example runs
  in all three targets. `oe`'s final call is now `.even?(10, even?, odd?)`
  instead of `.even?(11000, even?, odd?)` (output unchanged: `1`), and
  `fib` now computes `.fib(10)` instead of `.fib(30)`, so its output
  changes from `832040` to `55`. The original arguments exceeded the
  interpreter recursion depth available in Python (a ~1,000-frame default
  limit, several frames per language-level call) and made `fib` take
  minutes. Course material quoting either argument or `fib`'s result
  needs updating.
```

- [ ] **Step 5: Commit**

```bash
git add src/V4/Prog/oe src/V4/Prog/fib dev-docs/course-material-impact.md
git commit -m "$(cat <<'EOF'
fix(V4): shrink the oe and fib example programs so they run everywhere

oe recursed ~11000 language-level calls deep and fib computed fib(30);
neither survives Python's recursion limit / runtime budget. oe now calls
.even?(10, ...) (same output, 1) and fib computes .fib(10) (55, was
832040). All six Prog/ programs now agree across the three targets.

Refs #14
EOF
)"
```

---

## Task 8: Rewrite the V4 bats test and add four cases

**Files:**
- Modify: `src/V4/tests/proc/V4test.bats`
- Create: `src/V4/tests/seq/V4.input`, `src/V4/tests/seq/V4.expected`, `src/V4/tests/seq/V4test.bats`
- Create: `src/V4/tests/closure/V4.input`, `src/V4/tests/closure/V4.expected`, `src/V4/tests/closure/V4test.bats`
- Create: `src/V4/tests/recursion/V4.input`, `src/V4/tests/recursion/V4.expected`, `src/V4/tests/recursion/V4test.bats`
- Create: `src/V4/tests/multi-formals/V4.input`, `src/V4/tests/multi-formals/V4.expected`, `src/V4/tests/multi-formals/V4test.bats`

One case per V4 addition. `proc/` is the existing case, ported off `plccmk`/`rep`. `seq/` is hand-written because **no `Prog/` example uses `{e; e; e}`**. The other three are mined from the `Prog/` programs verified in Task 7. `Prog/11` and `Prog/11-nolet` are deliberately not promoted — their coverage is already carried by `proc/`.

- [ ] **Step 1: Capture the current "command not found" baseline**

The old `src/V4/tests/proc/V4test.bats` still calls `plccmk`/`rep`, so it currently fails as a `command not found`. Measure the count **now**, fresh — do not copy a number from an earlier phase's plan:

```bash
BASELINE_CNF=$(bin/test.bash 2>&1 | grep -c 'command not found'); echo "baseline=$BASELINE_CNF"
```

Note the number. After this task it must drop by exactly 1 (the single old V4 `@test` this replaces).

- [ ] **Step 2: Rewrite `src/V4/tests/proc/V4test.bats` for the three targets**

Replace the whole file with:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 proc (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/proc/V4.input)"
  expected_output=$(< "../tests/proc/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 proc (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/proc/V4.input)"
  expected_output=$(< "../tests/proc/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 proc (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/proc/V4.input)"
  expected_output=$(< "../tests/proc/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

The existing `src/V4/tests/proc/V4.input` (`.proc(x) +(x,3) (5)`) and `V4.expected` (`8`) are unchanged.

- [ ] **Step 3: Write the `seq` case**

`src/V4/tests/seq/V4.input`:
```
let x = 4 in {add1(x); sub1(x); *(x, x)}
```

`src/V4/tests/seq/V4.expected`:
```
16
```

Three sequenced expressions, of which only the last supplies the value — `add1(x)` and `sub1(x)` are evaluated and discarded.

`src/V4/tests/seq/V4test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 seq (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/seq/V4.input)"
  expected_output=$(< "../tests/seq/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 seq (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/seq/V4.input)"
  expected_output=$(< "../tests/seq/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 seq (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/seq/V4.input)"
  expected_output=$(< "../tests/seq/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 4: Write the `closure` case**

`src/V4/tests/closure/V4.input` — the contents of `src/V4/Prog/pp`, two complete programs: the first closes a `proc` body over a `let`, the second closes a `proc` over an enclosing `let`:

```
let
  p = proc(x)
        let
          y = 1
        in
          +(x,y)
in
  .p(.p(.p(3)))

let
  p = let
        y = 1
      in
        proc(x) +(x,y)
in
  .p(.p(.p(3)))
```

`src/V4/tests/closure/V4.expected`:
```
6
6
```

**Fallback:** if Task 7 Step 3 found that `plcc-rep` evaluates only the first program per run, use only the first program above as the input and `6` as the expected output, and add a comment line above the `@test` blocks pointing at the issue filed there.

`src/V4/tests/closure/V4test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 closure (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/closure/V4.input)"
  expected_output=$(< "../tests/closure/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 closure (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/closure/V4.input)"
  expected_output=$(< "../tests/closure/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 closure (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/closure/V4.input)"
  expected_output=$(< "../tests/closure/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 5: Write the `recursion` case**

`src/V4/tests/recursion/V4.input` — the contents of `src/V4/Prog/fact-acc`, recursion by self-application (V4 has no `letrec`; that arrives in V5):

```
let
  fact = proc(x)
    let
      factx = proc(f, x, acc)
        if zero?(x)
        then acc
        else .f(f, sub1(x), *(x, acc))
    in
      .factx(factx, x, 1)
  in
    .fact(5)
```

`src/V4/tests/recursion/V4.expected`:
```
120
```

`src/V4/tests/recursion/V4test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 recursion (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/recursion/V4.input)"
  expected_output=$(< "../tests/recursion/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 recursion (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/recursion/V4.input)"
  expected_output=$(< "../tests/recursion/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 recursion (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/recursion/V4.input)"
  expected_output=$(< "../tests/recursion/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 6: Write the `multi-formals` case**

`src/V4/tests/multi-formals/V4.input` — the contents of the shrunk `src/V4/Prog/oe`, exercising three-formal procedures, `?`-suffixed identifiers, and mutual recursion by parameter passing:

```
let
  even? = proc(x, even?, odd?) if zero?(x) then 1 else .odd?(sub1(x), even?, odd?)
  odd? = proc(x, even?, odd?) if zero?(x) then 0 else .even?(sub1(x), even?, odd?)
in
  .even?(10, even?, odd?)
```

`src/V4/tests/multi-formals/V4.expected`:
```
1
```

`src/V4/tests/multi-formals/V4test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V4 multi-formals (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/multi-formals/V4.input)"
  expected_output=$(< "../tests/multi-formals/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 multi-formals (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/multi-formals/V4.input)"
  expected_output=$(< "../tests/multi-formals/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V4 multi-formals (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/multi-formals/V4.input)"
  expected_output=$(< "../tests/multi-formals/V4.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 7: Run the V4 suite**

```bash
bats --recursive src/V4/tests
```

Expected: 15 tests, all passing (5 cases × 3 targets). If a Java case fails on a stale build, `rm -rf src/V4/*/plcc-ng` and rerun — `relocate` copies `src/` into a tmpdir, so committed build artifacts would travel with it.

- [ ] **Step 8: Run the full suite and confirm no regression**

```bash
bin/test.bash 2>&1 | tail -20
NEW_CNF=$(bin/test.bash 2>&1 | grep -c 'command not found'); echo "now=$NEW_CNF baseline=$BASELINE_CNF"
```

Expected: every V0, V1, V2, V3, and V4 test passes. `NEW_CNF` must be exactly `BASELINE_CNF - 1`. Every remaining failure must be a `command not found` from a language not yet migrated (V5, V6, SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ) — no other failure mode is acceptable. If a V0–V3 test that passed before now fails, stop and report: V4 must not have touched anything shared.

- [ ] **Step 9: Commit**

```bash
git add src/V4/tests
git commit -m "$(cat <<'EOF'
test(V4): port the proc test to plcc-rep and add four cases

Rewrites proc/ for the three targets and adds seq/ (hand-written -- no
Prog/ example uses the sequence operator), plus closure/, recursion/,
and multi-formals/ mined from Prog/pp, Prog/fact-acc, and Prog/oe.

Refs #14
EOF
)"
```

---

## Task 9: Close the V4 issue

- [ ] **Step 1: Re-verify before closing**

```bash
bats --recursive src/V4/tests
```

Expected: 15/15 passing. Do not close on a stale result from Task 8 — run it again.

- [ ] **Step 2: Close the issue**

Run: `bin/issues/close.bash 14`

Expected: prints `closed: dev-docs/issues/done/014-migrate-v4-to-plcc-ng.md` and updates `dev-docs/roadmap.md`.

- [ ] **Step 3: Verify bookkeeping consistency**

Run: `bin/issues/check.bash`

Expected: reports the roadmap consistent with `done/` and the open set. Issues #12 and #13 remain open (both deferred by design); any issue filed during Tasks 2 or 7 also remains open.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs(issues): close issue 14 (migrate V4 to plcc-ng), update roadmap"
```

---

## What's next

V4 confirms the closure/`ProcVal` pattern and `Formals:init` across all three targets, and — via the `closure/` case — gives an early read on whether `plcc-rep` evaluates multiple programs in one run, which V6's `define`/`Eval` phase depends on (V6 additionally needs `Program`-level state to *persist* across those parses). V5 is next (`V4 + letrec`), reusing `envVal` and every V4 class unchanged. Per the phase-by-phase discipline, V5 and V6 are deliberately **not** planned yet; return once V4 is merged.

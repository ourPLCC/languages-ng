# plcc-ng Phase 4 — TYPE0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port TYPE0 (`REF + type declarations, but no type checking`) to plcc-ng in Python, Java, and JavaScript.

**Architecture:** TYPE0 is REF plus a boolean type and a type-annotation syntax the evaluator never reads. `src/TYPE0/grammar.plcc` is REF's file with fourteen new tokens, thirteen new productions, two changed ones (`<Proc>` and `<Formals>` gain type annotations), and one typo fix. Each target's `spec.plcc` is a copy of REF's with a four-hunk delta: `Val` gains a throwing `boolVal()` and its `isTrue()` starts throwing, `IntVal` loses its `isTrue()` override, a free-standing `BoolVal` class is inserted after `IntVal`, `TrueExp`/`FalseExp` classes are added before `VarExp`, `ZeropPrim` switches to returning a `BoolVal`, and six relational `Prim` subclasses are appended. The shared `src/Env/envRef/<target>/env.plcc` is `%include`d **unchanged** — this phase touches nothing under `src/Env/`.

**Tech Stack:** plcc-ng (`plcc-rep`, `plcc-scan`, `plcc-parse`), bats, Python 3, Java, Node.js.

**Design of record:** [dev-docs/specs/2026-08-06-plcc-ng-type0-design.md](../specs/2026-08-06-plcc-ng-type0-design.md). Read it before Task 1.

## Global Constraints

- **Work in the existing worktree** `/workspaces/languages-ng/.claude/worktrees/type0`, branch `worktree-type0`. Do not create a new worktree. Do not `cd` to the main checkout.

- **Copy from `src/REF/`, never from `src/NEED/`.** TYPE0 forks REF *before* the NAME/NEED laziness branch: `src/TYPE0/code` uses eager `ValRef` operands with no `ThunkRef` and no `ValRORef`. NEED is the most recently ported language, which makes it the tempting starting point and the wrong one — copying it would silently give TYPE0 call-by-need semantics it does not have. Every "copy the spec" step below names `src/REF/` explicitly.

- **Run the full suite with plain `bin/test.bash`.** Everywhere this plan says "run the full suite", that means:

  ```bash
  cd /workspaces/languages-ng/.claude/worktrees/type0
  bin/test.bash > /tmp/type0-<task>.txt 2>&1; echo "EXIT=$?"
  ```

  Read the exit status, not just the counts. Issue [#31](../issues/031-suite-exhausts-disk-and-reports-spurious-failure.md) gave `bin/test.bash` a three-value contract: **0** every test passed, **1** the run completed with real test failures, **2** the harness itself did not finish. **Exit 2 means the numbers in the file are meaningless — do not count them, and do not report a result.** Throughout this phase the expected status is **1**, because `OBJ class` and `TYPE1 proc-types` stay red from start to finish; a `0` would mean something unexpected started passing and is just as much a reason to stop as a `2`.

  Then count with `grep -c '^ok '` and `grep -c '^not ok '`, and list the failures with `grep '^not ok '`.

  > **Amended 2026-08-06, pre-execution.** This constraint originally read "**`bin/test.bash` cannot complete on this container**" and prescribed a split-`TMPDIR` workaround (`TMPDIR=…/.bats-tmp bats --recursive src`, then a second default-`TMPDIR` pass over `bin`) with a manual `tail -1` check on each pass. Both halves of its premise have since expired. Issue #31 landed on `main`, so a dead run now exits 2 with a banner instead of reporting a spurious `not ok` against an innocent test — the manual `tail -1` check is now the harness's own job. And the accumulation that motivated it is gone: #31 also added `bin/bats-tmpdir.bash`, a `teardown` that empties each *passing* test's `BATS_TEST_TMPDIR`, so peak disk is now one test's footprint instead of the sum of all of them. Free space helps too (#31 was observed at ~230 MB free, where this container now has 25 GB), but the teardown is the mechanism — it keeps the peak flat as the suite grows, which free space alone does not. Measured 2026-08-06 after rebasing onto `main`: `bin/test.bash` runs unaided end to end, one invocation, exit 1, disk flat throughout. The workaround is removed rather than kept as a fallback, because its per-pass counts are a second set of numbers to keep in sync and its `.bats-tmp` directory is one more thing to leak.

- **Baseline, re-measured 2026-08-06 after the rebase onto `main`:** **141 tests, 138 passing, 3 failing**, exit status 1. The 3 failures are `OBJ class`, `TYPE0 boolean`, and `TYPE1 proc-types` — all `plccmk: command not found`.

  > **Amended 2026-08-06, pre-execution.** The baseline was originally **130 / 127 / 3**, measured before this branch was rebased onto `main`. The `src` half is unchanged at tests 1–120; all 11 new tests are in `bin/`, added by issue #31's own work (the `check_run_complete` cases, `clean.bash`, and the expanded `relocate_copy_tree` set). The failure set did not change. Every "run the full suite" gate in Tasks 2–5 shifted by the same +11 and has been restated; the deltas between them (−1 old TYPE0 test, +4 per target) are untouched.

- **No test that passes may start failing.** There is no retro-fix in this phase touching already-passing languages, so a `V`-prefixed, `SET`, `REF`, `NAME`, or `NEED` failure means a genuine regression, not expected churn.

- **Do not implement any type checking.** `TypeExp`, `PrimTypeExp`, `ProcTypeExp`, `PrimType`, `BoolPrimType`, `IntPrimType`, and `TypeExps` get **zero `%%%` blocks** in all three specs — no `eval`, no `toString`, no arity check, no well-formedness check, no placeholder comment block. `let f = proc(x:int):bool 5 in .f(3)` returning `5` is the feature. Adding any validation here starts building TYPE1 inside TYPE0 and erases the distinction the two languages exist to teach.

- **Do not reorder the lexical section.** plcc-ng resolves tokens by longest match, not declaration order, so declaring `IN 'in'` before `INT 'int'` and `EQUALS '='` before `RARROW '=>'` is safe — measured. Reordering to "fix" a non-problem leaves an unexplained diff against the pre-migration file.

- **`LetDecls:init` is inherited from REF and must be kept.** Pre-migration TYPE0 is the only file in the repository lacking the duplicate-LHS check, and that is drift, not design — TYPE1 keeps the same parse-time call verbatim. Copying REF's spec gets this right for free; the risk is "tidying" it out to match `src/TYPE0/code`. Leave it.

- **`apply` keeps its `Env` parameter** in every target — `apply(args, env)` / `apply(List<Ref> args, Env e)`. It is unread at runtime. It is the seam for a dynamic-scoping homework assignment. **Never remove it as dead code.** The pre-migration `src/TYPE0/val` declares `apply(List<Ref> refList)` with no `Env` and no arity check; that shape is not carried forward. Copying REF's spec gets this right too.

- **`boolVal()` is kept although nothing in TYPE0 calls it.** This is deliberate and departs from the Phase 3 lesson about trimming dead code. `src/TYPE1/prim:247-282` calls it from `AndPrim`, `OrPrim`, and `NotPrim` one phase out. Do not remove it.

- **Do not touch `src/Env/`.** SET ported `envRef`; REF, NAME, and NEED reused it unchanged; TYPE0 reuses it unchanged again. In particular, do **not** port anything out of `src/TYPE0/envRef` — that file is deleted in Task 5, not migrated. It already *is* the canonical `void checkDuplicates` shape.

- **Grammar conventions, unchanged since V0:** identifier token is `SYMBOL` (never `VAR`); nonterminals are PascalCase; multi-capture alt-names are camelCase (`<Exp:testExp>`), not the obsolete lowercase workaround.

- **Input and expected files carry no trailing newline** — verified against all four of REF's. Use `printf`, never `echo` or a bare heredoc. This is cosmetic (`$(< file)` and `$(...)` both strip trailing newlines) but matches the convention.

- **Course-material impact entries go in the same commit as the change they describe**, under a `## TYPE0` heading in [dev-docs/course-material-impact.md](../course-material-impact.md), added after the existing `## NEED` section. Never batch them.

- **Every `.bats` file loads both helpers**, in this order, as its only two `load` lines:

  ```bash
  load '../../../../bin/relocate.bash'
  load '../../../../bin/bats-tmpdir.bash'
  ```

  All 42 existing `src/**/*test.bats` files do. `bats-tmpdir.bash` is the `teardown` that empties a passing test's `BATS_TEST_TMPDIR`; a file that omits it silently reintroduces the per-test accumulation of issue #31 for its own tests, and nothing fails to announce it — the suite just gets heavier. Only Task 2 writes these headers; Tasks 3 and 4 append `@test` blocks to files that already have them, and must not add a second `load` pair.

  > **Amended 2026-08-06, pre-execution.** This constraint is new. The four `.bats` templates in Task 2 originally carried only the `relocate.bash` line, which was *correct when the plan was written*: at the plan's base commit `b1d87d9`, `bin/bats-tmpdir.bash` did not exist and REF's own test files loaded `relocate.bash` alone. Issue #31's commit `420f558` added the helper and retrofitted the `load` line into all 42 existing test files. The plan's four new files would have been the only ones in the repository without it. Same rebase drift as the count staleness above, in a place a grep for `TMPDIR` and test counts did not reach.

- **Never assign issue numbers by hand.** Use `bin/issues/new.bash` and `bin/issues/close.bash`.

- Every target's `spec.plcc` writes build artifacts to a `plcc-ng/` subdirectory; `.gitignore` already covers `plcc-ng/`, `__pycache__/`, and `*.class`. Never commit them.

---

### Task 1: File the TYPE0 issue and confirm the baseline

Pure bookkeeping plus the gate every later task's expected counts depend on.

**Files:**
- Create: `dev-docs/issues/0NN-migrate-type0-to-plcc-ng.md` (number assigned by the script)
- Modify: `dev-docs/roadmap.md`
- Test: the existing suite, via `bin/test.bash`

**Interfaces:**
- Consumes: nothing.
- Produces: the issue number `NN`, referenced by Task 5's `bin/issues/close.bash <NN>`.

- [ ] **Step 1: File the issue**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type0
bin/issues/new.bash migrate-type0-to-plcc-ng feat
```

Note the number it prints — that is `NN` for the rest of this plan. Fill in the issue's `## Description` with the TYPE0 port: a grammar delta of fourteen tokens and thirteen productions plus the `BoolPrimtype` → `BoolPrimType` typo fix, a four-hunk semantic delta over REF introducing `BoolVal` and strict booleans, the added `LetDecls:init`, three targets, four test cases, and no `Prog/` directory. Add a `## Notes` section pointing at the design doc, recording that the type nonterminals deliberately carry no semantics, and listing what is out of scope (TYPE1, OBJ; any type checking; error-path tests; issues #16, #19, #22, #31). Leave `target:` at its default (`this repo`) — this is our own work, not a plcc-ng defect.

- [ ] **Step 2: Add the roadmap entry**

Add an entry to the **Open Issues** section of `dev-docs/roadmap.md`, under a `### Feat` heading. That heading does **not** exist today — the roadmap's contract is that a type group exists only while it has open entries, and `close.bash` removed the last one at the end of NEED's phase. Create it, placed alphabetically among the existing `### Chore`, `### Docs`, and `### Test` headings (so: Chore, Docs, **Feat**, Test). Use this exact two-line format, which the scripts parse:

```markdown
- **[#0NN](issues/0NN-migrate-type0-to-plcc-ng.md) — migrate-type0-to-plcc-ng**
  Port TYPE0 (REF + type declarations, no type checking) to plcc-ng in Python, Java, and JavaScript: a `BoolVal` with `true`/`false` literals and six relational prims, strict booleans in `if`, a type-annotation grammar whose classes carry no semantics, and four value-only test cases.
```

- [ ] **Step 3: Verify the issue bookkeeping is consistent**

Run: `bin/issues/check.bash`
Expected: exit status 0, no output about drift. If it complains, fix the roadmap entry's format before continuing — `close.bash` in Task 5 parses the same shape.

- [ ] **Step 4: Capture the baseline**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type0
bin/test.bash > /tmp/type0-base.txt 2>&1; echo "EXIT=$?"   # expect EXIT=1
grep -c '^ok ' /tmp/type0-base.txt      # expect 138
grep -c '^not ok ' /tmp/type0-base.txt  # expect 3
grep '^not ok ' /tmp/type0-base.txt
```

Expected: **141 tests total, 138 passing, 3 failing** — `OBJ class`, `TYPE0 boolean`, `TYPE1 proc-types`, all `plccmk: command not found`.

On `EXIT=2` the harness died and the counts in the file mean nothing; investigate (`df -h /` first) and rerun rather than reporting them. On `EXIT=0` something that was failing now passes — also stop. If the failure set differs from the three above, **stop**: the plan's counts are stale and every later task's expectation is wrong.

> **Amended 2026-08-06, pre-execution** — restated for `bin/test.bash` and the post-rebase baseline. See the two amendment notes under Global Constraints.

- [ ] **Step 5: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): file issue NN - migrate TYPE0 to plcc-ng

Refs #NN"
```

Replace `NN` with the number from Step 1.

---

### Task 2: Grammar + Python target + all four test cases

Delivers `src/TYPE0/grammar.plcc`, the Python `spec.plcc`, and all four test cases with their **Python** `@test` blocks. Tasks 3 and 4 append the Java and JavaScript blocks to the same `.bats` files.

**Files:**
- Create: `src/TYPE0/grammar.plcc`
- Create: `src/TYPE0/python/spec.plcc`
- Rename: `src/TYPE0/tests/boolean/` → `src/TYPE0/tests/relational-prims/`, then replace its `TYPE0.input`, `TYPE0.expected`, and `TYPE0test.bats`
- Create: `src/TYPE0/tests/boolean-literals/{TYPE0.input,TYPE0.expected,TYPE0test.bats}`
- Create: `src/TYPE0/tests/type-annotations-ignored/{TYPE0.input,TYPE0.expected,TYPE0test.bats}`
- Create: `src/TYPE0/tests/declared-type-not-checked/{TYPE0.input,TYPE0.expected,TYPE0test.bats}`
- Modify: `dev-docs/course-material-impact.md`
- Test: `bats --recursive src/TYPE0/tests`, then the full suite

**Interfaces:**
- Consumes: `NN` from Task 1 (not used until Task 5).
- Produces:
  - `src/TYPE0/grammar.plcc`, `%include`d by all three targets, defining the fourteen new tokens, the `<TypeExp>`/`<PrimType>`/`<TypeExps>` productions, `<Exp:TrueExp>`/`<Exp:FalseExp>`, and the six relational `<Prim>` alternatives.
  - `src/TYPE0/python/spec.plcc` defining a free-standing `BoolVal(val)` subclass of `Val` with `isTrue()`, `boolVal()`, and `__str__()`; a `Val.boolVal()` that raises; a `Val.isTrue()` that raises; `TrueExp.eval(env) -> BoolVal` and `FalseExp.eval(env) -> BoolVal`; a `ZeropPrim.apply(args) -> BoolVal`; and six relational prims `LTPrim`, `LEPrim`, `GTPrim`, `GEPrim`, `EQPrim`, `NEPrim`, each with `apply(args) -> BoolVal`.
  - The four test case directories, which Tasks 3 and 4 append `@test` blocks to.

- [ ] **Step 1: Create the grammar**

Write `src/TYPE0/grammar.plcc` with exactly this content. It is REF's grammar with the delta already applied, and it has been validated end-to-end against `plcc-scan`, `plcc-parse`, and `plcc-rep` in all three targets:

```
# Language TYPE0
#   Language REF with type declarations (but no type checking)
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
token LTP '<\?'
token LEP '<=\?'
token GTP '>\?'
token GEP '>=\?'
token EQP '=\?'
token NEP '<>\?'
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
token LBRACK '\['
token RBRACK '\]'
token COLON ':'
token RARROW '=>'
token BOOL 'bool'
token INT  'int'
token TRUE 'true'
token FALSE 'false'
token SEMI ';'
token SYMBOL '[A-Za-z][\w?]*'
%
<Program:Define>        ::= DEFINE <SYMBOL> EQUALS <Exp>
<Program:Eval>          ::= <Exp>
<TypeExp:PrimTypeExp>   ::= <PrimType>
<TypeExp:ProcTypeExp>   ::= LBRACK <TypeExps> RARROW <TypeExp> RBRACK
<PrimType:BoolPrimType> ::= BOOL
<PrimType:IntPrimType>  ::= INT
<TypeExps>              **= <TypeExp> +COMMA
<Exp:LitExp>            ::= <LIT>
<Exp:TrueExp>           ::= TRUE
<Exp:FalseExp>          ::= FALSE
<Exp:VarExp>            ::= <SYMBOL>
<Exp:IfExp>             ::= IF <Exp:testExp> THEN <Exp:trueExp> ELSE <Exp:falseExp>
<Exp:PrimappExp>        ::= <Prim> LPAREN <Rands> RPAREN
<Exp:LetExp>            ::= LET <LetDecls> IN <Exp>
<Exp:LetrecExp>         ::= LETREC <LetDecls> IN <Exp>
<Exp:ProcExp>           ::= <Proc>
<Exp:AppExp>            ::= DOT <Exp> LPAREN <Rands> RPAREN
<Exp:SeqExp>            ::= LBRACE <Exp> <SeqExps> RBRACE
<Exp:SetExp>            ::= SET <SYMBOL> EQUALS <Exp>
<SeqExps>               **= SEMI <Exp>
<Proc>                  ::= PROC LPAREN <Formals> RPAREN COLON <TypeExp> <Exp>
<Formals>               **= <SYMBOL> COLON <TypeExp> +COMMA
<LetDecls>              **= <SYMBOL> EQUALS <Exp>
<Rands>                 **= <Exp> +COMMA
<Prim:AddPrim>          ::= ADDOP
<Prim:SubPrim>          ::= SUBOP
<Prim:MulPrim>          ::= MULOP
<Prim:DivPrim>          ::= DIVOP
<Prim:Add1Prim>         ::= ADD1OP
<Prim:Sub1Prim>         ::= SUB1OP
<Prim:ZeropPrim>        ::= ZEROP
<Prim:LTPrim>           ::= LTP
<Prim:LEPrim>           ::= LEP
<Prim:GTPrim>           ::= GTP
<Prim:GEPrim>           ::= GEP
<Prim:EQPrim>           ::= EQP
<Prim:NEPrim>           ::= NEP
```

Three things a reader may want to "correct" and must not:

- `token IN 'in'` precedes `token INT 'int'`, and `token EQUALS '='` precedes `token RARROW '=>'`. Longest match makes both safe. Leave the order alone.
- `<PrimType:BoolPrimType>` fixes the pre-migration file's `BoolPrimtype` typo, matching `IntPrimType` and TYPE1's spelling. Keep the fix.
- There is **no** `%include` tail. Old-PLCC grammars ended with `%include code` / `%include prim` / etc.; plcc-ng grammars end after the syntactic section, and each target's `spec.plcc` supplies the semantics.

- [ ] **Step 2: Verify the grammar parses**

```bash
rm -rf /tmp/t0-check && mkdir -p /tmp/t0-check
cp src/TYPE0/grammar.plcc /tmp/t0-check/spec.plcc
( cd /tmp/t0-check && echo 'let f = proc(x:int, g:[int,int=>bool]):bool .g(x,x) in .f(3, proc(a:int,b:int):bool <=?(a,b))' \
    | plcc-parse )
```

A grammar file is a valid `spec.plcc` on its own — `plcc-scan` and `plcc-parse` need only the lexical and syntactic sections, and this one deliberately ends without a trailing `%`. Copying it to a scratch directory rather than passing `plcc-parse -s <path>` avoids that flag's documented stickiness ("Once set, remembered for subsequent commands until changed"), which would otherwise be one more piece of hidden state to reason about before Step 4's smoke test.

Expected: a parse tree containing `ProcTypeExp`, a `TypeExps` with two `IntPrimType` children, and a `Formals` listing `SYMBOL 'x'` and `SYMBOL 'g'`. An `LL1` or `no production for` error means one of the type productions was mistyped — compare against Step 1 character by character rather than trying to refactor the grammar; it is known LL(1)-clean as written.

Then confirm the token ordering really is longest-match on this machine:

```bash
( cd /tmp/t0-check && printf 'int in = => <? <=?\n' | plcc-scan )
```

Expected exactly: `INT 'int'`, `IN 'in'`, `EQUALS '='`, `RARROW '=>'`, `LTP '<?'`, `LEP '<=?'`. If `int` scans as `IN` followed by a `SYMBOL`, plcc-ng's scanner has changed behavior since this plan was written — **stop and report it**, do not silently reorder the tokens.

- [ ] **Step 3: Create the Python spec from REF's**

```bash
mkdir -p src/TYPE0/python
cp src/REF/python/spec.plcc src/TYPE0/python/spec.plcc
```

The `%include ../grammar.plcc` and `%include ../../Env/envRef/python/env.plcc` lines at the top are already correct and need no edit — the relative paths resolve the same from `src/TYPE0/python/` as from `src/REF/python/`.

Now make exactly four edits.

**(a) In the `Val` block**, change `isTrue` to raise and add `boolVal`:

```python
    def isTrue(self):
        raise LanguageError("boolean expression expected")

    def intVal(self):
        raise LanguageError(f"{self}: not an Int")

    def boolVal(self):
        raise LanguageError(f"{self}: not a Bool")
```

`LanguageError` is already imported in this block; no import change.

**(b) In the `IntVal` block**, delete its `isTrue` override entirely, then insert a whole new `BoolVal` block after `IntVal`'s closing `%%%`. `IntVal` ends at `__str__`, and the new block follows:

```python
IntVal
%%%
from Val import Val


class IntVal(Val):

    def __init__(self, val):
        self.val = int(val)

    def intVal(self):
        return self

    def __str__(self):
        return str(self.val)
%%%

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

**`BoolVal.__str__` is the single most error-prone line in this phase.** Python's `str(True)` is `True` — capitalised — while Java and JavaScript both produce lowercase natively. The explicit conditional is load-bearing: without it every one of the four test cases fails in Python only, on output text rather than on logic, and the Java and JavaScript tasks will look correct while the suite stays red.

**(c) Insert `TrueExp` and `FalseExp` before the `VarExp` block**, after `LitExp`'s closing `%%%`:

```python
TrueExp:import
%%%
from BoolVal import BoolVal
%%%

TrueExp
%%%
def eval(self, env):
    return BoolVal(True)

def __str__(self):
    return "true"
%%%

FalseExp:import
%%%
from BoolVal import BoolVal
%%%

FalseExp
%%%
def eval(self, env):
    return BoolVal(False)

def __str__(self):
    return "false"
%%%
```

**(d) Change `ZeropPrim` and append the six relational prims.** In `ZeropPrim:import`, change `from IntVal import IntVal` to `from BoolVal import BoolVal`; in `ZeropPrim`, change the return to `return BoolVal(i0 == 0)`. Then append the following at the end of the file, after `ZeropPrim`'s closing `%%%`:

```python
LTPrim:import
%%%
from BoolVal import BoolVal
from runtime.base import LanguageError
%%%

LTPrim
%%%
def __str__(self):
    return "<?"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return BoolVal(i0 < i1)
%%%

LEPrim:import
%%%
from BoolVal import BoolVal
from runtime.base import LanguageError
%%%

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

GTPrim:import
%%%
from BoolVal import BoolVal
from runtime.base import LanguageError
%%%

GTPrim
%%%
def __str__(self):
    return ">?"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return BoolVal(i0 > i1)
%%%

GEPrim:import
%%%
from BoolVal import BoolVal
from runtime.base import LanguageError
%%%

GEPrim
%%%
def __str__(self):
    return ">=?"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return BoolVal(i0 >= i1)
%%%

EQPrim:import
%%%
from BoolVal import BoolVal
from runtime.base import LanguageError
%%%

EQPrim
%%%
def __str__(self):
    return "=?"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return BoolVal(i0 == i1)
%%%

NEPrim:import
%%%
from BoolVal import BoolVal
from runtime.base import LanguageError
%%%

NEPrim
%%%
def __str__(self):
    return "<>?"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return BoolVal(i0 != i1)
%%%
```

Every one of these eight new classes needs its own `:import` block. plcc-ng gives each generated class file only its own imports — there is no file-wide import — so omitting one produces `NameError: name 'BoolVal' is not defined` in that single file, which shows up as one failing operator and nothing else.

Verify the whole edit is exactly these four changes and nothing else:

```bash
diff src/REF/python/spec.plcc src/TYPE0/python/spec.plcc
```

Expected: hunks for the `Val` `isTrue`/`boolVal` change, the `IntVal` `isTrue` removal plus inserted `BoolVal` block, the inserted `TrueExp`/`FalseExp` blocks, the `ZeropPrim` import and return change, and the six appended prims. **No hunk should touch `LetDecls:init`, `Formals:init`, `ProcVal.apply`, `Exp.evalRef`, or the `%include` lines.** Anything else is an accident; revert it.

- [ ] **Step 4: Smoke-test the Python target**

```bash
( cd src/TYPE0/python && printf '<=?(3,3)\ntrue\nzero?(0)\nlet f = proc(x:int):bool 5 in .f(3)\n' | plcc-rep )
```

Expected exactly: `true`, `true`, `true`, `5`.

If booleans print as `True`/`False`, edit (b)'s `__str__` conditional is missing. If `zero?(0)` prints `1`, edit (d)'s `ZeropPrim` change did not take. If `let f = …` errors instead of printing `5`, something added type checking that must not be there.

- [ ] **Step 5: Rename the old test directory and write its new files**

```bash
git mv src/TYPE0/tests/boolean src/TYPE0/tests/relational-prims
```

All three files in the renamed directory are then **overwritten in place** — do not try to `git mv` the old `TYPE0test.bats` out of the repository, which fails because the destination is not under version control. Its contents are replaced wholesale rather than edited: it uses the old `plccmk -c grammar` / `rep -n` invocation that no migrated language uses.

Write the widened input and its expected output:

```bash
printf '<?(1,2)\n<=?(3,3)\n>?(1,2)\n>=?(1,2)\n=?(2,2)\n<>?(1,2)\nzero?(0)\nzero?(1)' \
    > src/TYPE0/tests/relational-prims/TYPE0.input
printf 'true\ntrue\nfalse\nfalse\ntrue\ntrue\ntrue\nfalse' \
    > src/TYPE0/tests/relational-prims/TYPE0.expected
```

Then write `src/TYPE0/tests/relational-prims/TYPE0test.bats` with the Python block only — Tasks 3 and 4 append the other two:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 relational-prims (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/relational-prims/TYPE0.input)"
  expected_output=$(< "../tests/relational-prims/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 6: Write the other three test cases**

```bash
mkdir -p src/TYPE0/tests/boolean-literals \
         src/TYPE0/tests/type-annotations-ignored \
         src/TYPE0/tests/declared-type-not-checked

printf 'true\nfalse\nif true then 1 else 2\nif false then 1 else 2' \
    > src/TYPE0/tests/boolean-literals/TYPE0.input
printf 'true\nfalse\n1\n2' \
    > src/TYPE0/tests/boolean-literals/TYPE0.expected

printf 'let\n    f = proc(x:int, g:[int,int=>bool]):bool .g(x,x)\nin\n    .f(3, proc(a:int,b:int):bool <=?(a,b))\nlet\n    p = proc():[=>int] proc():int 7\nin\n    .p()' \
    > src/TYPE0/tests/type-annotations-ignored/TYPE0.input
printf 'true\nproc' \
    > src/TYPE0/tests/type-annotations-ignored/TYPE0.expected

printf 'let f = proc(x:int):bool 5 in .f(3)\nlet g = proc(x:int):int true in .g(3)' \
    > src/TYPE0/tests/declared-type-not-checked/TYPE0.input
printf '5\ntrue' \
    > src/TYPE0/tests/declared-type-not-checked/TYPE0.expected
```

`type-annotations-ignored` is the only coverage of `ProcTypeExp`, `TypeExps`, the empty-`TypeExps` case (`[=>int]`), empty `<Formals>`, and the `Formals` `typeExpList` — none of which any semantic block reads, which is exactly why they need a test proving they parse. Its second program returns a closure, so the expected value is the literal string `proc` from `ProcVal.__str__`.

Now write the three `TYPE0test.bats` files, Python block only. `src/TYPE0/tests/boolean-literals/TYPE0test.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 boolean-literals (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/boolean-literals/TYPE0.input)"
  expected_output=$(< "../tests/boolean-literals/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

`src/TYPE0/tests/type-annotations-ignored/TYPE0test.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 type-annotations-ignored (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/type-annotations-ignored/TYPE0.input)"
  expected_output=$(< "../tests/type-annotations-ignored/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

`src/TYPE0/tests/declared-type-not-checked/TYPE0test.bats`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE0 declared-type-not-checked (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/declared-type-not-checked/TYPE0.input)"
  expected_output=$(< "../tests/declared-type-not-checked/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 7: Run the TYPE0 tests**

Run: `bats --recursive src/TYPE0/tests`
Expected: **4 tests, 4 passing.**

If `type-annotations-ignored` fails to parse, a type production in Step 1 is wrong. If `declared-type-not-checked` errors instead of printing `5`, type checking has crept in. If several cases disagree only on the words `true`/`false` versus `True`/`False`, it is edit (b)'s `__str__`.

- [ ] **Step 8: Sanity-check the REF contrast**

The point of TYPE0 is that it disagrees with REF. Confirm it does, rather than assuming. Each `cd` is wrapped in a subshell so a failing `plcc-rep` cannot leave you in the wrong directory:

```bash
( cd src/REF/python   && echo 'if 1 then 1 else 2' | plcc-rep )
( cd src/TYPE0/python && echo 'if 1 then 1 else 2' | plcc-rep )
( cd src/REF/python   && echo 'zero?(0)' | plcc-rep )
( cd src/TYPE0/python && echo 'zero?(0)' | plcc-rep )
```

Expected: `1` from REF, `boolean expression expected` from TYPE0; then `1` from REF, `true` from TYPE0. Matching answers mean edits (a) and (d) did not take.

Then confirm the inherited `LetDecls:init` survived the copy:

```bash
( cd src/TYPE0/python && echo 'let x = 1 x = 2 in x' | plcc-rep )
```

Expected: `duplicate ID x in let/letrec LHS identifiers`. A bare `1` means the check was removed to match the pre-migration file — put it back.

- [ ] **Step 9: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type0-task2.txt`. Confirm `EXIT=1`, then count.

Expected: **144 tests, 142 passing, 2 failing.** That is the baseline's 141, minus TYPE0's 1 old test, plus 4 new Python tests. The 2 remaining failures are `OBJ class` and `TYPE1 proc-types` — both `plccmk: command not found`. Any `V`-prefixed, `SET`, `REF`, `NAME`, or `NEED` failure is a regression; stop and fix it.

> **Amended 2026-08-06, pre-execution** — was 133 / 131 / 2 against the pre-rebase baseline of 130.

- [ ] **Step 10: Add the course-material impact entries**

Append a `## TYPE0` section to `dev-docs/course-material-impact.md`, after the existing `## NEED` section, matching the prose style of the sections already there. Cover, one bullet each:

- The `VAR` → `SYMBOL` token rename and the `var` → `symbol` field rename, the standing convention since V0 — `VarExp` reads `env.applyEnv(self.symbol.lexeme)`.
- `$run()` → `_run()`, which **returns** its output string rather than printing it.
- The `BoolPrimtype` → `BoolPrimType` grammar-symbol rename, bringing TYPE0 in line with its own `IntPrimType` and with TYPE1's spelling.
- The new `LetDecls:init` duplicate check, absent from pre-migration TYPE0 and present in every other language in the repository. Give the observable: `let x = 1 x = 2 in x` now raises `duplicate ID x in let/letrec LHS identifiers` where it returned `1`. Note that TYPE1 does *not* subsume this into type checking — it keeps the same parse-time call — so TYPE0 was simply the odd one out.
- `apply` taking a `List<Ref>` **and** an `Env` (the dynamic-scoping homework seam), where pre-migration TYPE0's `apply(List<Ref>)` had no `Env`, and `ProcVal.apply` now raising `formals/args number mismatch` on an arity error, which pre-migration TYPE0 did not check.
- `Val.toArray` dropped, as in every migrated language before this one.
- The `tests/boolean/` → `tests/relational-prims/` rename and its widening from a single `<=?(3,3)` program to all six relational operators plus `zero?` both ways.
- **The REF↔TYPE0 contrast**, which is lecture material in its own right. Two rows carry the weight: `if` now requires a genuine boolean, so `if 1 then 1 else 2` raises `boolean expression expected` where REF returns `1`; and `zero?` returns `true`/`false` where REF returns `1`/`0`. Those are the two places a REF program stops behaving the same under TYPE0. Add that TYPE0's type annotations are parsed and then ignored — `proc(x:int):bool 5` returns `5` — which is the distinction TYPE1 exists to remove.

- [ ] **Step 11: Commit**

```bash
git add src/TYPE0/grammar.plcc src/TYPE0/python src/TYPE0/tests dev-docs/course-material-impact.md
git commit -m "feat(TYPE0): port grammar and Python target to plcc-ng

Refs #NN"
```

Replace `NN` with the number from Task 1.

---

### Task 3: Java target

Adds `src/TYPE0/java/spec.plcc` and a Java `@test` block to each of the four `.bats` files.

**Files:**
- Create: `src/TYPE0/java/spec.plcc`
- Modify: `src/TYPE0/tests/relational-prims/TYPE0test.bats`
- Modify: `src/TYPE0/tests/boolean-literals/TYPE0test.bats`
- Modify: `src/TYPE0/tests/type-annotations-ignored/TYPE0test.bats`
- Modify: `src/TYPE0/tests/declared-type-not-checked/TYPE0test.bats`
- Test: `bats --recursive src/TYPE0/tests`, then the full suite

**Interfaces:**
- Consumes: `src/TYPE0/grammar.plcc` and the four test case directories from Task 2. The `TYPE0.input`/`TYPE0.expected` files are shared and **must not change** — all three targets produce identical output.
- Produces: `src/TYPE0/java/spec.plcc` defining `public class BoolVal extends Val` with `public boolean val`, `isTrue()`, `boolVal()`, `toString()`; `Val.boolVal()` and `Val.isTrue()` that throw; `TrueExp.eval(Env)` / `FalseExp.eval(Env)`; and six relational prims each with `public Val apply(Val [] va)`.

- [ ] **Step 1: Create the Java spec from REF's**

```bash
mkdir -p src/TYPE0/java
cp src/REF/java/spec.plcc src/TYPE0/java/spec.plcc
```

The `%include ../grammar.plcc` and `%include ../../Env/envRef/java/env.plcc` lines need no edit.

**Java needs no `:import` block anywhere in this delta** — its generated classes are same-directory and package-less, so they reference each other with no import statement at all. Do not add `:import` blocks by analogy with the Python task; they are unnecessary and unlike anything in REF's Java spec, which carries only two, both for `java.util`.

Make exactly four edits.

**(a) In the `Val` block**, change `isTrue` to throw and add `boolVal`:

```java
    public boolean isTrue() {
        throw new LanguageError("boolean expression expected");
    }

    public IntVal intVal() {
        throw new LanguageError(this + ": not an Int");
    }

    public BoolVal boolVal() {
        throw new LanguageError(this + ": not a Bool");
    }
```

`LanguageError` is already imported in this block.

**(b) In the `IntVal` block**, delete its `isTrue` override, then add a `BoolVal` block after `IntVal`'s closing `%%%`:

```java
BoolVal
%%%
public class BoolVal extends Val {

    public boolean val;

    public BoolVal(boolean b) {
        val = b;
    }

    public boolean isTrue() {
        return val;
    }

    public BoolVal boolVal() {
        return this;
    }

    public String toString() {
        return "" + val;
    }
}
%%%
```

`"" + val` on a Java `boolean` yields lowercase `true`/`false`, which is what the shared expected files require. No conditional is needed here — unlike Python.

**(c) Insert `TrueExp` and `FalseExp` before the `VarExp` block**:

```java
TrueExp
%%%
public Val eval(Env env) {
    return new BoolVal(true);
}

public String toString() {
    return "true";
}
%%%

FalseExp
%%%
public Val eval(Env env) {
    return new BoolVal(false);
}

public String toString() {
    return "false";
}
%%%
```

**(d) Change `ZeropPrim`'s return to `return new BoolVal(i0 == 0);`**, then append the six relational prims at the end of the file:

```java
LTPrim
%%%
public String toString() {
    return "<?";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new BoolVal(i0 < i1);
}
%%%

LEPrim
%%%
public String toString() {
    return "<=?";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new BoolVal(i0 <= i1);
}
%%%

GTPrim
%%%
public String toString() {
    return ">?";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new BoolVal(i0 > i1);
}
%%%

GEPrim
%%%
public String toString() {
    return ">=?";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new BoolVal(i0 >= i1);
}
%%%

EQPrim
%%%
public String toString() {
    return "=?";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new BoolVal(i0 == i1);
}
%%%

NEPrim
%%%
public String toString() {
    return "<>?";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new BoolVal(i0 != i1);
}
%%%
```

**`apply` takes `Val [] va`, not a `List`.** REF's Java prims use the array form (`va.length`, `va[0]`) while its Python and JavaScript prims use lists. Transliterating Task 2's Python signature here gives a compile error against the generated `Prim` base class.

Verify:

```bash
diff src/REF/java/spec.plcc src/TYPE0/java/spec.plcc
```

Expected: the same four hunk groups as Python's, with no `:import` blocks anywhere and nothing touching `LetDecls:init`, `Formals:init`, `ProcVal.apply`, or the `%include` lines.

- [ ] **Step 2: Smoke-test the Java target**

```bash
( cd src/TYPE0/java && printf '<=?(3,3)\ntrue\nzero?(0)\nlet f = proc(x:int):bool 5 in .f(3)\n' | plcc-rep )
```

Expected exactly: `true`, `true`, `true`, `5`. A `cannot find symbol: class BoolVal` means edit (b)'s block is missing or misnamed.

- [ ] **Step 3: Append the Java `@test` blocks**

Append to `src/TYPE0/tests/relational-prims/TYPE0test.bats`:

```bash
@test "TYPE0 relational-prims (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/relational-prims/TYPE0.input)"
  expected_output=$(< "../tests/relational-prims/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append to `src/TYPE0/tests/boolean-literals/TYPE0test.bats`:

```bash
@test "TYPE0 boolean-literals (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/boolean-literals/TYPE0.input)"
  expected_output=$(< "../tests/boolean-literals/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append to `src/TYPE0/tests/type-annotations-ignored/TYPE0test.bats`:

```bash
@test "TYPE0 type-annotations-ignored (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/type-annotations-ignored/TYPE0.input)"
  expected_output=$(< "../tests/type-annotations-ignored/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append to `src/TYPE0/tests/declared-type-not-checked/TYPE0test.bats`:

```bash
@test "TYPE0 declared-type-not-checked (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/declared-type-not-checked/TYPE0.input)"
  expected_output=$(< "../tests/declared-type-not-checked/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Do not modify any `TYPE0.input` or `TYPE0.expected` file. If Java disagrees with an expected value, the Java spec is wrong, not the expectation — all three targets were measured producing identical output.

- [ ] **Step 4: Run the TYPE0 tests**

Run: `bats --recursive src/TYPE0/tests`
Expected: **8 tests, 8 passing** — four Python, four Java.

- [ ] **Step 5: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type0-task3.txt`. Confirm `EXIT=1`, then count.

Expected: **148 tests, 146 passing, 2 failing.** The 2 failures remain `OBJ class` and `TYPE1 proc-types`.

> **Amended 2026-08-06, pre-execution** — was 137 / 135 / 2 against the pre-rebase baseline of 130.

- [ ] **Step 6: Commit**

```bash
git add src/TYPE0/java src/TYPE0/tests
git commit -m "feat(TYPE0): port Java target to plcc-ng

Refs #NN"
```

---

### Task 4: JavaScript target

Adds `src/TYPE0/javascript/spec.plcc` and a JavaScript `@test` block to each of the four `.bats` files. This completes the port.

**Files:**
- Create: `src/TYPE0/javascript/spec.plcc`
- Modify: all four `src/TYPE0/tests/*/TYPE0test.bats`
- Test: `bats --recursive src/TYPE0/tests`, then the full suite

**Interfaces:**
- Consumes: `src/TYPE0/grammar.plcc` and the four test case directories. The shared `TYPE0.input`/`TYPE0.expected` files **must not change**.
- Produces: `src/TYPE0/javascript/spec.plcc` defining `class BoolVal extends Val` exported via `module.exports = { BoolVal };`, with `isTrue()`, `boolVal()`, `toString()`; `Val.boolVal()` and `Val.isTrue()` that throw; `TrueExp.eval(env)` / `FalseExp.eval(env)`; and six relational prims each with `apply(args)`.

- [ ] **Step 1: Create the JavaScript spec from REF's**

```bash
mkdir -p src/TYPE0/javascript
cp src/REF/javascript/spec.plcc src/TYPE0/javascript/spec.plcc
```

Two JavaScript-specific rules govern every `:import` decision below:

- **Free-standing classes get no auto-injected requires.** `BoolVal` corresponds to no grammar nonterminal, so its block must require what it uses (`Val`) and end with its own `module.exports`.
- **Grammar-derived classes already have `const { Node, Token, LanguageError } = require('./runtime/base');` injected.** `TrueExp`, `FalseExp`, and all six relational prims are grammar-derived, so their `:import` blocks name **only `BoolVal`**. Adding `LanguageError` redeclares an existing binding and fails at load with `Identifier 'LanguageError' has already been declared` — a whole-file failure, not a single wrong answer.

Make exactly four edits.

**(a) In the `Val` block**, change `isTrue` to throw and add `boolVal`:

```javascript
    isTrue() {
        throw new LanguageError("boolean expression expected");
    }

    intVal() {
        throw new LanguageError(`${this}: not an Int`);
    }

    boolVal() {
        throw new LanguageError(`${this}: not a Bool`);
    }
```

**(b) In the `IntVal` block**, delete its `isTrue` override — taking care to leave `module.exports = { IntVal };` in place, since it sits directly after the method being removed — then add a `BoolVal` block after `IntVal`'s closing `%%%`:

```javascript
BoolVal
%%%
const { Val } = require('./Val');

class BoolVal extends Val {

    constructor(val) {
        super();
        this.val = val;
    }

    isTrue() {
        return this.val;
    }

    boolVal() {
        return this;
    }

    toString() {
        return String(this.val);
    }
}

module.exports = { BoolVal };
%%%
```

`String(true)` yields lowercase `true` in JavaScript, matching the shared expected files. No conditional is needed — unlike Python.

**(c) Insert `TrueExp` and `FalseExp` before the `VarExp` block**:

```javascript
TrueExp:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

TrueExp
%%%
eval(env) {
    return new BoolVal(true);
}

toString() {
    return "true";
}
%%%

FalseExp:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

FalseExp
%%%
eval(env) {
    return new BoolVal(false);
}

toString() {
    return "false";
}
%%%
```

**(d) Change `ZeropPrim` and append the six relational prims.** In `ZeropPrim:import`, change `const { IntVal } = require('./IntVal');` to `const { BoolVal } = require('./BoolVal');`; in `ZeropPrim`, change the return to `return new BoolVal(i0 === 0);`. Then append:

```javascript
LTPrim:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

LTPrim
%%%
toString() {
    return "<?";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new BoolVal(i0 < i1);
}
%%%

LEPrim:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

LEPrim
%%%
toString() {
    return "<=?";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new BoolVal(i0 <= i1);
}
%%%

GTPrim:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

GTPrim
%%%
toString() {
    return ">?";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new BoolVal(i0 > i1);
}
%%%

GEPrim:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

GEPrim
%%%
toString() {
    return ">=?";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new BoolVal(i0 >= i1);
}
%%%

EQPrim:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

EQPrim
%%%
toString() {
    return "=?";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new BoolVal(i0 === i1);
}
%%%

NEPrim:import
%%%
const { BoolVal } = require('./BoolVal');
%%%

NEPrim
%%%
toString() {
    return "<>?";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new BoolVal(i0 !== i1);
}
%%%
```

`EQPrim` and `NEPrim` use `===` and `!==`, matching the strict-equality idiom REF's JavaScript spec already uses.

Verify:

```bash
diff src/REF/javascript/spec.plcc src/TYPE0/javascript/spec.plcc
```

Expected: the same four hunk groups, with `:import` blocks naming only `BoolVal` on the eight grammar-derived classes, `require('./Val')` plus `module.exports` inside the free-standing `BoolVal`, and nothing touching `LetDecls:init`, `Formals:init`, `ProcVal.apply`, or the `%include` lines.

- [ ] **Step 2: Smoke-test the JavaScript target**

```bash
( cd src/TYPE0/javascript && printf '<=?(3,3)\ntrue\nzero?(0)\nlet f = proc(x:int):bool 5 in .f(3)\n' | plcc-rep )
```

Expected exactly: `true`, `true`, `true`, `5`.

`Identifier 'LanguageError' has already been declared` means an `:import` block on a grammar-derived class named it — remove that name. `Cannot find module './BoolVal'` means edit (b)'s block is missing. `BoolVal is not a constructor` means its `module.exports` line is missing.

- [ ] **Step 3: Append the JavaScript `@test` blocks**

Append to `src/TYPE0/tests/relational-prims/TYPE0test.bats`:

```bash
@test "TYPE0 relational-prims (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/relational-prims/TYPE0.input)"
  expected_output=$(< "../tests/relational-prims/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append to `src/TYPE0/tests/boolean-literals/TYPE0test.bats`:

```bash
@test "TYPE0 boolean-literals (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/boolean-literals/TYPE0.input)"
  expected_output=$(< "../tests/boolean-literals/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append to `src/TYPE0/tests/type-annotations-ignored/TYPE0test.bats`:

```bash
@test "TYPE0 type-annotations-ignored (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/type-annotations-ignored/TYPE0.input)"
  expected_output=$(< "../tests/type-annotations-ignored/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Append to `src/TYPE0/tests/declared-type-not-checked/TYPE0test.bats`:

```bash
@test "TYPE0 declared-type-not-checked (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/declared-type-not-checked/TYPE0.input)"
  expected_output=$(< "../tests/declared-type-not-checked/TYPE0.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 4: Run the TYPE0 tests**

Run: `bats --recursive src/TYPE0/tests`
Expected: **12 tests, 12 passing** — four cases × three targets.

- [ ] **Step 5: Confirm the three targets agree byte-for-byte**

The suite already asserts each target against the shared expected file, so this adds little coverage — but it states the cross-target invariant directly, which is the property the whole three-target architecture rests on:

```bash
for c in relational-prims boolean-literals type-annotations-ignored declared-type-not-checked; do
  n=$(for t in python java javascript; do
        ( cd "src/TYPE0/$t" && plcc-rep < "../tests/$c/TYPE0.input" ) | md5sum
      done | sort -u | wc -l)
  printf '%s: %s distinct output(s) across 3 targets\n' "$c" "$n"
done
```

Expected: `1` on every line. Note the `md5sum` is inside the inner loop — hashing each target's output separately and then counting distinct hashes. Hashing the three concatenated outputs instead would produce a single hash that proves nothing.

- [ ] **Step 6: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type0-task4.txt`. Confirm `EXIT=1`, then count.

Expected: **152 tests, 150 passing, 2 failing.** The 2 failures remain `OBJ class` and `TYPE1 proc-types` — the phase's load-bearing invariant is that the `command not found` count dropped by **exactly 1** from the baseline's 3. Check that invariant directly (`grep -c 'command not found' /tmp/type0-task4.txt`) rather than inferring it from the totals: it is the one gate here that does not move when the suite grows underneath this branch.

> **Amended 2026-08-06, pre-execution** — was 141 / 139 / 2 against the pre-rebase baseline of 130. Note that the old expected total, 141, is exactly the *new* baseline; anyone working from the stale number would have seen 141 tests on an untouched tree and read it as success.

- [ ] **Step 7: Commit**

```bash
git add src/TYPE0/javascript src/TYPE0/tests
git commit -m "feat(TYPE0): port JavaScript target to plcc-ng

Refs #NN"
```

---

### Task 5: Remove TYPE0's old-PLCC files and close the issue

**Files:**
- Delete: `src/TYPE0/{grammar,code,prim,envRef,val,ref}`
- Modify: `dev-docs/issues/0NN-migrate-type0-to-plcc-ng.md` (via script)
- Modify: `dev-docs/roadmap.md` (via script)
- Test: the full suite

**Interfaces:**
- Consumes: `NN` from Task 1; a fully passing TYPE0 suite from Task 4.
- Produces: nothing later depends on.

- [ ] **Step 1: Confirm nothing still references the old files**

```bash
grep -rnE 'TYPE0/(grammar([^.]|$)|code|prim|envRef|val|ref)' \
    --include='*.bats' --include='*.plcc' --include='*.bash' --include='*.md' . \
    | grep -v '^\./dev-docs/'
```

Expected: no output. Hits under `dev-docs/` are design and plan prose and are fine. A hit anywhere else means something still depends on a file about to be deleted — resolve it before deleting.

The `grammar([^.]|$)` branch is deliberate and must not be simplified to `grammar\b`: a word boundary matches between `grammar` and the `.` of `grammar.plcc`, so `TYPE0/grammar\b` flags the very file this task must keep. Verified — `\b` matches both spellings, the `-E` form only the extensionless one.

- [ ] **Step 2: Delete the old-PLCC sources**

```bash
git rm src/TYPE0/grammar src/TYPE0/code src/TYPE0/prim \
       src/TYPE0/envRef src/TYPE0/val src/TYPE0/ref
```

Note `src/TYPE0/grammar` (no extension) is a different file from `src/TYPE0/grammar.plcc` created in Task 2 — there is no collision, which is why this deletion comes at the end rather than up front. Confirm `src/TYPE0/grammar.plcc` survives:

```bash
ls src/TYPE0
```

Expected: `grammar.plcc`, `java`, `javascript`, `python`, `tests` — and nothing else. No `Prog/` directory: TYPE0 ships no example programs, by design.

- [ ] **Step 3: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type0-task5.txt`. Confirm `EXIT=1`, then count.

Expected: **152 tests, 150 passing, 2 failing** — unchanged from Task 4. Deleting the old-PLCC sources removes no test, because Task 2 already replaced TYPE0's only old test file.

> **Amended 2026-08-06, pre-execution** — was 141 / 139 / 2 against the pre-rebase baseline of 130.

- [ ] **Step 4: Commit the deletion**

```bash
git commit -m "refactor(TYPE0): remove old-PLCC sources superseded by the plcc-ng port

Refs #NN"
```

- [ ] **Step 5: Close the issue**

```bash
bin/issues/close.bash NN
bin/issues/check.bash
```

`close.bash` fills in the issue's `closed` date and removes its roadmap entry. Because this was the only `### Feat` entry, that heading should disappear with it — the roadmap's contract is that a type group exists only while it has open entries. `check.bash` must exit 0.

- [ ] **Step 6: Commit**

> **Amended 2026-08-06, pre-execution.** This was Step 7. The original Step 6
> was `rm -rf /workspaces/languages-ng/.claude/worktrees/.bats-tmp`, cleaning
> up after the split-`TMPDIR` workaround; nothing creates that directory
> anymore. Removed rather than left as a harmless no-op, so no one goes
> looking for the mechanism that was supposed to have made it.

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): close issue NN (migrate TYPE0 to plcc-ng), update roadmap"
```

This is the branch's final commit.

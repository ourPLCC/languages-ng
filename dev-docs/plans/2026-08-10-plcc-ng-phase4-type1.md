# plcc-ng Phase 4 — TYPE1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port TYPE1 (`TYPE0 + declare + and/or/not + strong type checking`) to plcc-ng in Python, Java, and JavaScript.

**Architecture:** TYPE1 is TYPE0 plus a static type checker that runs before every evaluation. `src/TYPE1/grammar.plcc` is TYPE0's file with four new tokens, one new program alternative (`Declare`), three new `<Prim>` alternatives, and the old-PLCC `#!trace` directive removed. Each target's `spec.plcc` is TYPE0's with nine new free-standing classes (`Type`, `IntType`, `BoolType`, `ProcType`, `TypeEnv`, `TypeEnvNode`, `TypeEnvNull`, `TypeBinding`, `TypeBindings`), an `evalType` method on `Exp` and its twelve subclasses, `toType()` filling the seven type nonterminals TYPE0 left empty, `definedType()` on all sixteen prims, and a rewritten top level in which `Program` carries a second static environment. The shared `src/Env/envRef/<target>/env.plcc` is `%include`d **unchanged** — this phase touches nothing under `src/Env/`.

**Tech Stack:** plcc-ng (`plcc-rep`, `plcc-scan`, `plcc-parse`), bats, Python 3, Java, Node.js.

**Design of record:** [dev-docs/specs/2026-08-10-plcc-ng-type1-design.md](../specs/2026-08-10-plcc-ng-type1-design.md). Read it before Task 1.

**Provenance of the spec text in this plan:** the three `spec.plcc` files and the grammar reproduced below are not sketches. The complete port was built and run under `plcc-rep` in all three targets during design, and every expected output in this plan is a measured result from that run, not a prediction. The text here was spliced from those working files rather than retyped. Transcribe it verbatim; if a step's expected output does not appear, the transcription is wrong before the design is.

## Global Constraints

- **Work in the existing worktree** `/workspaces/languages-ng/.claude/worktrees/type1`, branch `type1`. Do not create a new worktree. Do not `cd` to the main checkout. Note that this branch was created from local `main` (`011ae7a`), not from `origin/main`, which is 13 commits behind and does not contain the TYPE0 port.

- **Copy from `src/TYPE0/`, never from `src/TYPE1/`'s flat files.** The pre-migration files in `src/TYPE1/` (`code`, `prim`, `val`, `ref`, `tenv`, `type`, `envRef`, `grammar`) are a fork of *pre-migration* TYPE0 and never received three corrections the migration made to TYPE0. They are the reference for **what TYPE1 adds** — the type checker — and must not be transliterated wholesale. Every "create the spec" step below starts from `src/TYPE0/<target>/spec.plcc`.

- **Run the full suite with plain `bin/test.bash`.** Everywhere this plan says "run the full suite", that means:

  ```bash
  cd /workspaces/languages-ng/.claude/worktrees/type1
  bin/test.bash > /tmp/type1-<task>.txt 2>&1; echo "EXIT=$?"
  ```

  Read the exit status, not just the counts. `bin/test.bash` has a three-value contract from issue [#31](../issues/031-suite-exhausts-disk-and-reports-spurious-failure.md): **0** every test passed, **1** the run completed with real test failures, **2** the harness itself did not finish. **Exit 2 means the numbers in the file are meaningless — do not count them, and do not report a result.** Throughout this phase the expected status is **1**, because `OBJ class` stays red from start to finish; a `0` would mean something unexpected started passing and is just as much a reason to stop as a `2`.

  Then count with `grep -c '^ok '` and `grep -c '^not ok '`, and list the failures with `grep '^not ok '`.

  Do not pipe `bin/test.bash` through `tail`, `head`, or `grep` directly. A pipeline's exit status is the last command's, which silently discards the three-value contract above.

- **Baseline, measured 2026-08-10 in this worktree at `011ae7a`: 152 tests, 150 passing, 2 failing**, exit status 1. The 2 failures are `not ok 28 OBJ class` and `not ok 68 TYPE1 proc-types`, both `plccmk: command not found` from a language still on old PLCC. Task 1 re-confirms this before anything is built.

- **No test that passes may start failing.** Nothing in this phase touches an already-passing language, so a `V`-prefixed, `SET`, `REF`, `NAME`, `NEED`, or `TYPE0` failure means a genuine regression, not expected churn.

- **`OBJ class` stays failing through every gate in this plan.** It is the last old-PLCC language. The `plccmk: command not found` count must go from 2 to 1 and no further.

- **Do not touch `src/Env/`.** SET ported `envRef`; REF, NAME, NEED, and TYPE0 reused it unchanged; TYPE1 reuses it unchanged again — the fifth consecutive zero-touch reuse. In particular, do **not** port anything out of `src/TYPE1/envRef`: that file is byte-identical to pre-migration TYPE0's and is deleted in Task 5, not migrated.

- **`Val.isTrue()` raises `boolean expression expected`.** Pre-migration TYPE1 returns `false`; that is drift. The body is unreachable in a well-typed program, so no test distinguishes them — which is exactly why it will look like harmless cleanup. Leave TYPE0's raise in place.

- **Keep every prim's runtime arity guard.** Pre-migration TYPE1 deleted all sixteen in favour of static checking via `definedType()`. Both mechanisms ship. Copying TYPE0's spec gets this right for free; the risk is deleting them to match `src/TYPE1/prim`.

- **Keep `ProcVal.apply`'s formals/args count check.** Pre-migration TYPE1 has none, but neither did pre-migration TYPE0 — the check is byte-identical in all five shipped predecessors and is something the migration introduced.

- **`apply` keeps its `Env` parameter** in every target — `apply(args, env)` / `apply(List<Ref> args, Env e)`. It is unread at runtime. It is the seam for a dynamic-scoping homework assignment. **Never remove it as dead code.**

- **`Rands.evalRandsRef` calls `evalRef`, restoring call-by-reference.** Pre-migration TYPE1 wraps every operand in a fresh `ValRef`, which silently drops the aliasing REF and TYPE0 provide and leaves `Exp.evalRef`/`VarExp.evalRef` defined but uncalled. TYPE0's list comprehension is correct and must be kept. This is observable and is pinned by the `call-by-reference/` test case in Task 2.

- **Do not implement subtyping, variance, or type inference.** `checkEquals` is exact structural equality in both directions and must stay that way: the invariance is what makes call-by-reference sound. A "helpful" relaxation — accepting an `int` where a `bool` is declared, or making `ProcType` parameters contravariant — introduces a real soundness hole, not just a style difference.

- **`Type`'s canonical types are static factory methods, not fields**, in all three targets including Java. A class attribute is evaluated when the class body runs, which in Python and JavaScript forces `Type` to import its own subclasses at module scope and makes the `Type`/`IntType` cycle depend on load order. Java could use `static final` fields and does not, so that all three read alike. Do not "optimize" these back into fields or memoize them; the types are stateless and `checkEquals` is structural, so a fresh instance per call is correct.

- **Grammar conventions, unchanged since V0:** identifier token is `SYMBOL` (never `VAR`); nonterminals are PascalCase; multi-capture alt-names are camelCase (`<Exp:testExp>`), not the obsolete lowercase workaround.

- **Input and expected files carry no trailing newline.** Use `printf`, never `echo` or a bare heredoc. `src/TYPE1/tests/proc-types/TYPE1.input` and `TYPE1.expected` already satisfy this and are **not** modified by this plan — only their `.bats` file is replaced.

- **Course-material impact entries go in the same commit as the change they describe**, under a `## TYPE1` heading in [dev-docs/course-material-impact.md](../course-material-impact.md), added after the existing `## TYPE0` section. Never batch them.

- **Every `.bats` file loads both helpers**, in this order, as its only two `load` lines:

  ```bash
  load '../../../../bin/relocate.bash'
  load '../../../../bin/bats-tmpdir.bash'
  ```

  `bats-tmpdir.bash` is the `teardown` that empties a passing test's `BATS_TEST_TMPDIR`; a file that omits it silently reintroduces the per-test disk accumulation of issue #31 for its own tests, and nothing announces it. Only Task 2 writes these headers; Tasks 3 and 4 append `@test` blocks to files that already have them and must not add a second `load` pair.

- **Never assign issue numbers by hand.** Use `bin/issues/new.bash` and `bin/issues/close.bash`.

- Every target's `spec.plcc` writes build artifacts to a `plcc-ng/` subdirectory; `.gitignore` already covers `plcc-ng/`, `__pycache__/`, and `*.class`. Never commit them.

---

### Task 1: File the TYPE1 issue and confirm the baseline

Pure bookkeeping plus the gate every later task's expected counts depend on.

**Files:**
- Create: `dev-docs/issues/0NN-migrate-type1-to-plcc-ng.md` (number assigned by the script)
- Modify: `dev-docs/roadmap.md`
- Test: the existing suite, via `bin/test.bash`

**Interfaces:**
- Consumes: nothing.
- Produces: the issue number `NN`, used in every later task's commit trailer and by `bin/issues/close.bash` in Task 5.

- [ ] **Step 1: Create the issue**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
bin/issues/new.bash migrate-type1-to-plcc-ng feat
```

Note the number it prints. Everywhere below, `NN` means that number.

- [ ] **Step 2: Fill in the issue body**

Open the created file and write its `## Description` section. Cover: TYPE1 is `TYPE0 + declare + and/or/not + strong type checking`, the last language in Phase 4; the port adds nine free-standing classes for the type and type-environment hierarchies, an `evalType` pass that runs before every evaluation, and `definedType()` on every prim; and it reverts four drift items inherited from a stale fork of pre-migration TYPE0, of which the substantive one is the loss of call-by-reference. Link the design doc.

Leave `**Target:**` as this repo — nothing here is a plcc-ng defect.

- [ ] **Step 3: Add the roadmap entry**

Add a bullet under the appropriate heading in `dev-docs/roadmap.md`, matching the format of the entries already there: a bold link line and one indented continuation line.

- [ ] **Step 4: Verify issue bookkeeping is consistent**

```bash
bin/issues/check.bash
```

Expected: no errors.

- [ ] **Step 5: Confirm the baseline**

Run the full suite per Global Constraints, writing to `/tmp/type1-task1.txt`.

Expected: `EXIT=1`, **152 tests, 150 passing, 2 failing.** The 2 failures must be exactly `OBJ class` and `TYPE1 proc-types`.

If the totals differ, **stop and re-derive every count in Tasks 2 through 5 from what you measured** before writing any code. Do not adjust them arithmetically from the numbers printed here. The overarching design flags this specific trap: TYPE0's plan copied a prior phase's count and decremented it, and was off by one until an implementer actually ran the command.

- [ ] **Step 6: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): file issue NN - migrate TYPE1 to plcc-ng"
```

Replace `NN` with the real number.

---
### Task 2: Grammar + Python target + all five test cases

Delivers `src/TYPE1/grammar.plcc`, the Python `spec.plcc`, and all five test cases with their **Python** `@test` blocks. Tasks 3 and 4 append the Java and JavaScript blocks to the same `.bats` files.

**Files:**
- Create: `src/TYPE1/grammar.plcc`
- Create: `src/TYPE1/python/spec.plcc`
- Replace: `src/TYPE1/tests/proc-types/TYPE1test.bats` (its `TYPE1.input` and `TYPE1.expected` are **not** touched)
- Create: `src/TYPE1/tests/boolean-ops/{TYPE1.input,TYPE1.expected,TYPE1test.bats}`
- Create: `src/TYPE1/tests/declare-define/{TYPE1.input,TYPE1.expected,TYPE1test.bats}`
- Create: `src/TYPE1/tests/call-by-reference/{TYPE1.input,TYPE1.expected,TYPE1test.bats}`
- Create: `src/TYPE1/tests/type-errors/{TYPE1.input,TYPE1.expected,TYPE1test.bats}`
- Modify: `dev-docs/course-material-impact.md`
- Test: `bats --recursive src/TYPE1/tests`, then the full suite

**Interfaces:**
- Consumes: `NN` from Task 1 (used only in the commit trailer).
- Produces:
  - `src/TYPE1/grammar.plcc`, `%include`d by all three targets, defining tokens `ANDOP`/`OROP`/`NOTOP`/`DECLARE`, the production `<Program:Declare> ::= DECLARE <SYMBOL> COLON <TypeExp>`, and the `<Prim>` alternatives `AndPrim`/`OrPrim`/`NotPrim`.
  - `src/TYPE1/python/spec.plcc` defining nine free-standing classes — `Type` (with static `intType()`, `boolType()`, `ii_i()`, `i_i()`, `ii_b()`, `i_b()`, `bb_b()`, `b_b()`, `checkEqualTypes(typeList1, typeList2)`, `typeMismatch(t1, t2)`, and instance `procType()`, `checkEquals(t)`, `checkIntType(t)`, `checkBoolType(t)`, `checkProcType(t)`), `IntType`, `BoolType`, `ProcType(paramTypeList, returnType)`, `TypeEnv` (static `initTypeEnv()`, instance `applyTypeEnv(sym)`, `add(b)`, `extendTypeEnv(bindings)`), `TypeEnvNode(bindings, typeEnv)`, `TypeEnvNull`, `TypeBinding(id, type)`, and `TypeBindings(idList=None, typeList=None)` with `add(b)`; plus `Exp.evalType(tenv)` on all twelve `Exp` subclasses, `toType()` on the seven type nonterminals, `definedType()` on all sixteen prims, `Formals.formalTypeList()` and `Formals.declaredTypeBindings()`, `LetDecls.addTypeBindings(tenv)` and `addLetrecTypeBindings(tenv)`, `Rands.evalTypeRands(tenv)`, `Proc.evalType(tenv)`, and `ProcVal(formals, returnTypeExp, body, env)`.
  - The five test case directories, which Tasks 3 and 4 append `@test` blocks to.

- [ ] **Step 1: Create the grammar**

Write `src/TYPE1/grammar.plcc` with exactly this content. It is TYPE0's grammar with the delta already applied, validated end-to-end against `plcc-scan`, `plcc-parse`, and `plcc-rep` in all three targets:

```
# Language TYPE1
#   Language TYPE0 with strong type checking
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
token ANDOP 'and'
token OROP 'or'
token NOTOP 'not'
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
token DECLARE 'declare'
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
<Program:Declare>       ::= DECLARE <SYMBOL> COLON <TypeExp>
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
<Prim:AndPrim>          ::= ANDOP
<Prim:OrPrim>           ::= OROP
<Prim:NotPrim>          ::= NOTOP
```

Against `src/TYPE0/grammar.plcc` this is five changes and nothing else: the header comment, four new tokens (`ANDOP`, `OROP`, `NOTOP`, `DECLARE`) each in its pre-migration position and all before `token SYMBOL`, the new `<Program:Declare>` alternative placed first, three new `<Prim>` alternatives after `NEPrim`, and no `#!trace` line. Diff the two files and confirm you see only those.

Do **not** reorder the lexical section. plcc-ng resolves tokens by longest match, not declaration order, so `and`/`or`/`not` sitting before `SYMBOL` is sufficient and an identifier such as `orange` still scans as `SYMBOL`.

- [ ] **Step 2: Confirm the grammar scans and parses**

`plcc-scan -s` accepts a grammar-only file (no semantic section), so the four new tokens can be checked before any spec exists:

```bash
mkdir -p /tmp/type1-scratch && cd /tmp/type1-scratch
printf 'declare f : [int,int=>bool] orange and or not\n' \
  | plcc-scan -s /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/grammar.plcc
```

Expected, exactly:

```
-:1:1 DECLARE 'declare'
-:1:9 SYMBOL 'f'
-:1:11 COLON ':'
-:1:13 LBRACK '['
-:1:14 INT 'int'
-:1:17 COMMA ','
-:1:18 INT 'int'
-:1:21 RARROW '=>'
-:1:23 BOOL 'bool'
-:1:27 RBRACK ']'
-:1:29 SYMBOL 'orange'
-:1:36 ANDOP 'and'
-:1:40 OROP 'or'
-:1:43 NOTOP 'not'
```

Two things are being checked here. `declare` must come back as `DECLARE`, not `SYMBOL` — running this same input against `src/TYPE0/grammar.plcc` yields `SYMBOL 'declare'`, so a `SYMBOL` here means the token is missing or was placed after `token SYMBOL`. And `orange` must come back as `SYMBOL`, not `OROP` followed by `ange`, which is the longest-match behaviour the design relies on for the three new keywords.

`plcc-parse` cannot run against a grammar alone; Step 4 exercises parsing through `plcc-rep`.

- [ ] **Step 3: Create the Python spec**

Write `src/TYPE1/python/spec.plcc` with exactly this content:

```
%include ../grammar.plcc
%
Python

%include ../../Env/envRef/python/env.plcc

Val
%%%
from runtime.base import LanguageError


class Val:

    def apply(self, args, env):
        raise LanguageError(f"Cannot apply {self}")

    def isTrue(self):
        raise LanguageError("boolean expression expected")

    def intVal(self):
        raise LanguageError(f"{self}: not an Int")

    def boolVal(self):
        raise LanguageError(f"{self}: not a Bool")
%%%

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

ProcVal
%%%
from Bindings import Bindings
from Val import Val
from runtime.base import LanguageError


class ProcVal(Val):

    def __init__(self, formals, returnTypeExp, body, env):
        self.formals = formals
        self.returnTypeExp = returnTypeExp
        self.body = body
        self.env = env

    def apply(self, args, env):
        if len(self.formals.symbolList) != len(args):
            raise LanguageError("formals/args number mismatch")
        bindings = Bindings(self.formals.symbolList, args)
        nenv = self.env.extendEnvRef(bindings)
        return self.body.eval(nenv)

    def __str__(self):
        return f"proc({self.formals}):{self.returnTypeExp.toType()}"
%%%

Type
%%%
from runtime.base import LanguageError


class Type:

    # The canonical types are factory methods rather than class
    # attributes. A class attribute is evaluated when the class body
    # runs, which would force Type to import its own subclasses at
    # module scope and leave the Type/IntType import cycle depending on
    # load order. Deferring the import into the method body is the same
    # fix Env.initEnv() uses. Java follows suit so the three targets
    # read alike, even though only Python and JavaScript need it.
    #
    # Returning a fresh instance per call is safe: the types are
    # stateless and checkEquals is structural, never identity.

    @staticmethod
    def intType():
        from IntType import IntType
        return IntType()

    @staticmethod
    def boolType():
        from BoolType import BoolType
        return BoolType()

    @staticmethod
    def ii_i():
        from ProcType import ProcType
        return ProcType([Type.intType(), Type.intType()], Type.intType())

    @staticmethod
    def i_i():
        from ProcType import ProcType
        return ProcType([Type.intType()], Type.intType())

    @staticmethod
    def ii_b():
        from ProcType import ProcType
        return ProcType([Type.intType(), Type.intType()], Type.boolType())

    @staticmethod
    def i_b():
        from ProcType import ProcType
        return ProcType([Type.intType()], Type.boolType())

    @staticmethod
    def bb_b():
        from ProcType import ProcType
        return ProcType([Type.boolType(), Type.boolType()], Type.boolType())

    @staticmethod
    def b_b():
        from ProcType import ProcType
        return ProcType([Type.boolType()], Type.boolType())

    # this Type as a ProcType, or an error if it is not one
    def procType(self):
        raise LanguageError(f"{self}: attempt to apply a non-procedure")

    def checkEquals(self, t):
        raise NotImplementedError

    @staticmethod
    def checkEqualTypes(typeList1, typeList2):
        if len(typeList1) != len(typeList2):
            raise LanguageError("argument number mismatch")
        for t1, t2 in zip(typeList1, typeList2):
            t1.checkEquals(t2)

    def checkIntType(self, t):
        Type.typeMismatch(self, t)

    def checkBoolType(self, t):
        Type.typeMismatch(self, t)

    def checkProcType(self, t):
        Type.typeMismatch(self, t)

    @staticmethod
    def typeMismatch(t1, t2):
        raise LanguageError(f"type mismatch: {t1} != {t2}")
%%%

IntType
%%%
from Type import Type


class IntType(Type):

    def checkEquals(self, t):
        t.checkIntType(self)

    def checkIntType(self, t):
        pass    # this IntType equals any other IntType

    def __str__(self):
        return "int"
%%%

BoolType
%%%
from Type import Type


class BoolType(Type):

    def checkEquals(self, t):
        t.checkBoolType(self)

    def checkBoolType(self, t):
        pass    # this BoolType equals any other BoolType

    def __str__(self):
        return "bool"
%%%

ProcType
%%%
from Type import Type


# the declared type of a procedure
class ProcType(Type):

    def __init__(self, paramTypeList, returnType):
        self.paramTypeList = paramTypeList
        self.returnType = returnType

    def procType(self):
        return self

    def checkEquals(self, t):
        t.checkProcType(self)

    def checkProcType(self, t):
        self.returnType.checkEquals(t.returnType)
        Type.checkEqualTypes(self.paramTypeList, t.paramTypeList)

    def __str__(self):
        params = ",".join(str(t) for t in self.paramTypeList)
        return f"[{params}=>{self.returnType}]"
%%%

TypeEnv
%%%
from runtime.base import LanguageError


class TypeEnv:

    @staticmethod
    def initTypeEnv():
        from TypeEnvNode import TypeEnvNode
        from TypeEnvNull import TypeEnvNull
        from TypeBindings import TypeBindings
        return TypeEnvNode(TypeBindings(), TypeEnvNull())

    def applyTypeEnv(self, sym):
        raise LanguageError("no type binding for " + sym)

    def add(self, b):
        raise LanguageError("no type bindings to add to")

    def extendTypeEnv(self, bindings):
        from TypeEnvNode import TypeEnvNode
        return TypeEnvNode(bindings, self)
%%%

TypeEnvNode
%%%
from TypeEnv import TypeEnv


class TypeEnvNode(TypeEnv):

    def __init__(self, bindings, typeEnv):
        self.bindings = bindings
        self.typeEnv = typeEnv

    def applyTypeEnv(self, sym):
        for b in self.bindings.bindingList:
            if sym == b.id:
                return b.type
        return self.typeEnv.applyTypeEnv(sym)

    def add(self, b):
        self.bindings.add(b)

    def __str__(self):
        return f"{self.bindings}\n{self.typeEnv}"
%%%

TypeEnvNull
%%%
from TypeEnv import TypeEnv


class TypeEnvNull(TypeEnv):

    def __str__(self):
        return "\n"
%%%

TypeBinding
%%%
class TypeBinding:

    def __init__(self, id, type):
        self.id = id
        self.type = type

    def __str__(self):
        return f"[{self.id}->{self.type}]"
%%%

TypeBindings
%%%
from TypeBinding import TypeBinding
from runtime.base import LanguageError


class TypeBindings:

    def __init__(self, idList=None, typeList=None):
        self.bindingList = []
        if idList is not None:
            if typeList is None or len(idList) != len(typeList):
                raise LanguageError("list sizes mismatch")
            for sym, t in zip(idList, typeList):
                self.bindingList.append(TypeBinding(sym.lexeme, t))

    def add(self, b):
        self.bindingList.append(b)

    def __str__(self):
        s = ""
        for b in self.bindingList:
            s += " " + str(b)
        return s
%%%

Program:import
%%%
from Env import Env
from TypeEnv import TypeEnv
%%%

Program
%%%
env = Env.initEnv()
tenv = TypeEnv.initTypeEnv()
%%%

Declare:import
%%%
from TypeBinding import TypeBinding
from runtime.base import LanguageError
%%%

Declare
%%%
def _run(self):
    tenv = Program.tenv
    sym = self.symbol.lexeme
    try:
        tenv.applyTypeEnv(sym)
    except LanguageError:
        # no type binding -- a new type declaration, which we add
        # to the top-level type environment
        varType = self.typeExp.toType()
        tenv.add(TypeBinding(sym, varType))
        return f"{sym}:{varType}"
    raise LanguageError(f"{sym}: duplicate variable declaration")
%%%

Define:import
%%%
from Binding import Binding
from ValRef import ValRef
from TypeBinding import TypeBinding
from runtime.base import LanguageError
%%%

Define
%%%
def _run(self):
    env = Program.env
    tenv = Program.tenv
    sym = self.symbol.lexeme
    try:
        lhsVarType = tenv.applyTypeEnv(sym)
    except LanguageError:
        # no type binding -- a new variable definition
        rhsExpType = self.exp.evalType(tenv)
        tenv.add(TypeBinding(sym, rhsExpType))
        rhsExpVal = self.exp.eval(env)
        env.add(Binding(sym, ValRef(rhsExpVal)))
        return f"{sym}:{rhsExpType}"
    # the variable has a declared type -- see if it still needs a value
    try:
        env.applyEnv(sym)
    except LanguageError:
        rhsExpType = self.exp.evalType(tenv)
        # the declared and defined types must be the same
        lhsVarType.checkEquals(rhsExpType)
        rhsExpVal = self.exp.eval(env)
        env.add(Binding(sym, ValRef(rhsExpVal)))
        return f"{sym}:{rhsExpType}"
    # the variable has a value too -- can't redefine it
    raise LanguageError(f"{sym}: duplicate variable definition")
%%%

Eval
%%%
def _run(self):
    self.exp.evalType(Program.tenv)     # type check first
    return str(self.exp.eval(Program.env))
%%%

Exp:import
%%%
from ValRef import ValRef
%%%

Exp
%%%
def evalRef(self, env):
    return ValRef(self.eval(env))

def evalType(self, tenv):
    raise NotImplementedError
%%%

LitExp:import
%%%
from IntVal import IntVal
from Type import Type
%%%

LitExp
%%%
def eval(self, env):
    return IntVal(self.lit.lexeme)

def evalType(self, tenv):
    return Type.intType()

def __str__(self):
    return self.lit.lexeme
%%%

TrueExp:import
%%%
from BoolVal import BoolVal
from Type import Type
%%%

TrueExp
%%%
def eval(self, env):
    return BoolVal(True)

def evalType(self, tenv):
    return Type.boolType()

def __str__(self):
    return "true"
%%%

FalseExp:import
%%%
from BoolVal import BoolVal
from Type import Type
%%%

FalseExp
%%%
def eval(self, env):
    return BoolVal(False)

def evalType(self, tenv):
    return Type.boolType()

def __str__(self):
    return "false"
%%%

VarExp
%%%
def eval(self, env):
    return env.applyEnv(self.symbol.lexeme)

def evalRef(self, env):
    return env.applyEnvRef(self.symbol.lexeme)

def evalType(self, tenv):
    return tenv.applyTypeEnv(self.symbol.lexeme)

def __str__(self):
    return self.symbol.lexeme
%%%

IfExp:import
%%%
from Type import Type
%%%

IfExp
%%%
def eval(self, env):
    if self.testExp.eval(env).isTrue():
        return self.trueExp.eval(env)
    else:
        return self.falseExp.eval(env)

def evalType(self, tenv):
    testType = self.testExp.evalType(tenv)
    testType.checkBoolType(Type.boolType())
    trueExpType = self.trueExp.evalType(tenv)
    falseExpType = self.falseExp.evalType(tenv)
    trueExpType.checkEquals(falseExpType)
    return trueExpType

def __str__(self):
    return f"if {self.testExp} then {self.trueExp} else {self.falseExp}"
%%%

PrimappExp:import
%%%
from Type import Type
%%%

PrimappExp
%%%
def eval(self, env):
    args = self.rands.evalRands(env)
    return self.prim.apply(args)

def evalType(self, tenv):
    pt = self.prim.definedType()
    argTypeList = self.rands.evalTypeRands(tenv)
    Type.checkEqualTypes(pt.paramTypeList, argTypeList)
    return pt.returnType

def __str__(self):
    return f"{self.prim}({self.rands})"
%%%

LetExp
%%%
def eval(self, env):
    nenv = self.letDecls.addBindings(env)
    return self.exp.eval(nenv)

def evalType(self, tenv):
    ntenv = self.letDecls.addTypeBindings(tenv)
    return self.exp.evalType(ntenv)

def __str__(self):
    return " ...LetExp... "
%%%

LetrecExp
%%%
def eval(self, env):
    env = self.letDecls.addLetrecBindings(env)
    return self.exp.eval(env)

def evalType(self, tenv):
    ntenv = self.letDecls.addLetrecTypeBindings(tenv)
    return self.exp.evalType(ntenv)

def __str__(self):
    return " ...LetrecExp... "
%%%

LetDecls:import
%%%
from Env import Env
from Binding import Binding
from Bindings import Bindings
from Ref import Ref
from ValRef import ValRef
from TypeBinding import TypeBinding
from TypeBindings import TypeBindings
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

def addTypeBindings(self, tenv):
    typeList = [e.evalType(tenv) for e in self.expList]
    return tenv.extendTypeEnv(TypeBindings(self.symbolList, typeList))

def addLetrecTypeBindings(self, tenv):
    tenv = tenv.extendTypeEnv(TypeBindings())
    for sym, e in zip(self.symbolList, self.expList):
        typ = e.evalType(tenv)
        tenv.add(TypeBinding(sym.lexeme, typ))
    return tenv

def __str__(self):
    return " ...LetDecls... "
%%%

ProcExp
%%%
def eval(self, env):
    return self.proc.makeClosure(env)

def evalType(self, tenv):
    return self.proc.evalType(tenv)

def __str__(self):
    return " ...ProcExp... "
%%%

Proc:import
%%%
from ProcVal import ProcVal
from ProcType import ProcType
%%%

Proc
%%%
def makeClosure(self, env):
    return ProcVal(self.formals, self.typeExp, self.exp, env)

def evalType(self, tenv):
    # the declared return type of the proc
    declaredReturnType = self.typeExp.toType()
    # bind the formal parameters to their declared types
    ntenv = tenv.extendTypeEnv(self.formals.declaredTypeBindings())
    # type the body in that extended type environment
    expType = self.exp.evalType(ntenv)
    # and check that the declared return type matches the body's
    declaredReturnType.checkEquals(expType)
    return ProcType(self.formals.formalTypeList(), declaredReturnType)
%%%

Formals:import
%%%
from Env import Env
from TypeBindings import TypeBindings
%%%

Formals:init
%%%
Env.checkDuplicates(self.symbolList, " in proc formals")
%%%

Formals
%%%
def formalTypeList(self):
    return [texp.toType() for texp in self.typeExpList]

def declaredTypeBindings(self):
    return TypeBindings(self.symbolList, self.formalTypeList())

def __str__(self):
    return ",".join(f"{sym.lexeme}:{texp.toType()}"
                    for sym, texp in zip(self.symbolList, self.typeExpList))
%%%

AppExp:import
%%%
from Type import Type
%%%

AppExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    args = self.rands.evalRandsRef(env)
    return v.apply(args, env)

def evalType(self, tenv):
    pt = self.exp.evalType(tenv).procType()
    argTypeList = self.rands.evalTypeRands(tenv)
    Type.checkEqualTypes(pt.paramTypeList, argTypeList)
    return pt.returnType

def __str__(self):
    return " ...AppExp... "
%%%

SeqExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    for e in self.seqExps.expList:
        v = e.eval(env)
    return v

def evalType(self, tenv):
    t = self.exp.evalType(tenv)
    for e in self.seqExps.expList:
        t = e.evalType(tenv)
    return t

def __str__(self):
    return " ...SeqExp... "
%%%

SetExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    ref = env.applyEnvRef(self.symbol.lexeme)
    return ref.setRef(v)

def evalType(self, tenv):
    varType = tenv.applyTypeEnv(self.symbol.lexeme)
    expType = self.exp.evalType(tenv)
    varType.checkEquals(expType)
    return varType

def __str__(self):
    return " ...SetExp... "
%%%

Rands
%%%
def evalRands(self, env):
    return [e.eval(env) for e in self.expList]

def evalRandsRef(self, env):
    return [e.evalRef(env) for e in self.expList]

def evalTypeRands(self, tenv):
    return [e.evalType(tenv) for e in self.expList]

def __str__(self):
    return ",".join(str(e) for e in self.expList)
%%%

TypeExp
%%%
def toType(self):
    raise NotImplementedError
%%%

PrimTypeExp
%%%
def toType(self):
    return self.primType.toType()
%%%

ProcTypeExp:import
%%%
from ProcType import ProcType
%%%

ProcTypeExp
%%%
def toType(self):
    return ProcType(self.typeExps.toTypes(), self.typeExp.toType())
%%%

TypeExps
%%%
def toTypes(self):
    return [te.toType() for te in self.typeExpList]
%%%

PrimType
%%%
def toType(self):
    raise NotImplementedError
%%%

BoolPrimType:import
%%%
from Type import Type
%%%

BoolPrimType
%%%
def toType(self):
    return Type.boolType()
%%%

IntPrimType:import
%%%
from Type import Type
%%%

IntPrimType
%%%
def toType(self):
    return Type.intType()
%%%

AddPrim:import
%%%
from IntVal import IntVal
from Type import Type
from runtime.base import LanguageError
%%%

AddPrim
%%%
def __str__(self):
    return "+"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return IntVal(i0 + i1)

def definedType(self):
    return Type.ii_i()
%%%

SubPrim:import
%%%
from IntVal import IntVal
from Type import Type
from runtime.base import LanguageError
%%%

SubPrim
%%%
def __str__(self):
    return "-"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return IntVal(i0 - i1)

def definedType(self):
    return Type.ii_i()
%%%

MulPrim:import
%%%
from IntVal import IntVal
from Type import Type
from runtime.base import LanguageError
%%%

MulPrim
%%%
def __str__(self):
    return "*"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    return IntVal(i0 * i1)

def definedType(self):
    return Type.ii_i()
%%%

DivPrim:import
%%%
from IntVal import IntVal
from Type import Type
from runtime.base import LanguageError
%%%

DivPrim
%%%
def __str__(self):
    return "/"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    i0 = args[0].intVal().val
    i1 = args[1].intVal().val
    if i1 == 0:
        raise LanguageError("attempt to divide by zero")
    return IntVal(int(i0 / i1))

def definedType(self):
    return Type.ii_i()
%%%

Add1Prim:import
%%%
from IntVal import IntVal
from Type import Type
from runtime.base import LanguageError
%%%

Add1Prim
%%%
def __str__(self):
    return "add1"

def apply(self, args):
    if len(args) != 1:
        raise LanguageError("one argument expected")
    i0 = args[0].intVal().val
    return IntVal(i0 + 1)

def definedType(self):
    return Type.i_i()
%%%

Sub1Prim:import
%%%
from IntVal import IntVal
from Type import Type
from runtime.base import LanguageError
%%%

Sub1Prim
%%%
def __str__(self):
    return "sub1"

def apply(self, args):
    if len(args) != 1:
        raise LanguageError("one argument expected")
    i0 = args[0].intVal().val
    return IntVal(i0 - 1)

def definedType(self):
    return Type.i_i()
%%%

ZeropPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
from runtime.base import LanguageError
%%%

ZeropPrim
%%%
def __str__(self):
    return "zero?"

def apply(self, args):
    if len(args) != 1:
        raise LanguageError("one argument expected")
    i0 = args[0].intVal().val
    return BoolVal(i0 == 0)

def definedType(self):
    return Type.i_b()
%%%

LTPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
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

def definedType(self):
    return Type.ii_b()
%%%

LEPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
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

def definedType(self):
    return Type.ii_b()
%%%

GTPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
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

def definedType(self):
    return Type.ii_b()
%%%

GEPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
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

def definedType(self):
    return Type.ii_b()
%%%

EQPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
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

def definedType(self):
    return Type.ii_b()
%%%

NEPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
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

def definedType(self):
    return Type.ii_b()
%%%

AndPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
from runtime.base import LanguageError
%%%

AndPrim
%%%
def __str__(self):
    return "and"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    b0 = args[0].boolVal().val
    b1 = args[1].boolVal().val
    return BoolVal(b0 and b1)

def definedType(self):
    return Type.bb_b()
%%%

OrPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
from runtime.base import LanguageError
%%%

OrPrim
%%%
def __str__(self):
    return "or"

def apply(self, args):
    if len(args) != 2:
        raise LanguageError("two arguments expected")
    b0 = args[0].boolVal().val
    b1 = args[1].boolVal().val
    return BoolVal(b0 or b1)

def definedType(self):
    return Type.bb_b()
%%%

NotPrim:import
%%%
from BoolVal import BoolVal
from Type import Type
from runtime.base import LanguageError
%%%

NotPrim
%%%
def __str__(self):
    return "not"

def apply(self, args):
    if len(args) != 1:
        raise LanguageError("one argument expected")
    b0 = args[0].boolVal().val
    return BoolVal(not b0)

def definedType(self):
    return Type.b_b()
%%%
```

Five things in that file are easy to "fix" into being wrong. Leave each alone:

1. `Val.isTrue()` raises. Pre-migration TYPE1 returns `False`. The body is unreachable in a well-typed program, so nothing will fail if you change it — that is what makes it dangerous.
2. Every prim keeps its `if len(args) != N` guard **and** gains `definedType()`. Both.
3. `ProcVal.apply` keeps the `formals/args number mismatch` check and the unread `env` parameter.
4. `Rands.evalRandsRef` is `[e.evalRef(env) for e in self.expList]`, not `[ValRef(e.eval(env)) ...]`. This is what makes `.g(a)` alias the caller's `a`.
5. `Type`'s eight canonical types are `@staticmethod`s that import inside the body. Hoisting those imports to module scope, or turning the methods into class attributes, reintroduces the `Type`/`IntType` circular-import failure the design describes.

- [ ] **Step 4: Smoke-test the Python target before writing any tests**

```bash
mkdir -p /tmp/type1-scratch/py && cd /tmp/type1-scratch/py
printf 'declare f : [=>int]\ndeclare y : int\ndefine f = proc():int y\ndefine y = 3\n.f()\n' \
  | plcc-rep -s /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/python/spec.plcc
```

Expected, exactly:

```
f:[=>int]
y:int
f:[=>int]
y:int
3
```

This one program exercises `Declare`, both `Define` branches, `Program.tenv` persisting across the read loop, `ProcTypeExp.toType()` on an empty `<TypeExps>`, and `AppExp.evalType`. If it prints nothing and reports a specification error, read the traceback: a `NameError` names the class whose `:import` block is missing.

- [ ] **Step 5: Create the four new test case fixtures**

`proc-types/TYPE1.input` and `proc-types/TYPE1.expected` already exist and are correct — do not touch them.

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/tests
mkdir -p boolean-ops declare-define call-by-reference type-errors

printf 'and(true,false)\nor(true,false)\nnot(true)\nand(<?(1,2), not(false))\nor(zero?(1), >=?(3,3))\nnot(=?(2,2))' \
  > boolean-ops/TYPE1.input
printf 'false\ntrue\nfalse\ntrue\ntrue\nfalse' \
  > boolean-ops/TYPE1.expected

printf 'declare odd? : [int=>bool]\ndeclare even? : [int=>bool]\ndefine odd? = proc(t:int):bool if zero?(t) then false else .even?(sub1(t))\ndefine even? = proc(t:int):bool if zero?(t) then true else .odd?(sub1(t))\n.odd?(7)\n.even?(7)' \
  > declare-define/TYPE1.input
printf 'odd?:[int=>bool]\neven?:[int=>bool]\nodd?:[int=>bool]\neven?:[int=>bool]\ntrue\nfalse' \
  > declare-define/TYPE1.expected

printf 'declare a : int\ndefine a = 1\ndefine g = proc(x:int):int set x = 5\n.g(a)\na' \
  > call-by-reference/TYPE1.input
printf 'a:int\na:int\ng:[int=>int]\n5\n5' \
  > call-by-reference/TYPE1.expected

printf 'if 1 then 1 else 2\nif true then 1 else false\n+(1,true)\n+(1)\n.1(2)\nlet x = 1 in set x = true\nproc(x:int):bool 5\ndeclare b : int\ndefine b = true' \
  > type-errors/TYPE1.input
printf 'type mismatch: int != bool\ntype mismatch: bool != int\ntype mismatch: bool != int\nargument number mismatch\nint: attempt to apply a non-procedure\ntype mismatch: bool != int\ntype mismatch: int != bool\nb:int\ntype mismatch: bool != int' \
  > type-errors/TYPE1.expected
```

Every one of those expected files is measured output, byte-identical across all three targets.

`type-errors/` is the scoped exception to the value-cases-only rule that every language since V3 has followed. It is justified because rejection *is* TYPE1's feature: all six `checkEquals`/`checkEqualTypes`/`procType` sites could be deleted and a value-only suite would still pass. It needs no harness support — a language error goes to **stdout**, `plcc-rep` exits **0**, and evaluation **continues to the next expression**, all measured. Do not extend it to inherited runtime diagnostics (divide by zero, unbound identifier, duplicate ID, `not an Int`, `formals/args number mismatch`); those belong to languages that already shipped.

- [ ] **Step 6: Create the five `.bats` files with their Python blocks**

Replace `src/TYPE1/tests/proc-types/TYPE1test.bats` entirely — the existing one drives old PLCC via `plccmk`/`rep -n` and is the suite's `not ok 68`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 proc-types (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/proc-types/TYPE1.input)"
  expected_output=$(< "../tests/proc-types/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

Create the other four the same way, changing only the case name in the `@test` description and in the two paths. For `boolean-ops`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 boolean-ops (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/boolean-ops/TYPE1.input)"
  expected_output=$(< "../tests/boolean-ops/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `declare-define`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 declare-define (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/declare-define/TYPE1.input)"
  expected_output=$(< "../tests/declare-define/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `call-by-reference`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 call-by-reference (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/call-by-reference/TYPE1.input)"
  expected_output=$(< "../tests/call-by-reference/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `type-errors`:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "TYPE1 type-errors (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/type-errors/TYPE1.input)"
  expected_output=$(< "../tests/type-errors/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 7: Run the TYPE1 tests**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
bats --recursive src/TYPE1/tests
```

Expected: 5 tests, all passing.

Diagnostics if not: a `type-errors` failure on the `.1(2)` line means `AppExp.evalType` still calls a separate `checkProcType()` instead of letting `procType()` raise. A `call-by-reference` failure printing `1` on the last line means `Rands.evalRandsRef` was written the pre-migration TYPE1 way. A `boolean-ops` failure showing `True`/`False` instead of `true`/`false` means `BoolVal.__str__` lost its conditional.

- [ ] **Step 8: Confirm the four `Prog/` examples still run**

They are course material, not tests, but they are the best available evidence that the port is faithful — all four were measured running unmodified during design.

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/python
for p in fact oe compose count; do printf '=== %s ===\n' "$p"; plcc-rep < "../Prog/$p"; done
```

Expected: `fact` ends `120`; `oe` prints four `sym:type` lines and nothing else; `compose` ends `56`; `count` ends with the sequence `1 4 9 16 25 0 1 4 9 16 25`. Do not edit any `Prog/` file to make this pass — if one fails, the spec is wrong.

- [ ] **Step 9: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type1-task2.txt`. Confirm `EXIT=1`, then count.

Expected: **156 tests, 155 passing, 1 failing.** That is the baseline's 152, minus TYPE1's 1 old test, plus 5 new Python tests. The single remaining failure is `OBJ class`. Any other failure is a regression; stop and fix it.

- [ ] **Step 10: Add the course-material impact entries**

Append a `## TYPE1` section to `dev-docs/course-material-impact.md`, after the existing `## TYPE0` section, matching the prose style of the sections already there. Cover, one bullet each:

- The `VAR` → `SYMBOL` token rename and the `var` → `symbol` field rename, the standing convention since V0.
- `$run()` → `_run()`, which **returns** its output string rather than printing it — in `Declare` and `Define` as well as `Eval`.
- `Type.intType` → `Type.intType()`, and the six prim signatures likewise (`Type.ii_b` → `Type.ii_b()`), with `Type.compile("ii>b")` and `decodeType` gone entirely. Explain why: a class attribute is evaluated at class-definition time, which makes the `Type`/`IntType` import cycle load-order dependent in Python and JavaScript, and Java adopts the same shape so all three read alike.
- `Type.checkEquals(a, b)` → `a.checkEquals(b)`, and the 0-argument `checkProcType()` folded into `procType()` — both because Python and JavaScript cannot carry the Java overloads, and both visible at call sites.
- `Val.isTrue()` raising `boolean expression expected` where pre-migration TYPE1 returned `false`, restoring the shape TYPE0 introduced.
- The retained prim arity guards and the added `formals/args number mismatch` check, neither of which pre-migration TYPE1 had. Note that the type checker catches both statically first, with `argument number mismatch`.
- **Call-by-reference restored.** Give the observable: with `define g = proc(x:int):int set x = 5`, calling `.g(a)` now mutates the caller's `a`, as in REF and TYPE0. Then give the soundness argument, which is lecture material in its own right: aliasing is safe here only because `checkEquals` is *exact* structural equality with no subtyping or variance, so `AppExp.evalType` and `SetExp.evalType` compose to guarantee that only values of `a`'s own declared type can reach `a`'s cell. This is the concrete answer to "why must `[int=>int]` match exactly rather than merely be compatible?"
- `ProcVal.toString()` now printing the full proc type — `proc():int`, `proc(x:int,g:[int,int=>bool]):bool` — where TYPE0 printed bare `proc`.
- The new `type-errors/` test case, and the scoped exception to the value-cases-only rule that justifies it.

- [ ] **Step 11: Commit**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
git add src/TYPE1/grammar.plcc src/TYPE1/python src/TYPE1/tests dev-docs/course-material-impact.md
git commit -m "feat(TYPE1): port grammar and Python target to plcc-ng

Refs #NN"
```

Replace `NN` with the number from Task 1.

---

### Task 3: Java target

Adds `src/TYPE1/java/spec.plcc` and a Java `@test` block to each of the five `.bats` files.

**Files:**
- Create: `src/TYPE1/java/spec.plcc`
- Modify: `src/TYPE1/tests/{proc-types,boolean-ops,declare-define,call-by-reference,type-errors}/TYPE1test.bats`
- Test: `bats --recursive src/TYPE1/tests`, then the full suite

**Interfaces:**
- Consumes: `src/TYPE1/grammar.plcc` and the five test case fixtures from Task 2. Same class and method names as the Python spec — `Type.intType()`, `Type.ii_b()`, `Type.checkEqualTypes(...)`, `TypeEnv.initTypeEnv()`, `TypeBindings(List<Token>, List<Type>)`, `Exp.evalType(TypeEnv)`, `TypeExp.toType()`, `Prim.definedType()`, `ProcVal(Formals, TypeExp, Exp, Env)`.
- Produces: a Java target passing the same five expected files.

- [ ] **Step 1: Create the Java spec**

Write `src/TYPE1/java/spec.plcc` with exactly this content:

```
%include ../grammar.plcc
%
Java

%include ../../Env/envRef/java/env.plcc

Val
%%%
import java.util.List;
import runtime.LanguageError;

public abstract class Val {

    public static Val [] toArray(List<Val> valList) {
        int n = valList.size();
        return valList.toArray(new Val[n]);
    }

    public Val apply(List<Ref> args, Env e) {
        throw new LanguageError("Cannot apply " + this);
    }

    public boolean isTrue() {
        throw new LanguageError("boolean expression expected");
    }

    public IntVal intVal() {
        throw new LanguageError(this + ": not an Int");
    }

    public BoolVal boolVal() {
        throw new LanguageError(this + ": not a Bool");
    }
}
%%%

IntVal
%%%
public class IntVal extends Val {

    public int val;

    public IntVal(String s) {
        val = Integer.parseInt(s);
    }

    public IntVal(int v) {
        val = v;
    }

    public IntVal intVal() {
        return this;
    }

    public String toString() {
        return "" + val;
    }
}
%%%

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

ProcVal
%%%
import java.util.List;
import runtime.LanguageError;

public class ProcVal extends Val {

    public Formals formals;
    public TypeExp returnTypeExp;
    public Exp body;
    public Env env;

    public ProcVal(Formals formals, TypeExp returnTypeExp, Exp body, Env env) {
        this.formals = formals;
        this.returnTypeExp = returnTypeExp;
        this.body = body;
        this.env = env;
    }

    public Val apply(List<Ref> args, Env e) {
        if (formals.symbolList.size() != args.size())
            throw new LanguageError("formals/args number mismatch");
        Bindings bindings = new Bindings(formals.symbolList, args);
        Env nenv = env.extendEnvRef(bindings);
        return body.eval(nenv);
    }

    public String toString() {
        return "proc(" + formals + "):" + returnTypeExp.toType();
    }
}
%%%

Type
%%%
import java.util.Arrays;
import java.util.List;
import runtime.LanguageError;

public abstract class Type {

    // The canonical types are factory methods rather than static
    // fields. Java could hold them as static finals, but Python and
    // JavaScript cannot: a class-body attribute is evaluated when the
    // class body runs, which would force Type to import its own
    // subclasses at module scope and leave the Type/IntType import
    // cycle depending on load order. Java follows the same shape so
    // the three targets read alike.
    //
    // Returning a fresh instance per call is safe: the types are
    // stateless and checkEquals is structural, never identity.

    public static IntType intType() {
        return new IntType();
    }

    public static BoolType boolType() {
        return new BoolType();
    }

    public static ProcType ii_i() {
        return new ProcType(Arrays.asList(intType(), intType()), intType());
    }

    public static ProcType i_i() {
        return new ProcType(Arrays.asList((Type) intType()), intType());
    }

    public static ProcType ii_b() {
        return new ProcType(Arrays.asList(intType(), intType()), boolType());
    }

    public static ProcType i_b() {
        return new ProcType(Arrays.asList((Type) intType()), boolType());
    }

    public static ProcType bb_b() {
        return new ProcType(Arrays.asList(boolType(), boolType()), boolType());
    }

    public static ProcType b_b() {
        return new ProcType(Arrays.asList((Type) boolType()), boolType());
    }

    // this Type as a ProcType, or an error if it is not one
    public ProcType procType() {
        throw new LanguageError(this + ": attempt to apply a non-procedure");
    }

    public abstract void checkEquals(Type t);

    public static void checkEqualTypes(List<Type> typeList1,
                                       List<Type> typeList2) {
        if (typeList1.size() != typeList2.size())
            throw new LanguageError("argument number mismatch");
        for (int i = 0; i < typeList1.size(); i++)
            typeList1.get(i).checkEquals(typeList2.get(i));
    }

    public void checkIntType(IntType t) {
        typeMismatch(this, t);
    }

    public void checkBoolType(BoolType t) {
        typeMismatch(this, t);
    }

    public void checkProcType(ProcType t) {
        typeMismatch(this, t);
    }

    public static void typeMismatch(Type t1, Type t2) {
        throw new LanguageError("type mismatch: " + t1 + " != " + t2);
    }
}
%%%

IntType
%%%
public class IntType extends Type {

    public void checkEquals(Type t) {
        t.checkIntType(this);
    }

    public void checkIntType(IntType t) {
        // this IntType equals any other IntType
    }

    public String toString() {
        return "int";
    }
}
%%%

BoolType
%%%
public class BoolType extends Type {

    public void checkEquals(Type t) {
        t.checkBoolType(this);
    }

    public void checkBoolType(BoolType t) {
        // this BoolType equals any other BoolType
    }

    public String toString() {
        return "bool";
    }
}
%%%

ProcType
%%%
import java.util.List;

// the declared type of a procedure
public class ProcType extends Type {

    public List<Type> paramTypeList;
    public Type returnType;

    public ProcType(List<Type> paramTypeList, Type returnType) {
        this.paramTypeList = paramTypeList;
        this.returnType = returnType;
    }

    public ProcType procType() {
        return this;
    }

    public void checkEquals(Type t) {
        t.checkProcType(this);
    }

    public void checkProcType(ProcType t) {
        this.returnType.checkEquals(t.returnType);
        checkEqualTypes(this.paramTypeList, t.paramTypeList);
    }

    public String toString() {
        String s = "[";
        String sep = "";
        for (Type t : paramTypeList) {
            s += sep + t;
            sep = ",";
        }
        return s + "=>" + returnType + "]";
    }
}
%%%

TypeEnv
%%%
import runtime.LanguageError;

public abstract class TypeEnv {

    public static TypeEnv initTypeEnv() {
        return new TypeEnvNode(new TypeBindings(), new TypeEnvNull());
    }

    public Type applyTypeEnv(String sym) {
        throw new LanguageError("no type binding for " + sym);
    }

    public void add(TypeBinding b) {
        throw new LanguageError("no type bindings to add to");
    }

    public TypeEnv extendTypeEnv(TypeBindings bindings) {
        return new TypeEnvNode(bindings, this);
    }
}
%%%

TypeEnvNode
%%%
public class TypeEnvNode extends TypeEnv {

    public TypeBindings bindings;   // local type bindings
    public TypeEnv typeEnv;         // next set of type bindings

    public TypeEnvNode(TypeBindings bindings, TypeEnv typeEnv) {
        this.bindings = bindings;
        this.typeEnv = typeEnv;
    }

    public Type applyTypeEnv(String sym) {
        for (TypeBinding b : bindings.bindingList)
            if (sym.equals(b.id))
                return b.type;
        return typeEnv.applyTypeEnv(sym);
    }

    public void add(TypeBinding b) {
        bindings.add(b);
    }

    public String toString() {
        return bindings + "\n" + typeEnv;
    }
}
%%%

TypeEnvNull
%%%
public class TypeEnvNull extends TypeEnv {

    public String toString() {
        return "\n";
    }
}
%%%

TypeBinding
%%%
public class TypeBinding {

    public String id;
    public Type type;

    public TypeBinding(String id, Type type) {
        this.id = id;
        this.type = type;
    }

    public String toString() {
        return "[" + id + "->" + type + "]";
    }
}
%%%

TypeBindings
%%%
import java.util.ArrayList;
import java.util.List;
import runtime.Token;
import runtime.LanguageError;

public class TypeBindings {

    public List<TypeBinding> bindingList;

    public TypeBindings() {
        bindingList = new ArrayList<TypeBinding>();
    }

    public TypeBindings(List<Token> idList, List<Type> typeList) {
        if (idList.size() != typeList.size())
            throw new LanguageError("list sizes mismatch");
        bindingList = new ArrayList<TypeBinding>(idList.size());
        for (int i = 0; i < idList.size(); i++)
            bindingList.add(new TypeBinding(idList.get(i).lexeme,
                                            typeList.get(i)));
    }

    public void add(TypeBinding b) {
        bindingList.add(b);
    }

    public String toString() {
        String s = "";
        for (TypeBinding b : bindingList)
            s += " " + b;
        return s;
    }
}
%%%

Program
%%%
public static Env env = Env.initEnv();
public static TypeEnv tenv = TypeEnv.initTypeEnv();
%%%

Declare
%%%
public String _run() {
    TypeEnv tenv = Program.tenv;
    String sym = symbol.lexeme;
    try {
        tenv.applyTypeEnv(sym);
    } catch (LanguageError e) {
        // no type binding -- a new type declaration, which we add
        // to the top-level type environment
        Type varType = typeExp.toType();
        tenv.add(new TypeBinding(sym, varType));
        return sym + ":" + varType;
    }
    throw new LanguageError(sym + ": duplicate variable declaration");
}
%%%

Define
%%%
public String _run() {
    Env env = Program.env;
    TypeEnv tenv = Program.tenv;
    String sym = symbol.lexeme;
    Type lhsVarType;
    try {
        lhsVarType = tenv.applyTypeEnv(sym);
    } catch (LanguageError e) {
        // no type binding -- a new variable definition
        Type rhsExpType = exp.evalType(tenv);
        tenv.add(new TypeBinding(sym, rhsExpType));
        Val rhsExpVal = exp.eval(env);
        env.add(new Binding(sym, new ValRef(rhsExpVal)));
        return sym + ":" + rhsExpType;
    }
    // the variable has a declared type -- see if it still needs a value
    try {
        env.applyEnv(sym);
    } catch (LanguageError e) {
        Type rhsExpType = exp.evalType(tenv);
        // the declared and defined types must be the same
        lhsVarType.checkEquals(rhsExpType);
        Val rhsExpVal = exp.eval(env);
        env.add(new Binding(sym, new ValRef(rhsExpVal)));
        return sym + ":" + rhsExpType;
    }
    // the variable has a value too -- can't redefine it
    throw new LanguageError(sym + ": duplicate variable definition");
}
%%%

Eval
%%%
public String _run() {
    exp.evalType(Program.tenv);     // type check first
    return exp.eval(Program.env).toString();
}
%%%

Exp
%%%
public abstract Val eval(Env env);

public Ref evalRef(Env env) {
    return new ValRef(eval(env));
}

public abstract Type evalType(TypeEnv tenv);
%%%

LitExp
%%%
public Val eval(Env env) {
    return new IntVal(lit.lexeme);
}

public Type evalType(TypeEnv tenv) {
    return Type.intType();
}

public String toString() {
    return lit.lexeme;
}
%%%

TrueExp
%%%
public Val eval(Env env) {
    return new BoolVal(true);
}

public Type evalType(TypeEnv tenv) {
    return Type.boolType();
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

public Type evalType(TypeEnv tenv) {
    return Type.boolType();
}

public String toString() {
    return "false";
}
%%%

VarExp
%%%
public Val eval(Env env) {
    return env.applyEnv(symbol.lexeme);
}

public Ref evalRef(Env env) {
    return env.applyEnvRef(symbol.lexeme);
}

public Type evalType(TypeEnv tenv) {
    return tenv.applyTypeEnv(symbol.lexeme);
}

public String toString() {
    return symbol.lexeme;
}
%%%

IfExp
%%%
public Val eval(Env env) {
    if (testExp.eval(env).isTrue())
        return trueExp.eval(env);
    else
        return falseExp.eval(env);
}

public Type evalType(TypeEnv tenv) {
    Type testType = testExp.evalType(tenv);
    testType.checkBoolType(Type.boolType());
    Type trueExpType = trueExp.evalType(tenv);
    Type falseExpType = falseExp.evalType(tenv);
    trueExpType.checkEquals(falseExpType);
    return trueExpType;
}

public String toString() {
    return "if " + testExp + " then " + trueExp + " else " + falseExp;
}
%%%

PrimappExp
%%%
public Val eval(Env env) {
    List<Val> args = rands.evalRands(env);
    Val [] va = Val.toArray(args);
    return prim.apply(va);
}

public Type evalType(TypeEnv tenv) {
    ProcType pt = prim.definedType();
    List<Type> argTypeList = rands.evalTypeRands(tenv);
    Type.checkEqualTypes(pt.paramTypeList, argTypeList);
    return pt.returnType;
}

public String toString() {
    return prim + "(" + rands + ")";
}
%%%

LetExp
%%%
public Val eval(Env env) {
    Env nenv = letDecls.addBindings(env);
    return exp.eval(nenv);
}

public Type evalType(TypeEnv tenv) {
    TypeEnv ntenv = letDecls.addTypeBindings(tenv);
    return exp.evalType(ntenv);
}

public String toString() {
    return " ...LetExp... ";
}
%%%

LetrecExp
%%%
public Val eval(Env env) {
    Env nenv = letDecls.addLetrecBindings(env);
    return exp.eval(nenv);
}

public Type evalType(TypeEnv tenv) {
    TypeEnv ntenv = letDecls.addLetrecTypeBindings(tenv);
    return exp.evalType(ntenv);
}

public String toString() {
    return " ...LetrecExp... ";
}
%%%

LetDecls:import
%%%
import java.util.ArrayList;
%%%

LetDecls:init
%%%
Env.checkDuplicates(symbolList, " in let/letrec LHS identifiers");
%%%

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

public TypeEnv addTypeBindings(TypeEnv tenv) {
    List<Type> typeList = new ArrayList<Type>(expList.size());
    for (Exp e : expList)
        typeList.add(e.evalType(tenv));
    return tenv.extendTypeEnv(new TypeBindings(symbolList, typeList));
}

public TypeEnv addLetrecTypeBindings(TypeEnv tenv) {
    tenv = tenv.extendTypeEnv(new TypeBindings());
    for (int i = 0; i < symbolList.size(); i++) {
        Type typ = expList.get(i).evalType(tenv);
        tenv.add(new TypeBinding(symbolList.get(i).lexeme, typ));
    }
    return tenv;
}

public String toString() {
    return " ...LetDecls... ";
}
%%%

ProcExp
%%%
public Val eval(Env env) {
    return proc.makeClosure(env);
}

public Type evalType(TypeEnv tenv) {
    return proc.evalType(tenv);
}

public String toString() {
    return " ...ProcExp... ";
}
%%%

Proc
%%%
public Val makeClosure(Env env) {
    return new ProcVal(formals, typeExp, exp, env);
}

public Type evalType(TypeEnv tenv) {
    // the declared return type of the proc
    Type declaredReturnType = typeExp.toType();
    // bind the formal parameters to their declared types
    TypeEnv ntenv = tenv.extendTypeEnv(formals.declaredTypeBindings());
    // type the body in that extended type environment
    Type expType = exp.evalType(ntenv);
    // and check that the declared return type matches the body's
    declaredReturnType.checkEquals(expType);
    return new ProcType(formals.formalTypeList(), declaredReturnType);
}
%%%

Formals:import
%%%
import java.util.ArrayList;
%%%

Formals:init
%%%
Env.checkDuplicates(symbolList, " in proc formals");
%%%

Formals
%%%
public List<Type> formalTypeList() {
    List<Type> typeList = new ArrayList<Type>(typeExpList.size());
    for (TypeExp texp : typeExpList)
        typeList.add(texp.toType());
    return typeList;
}

public TypeBindings declaredTypeBindings() {
    return new TypeBindings(symbolList, formalTypeList());
}

public String toString() {
    String s = "";
    String sep = "";
    for (int i = 0; i < symbolList.size(); i++) {
        s += sep + symbolList.get(i).lexeme + ":"
                 + typeExpList.get(i).toType();
        sep = ",";
    }
    return s;
}
%%%

AppExp
%%%
public Val eval(Env env) {
    Val v = exp.eval(env);
    List<Ref> args = rands.evalRandsRef(env);
    return v.apply(args, env);
}

public Type evalType(TypeEnv tenv) {
    ProcType pt = exp.evalType(tenv).procType();
    List<Type> argTypeList = rands.evalTypeRands(tenv);
    Type.checkEqualTypes(pt.paramTypeList, argTypeList);
    return pt.returnType;
}

public String toString() {
    return " ...AppExp... ";
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

public Type evalType(TypeEnv tenv) {
    Type t = exp.evalType(tenv);
    for (Exp e : seqExps.expList)
        t = e.evalType(tenv);
    return t;
}

public String toString() {
    return " ...SeqExp... ";
}
%%%

SetExp
%%%
public Val eval(Env env) {
    Val v = exp.eval(env);
    Ref ref = env.applyEnvRef(symbol.lexeme);
    return ref.setRef(v);
}

public Type evalType(TypeEnv tenv) {
    Type varType = tenv.applyTypeEnv(symbol.lexeme);
    Type expType = exp.evalType(tenv);
    varType.checkEquals(expType);
    return varType;
}

public String toString() {
    return " ...SetExp... ";
}
%%%

Rands:import
%%%
import java.util.ArrayList;
%%%

Rands
%%%
public List<Val> evalRands(Env env) {
    List<Val> args = new ArrayList<Val>(expList.size());
    for (Exp e : expList)
        args.add(e.eval(env));
    return args;
}

public List<Ref> evalRandsRef(Env env) {
    List<Ref> refList = new ArrayList<Ref>(expList.size());
    for (Exp e : expList)
        refList.add(e.evalRef(env));
    return refList;
}

public List<Type> evalTypeRands(TypeEnv tenv) {
    List<Type> typeList = new ArrayList<Type>(expList.size());
    for (Exp e : expList)
        typeList.add(e.evalType(tenv));
    return typeList;
}

public String toString() {
    String s = "";
    String sep = "";
    for (Exp e : expList) {
        s += sep + e;
        sep = ",";
    }
    return s;
}
%%%

TypeExp
%%%
public abstract Type toType();
%%%

PrimTypeExp
%%%
public Type toType() {
    return primType.toType();
}
%%%

ProcTypeExp
%%%
public Type toType() {
    return new ProcType(typeExps.toTypes(), typeExp.toType());
}
%%%

TypeExps:import
%%%
import java.util.ArrayList;
%%%

TypeExps
%%%
public List<Type> toTypes() {
    List<Type> paramTypeList = new ArrayList<Type>(typeExpList.size());
    for (TypeExp te : typeExpList)
        paramTypeList.add(te.toType());
    return paramTypeList;
}
%%%

PrimType
%%%
public abstract Type toType();
%%%

BoolPrimType
%%%
public Type toType() {
    return Type.boolType();
}
%%%

IntPrimType
%%%
public Type toType() {
    return Type.intType();
}
%%%

Prim
%%%
public abstract Val apply(Val [] va);

public abstract ProcType definedType();
%%%

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

public ProcType definedType() {
    return Type.ii_i();
}
%%%

SubPrim
%%%
public String toString() {
    return "-";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new IntVal(i0 - i1);
}

public ProcType definedType() {
    return Type.ii_i();
}
%%%

MulPrim
%%%
public String toString() {
    return "*";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    return new IntVal(i0 * i1);
}

public ProcType definedType() {
    return Type.ii_i();
}
%%%

DivPrim
%%%
public String toString() {
    return "/";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    int i0 = va[0].intVal().val;
    int i1 = va[1].intVal().val;
    if (i1 == 0)
        throw new LanguageError("attempt to divide by zero");
    return new IntVal(i0 / i1);
}

public ProcType definedType() {
    return Type.ii_i();
}
%%%

Add1Prim
%%%
public String toString() {
    return "add1";
}

public Val apply(Val [] va) {
    if (va.length != 1)
        throw new LanguageError("one argument expected");
    int i0 = va[0].intVal().val;
    return new IntVal(i0 + 1);
}

public ProcType definedType() {
    return Type.i_i();
}
%%%

Sub1Prim
%%%
public String toString() {
    return "sub1";
}

public Val apply(Val [] va) {
    if (va.length != 1)
        throw new LanguageError("one argument expected");
    int i0 = va[0].intVal().val;
    return new IntVal(i0 - 1);
}

public ProcType definedType() {
    return Type.i_i();
}
%%%

ZeropPrim
%%%
public String toString() {
    return "zero?";
}

public Val apply(Val [] va) {
    if (va.length != 1)
        throw new LanguageError("one argument expected");
    int i0 = va[0].intVal().val;
    return new BoolVal(i0 == 0);
}

public ProcType definedType() {
    return Type.i_b();
}
%%%

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

public ProcType definedType() {
    return Type.ii_b();
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

public ProcType definedType() {
    return Type.ii_b();
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

public ProcType definedType() {
    return Type.ii_b();
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

public ProcType definedType() {
    return Type.ii_b();
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

public ProcType definedType() {
    return Type.ii_b();
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

public ProcType definedType() {
    return Type.ii_b();
}
%%%

AndPrim
%%%
public String toString() {
    return "and";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    boolean b0 = va[0].boolVal().val;
    boolean b1 = va[1].boolVal().val;
    return new BoolVal(b0 && b1);
}

public ProcType definedType() {
    return Type.bb_b();
}
%%%

OrPrim
%%%
public String toString() {
    return "or";
}

public Val apply(Val [] va) {
    if (va.length != 2)
        throw new LanguageError("two arguments expected");
    boolean b0 = va[0].boolVal().val;
    boolean b1 = va[1].boolVal().val;
    return new BoolVal(b0 || b1);
}

public ProcType definedType() {
    return Type.bb_b();
}
%%%

NotPrim
%%%
public String toString() {
    return "not";
}

public Val apply(Val [] va) {
    if (va.length != 1)
        throw new LanguageError("one argument expected");
    boolean b0 = va[0].boolVal().val;
    return new BoolVal(!b0);
}

public ProcType definedType() {
    return Type.b_b();
}
%%%
```

Four Java-only mechanics in that file were found by running it, not by reading, and are the likely failure points if you deviate:

1. **Grammar-derived Java classes get `java.util.List` auto-injected but not `ArrayList`.** `LetDecls`, `Rands`, `Formals`, and `TypeExps` each carry their own `:import` block containing `import java.util.ArrayList;`. TYPE0's spec already needed this for `LetDecls` and `Rands`; `Formals` and `TypeExps` are new in this phase because their TYPE1 methods build lists. Omitting one is a compile error naming the class, not a silent failure.
2. **The `Prim` block declares both abstract methods** — `public abstract Val apply(Val [] va);` and `public abstract ProcType definedType();`. TYPE0's spec has only the first. Without the second, `PrimappExp.evalType` fails to compile with `cannot find symbol: method definedType()`.
3. **Java prims take `Val [] va`, not a list**, and `Val.toArray` is therefore **kept** in Java where Python and JavaScript have no such method. This mirrors TYPE0 exactly and is not new divergence.
4. **`Type.ii_i()` and friends use `Arrays.asList(...)`**, which is why `Type` imports `java.util.Arrays`. The single-parameter signatures cast their argument — `Arrays.asList((Type) intType())` — so the inferred element type is `Type` rather than `IntType`; without the cast the returned `List<IntType>` will not satisfy `ProcType`'s `List<Type>` parameter.

Everything else matches the Python spec method-for-method, deliberately: same class inventory, same method names, same control flow. Java keeps two `TypeBindings` constructors where Python uses default arguments, which is the one permitted kind of divergence — an overload standing in for a default argument, invisible at every call site, exactly as the shipped `Bindings` port already does.

- [ ] **Step 2: Smoke-test the Java target**

```bash
mkdir -p /tmp/type1-scratch/java && cd /tmp/type1-scratch/java
printf 'declare f : [=>int]\ndeclare y : int\ndefine f = proc():int y\ndefine y = 3\n.f()\n' \
  | plcc-rep -s /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/java/spec.plcc
```

Expected, exactly:

```
f:[=>int]
y:int
f:[=>int]
y:int
3
```

Compile errors print before any output and name the file and line; read them rather than guessing.

- [ ] **Step 3: Append the Java `@test` blocks**

Append one block to each of the five `.bats` files. Do **not** add a second `load` pair. For `proc-types/TYPE1test.bats`:

```bash
@test "TYPE1 proc-types (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/proc-types/TYPE1.input)"
  expected_output=$(< "../tests/proc-types/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `boolean-ops/TYPE1test.bats`:

```bash
@test "TYPE1 boolean-ops (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/boolean-ops/TYPE1.input)"
  expected_output=$(< "../tests/boolean-ops/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `declare-define/TYPE1test.bats`:

```bash
@test "TYPE1 declare-define (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/declare-define/TYPE1.input)"
  expected_output=$(< "../tests/declare-define/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `call-by-reference/TYPE1test.bats`:

```bash
@test "TYPE1 call-by-reference (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/call-by-reference/TYPE1.input)"
  expected_output=$(< "../tests/call-by-reference/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `type-errors/TYPE1test.bats`:

```bash
@test "TYPE1 type-errors (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/type-errors/TYPE1.input)"
  expected_output=$(< "../tests/type-errors/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 4: Run the TYPE1 tests**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
bats --recursive src/TYPE1/tests
```

Expected: 10 tests, all passing — 5 Python, 5 Java, against the same five expected files.

- [ ] **Step 5: Confirm the `Prog/` examples under Java**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/java
for p in fact oe compose count; do printf '=== %s ===\n' "$p"; plcc-rep < "../Prog/$p"; done
```

Expected: byte-identical to Task 2 Step 8's Python output.

- [ ] **Step 6: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type1-task3.txt`. Confirm `EXIT=1`, then count.

Expected: **161 tests, 160 passing, 1 failing** — Task 2's 156 plus 5 Java tests, with `OBJ class` still the only failure.

- [ ] **Step 7: Commit**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
git add src/TYPE1/java src/TYPE1/tests
git commit -m "feat(TYPE1): port Java target to plcc-ng

Refs #NN"
```

---

### Task 4: JavaScript target

Adds `src/TYPE1/javascript/spec.plcc` and a JavaScript `@test` block to each of the five `.bats` files.

**Files:**
- Create: `src/TYPE1/javascript/spec.plcc`
- Modify: `src/TYPE1/tests/{proc-types,boolean-ops,declare-define,call-by-reference,type-errors}/TYPE1test.bats`
- Test: `bats --recursive src/TYPE1/tests`, then the full suite

**Interfaces:**
- Consumes: `src/TYPE1/grammar.plcc` and the five test case fixtures from Task 2. Same class and method names as the Python and Java specs.
- Produces: the third target, completing the language.

- [ ] **Step 1: Create the JavaScript spec**

Write `src/TYPE1/javascript/spec.plcc` with exactly this content:

```
%include ../grammar.plcc
%
javascript

%include ../../Env/envRef/javascript/env.plcc

Val
%%%
const { LanguageError } = require('./runtime/base');

class Val {

    apply(args, env) {
        throw new LanguageError(`Cannot apply ${this}`);
    }

    isTrue() {
        throw new LanguageError("boolean expression expected");
    }

    intVal() {
        throw new LanguageError(`${this}: not an Int`);
    }

    boolVal() {
        throw new LanguageError(`${this}: not a Bool`);
    }
}

module.exports = { Val };
%%%

IntVal
%%%
const { Val } = require('./Val');

class IntVal extends Val {

    constructor(val) {
        super();
        this.val = parseInt(val, 10);
    }

    intVal() {
        return this;
    }

    toString() {
        return String(this.val);
    }
}

module.exports = { IntVal };
%%%

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
        return String(this.val);
    }
}

module.exports = { ValRef };
%%%

ProcVal
%%%
const { Val } = require('./Val');
const { Bindings } = require('./Bindings');
const { LanguageError } = require('./runtime/base');

class ProcVal extends Val {

    constructor(formals, returnTypeExp, body, env) {
        super();
        this.formals = formals;
        this.returnTypeExp = returnTypeExp;
        this.body = body;
        this.env = env;
    }

    apply(args, env) {
        if (this.formals.symbolList.length !== args.length)
            throw new LanguageError("formals/args number mismatch");
        const bindings = new Bindings(this.formals.symbolList, args);
        const nenv = this.env.extendEnvRef(bindings);
        return this.body.eval(nenv);
    }

    toString() {
        return `proc(${this.formals}):${this.returnTypeExp.toType()}`;
    }
}

module.exports = { ProcVal };
%%%

Type
%%%
const { LanguageError } = require('./runtime/base');

// The canonical types are factory methods rather than static fields.
// A static class field is evaluated when the class body runs, which
// would force Type to require its own subclasses at module scope and
// leave the Type/IntType require cycle depending on load order.
// Deferring the require into the method body is the same fix
// Env.initEnv() uses. Java follows suit so the three targets read
// alike, even though only Python and JavaScript need it.
//
// Returning a fresh instance per call is safe: the types are stateless
// and checkEquals is structural, never identity.

class Type {

    static intType() {
        const { IntType } = require('./IntType');
        return new IntType();
    }

    static boolType() {
        const { BoolType } = require('./BoolType');
        return new BoolType();
    }

    static ii_i() {
        const { ProcType } = require('./ProcType');
        return new ProcType([Type.intType(), Type.intType()], Type.intType());
    }

    static i_i() {
        const { ProcType } = require('./ProcType');
        return new ProcType([Type.intType()], Type.intType());
    }

    static ii_b() {
        const { ProcType } = require('./ProcType');
        return new ProcType([Type.intType(), Type.intType()], Type.boolType());
    }

    static i_b() {
        const { ProcType } = require('./ProcType');
        return new ProcType([Type.intType()], Type.boolType());
    }

    static bb_b() {
        const { ProcType } = require('./ProcType');
        return new ProcType([Type.boolType(), Type.boolType()], Type.boolType());
    }

    static b_b() {
        const { ProcType } = require('./ProcType');
        return new ProcType([Type.boolType()], Type.boolType());
    }

    // this Type as a ProcType, or an error if it is not one
    procType() {
        throw new LanguageError(`${this}: attempt to apply a non-procedure`);
    }

    checkEquals(t) {
        throw new Error("not implemented");
    }

    static checkEqualTypes(typeList1, typeList2) {
        if (typeList1.length !== typeList2.length)
            throw new LanguageError("argument number mismatch");
        for (let i = 0; i < typeList1.length; i++)
            typeList1[i].checkEquals(typeList2[i]);
    }

    checkIntType(t) {
        Type.typeMismatch(this, t);
    }

    checkBoolType(t) {
        Type.typeMismatch(this, t);
    }

    checkProcType(t) {
        Type.typeMismatch(this, t);
    }

    static typeMismatch(t1, t2) {
        throw new LanguageError(`type mismatch: ${t1} != ${t2}`);
    }
}

module.exports = { Type };
%%%

IntType
%%%
const { Type } = require('./Type');

class IntType extends Type {

    checkEquals(t) {
        t.checkIntType(this);
    }

    checkIntType(t) {
        // this IntType equals any other IntType
    }

    toString() {
        return "int";
    }
}

module.exports = { IntType };
%%%

BoolType
%%%
const { Type } = require('./Type');

class BoolType extends Type {

    checkEquals(t) {
        t.checkBoolType(this);
    }

    checkBoolType(t) {
        // this BoolType equals any other BoolType
    }

    toString() {
        return "bool";
    }
}

module.exports = { BoolType };
%%%

ProcType
%%%
const { Type } = require('./Type');

// the declared type of a procedure
class ProcType extends Type {

    constructor(paramTypeList, returnType) {
        super();
        this.paramTypeList = paramTypeList;
        this.returnType = returnType;
    }

    procType() {
        return this;
    }

    checkEquals(t) {
        t.checkProcType(this);
    }

    checkProcType(t) {
        this.returnType.checkEquals(t.returnType);
        Type.checkEqualTypes(this.paramTypeList, t.paramTypeList);
    }

    toString() {
        const params = this.paramTypeList.map(t => String(t)).join(",");
        return `[${params}=>${this.returnType}]`;
    }
}

module.exports = { ProcType };
%%%

TypeEnv
%%%
const { LanguageError } = require('./runtime/base');

class TypeEnv {

    static initTypeEnv() {
        const { TypeEnvNode } = require('./TypeEnvNode');
        const { TypeEnvNull } = require('./TypeEnvNull');
        const { TypeBindings } = require('./TypeBindings');
        return new TypeEnvNode(new TypeBindings(), new TypeEnvNull());
    }

    applyTypeEnv(sym) {
        throw new LanguageError("no type binding for " + sym);
    }

    add(b) {
        throw new LanguageError("no type bindings to add to");
    }

    extendTypeEnv(bindings) {
        const { TypeEnvNode } = require('./TypeEnvNode');
        return new TypeEnvNode(bindings, this);
    }
}

module.exports = { TypeEnv };
%%%

TypeEnvNode
%%%
const { TypeEnv } = require('./TypeEnv');

class TypeEnvNode extends TypeEnv {

    constructor(bindings, typeEnv) {
        super();
        this.bindings = bindings;
        this.typeEnv = typeEnv;
    }

    applyTypeEnv(sym) {
        for (const b of this.bindings.bindingList)
            if (sym === b.id)
                return b.type;
        return this.typeEnv.applyTypeEnv(sym);
    }

    add(b) {
        this.bindings.add(b);
    }

    toString() {
        return `${this.bindings}\n${this.typeEnv}`;
    }
}

module.exports = { TypeEnvNode };
%%%

TypeEnvNull
%%%
const { TypeEnv } = require('./TypeEnv');

class TypeEnvNull extends TypeEnv {

    toString() {
        return "\n";
    }
}

module.exports = { TypeEnvNull };
%%%

TypeBinding
%%%
class TypeBinding {

    constructor(id, type) {
        this.id = id;
        this.type = type;
    }

    toString() {
        return `[${this.id}->${this.type}]`;
    }
}

module.exports = { TypeBinding };
%%%

TypeBindings
%%%
const { TypeBinding } = require('./TypeBinding');
const { LanguageError } = require('./runtime/base');

class TypeBindings {

    constructor(idList = null, typeList = null) {
        this.bindingList = [];
        if (idList !== null) {
            if (typeList === null || idList.length !== typeList.length)
                throw new LanguageError("list sizes mismatch");
            for (let i = 0; i < idList.length; i++)
                this.bindingList.push(new TypeBinding(idList[i].lexeme,
                                                      typeList[i]));
        }
    }

    add(b) {
        this.bindingList.push(b);
    }

    toString() {
        let s = "";
        for (const b of this.bindingList)
            s += " " + b;
        return s;
    }
}

module.exports = { TypeBindings };
%%%

Program:import
%%%
const { Env } = require('./Env');
const { TypeEnv } = require('./TypeEnv');
%%%

Program
%%%
static env = Env.initEnv();
static tenv = TypeEnv.initTypeEnv();
%%%

Declare:import
%%%
const { TypeBinding } = require('./TypeBinding');
%%%

Declare
%%%
_run() {
    const tenv = Program.tenv;
    const sym = this.symbol.lexeme;
    try {
        tenv.applyTypeEnv(sym);
    } catch (e) {
        // JavaScript has no typed catch, so re-throw anything that is
        // not a language error rather than swallowing it.
        if (!(e instanceof LanguageError)) throw e;
        // no type binding -- a new type declaration, which we add
        // to the top-level type environment
        const varType = this.typeExp.toType();
        tenv.add(new TypeBinding(sym, varType));
        return `${sym}:${varType}`;
    }
    throw new LanguageError(`${sym}: duplicate variable declaration`);
}
%%%

Define:import
%%%
const { Binding } = require('./Binding');
const { ValRef } = require('./ValRef');
const { TypeBinding } = require('./TypeBinding');
%%%

Define
%%%
_run() {
    const env = Program.env;
    const tenv = Program.tenv;
    const sym = this.symbol.lexeme;
    let lhsVarType;
    try {
        lhsVarType = tenv.applyTypeEnv(sym);
    } catch (e) {
        if (!(e instanceof LanguageError)) throw e;
        // no type binding -- a new variable definition
        const rhsExpType = this.exp.evalType(tenv);
        tenv.add(new TypeBinding(sym, rhsExpType));
        const rhsExpVal = this.exp.eval(env);
        env.add(new Binding(sym, new ValRef(rhsExpVal)));
        return `${sym}:${rhsExpType}`;
    }
    // the variable has a declared type -- see if it still needs a value
    try {
        env.applyEnv(sym);
    } catch (e) {
        if (!(e instanceof LanguageError)) throw e;
        const rhsExpType = this.exp.evalType(tenv);
        // the declared and defined types must be the same
        lhsVarType.checkEquals(rhsExpType);
        const rhsExpVal = this.exp.eval(env);
        env.add(new Binding(sym, new ValRef(rhsExpVal)));
        return `${sym}:${rhsExpType}`;
    }
    // the variable has a value too -- can't redefine it
    throw new LanguageError(`${sym}: duplicate variable definition`);
}
%%%

Eval
%%%
_run() {
    this.exp.evalType(Program.tenv);     // type check first
    return String(this.exp.eval(Program.env));
}
%%%

Exp:import
%%%
const { ValRef } = require('./ValRef');
%%%

Exp
%%%
evalRef(env) {
    return new ValRef(this.eval(env));
}

evalType(tenv) {
    throw new Error("not implemented");
}
%%%

LitExp:import
%%%
const { IntVal } = require('./IntVal');
const { Type } = require('./Type');
%%%

LitExp
%%%
eval(env) {
    return new IntVal(this.lit.lexeme);
}

evalType(tenv) {
    return Type.intType();
}

toString() {
    return this.lit.lexeme;
}
%%%

TrueExp:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
%%%

TrueExp
%%%
eval(env) {
    return new BoolVal(true);
}

evalType(tenv) {
    return Type.boolType();
}

toString() {
    return "true";
}
%%%

FalseExp:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
%%%

FalseExp
%%%
eval(env) {
    return new BoolVal(false);
}

evalType(tenv) {
    return Type.boolType();
}

toString() {
    return "false";
}
%%%

VarExp
%%%
eval(env) {
    return env.applyEnv(this.symbol.lexeme);
}

evalRef(env) {
    return env.applyEnvRef(this.symbol.lexeme);
}

evalType(tenv) {
    return tenv.applyTypeEnv(this.symbol.lexeme);
}

toString() {
    return this.symbol.lexeme;
}
%%%

IfExp:import
%%%
const { Type } = require('./Type');
%%%

IfExp
%%%
eval(env) {
    if (this.testExp.eval(env).isTrue())
        return this.trueExp.eval(env);
    else
        return this.falseExp.eval(env);
}

evalType(tenv) {
    const testType = this.testExp.evalType(tenv);
    testType.checkBoolType(Type.boolType());
    const trueExpType = this.trueExp.evalType(tenv);
    const falseExpType = this.falseExp.evalType(tenv);
    trueExpType.checkEquals(falseExpType);
    return trueExpType;
}

toString() {
    return `if ${this.testExp} then ${this.trueExp} else ${this.falseExp}`;
}
%%%

PrimappExp:import
%%%
const { Type } = require('./Type');
%%%

PrimappExp
%%%
eval(env) {
    const args = this.rands.evalRands(env);
    return this.prim.apply(args);
}

evalType(tenv) {
    const pt = this.prim.definedType();
    const argTypeList = this.rands.evalTypeRands(tenv);
    Type.checkEqualTypes(pt.paramTypeList, argTypeList);
    return pt.returnType;
}

toString() {
    return `${this.prim}(${this.rands})`;
}
%%%

LetExp
%%%
eval(env) {
    const nenv = this.letDecls.addBindings(env);
    return this.exp.eval(nenv);
}

evalType(tenv) {
    const ntenv = this.letDecls.addTypeBindings(tenv);
    return this.exp.evalType(ntenv);
}

toString() {
    return " ...LetExp... ";
}
%%%

LetrecExp
%%%
eval(env) {
    const nenv = this.letDecls.addLetrecBindings(env);
    return this.exp.eval(nenv);
}

evalType(tenv) {
    const ntenv = this.letDecls.addLetrecTypeBindings(tenv);
    return this.exp.evalType(ntenv);
}

toString() {
    return " ...LetrecExp... ";
}
%%%

LetDecls:import
%%%
const { Env } = require('./Env');
const { Binding } = require('./Binding');
const { Bindings } = require('./Bindings');
const { Ref } = require('./Ref');
const { ValRef } = require('./ValRef');
const { TypeBinding } = require('./TypeBinding');
const { TypeBindings } = require('./TypeBindings');
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

addTypeBindings(tenv) {
    const typeList = this.expList.map(e => e.evalType(tenv));
    return tenv.extendTypeEnv(new TypeBindings(this.symbolList, typeList));
}

addLetrecTypeBindings(tenv) {
    tenv = tenv.extendTypeEnv(new TypeBindings());
    for (let i = 0; i < this.symbolList.length; i++) {
        const typ = this.expList[i].evalType(tenv);
        tenv.add(new TypeBinding(this.symbolList[i].lexeme, typ));
    }
    return tenv;
}

toString() {
    return " ...LetDecls... ";
}
%%%

ProcExp
%%%
eval(env) {
    return this.proc.makeClosure(env);
}

evalType(tenv) {
    return this.proc.evalType(tenv);
}

toString() {
    return " ...ProcExp... ";
}
%%%

Proc:import
%%%
const { ProcVal } = require('./ProcVal');
const { ProcType } = require('./ProcType');
%%%

Proc
%%%
makeClosure(env) {
    return new ProcVal(this.formals, this.typeExp, this.exp, env);
}

evalType(tenv) {
    // the declared return type of the proc
    const declaredReturnType = this.typeExp.toType();
    // bind the formal parameters to their declared types
    const ntenv = tenv.extendTypeEnv(this.formals.declaredTypeBindings());
    // type the body in that extended type environment
    const expType = this.exp.evalType(ntenv);
    // and check that the declared return type matches the body's
    declaredReturnType.checkEquals(expType);
    return new ProcType(this.formals.formalTypeList(), declaredReturnType);
}
%%%

Formals:import
%%%
const { Env } = require('./Env');
const { TypeBindings } = require('./TypeBindings');
%%%

Formals:init
%%%
Env.checkDuplicates(this.symbolList, " in proc formals");
%%%

Formals
%%%
formalTypeList() {
    return this.typeExpList.map(texp => texp.toType());
}

declaredTypeBindings() {
    return new TypeBindings(this.symbolList, this.formalTypeList());
}

toString() {
    return this.symbolList
        .map((sym, i) => `${sym.lexeme}:${this.typeExpList[i].toType()}`)
        .join(",");
}
%%%

AppExp:import
%%%
const { Type } = require('./Type');
%%%

AppExp
%%%
eval(env) {
    const v = this.exp.eval(env);
    const args = this.rands.evalRandsRef(env);
    return v.apply(args, env);
}

evalType(tenv) {
    const pt = this.exp.evalType(tenv).procType();
    const argTypeList = this.rands.evalTypeRands(tenv);
    Type.checkEqualTypes(pt.paramTypeList, argTypeList);
    return pt.returnType;
}

toString() {
    return " ...AppExp... ";
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

evalType(tenv) {
    let t = this.exp.evalType(tenv);
    for (const e of this.seqExps.expList)
        t = e.evalType(tenv);
    return t;
}

toString() {
    return " ...SeqExp... ";
}
%%%

SetExp
%%%
eval(env) {
    const v = this.exp.eval(env);
    const ref = env.applyEnvRef(this.symbol.lexeme);
    return ref.setRef(v);
}

evalType(tenv) {
    const varType = tenv.applyTypeEnv(this.symbol.lexeme);
    const expType = this.exp.evalType(tenv);
    varType.checkEquals(expType);
    return varType;
}

toString() {
    return " ...SetExp... ";
}
%%%

Rands
%%%
evalRands(env) {
    return this.expList.map(e => e.eval(env));
}

evalRandsRef(env) {
    return this.expList.map(e => e.evalRef(env));
}

evalTypeRands(tenv) {
    return this.expList.map(e => e.evalType(tenv));
}

toString() {
    return this.expList.map(e => String(e)).join(",");
}
%%%

TypeExp
%%%
toType() {
    throw new Error("not implemented");
}
%%%

PrimTypeExp
%%%
toType() {
    return this.primType.toType();
}
%%%

ProcTypeExp:import
%%%
const { ProcType } = require('./ProcType');
%%%

ProcTypeExp
%%%
toType() {
    return new ProcType(this.typeExps.toTypes(), this.typeExp.toType());
}
%%%

TypeExps
%%%
toTypes() {
    return this.typeExpList.map(te => te.toType());
}
%%%

PrimType
%%%
toType() {
    throw new Error("not implemented");
}
%%%

BoolPrimType:import
%%%
const { Type } = require('./Type');
%%%

BoolPrimType
%%%
toType() {
    return Type.boolType();
}
%%%

IntPrimType:import
%%%
const { Type } = require('./Type');
%%%

IntPrimType
%%%
toType() {
    return Type.intType();
}
%%%

AddPrim:import
%%%
const { IntVal } = require('./IntVal');
const { Type } = require('./Type');
%%%

AddPrim
%%%
toString() {
    return "+";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new IntVal(i0 + i1);
}

definedType() {
    return Type.ii_i();
}
%%%

SubPrim:import
%%%
const { IntVal } = require('./IntVal');
const { Type } = require('./Type');
%%%

SubPrim
%%%
toString() {
    return "-";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new IntVal(i0 - i1);
}

definedType() {
    return Type.ii_i();
}
%%%

MulPrim:import
%%%
const { IntVal } = require('./IntVal');
const { Type } = require('./Type');
%%%

MulPrim
%%%
toString() {
    return "*";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    return new IntVal(i0 * i1);
}

definedType() {
    return Type.ii_i();
}
%%%

DivPrim:import
%%%
const { IntVal } = require('./IntVal');
const { Type } = require('./Type');
%%%

DivPrim
%%%
toString() {
    return "/";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const i0 = args[0].intVal().val;
    const i1 = args[1].intVal().val;
    if (i1 === 0)
        throw new LanguageError("attempt to divide by zero");
    return new IntVal(Math.trunc(i0 / i1));
}

definedType() {
    return Type.ii_i();
}
%%%

Add1Prim:import
%%%
const { IntVal } = require('./IntVal');
const { Type } = require('./Type');
%%%

Add1Prim
%%%
toString() {
    return "add1";
}

apply(args) {
    if (args.length !== 1)
        throw new LanguageError("one argument expected");
    const i0 = args[0].intVal().val;
    return new IntVal(i0 + 1);
}

definedType() {
    return Type.i_i();
}
%%%

Sub1Prim:import
%%%
const { IntVal } = require('./IntVal');
const { Type } = require('./Type');
%%%

Sub1Prim
%%%
toString() {
    return "sub1";
}

apply(args) {
    if (args.length !== 1)
        throw new LanguageError("one argument expected");
    const i0 = args[0].intVal().val;
    return new IntVal(i0 - 1);
}

definedType() {
    return Type.i_i();
}
%%%

ZeropPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
%%%

ZeropPrim
%%%
toString() {
    return "zero?";
}

apply(args) {
    if (args.length !== 1)
        throw new LanguageError("one argument expected");
    const i0 = args[0].intVal().val;
    return new BoolVal(i0 === 0);
}

definedType() {
    return Type.i_b();
}
%%%

LTPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
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

definedType() {
    return Type.ii_b();
}
%%%

LEPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
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

definedType() {
    return Type.ii_b();
}
%%%

GTPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
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

definedType() {
    return Type.ii_b();
}
%%%

GEPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
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

definedType() {
    return Type.ii_b();
}
%%%

EQPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
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

definedType() {
    return Type.ii_b();
}
%%%

NEPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
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

definedType() {
    return Type.ii_b();
}
%%%

AndPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
%%%

AndPrim
%%%
toString() {
    return "and";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const b0 = args[0].boolVal().val;
    const b1 = args[1].boolVal().val;
    return new BoolVal(b0 && b1);
}

definedType() {
    return Type.bb_b();
}
%%%

OrPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
%%%

OrPrim
%%%
toString() {
    return "or";
}

apply(args) {
    if (args.length !== 2)
        throw new LanguageError("two arguments expected");
    const b0 = args[0].boolVal().val;
    const b1 = args[1].boolVal().val;
    return new BoolVal(b0 || b1);
}

definedType() {
    return Type.bb_b();
}
%%%

NotPrim:import
%%%
const { BoolVal } = require('./BoolVal');
const { Type } = require('./Type');
%%%

NotPrim
%%%
toString() {
    return "not";
}

apply(args) {
    if (args.length !== 1)
        throw new LanguageError("one argument expected");
    const b0 = args[0].boolVal().val;
    return new BoolVal(!b0);
}

definedType() {
    return Type.b_b();
}
%%%
```

Three JavaScript-only mechanics to preserve:

1. **JavaScript has no typed `catch`.** `Declare` and `Define` guard each handler with `if (!(e instanceof LanguageError)) throw e;` before treating the exception as "no binding found". Dropping that line makes a genuine `TypeError` — a real bug in the spec — look like an undeclared variable and silently produce a wrong answer. This is one extra line per handler in one target and is the only place the three targets' control flow differs.
2. **Grammar-derived classes must not re-require `Node`, `Token`, or `LanguageError`.** plcc-ng auto-injects `const { Node, Token, LanguageError } = require('./runtime/base');` into every generated grammar class file; naming one again in a `:import` block fails at load with `Identifier 'LanguageError' has already been declared`. Note that the prims' `:import` blocks here name only `IntVal`/`BoolVal` and `Type` for exactly this reason, even though their bodies throw `LanguageError`.
3. **Free-standing classes get no auto-injected requires and need explicit ones plus a `module.exports`.** All nine new classes have both. `Type`'s subclass requires are deliberately *inside* the static methods; hoisting them to the top of the file recreates the `Type`/`IntType` require cycle.

- [ ] **Step 2: Smoke-test the JavaScript target**

```bash
mkdir -p /tmp/type1-scratch/js && cd /tmp/type1-scratch/js
printf 'declare f : [=>int]\ndeclare y : int\ndefine f = proc():int y\ndefine y = 3\n.f()\n' \
  | plcc-rep -s /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/javascript/spec.plcc
```

Expected, exactly:

```
f:[=>int]
y:int
f:[=>int]
y:int
3
```

- [ ] **Step 3: Append the JavaScript `@test` blocks**

Append one block to each of the five `.bats` files. Do **not** add a second `load` pair. For `proc-types/TYPE1test.bats`:

```bash
@test "TYPE1 proc-types (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/proc-types/TYPE1.input)"
  expected_output=$(< "../tests/proc-types/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `boolean-ops/TYPE1test.bats`:

```bash
@test "TYPE1 boolean-ops (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/boolean-ops/TYPE1.input)"
  expected_output=$(< "../tests/boolean-ops/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `declare-define/TYPE1test.bats`:

```bash
@test "TYPE1 declare-define (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/declare-define/TYPE1.input)"
  expected_output=$(< "../tests/declare-define/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `call-by-reference/TYPE1test.bats`:

```bash
@test "TYPE1 call-by-reference (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/call-by-reference/TYPE1.input)"
  expected_output=$(< "../tests/call-by-reference/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

For `type-errors/TYPE1test.bats`:

```bash
@test "TYPE1 type-errors (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/type-errors/TYPE1.input)"
  expected_output=$(< "../tests/type-errors/TYPE1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 4: Run the TYPE1 tests**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
bats --recursive src/TYPE1/tests
```

Expected: 15 tests, all passing — 5 cases × 3 targets.

- [ ] **Step 5: Confirm the `Prog/` examples under JavaScript**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1/src/TYPE1/javascript
for p in fact oe compose count; do printf '=== %s ===\n' "$p"; plcc-rep < "../Prog/$p"; done
```

Expected: byte-identical to Tasks 2 and 3.

- [ ] **Step 6: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type1-task4.txt`. Confirm `EXIT=1`, then count.

Expected: **166 tests, 165 passing, 1 failing** — Task 3's 161 plus 5 JavaScript tests, with `OBJ class` the sole remaining failure and the only `plccmk: command not found` left in the repository.

- [ ] **Step 7: Commit**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
git add src/TYPE1/javascript src/TYPE1/tests
git commit -m "feat(TYPE1): port JavaScript target to plcc-ng

Refs #NN"
```

---

### Task 5: Remove TYPE1's old-PLCC files and close the issue

**Files:**
- Delete: `src/TYPE1/{grammar,code,prim,envRef,val,ref,tenv,type}`
- Modify: `dev-docs/issues/0NN-migrate-type1-to-plcc-ng.md` and `dev-docs/roadmap.md`, both via `bin/issues/close.bash`
- Test: the full suite

**Interfaces:**
- Consumes: `NN` from Task 1; a green three-target port from Task 4.
- Produces: nothing later depends on.

- [ ] **Step 1: Delete the eight flat old-PLCC files**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
git rm src/TYPE1/grammar src/TYPE1/code src/TYPE1/prim src/TYPE1/envRef \
       src/TYPE1/val src/TYPE1/ref src/TYPE1/tenv src/TYPE1/type
```

None of these collides with a new path — `src/TYPE1/grammar` versus `src/TYPE1/grammar.plcc` — which is why the deletion comes last, following the REF, NAME, NEED, and TYPE0 ordering rather than SET's.

**Keep `src/TYPE1/Prog/` and `src/TYPE1/J/EO.java`.** `Prog/` is course material that every migrated language retains, and all four of its programs were confirmed running in Tasks 2 through 4. `J/EO.java` is a tracked Java illustration accompanying `Prog/oe`; issue [#15](../issues/015-gitignore-java-pattern-shadows-source-dirs.md) names it explicitly as a real source file. It is the repository's only `J/` directory, which is a pre-existing oddity and not this phase's to resolve.

- [ ] **Step 2: Confirm nothing referenced them**

```bash
grep -rn "TYPE1/\(code\|prim\|envRef\|val\|ref\|tenv\|type\)\b" --include='*.bats' --include='*.bash' --include='*.md' . \
  | grep -v dev-docs/specs | grep -v dev-docs/plans
```

Expected: no output. Matches inside `dev-docs/specs/` and `dev-docs/plans/` are historical references in design and plan documents and are correct to leave.

- [ ] **Step 3: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/type1-task5.txt`. Confirm `EXIT=1`, then count.

Expected: **166 tests, 165 passing, 1 failing** — unchanged from Task 4. The deletion removes source files, not tests. A drop in the total means a `.bats` file was deleted by accident.

- [ ] **Step 4: Commit the deletion**

```bash
git commit -m "refactor(TYPE1): remove old-PLCC sources superseded by the plcc-ng port

Refs #NN"
```

- [ ] **Step 5: Close the issue**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
bin/issues/close.bash NN
bin/issues/check.bash
```

`close.bash` fills in the issue's `closed` date and updates `dev-docs/roadmap.md`. `check.bash` must report no errors.

- [ ] **Step 6: Commit the close**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): close issue NN (migrate TYPE1 to plcc-ng), update roadmap"
```

This is the branch's final commit.

- [ ] **Step 7: Final verification**

```bash
cd /workspaces/languages-ng/.claude/worktrees/type1
git status --short
```

Expected: clean. No `plcc-ng/`, `__pycache__/`, or `*.class` artifacts staged or untracked-and-unignored.

```bash
git log --oneline --no-merges 011ae7a..HEAD
git branch --show-current
```

Expected: **eight** commits on branch `type1` — the design doc and this plan (both already present before Task 1), then the issue filing, the three target ports, the deletion, and the close. `git branch --show-current` must print `type1`.

Confirm the commits are on `type1` and **not** on `main`: `git log --oneline -1 main` must still be `011ae7a`. A reported SHA says nothing about which branch it landed on, and work in a worktree has previously been committed to `main` by accident.

---

## Phase 4 is complete

With TYPE1 green in all three targets, **OBJ is the only language left on old PLCC** and the only remaining `plccmk: command not found`. Its phase should diff its `envRef` fork against `src/Env/envRef/<target>/env.plcc` — the ported canonical shape — not against any per-language flat file, all of which are now gone from the working tree and survive only in git history.

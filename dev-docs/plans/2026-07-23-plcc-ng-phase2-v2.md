# plcc-ng Migration — Phase 2 (V2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port V2's grammar and Python/Java/JavaScript semantics to `plcc-ng`. V2 is `V1 + IfExp` — same `Env` variant (`envRN`, already ported under `src/Env/envRN/<target>/` by V1), same seven `Prim`s and `Val`/`IntVal`, plus one new grammar production (`IfExp`) and its semantics in all three targets.

**Architecture:** Unlike V1, V2 does no new `Env` porting work — `envRN` already exists at `src/Env/envRN/<target>/env.plcc` and is reused via the same `%include ../../Env/envRN/<target>/env.plcc` V1 established. The only genuinely new mechanic is `IfExp`, which captures the same nonterminal (`Exp`) three times in one alternative (`testexp`/`trueexp`/`falseexp`) — the first rule in this migration to do that. A live smoke test against the installed `plcc-ng` CLI (done while writing this plan) found that camelCase alt-names for repeated captures break at runtime (parser lowercases them, codegen doesn't — filed as issue #6), and confirmed the workaround: spell the alt-names entirely in lowercase in the grammar. That's reflected in the grammar and semantic code below, which were both validated end-to-end (all three targets parse and evaluate correctly) before being written down here.

**Tech Stack:** `plcc-ng` CLI (`plcc-scan`, `plcc-parse`, `plcc-rep`), `bats-core` (via `bin/test.bash`), bash, Python 3.12+, Java JDK 21+, Node.js 18+. All already available in this devcontainer.

## Global Constraints

- Scope is V2 only. Do not touch V3–V6 or `envVal` in this plan.
- `Env`: no new porting work. Reuse `src/Env/envRN/<target>/env.plcc` exactly as V1 left it, via `%include ../../Env/envRN/<target>/env.plcc`.
- `Val`/`IntVal`/`Prim` (all seven: `AddPrim`, `SubPrim`, `MulPrim`, `DivPrim`, `Add1Prim`, `Sub1Prim`, `ZeropPrim`): identical logic to V1's — same truncating-division rule, same argument-count checks, same error messages. Copy V1's code verbatim per target; do not modify it.
- **`IfExp`'s repeated `Exp` capture must use all-lowercase alt-names** — `<Exp:testexp>`, `<Exp:trueexp>`, `<Exp:falseexp>` — not camelCase. This works around a live `plcc-ng` bug (issue #6): the parser always lowercases an alt-name when building the runtime tree, but code generation preserves whatever case the alt-name was written in, so a camelCase alt-name produces a class field the parser can never actually supply a value for (`KeyError: "No class for rule 'IfExp' with fields {'testexp', ...}"` at runtime). Semantic code in all three targets therefore reads `self.testexp` / `testexp` / `this.testexp` (all lowercase), not `testExp`.
- Structural fidelity across targets: method names (`eval`, `apply`, `evalRands`, `isTrue`, `intVal`, `applyEnv`) stay identical across Python, Java, and JavaScript, same as V1.
- JavaScript: grammar-derived classes (anything that's an alternative of a grammar nonterminal — `IfExp` included) get `Node`/`Token`/`LanguageError` auto-injected already; an explicit `:import` for those three names on such a class fails with `Identifier 'X' has already been declared`. `IfExp` itself needs no `:import` block at all — it never references `Val`/`IntVal`/`LanguageError` by name, only through polymorphic `.eval()`/`.isTrue()` calls.
- Every test case gets one shared `<LANG>.input` / `<LANG>.expected` pair, asserted against by one `@test` block per target in a single `.bats` file.
- Any genuine `plcc-ng` bug or migration-guide gap discovered gets filed as an issue in **this** repo (`bin/issues/new.bash`), `Target: ourPLCC/plcc-ng`, no upstream filing without explicit go-ahead. Per the recently-clarified convention ([dev-docs/issue-conventions.md](../issue-conventions.md)), such issues stay open until upstream actually fixes the defect and the local workaround is reverted — not merely reported.
- Any change affecting course material (renamed fields, changed casing conventions) gets logged in [dev-docs/course-material-impact.md](../course-material-impact.md) under V2's heading, in the same commit that makes the change.
- Full design context: [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md) (see its Phase 2 notes for the `IfExp` alt-name casing finding this plan relies on) and issue [006](../issues/006-multi-capture-alt-name-case-mismatch.md).

---

## Task 1: File the V2 issue

**Files:**
- Create: `dev-docs/issues/007-migrate-v2-to-plcc-ng.md` (generated, filename includes the assigned id)
- Modify: `dev-docs/roadmap.md`

- [ ] **Step 1: Generate the issue file**

Run: `bin/issues/new.bash migrate-v2-to-plcc-ng feat`
Expected output: `dev-docs/issues/007-migrate-v2-to-plcc-ng.md`

- [ ] **Step 2: Fill in the issue's Description and Notes**

Edit `dev-docs/issues/007-migrate-v2-to-plcc-ng.md`:

```markdown
## Description

Port V2's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V2 is
V1 + IfExp: it reuses the envRN Env variant and V1's Prim/Val unchanged,
adding only the IfExp grammar production and its semantics. V3–V6 are
explicitly out of scope for this issue.

## Notes

See [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md),
[dev-docs/plans/2026-07-23-plcc-ng-phase2-v2.md](../plans/2026-07-23-plcc-ng-phase2-v2.md),
and [issue #6](006-multi-capture-alt-name-case-mismatch.md) (IfExp's
repeated-capture alt-names must be all-lowercase).
```

(Delete the `## Steps to Reproduce` section — not a bug.)

- [ ] **Step 3: Add the roadmap entry**

Edit `dev-docs/roadmap.md`. Add under the existing `### Feat` group (create it if V1's entry was already removed by its own close):

```markdown
### Feat

- **[#7](issues/007-migrate-v2-to-plcc-ng.md) — Migrate V2 to plcc-ng**
  Ports V2's grammar and Java semantics to plcc-ng syntax, adds Python and JavaScript semantics, reusing envRN and V1's Prim/Val unchanged.
```

- [ ] **Step 4: Commit**

```bash
git add dev-docs/issues/007-migrate-v2-to-plcc-ng.md dev-docs/roadmap.md
git commit -m "$(cat <<'EOF'
docs(issues): file 007 - migrate V2 to plcc-ng

Refs #7
EOF
)"
```

---

## Task 2: Create the shared V2 grammar and verify scan/parse

**Files:**
- Create: `src/V2/grammar.plcc`
- Modify: `dev-docs/course-material-impact.md`

- [ ] **Step 1: Write `src/V2/grammar.plcc`**

```text
# Language V2
#   Language V1 + if...then...else
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
token VAR '[A-Za-z]\w*'
%
<Program>        ::= <Exp>
<Exp:LitExp>     ::= <LIT>
<Exp:VarExp>     ::= <VAR:name>
<Exp:IfExp>      ::= IF <Exp:testexp> THEN <Exp:trueexp> ELSE <Exp:falseexp>
<Exp:PrimappExp> ::= <Prim> LPAREN <Rands> RPAREN
<Rands>          **= <Exp> +COMMA
<Prim:AddPrim>   ::= ADDOP
<Prim:SubPrim>   ::= SUBOP
<Prim:MulPrim>   ::= MULOP
<Prim:DivPrim>   ::= DIVOP
<Prim:Add1Prim>  ::= ADD1OP
<Prim:Sub1Prim>  ::= SUB1OP
<Prim:ZeropPrim> ::= ZEROP
```

`IF`/`THEN`/`ELSE` are declared before `VAR`, same as the old grammar's order — `VAR`'s `[A-Za-z]\w*` pattern would otherwise also match the literal keywords.

- [ ] **Step 2: Verify the lexical + syntactic sections alone**

```bash
cd src/V2
echo "if if 1 then 0 else 1 then 42 else 15" | plcc-parse -s grammar.plcc
```

Expected output:

```
Program
  IfExp
    IfExp
      LitExp
        LIT '1' [-:1:7]
      LitExp
        LIT '0' [-:1:14]
      LitExp
        LIT '1' [-:1:21]
    LitExp
      LIT '42' [-:1:28]
    LitExp
      LIT '15' [-:1:36]
```

Clean up and return:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Log the course-material impact**

Add to `dev-docs/course-material-impact.md`, after the existing `## V1` section:

```markdown
## V2

- Same `VAR`-field rename as V0/V1: the captured field is `name`, not
  `var`.
- `IfExp`'s three `Exp` children are captured as `testexp`, `trueexp`,
  `falseexp` — **all lowercase**, not the camelCase `testExp`/`trueExp`/
  `falseExp` the old PLCC grammar used. This isn't a style choice: a
  camelCase alt-name on a repeated nonterminal capture hits a live
  `plcc-ng` bug (parser vs. codegen disagree on casing — see issue #6),
  so the lowercase spelling is required, not optional. Course material
  walking through `IfExp.eval()` should refer to `self.testexp` /
  `testexp` / `this.testexp`, etc., not the old camelCase names.
```

- [ ] **Step 4: Commit**

```bash
git add src/V2/grammar.plcc dev-docs/course-material-impact.md
git commit -m "$(cat <<'EOF'
feat(V2): add plcc-ng grammar (lexical + syntactic sections)

IfExp's repeated Exp capture uses all-lowercase alt-names (testexp/
trueexp/falseexp) to work around issue #6 -- a camelCase alt-name on a
repeated nonterminal capture produces a class field the parser can
never supply a value for, since the parser always lowercases alt-names
but codegen doesn't.

Refs #7
EOF
)"
```

---

## Task 3: Add V2 Python semantics

**Files:**
- Create: `src/V2/python/spec.plcc`

Reuses `src/Env/envRN/python/env.plcc` as-is (no changes). `Val`, `IntVal`, and all seven `Prim` classes are copied verbatim from `src/V1/python/spec.plcc`; only `IfExp` is new.

- [ ] **Step 1: Write `src/V2/python/spec.plcc`**

```text
%include ../grammar.plcc
%
Python

%include ../../Env/envRN/python/env.plcc

Val
%%%
from runtime.base import LanguageError


class Val:

    def isTrue(self):
        return True

    def intVal(self):
        raise LanguageError(f"{self}: not an Int")
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

    def isTrue(self):
        return self.val != 0
%%%

Program:import
%%%
from Env import Env
%%%

Program
%%%
env = Env.initEnv()

def _run(self):
    print(self.exp.eval(Program.env))
%%%

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

VarExp
%%%
def eval(self, env):
    return env.applyEnv(self.name.lexeme)

def __str__(self):
    return self.name.lexeme
%%%

IfExp
%%%
def eval(self, env):
    if self.testexp.eval(env).isTrue():
        return self.trueexp.eval(env)
    else:
        return self.falseexp.eval(env)

def __str__(self):
    return f"if {self.testexp} then {self.trueexp} else {self.falseexp}"
%%%

PrimappExp
%%%
def eval(self, env):
    args = self.rands.evalRands(env)
    return self.prim.apply(args)

def __str__(self):
    return f"{self.prim}({self.rands})"
%%%

Rands
%%%
def evalRands(self, env):
    return [e.eval(env) for e in self.expList]

def __str__(self):
    return ",".join(str(e) for e in self.expList)
%%%

AddPrim:import
%%%
from IntVal import IntVal
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
%%%

SubPrim:import
%%%
from IntVal import IntVal
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
%%%

MulPrim:import
%%%
from IntVal import IntVal
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
%%%

DivPrim:import
%%%
from IntVal import IntVal
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
%%%

Add1Prim:import
%%%
from IntVal import IntVal
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
%%%

Sub1Prim:import
%%%
from IntVal import IntVal
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
%%%

ZeropPrim:import
%%%
from IntVal import IntVal
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
    return IntVal(1 if i0 == 0 else 0)
%%%
```

- [ ] **Step 2: Verify manually**

```bash
cd src/V2/python
echo "if x then add1(v) else sub1(m)" | plcc-rep
```

Expected output: `6` (envRN: `x` → 10, truthy; `add1(v)` → `add1(5)` → `6`)

```bash
echo "if if 1 then 0 else 1 then 42 else 15" | plcc-rep
```

Expected output: `15`

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Commit**

```bash
git add src/V2/python/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V2): add Python semantics

Reuses envRN and V1's Val/IntVal/Prim classes unchanged; IfExp is the
only new class, reading the all-lowercase testexp/trueexp/falseexp
fields established in grammar.plcc.

Refs #7
EOF
)"
```

---

## Task 4: Add V2 Java semantics

**Files:**
- Create: `src/V2/java/spec.plcc`

Same reuse pattern as Task 3: `Val`/`IntVal`/all seven `Prim`s copied verbatim from `src/V1/java/spec.plcc`.

- [ ] **Step 1: Write `src/V2/java/spec.plcc`**

```text
%include ../grammar.plcc
%
Java

%include ../../Env/envRN/java/env.plcc

Val
%%%
import runtime.LanguageError;

public abstract class Val {

    public boolean isTrue() {
        return true;
    }

    public IntVal intVal() {
        throw new LanguageError(this + ": not an Int");
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

    public boolean isTrue() {
        return val != 0;
    }
}
%%%

Program
%%%
public static Env env = Env.initEnv();

public void _run() {
    System.out.println(exp.eval(env));
}
%%%

Exp
%%%
public abstract Val eval(Env env);
%%%

LitExp
%%%
public Val eval(Env env) {
    return new IntVal(lit.lexeme);
}

public String toString() {
    return lit.lexeme;
}
%%%

VarExp
%%%
public Val eval(Env env) {
    return env.applyEnv(name.lexeme);
}

public String toString() {
    return name.lexeme;
}
%%%

IfExp
%%%
public Val eval(Env env) {
    Val testVal = testexp.eval(env);
    if (testVal.isTrue())
        return trueexp.eval(env);
    else
        return falseexp.eval(env);
}

public String toString() {
    return "if " + testexp + " then " + trueexp + " else " + falseexp;
}
%%%

PrimappExp
%%%
public Val eval(Env env) {
    List<Val> args = rands.evalRands(env);
    return prim.apply(args);
}

public String toString() {
    return prim + "(" + rands + ")";
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

Prim
%%%
public abstract Val apply(List<Val> args);
%%%

AddPrim
%%%
public String toString() {
    return "+";
}

public Val apply(List<Val> args) {
    if (args.size() != 2)
        throw new LanguageError("two arguments expected");
    int i0 = args.get(0).intVal().val;
    int i1 = args.get(1).intVal().val;
    return new IntVal(i0 + i1);
}
%%%

SubPrim
%%%
public String toString() {
    return "-";
}

public Val apply(List<Val> args) {
    if (args.size() != 2)
        throw new LanguageError("two arguments expected");
    int i0 = args.get(0).intVal().val;
    int i1 = args.get(1).intVal().val;
    return new IntVal(i0 - i1);
}
%%%

MulPrim
%%%
public String toString() {
    return "*";
}

public Val apply(List<Val> args) {
    if (args.size() != 2)
        throw new LanguageError("two arguments expected");
    int i0 = args.get(0).intVal().val;
    int i1 = args.get(1).intVal().val;
    return new IntVal(i0 * i1);
}
%%%

DivPrim
%%%
public String toString() {
    return "/";
}

public Val apply(List<Val> args) {
    if (args.size() != 2)
        throw new LanguageError("two arguments expected");
    int i0 = args.get(0).intVal().val;
    int i1 = args.get(1).intVal().val;
    if (i1 == 0)
        throw new LanguageError("attempt to divide by zero");
    return new IntVal(i0 / i1);
}
%%%

Add1Prim
%%%
public String toString() {
    return "add1";
}

public Val apply(List<Val> args) {
    if (args.size() != 1)
        throw new LanguageError("one argument expected");
    int i0 = args.get(0).intVal().val;
    return new IntVal(i0 + 1);
}
%%%

Sub1Prim
%%%
public String toString() {
    return "sub1";
}

public Val apply(List<Val> args) {
    if (args.size() != 1)
        throw new LanguageError("one argument expected");
    int i0 = args.get(0).intVal().val;
    return new IntVal(i0 - 1);
}
%%%

ZeropPrim
%%%
public String toString() {
    return "zero?";
}

public Val apply(List<Val> args) {
    if (args.size() != 1)
        throw new LanguageError("one argument expected");
    int i0 = args.get(0).intVal().val;
    return new IntVal(i0 == 0 ? 1 : 0);
}
%%%
```

`IfExp` needs no `:import` — `Val`, `Env`, and `LanguageError` are all either same-directory (package-less) classes or already in scope via `Exp`'s own type.

- [ ] **Step 2: Verify manually**

```bash
cd src/V2/java
echo "if x then add1(v) else sub1(m)" | plcc-rep
```

Expected output: `6`

```bash
echo "if if 1 then 0 else 1 then 42 else 15" | plcc-rep
```

Expected output: `15`

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Commit**

```bash
git add src/V2/java/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V2): add Java semantics

Reuses envRN and V1's Val/IntVal/Prim classes unchanged; IfExp is the
only new class, reading the all-lowercase testexp/trueexp/falseexp
fields established in grammar.plcc.

Refs #7
EOF
)"
```

---

## Task 5: Add V2 JavaScript semantics

**Files:**
- Create: `src/V2/javascript/spec.plcc`

Same reuse pattern again: `Val`/`IntVal`/all seven `Prim`s copied verbatim from `src/V1/javascript/spec.plcc`. `IfExp` is grammar-derived, so it gets `Node`/`Token`/`LanguageError` auto-injected already — no `:import` block, and it doesn't reference `Val`/`IntVal` by name anyway.

- [ ] **Step 1: Write `src/V2/javascript/spec.plcc`**

```text
%include ../grammar.plcc
%
javascript

%include ../../Env/envRN/javascript/env.plcc

Val
%%%
const { LanguageError } = require('./runtime/base');

class Val {

    isTrue() {
        return true;
    }

    intVal() {
        throw new LanguageError(`${this}: not an Int`);
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
        this.val = typeof val === "string" ? parseInt(val, 10) : val;
    }

    intVal() {
        return this;
    }

    toString() {
        return String(this.val);
    }

    isTrue() {
        return this.val !== 0;
    }
}

module.exports = { IntVal };
%%%

Program:import
%%%
const { Env } = require('./Env');
%%%

Program
%%%
static env = Env.initEnv();

_run() {
    return String(this.exp.eval(Program.env));
}
%%%

LitExp:import
%%%
const { IntVal } = require('./IntVal');
%%%

LitExp
%%%
eval(env) {
    return new IntVal(this.lit.lexeme);
}

toString() {
    return this.lit.lexeme;
}
%%%

VarExp
%%%
eval(env) {
    return env.applyEnv(this.name.lexeme);
}

toString() {
    return this.name.lexeme;
}
%%%

IfExp
%%%
eval(env) {
    if (this.testexp.eval(env).isTrue())
        return this.trueexp.eval(env);
    else
        return this.falseexp.eval(env);
}

toString() {
    return `if ${this.testexp} then ${this.trueexp} else ${this.falseexp}`;
}
%%%

PrimappExp
%%%
eval(env) {
    const args = this.rands.evalRands(env);
    return this.prim.apply(args);
}

toString() {
    return `${this.prim}(${this.rands})`;
}
%%%

Rands
%%%
evalRands(env) {
    return this.expList.map(e => e.eval(env));
}

toString() {
    return this.expList.map(e => String(e)).join(",");
}
%%%

AddPrim:import
%%%
const { IntVal } = require('./IntVal');
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
%%%

SubPrim:import
%%%
const { IntVal } = require('./IntVal');
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
%%%

MulPrim:import
%%%
const { IntVal } = require('./IntVal');
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
%%%

DivPrim:import
%%%
const { IntVal } = require('./IntVal');
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
%%%

Add1Prim:import
%%%
const { IntVal } = require('./IntVal');
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
%%%

Sub1Prim:import
%%%
const { IntVal } = require('./IntVal');
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
%%%

ZeropPrim:import
%%%
const { IntVal } = require('./IntVal');
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
    return new IntVal(i0 === 0 ? 1 : 0);
}
%%%
```

- [ ] **Step 2: Verify manually — also proves the lowercase alt-name workaround holds for JavaScript too**

```bash
cd src/V2/javascript
echo "if x then add1(v) else sub1(m)" | plcc-rep
```

Expected output: `6`

```bash
echo "if if 1 then 0 else 1 then 42 else 15" | plcc-rep
```

Expected output: `15`

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Commit**

```bash
git add src/V2/javascript/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V2): add JavaScript semantics

Reuses envRN and V1's Val/IntVal/Prim classes unchanged; IfExp is the
only new class. Confirms the all-lowercase testexp/trueexp/falseexp
workaround (issue #6) holds for the JavaScript target too.

Refs #7
EOF
)"
```

---

## Task 6: Remove the old V2 files

**Files:**
- Delete: `src/V2/grammar`, `src/V2/code`, `src/V2/prim`, `src/V2/val`, `src/V2/envRN`

- [ ] **Step 1: Remove the old PLCC files**

```bash
git rm src/V2/grammar src/V2/code src/V2/prim src/V2/val src/V2/envRN
```

- [ ] **Step 2: Confirm no stray build artifacts were left behind**

```bash
find src/V2 -name plcc-ng -o -name __pycache__
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore(V2): remove old PLCC grammar, code, prim, val, and envRN files

Superseded by grammar.plcc and python/java/javascript/spec.plcc. No
shared Env/envRN file to remove here -- V1 already deleted the flat
src/Env/envRN duplicate when it ported the shared version.

Refs #7
EOF
)"
```

---

## Task 7: Rewrite the V2 bats test and add an env+if test case

**Files:**
- Create: `src/V2/tests/env-if/V2.input`, `src/V2/tests/env-if/V2.expected`
- Modify: `src/V2/tests/nested-ifs/V2test.bats`
- Create: `src/V2/tests/env-if/V2test.bats`

`nested-ifs` (`if if 1 then 0 else 1 then 42 else 15` → `15`) exercises nested `IfExp`s but never touches `Env` — every test value is a literal. `env-if` closes that gap, proving `IfExp`'s test/true/false branches all correctly receive `env` and can look up `envRN`'s preset bindings.

- [ ] **Step 1: Write the new test case fixtures**

`src/V2/tests/env-if/V2.input`:
```
if x then add1(v) else sub1(m)
```

`src/V2/tests/env-if/V2.expected`:
```
6
```

(`envRN`'s preset bindings: `x` → 10, truthy, so the `then` branch runs; `add1(v)` → `add1(5)` → `6`.)

- [ ] **Step 2: Rewrite `src/V2/tests/nested-ifs/V2test.bats`**

Current content (old PLCC):
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V2 nested-ifs" {
  relocate
  plccmk -c grammar > /dev/null
  RESULT="$(rep -n < ./tests/nested-ifs/V2.input)"

  expected_output=$(< "./tests/nested-ifs/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]

}
```

New content:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V2 nested-ifs (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nested-ifs/V2.input)"
  expected_output=$(< "../tests/nested-ifs/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 nested-ifs (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nested-ifs/V2.input)"
  expected_output=$(< "../tests/nested-ifs/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 nested-ifs (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nested-ifs/V2.input)"
  expected_output=$(< "../tests/nested-ifs/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 3: Write `src/V2/tests/env-if/V2test.bats`**

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V2 env-if (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/env-if/V2.input)"
  expected_output=$(< "../tests/env-if/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 env-if (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/env-if/V2.input)"
  expected_output=$(< "../tests/env-if/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V2 env-if (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/env-if/V2.input)"
  expected_output=$(< "../tests/env-if/V2.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 4: Run the full suite**

Run: `bin/test.bash 2>&1 | head -1`
Expected: `1..26` (21 pre-existing + 6 new V2 tests − 1 old V2 test this replaces = 26)

Run: `bin/test.bash 2>&1 | grep 'V2 '`
Expected:
```
ok N V2 nested-ifs (python)
ok N V2 nested-ifs (java)
ok N V2 nested-ifs (javascript)
ok N V2 env-if (python)
ok N V2 env-if (java)
ok N V2 env-if (javascript)
```
(exact `N` values depend on bats' run order — all six must say `ok`.)

Run: `bin/test.bash 2>&1 | grep -c 'plccmk: command not found'`
Expected: `11` (V3–V6, SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ — unchanged, still awaiting their own phases).

- [ ] **Step 5: Commit**

```bash
git add src/V2/tests
git commit -m "$(cat <<'EOF'
test(V2): run against all three plcc-ng targets; add Env-lookup coverage

nested-ifs never referenced any of envRN's preset bindings -- every
branch was a literal. env-if closes that gap, proving IfExp correctly
threads env through its test/true/false branches.

Refs #7
EOF
)"
```

---

## Task 8: Close the V2 issue

- [ ] **Step 1: Close the issue**

Run: `bin/issues/close.bash 7`
Expected: prints `closed: dev-docs/issues/done/007-migrate-v2-to-plcc-ng.md`.

- [ ] **Step 2: Verify consistency**

Run: `bin/issues/check.bash`
Expected: `OK: 3 open issues, roadmap consistent, next id 8` (issues #3/#4/#6 remain open — upstream-defect records that stay open until their local workarounds are reverted, per the clarified closing rule).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs(issues): close issue 7 (migrate V2 to plcc-ng), update roadmap"
```

---

## What's next

V2 proves `envRN` is genuinely reusable across languages with no rework, and that the multi-capture alt-name workaround (lowercase, per issue #6) is stable across all three targets. V3 is next — it introduces `let` and the `envVal` Env variant, including the flat-file/directory collision already flagged in the design spec's Phase 2 notes and the `checkDuplicates`/two-list-`Bindings`-constructor requirements `envRN` correctly dropped but `envVal` must keep. Per the decision made before writing this plan, V3–V6 are deliberately **not** planned yet — come back once V2 is merged and issue #6's workaround has proven stable in practice, the same relationship V1 had to V2.

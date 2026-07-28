# plcc-ng Migration — Phase 2 (V1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port V1's grammar and Python/Java/JavaScript semantics to `plcc-ng`, and — as part of doing so — port the `envRN` `Env` variant into the shared `src/Env/envRN/<target>/` location so V2 (planned separately, later) can reuse it via `%include`.

**Architecture:** V1 is the first language with an `Env` dependency, so it's the pathfinder for two things Phase 1's V0 work never exercised: (1) semantic-section classes that don't correspond to any grammar nonterminal (`Env`, `EnvNode`, `EnvNull`, `Binding`, `Bindings`, `Val`, `IntVal`), and (2) `%include` reaching into a sibling top-level directory (`src/V1/python/spec.plcc` → `../../Env/envRN/python/env.plcc`). Both were live-smoke-tested against the installed `plcc-ng` CLI while writing this plan (see Global Constraints) and are confirmed to work; the concrete syntax below reflects what was actually run, not a guess. `envVal` (needed starting V3) and V2–V6 generally are **out of scope for this plan** — V1 is being planned and executed on its own first, the same way V0 was Phase 1's pathfinder, so the `Env`-sharing pattern is proven before it fans out further.

**Tech Stack:** `plcc-ng` CLI (`plcc-scan`, `plcc-parse`, `plcc-rep`), `bats-core` (via `bin/test.bash`), bash, Python 3.12+, Java JDK 21+, Node.js 18+. All already available in this devcontainer.

## Global Constraints

- Scope is V1 only. Do not touch V2–V6 or `envVal` in this plan.
- Structural fidelity across targets: method names (`applyEnv`, `extendEnv`, `initEnv`, `lookup`, `add`, `eval`, `apply`, `evalRands`) are identical across Python, Java, and JavaScript — even though Python convention would prefer `snake_case`. This is deliberate (see the design spec's "Structural Fidelity Across Targets" section): one textbook narrative, three appendices.
- **A semantic-section class block whose name matches no grammar nonterminal becomes a free-standing file** — you write the entire file yourself (full `class` declaration, its own imports/`require`s), not just method bodies merged into an auto-generated scaffold. This is how `Env`, `EnvNode`, `EnvNull`, `Binding`, `Bindings`, `Val`, `IntVal` get ported. Confirmed live in all three targets while writing this plan.
- **`ClassName:import`** splices import/`require` lines into that *specific* generated file — needed once per file that references a free-standing class (Python and JavaScript only; same-directory Java classes need no import at all, and JDK types not in `plcc-ng`'s auto-imports — e.g. `ArrayList` — need `import java.util.ArrayList;` via the same modifier). **Not** a some-file-imports-it-for-everyone mechanism: every class that touches `Env`/`Val`/`IntVal` needs its own `:import` block in Python/JS.
- **`ClassName:init`** splices code into the generated constructor, after fields are assigned — not needed by this plan (V1 has no duplicate-check hooks; that starts at V3), but confirmed working and worth knowing about for later phases.
- A plain assignment statement in a class's default (no-modifier) block becomes a class-level attribute (Python `env = Env.initEnv()` / Java `public static Env env = Env.initEnv();` / JS `static env = Env.initEnv();`) — legal to mix with method definitions in the same block, same as old PLCC.
- `Prim.apply` takes a `List<Val>` (Java) / list (Python/JS) directly — **not** the old code's `Val[]` array plus a `Val.toArray()` conversion helper. That conversion only existed to satisfy Java; dropping it keeps all three targets identical and removes dead ceremony none of them need.
- The old `envRN`'s `applyEnv(Token)` convenience overload and the `Bindings(idList, valList)` two-list constructor are **dropped**, not ported — V1 (and V2, which will reuse this port) never calls either; the overload only existed so old Java code could pass a raw `Token` instead of calling `.toString()` on it first, and this repo already established (V0) that relying on `Token.toString()` is the wrong move (`.lexeme` is the documented, robust attribute). `VarExp.eval` calls `env.applyEnv(self.name.lexeme)` / `env.applyEnv(name.lexeme)` / `env.applyEnv(this.name.lexeme)` directly.
- **Integer division must truncate toward zero in all three targets**, matching Java's native `int / int` semantics: Python needs `int(i0 / i1)` (not `i0 // i1`, which floors instead), JavaScript needs `Math.trunc(i0 / i1)` (not plain `/`, which returns a float). Caught during this plan's own drafting by working through a negative-operand example (`-7 / 2` → `-3` truncated vs. `-4` floored) — this is exactly the kind of silent three-target divergence the shared-expected-output test strategy exists to catch, so `DivPrim` gets its own test coverage below rather than relying on luck.
- Every test case gets one shared `<LANG>.input` / `<LANG>.expected` pair, asserted against by one `@test` block per target in a single `.bats` file.
- Any genuine `plcc-ng` bug or migration-guide gap discovered gets filed as an issue in **this** repo (`bin/issues/new.bash`), `Target: ourPLCC/plcc-ng`, no upstream filing without explicit go-ahead.
- Full design context: [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md) (see its "Addendum: Validated Syntax Facts" for the free-class/`:import`/`:init` findings this plan relies on).

---

## Task 1: File the V1 issue

**Files:**
- Create: `dev-docs/issues/migrate-v1-to-plcc-ng.md` (generated, filename includes the assigned id)
- Modify: `dev-docs/roadmap.md`

- [ ] **Step 1: Generate the issue file**

Run: `bin/issues/new.bash migrate-v1-to-plcc-ng feat`
Expected output: `dev-docs/issues/005-migrate-v1-to-plcc-ng.md`

- [ ] **Step 2: Fill in the issue's Description and Notes**

Edit `dev-docs/issues/005-migrate-v1-to-plcc-ng.md`:

```markdown
## Description

Port V1's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V1 is the
first kept language that depends on `Env`, so this issue also ports the
`envRN` variant into the shared `src/Env/envRN/<target>/` location V2
will later reuse via `%include`. V2–V6 are explicitly out of scope for
this issue.

## Notes

See [dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)
and [dev-docs/plans/2026-07-22-plcc-ng-phase2-v1.md](../plans/2026-07-22-plcc-ng-phase2-v1.md).
```

(Delete the `## Steps to Reproduce` section — not a bug.)

- [ ] **Step 3: Add the roadmap entry**

Edit `dev-docs/roadmap.md`. Add a `### Feat` group before the existing `### Docs` group:

```markdown
# Roadmap

## Open Issues

### Feat

- **[#5](issues/005-migrate-v1-to-plcc-ng.md) — Migrate V1 to plcc-ng**
  Ports V1's grammar and Java semantics to plcc-ng syntax, adds Python and JavaScript semantics, and ports the envRN Env variant into the shared src/Env/envRN/ location.

### Docs

- **[#3](issues/done/003-python-run-return-value-quoted.md) — Python _run() return value printed with quotes**
  plcc-ng's Python target wraps a string returned from _run() in quotes, contradicting its own docs; upstream defect, tracked here pending approval to file.
- **[#4](issues/done/004-js-var-field-reserved-word.md) — JS target breaks on a VAR field name**
  A token auto-captured as `var` generates invalid JavaScript; upstream defect, tracked here pending approval to file.
```

- [ ] **Step 4: Commit**

```bash
git add dev-docs/issues/005-migrate-v1-to-plcc-ng.md dev-docs/roadmap.md
git commit -m "docs(issues): file 005 - migrate V1 to plcc-ng"
```

---

## Task 2: Create the shared V1 grammar and verify scan/parse

**Files:**
- Create: `src/V1/grammar.plcc`

The current `src/V1/grammar` (old PLCC syntax) was already read in full while preparing this plan; the translation below applies the same rules V0 already validated (PascalCase nonterminals, `token`/`skip` keyword on every lexical rule, alternative names move inside the brackets, `VAR` renamed to avoid the JavaScript reserved-word collision) plus dropping the trailing `%include`s — V1's semantics live per-target now, not in one shared omnibus file.

- [ ] **Step 1: Write `src/V1/grammar.plcc`**

```text
# Language V1
# The Rep loop prints the arithmetic value of the expression
#   using an initial set of bindings to certain Roman numerals
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
token VAR '[A-Za-z]\w*'
%
<Program>        ::= <Exp>
<Exp:LitExp>     ::= <LIT>
<Exp:VarExp>     ::= <VAR:name>
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

- [ ] **Step 2: Verify the lexical + syntactic sections alone**

```bash
cd src/V1
echo "add1(+(2,3))" | plcc-scan -s grammar.plcc
```

Expected output:

```
-:1:1 ADD1OP 'add1'
-:1:5 LPAREN '('
-:1:6 ADDOP '+'
-:1:7 LPAREN '('
-:1:8 LIT '2'
-:1:9 COMMA ','
-:1:10 LIT '3'
-:1:11 RPAREN ')'
-:1:12 RPAREN ')'
```

```bash
echo "add1(+(2,3))" | plcc-parse -s grammar.plcc
```

Expected output:

```
Program
  PrimappExp
    Add1Prim (empty)
    Rands
      PrimappExp
        AddPrim (empty)
        Rands
          LitExp
            LIT '2' [-:1:8]
          LitExp
            LIT '3' [-:1:10]
```

Clean up and return:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Commit**

```bash
git add src/V1/grammar.plcc
git commit -m "$(cat <<'EOF'
feat(V1): add plcc-ng grammar (lexical + syntactic sections)

Refs #005
EOF
)"
```

---

## Task 3: Port envRN and add V1 Python semantics

**Files:**
- Create: `src/Env/envRN/python/env.plcc`
- Create: `src/V1/python/spec.plcc`

This is the first port of a free-standing (non-grammar) semantic class, and the first cross-directory `%include`. Both patterns were confirmed live while drafting this plan (see Global Constraints).

- [ ] **Step 1: Write `src/Env/envRN/python/env.plcc`**

```text
Env
%%%
from Binding import Binding
from Bindings import Bindings
from IntVal import IntVal


class Env:

    @staticmethod
    def initEnv():
        from EnvNode import EnvNode
        from EnvNull import EnvNull
        bindings = Bindings([
            Binding("i", IntVal(1)),
            Binding("v", IntVal(5)),
            Binding("x", IntVal(10)),
            Binding("l", IntVal(50)),
            Binding("c", IntVal(100)),
            Binding("d", IntVal(500)),
            Binding("m", IntVal(1000)),
        ])
        return EnvNode(bindings, EnvNull())

    def lookup(self, sym):
        raise NotImplementedError

    def applyEnv(self, sym):
        raise NotImplementedError

    def extendEnv(self, bindings):
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

    def applyEnv(self, sym):
        b = self.bindings.lookup(sym)
        if b is None:
            return self.env.applyEnv(sym)
        return b.val

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

    def applyEnv(self, sym):
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

    def __init__(self, id, val):
        self.id = id
        self.val = val

    def __str__(self):
        return f"[{self.id}:{self.val}]"
%%%

Bindings
%%%
class Bindings:

    def __init__(self, bindingList=None):
        self.bindingList = bindingList if bindingList is not None else []

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

Notes on the translation:
- No language header line (`Python`) in this file — it's spliced by `%include` into a spec.plcc that already supplied one.
- `Env.initEnv` and `Env.extendEnv` import `EnvNode`/`EnvNull` *inside the method*, not at module level — `EnvNode.py` and `EnvNull.py` both import `Env` at module level, so a module-level import the other way would be circular.
- Dropped vs. the old PLCC `envRN`: the `applyEnv(Token)` overload and the `Bindings(idList, valList)` two-list constructor (see Global Constraints — neither is called by V1 or, per its identical old grammar shape, V2).
- `PLCCException` → `LanguageError` (from `runtime.base`, this repo's `plcc-ng`-native equivalent).

- [ ] **Step 2: Write `src/V1/python/spec.plcc`**

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

Note: neither `Exp` nor `Prim` gets a block in Python — unlike Java, Python doesn't statically check that `self.exp.eval(...)` or `self.prim.apply(...)` exist on the declared type, so there's nothing to declare (same reasoning V0 already established for skipping method stubs no target actually needs).

- [ ] **Step 2: Verify manually**

```bash
cd src/V1/python
echo "add1(+(2,3))" | plcc-rep
```

Expected output: `6`

```bash
echo "+(x,/(-(3,10),2))" | plcc-rep
```

Expected output: `7` (env lookup: `x` → 10; `-(3,10)` → -7; `/(-7,2)` truncates to -3; `10 + -3` → 7)

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Commit**

```bash
git add src/Env/envRN/python/env.plcc src/V1/python/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V1): add Python semantics; port envRN to plcc-ng (Python)

envRN is ported as free-standing classes (Env/EnvNode/EnvNull/Binding/
Bindings) under src/Env/envRN/python/, %include'd into V1's spec.plcc --
the first plcc-ng semantic class not tied to a grammar production, and
the first %include reaching into a sibling top-level directory.

Refs #005
EOF
)"
```

---

## Task 4: Port envRN and add V1 Java semantics

**Files:**
- Create: `src/Env/envRN/java/env.plcc`
- Create: `src/V1/java/spec.plcc`

Java needs none of Python's `:import` ceremony for these classes — same-directory, package-less classes reference each other with no import statement, and `plcc-ng` already auto-imports `java.util.List`/`Map`, `runtime.Token`, `runtime.LanguageError` into every grammar-derived class file.

- [ ] **Step 1: Write `src/Env/envRN/java/env.plcc`**

```text
Env
%%%
import java.util.*;

public abstract class Env {

    public static Env initEnv() {
        Bindings bindings = new Bindings(Arrays.asList(
            new Binding("i", new IntVal(1)),
            new Binding("v", new IntVal(5)),
            new Binding("x", new IntVal(10)),
            new Binding("l", new IntVal(50)),
            new Binding("c", new IntVal(100)),
            new Binding("d", new IntVal(500)),
            new Binding("m", new IntVal(1000))));
        return new EnvNode(bindings, new EnvNull());
    }

    public abstract Binding lookup(String sym);

    public abstract Val applyEnv(String sym);

    public Env extendEnv(Bindings bindings) {
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

    public Val applyEnv(String sym) {
        Binding b = bindings.lookup(sym);
        if (b == null)
            return env.applyEnv(sym);
        return b.val;
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

    public Val applyEnv(String sym) {
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
    public Val val;

    public Binding(String id, Val val) {
        this.id = id;
        this.val = val;
    }

    public String toString() {
        return "[" + id + ":" + val + "]";
    }
}
%%%

Bindings
%%%
import java.util.*;

public class Bindings {

    public List<Binding> bindingList;

    public Bindings() {
        bindingList = new ArrayList<Binding>();
    }

    public Bindings(List<Binding> bindingList) {
        this.bindingList = bindingList;
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

Each free-standing class is its own `import`-bearing file (`java.util.*` where `List`/`Arrays`/`ArrayList` are used, `runtime.LanguageError` where thrown) — unlike grammar-derived classes, nothing is auto-imported here.

- [ ] **Step 2: Write `src/V1/java/spec.plcc`**

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

`Exp` gets an explicit `public abstract Val eval(Env env);` here — Java's static type checker requires it (the `exp` field's declared type is `Exp`), unlike Python/JavaScript.

- [ ] **Step 2: Verify manually**

```bash
cd src/V1/java
echo "add1(+(2,3))" | plcc-rep
```

Expected output: `6`

```bash
echo "+(x,/(-(3,10),2))" | plcc-rep
```

Expected output: `7`

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Commit**

```bash
git add src/Env/envRN/java/env.plcc src/V1/java/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V1): add Java semantics; port envRN to plcc-ng (Java)

Nearly line-for-line the old src/V1/{code,prim,val,envRN} files, minus
the applyEnv(Token) overload and the unused two-list Bindings
constructor (see plan Global Constraints), and using List<Val> directly
instead of old code's Val[] array + toArray() conversion.

Refs #005
EOF
)"
```

---

## Task 5: Port envRN and add V1 JavaScript semantics

**Files:**
- Create: `src/Env/envRN/javascript/env.plcc`
- Create: `src/V1/javascript/spec.plcc`

Every cross-file reference needs its own `require` in JavaScript — including between two free-standing classes in the *same* `env.plcc`, since each still becomes its own module/file. Watch for circularity the same way Task 3's Python did: `Env.js`'s `initEnv`/`extendEnv` `require('./EnvNode')`/`require('./EnvNull')` lazily inside the method, not at module top, because `EnvNode.js`/`EnvNull.js` both `require('./Env')` at module top.

- [ ] **Step 1: Write `src/Env/envRN/javascript/env.plcc`**

```text
Env
%%%
const { Binding } = require('./Binding');
const { Bindings } = require('./Bindings');
const { IntVal } = require('./IntVal');

class Env {

    static initEnv() {
        const { EnvNode } = require('./EnvNode');
        const { EnvNull } = require('./EnvNull');
        const bindings = new Bindings([
            new Binding("i", new IntVal(1)),
            new Binding("v", new IntVal(5)),
            new Binding("x", new IntVal(10)),
            new Binding("l", new IntVal(50)),
            new Binding("c", new IntVal(100)),
            new Binding("d", new IntVal(500)),
            new Binding("m", new IntVal(1000)),
        ]);
        return new EnvNode(bindings, new EnvNull());
    }

    lookup(sym) {
        throw new Error("not implemented");
    }

    applyEnv(sym) {
        throw new Error("not implemented");
    }

    extendEnv(bindings) {
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

    applyEnv(sym) {
        const b = this.bindings.lookup(sym);
        if (b === null)
            return this.env.applyEnv(sym);
        return b.val;
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

    applyEnv(sym) {
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

    constructor(id, val) {
        this.id = id;
        this.val = val;
    }

    toString() {
        return `[${this.id}:${this.val}]`;
    }
}

module.exports = { Binding };
%%%

Bindings
%%%
class Bindings {

    constructor(bindingList) {
        this.bindingList = bindingList || [];
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

- [ ] **Step 2: Write `src/V1/javascript/spec.plcc`**

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
const { LanguageError } = require('./runtime/base');
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
const { LanguageError } = require('./runtime/base');
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
const { LanguageError } = require('./runtime/base');
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
const { LanguageError } = require('./runtime/base');
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
const { LanguageError } = require('./runtime/base');
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
const { LanguageError } = require('./runtime/base');
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
const { LanguageError } = require('./runtime/base');
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

`_run()` returns the string rather than printing it, per the already-established JavaScript-specific rule (writing to stdout directly from `_run()` corrupts `plcc-rep`'s output protocol). As in Python, neither `Exp` nor `Prim` gets a block here — JavaScript doesn't statically check method existence either, so there's nothing to declare.

- [ ] **Step 2: Verify manually — also proves the `VAR` rename fix still holds here**

```bash
cd src/V1/javascript
echo "add1(+(2,3))" | plcc-rep
```

Expected output: `6`

```bash
echo "+(x,/(-(3,10),2))" | plcc-rep
```

Expected output: `7`

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng
```

- [ ] **Step 3: Commit**

```bash
git add src/Env/envRN/javascript/env.plcc src/V1/javascript/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V1): add JavaScript semantics; port envRN to plcc-ng (JavaScript)

Every cross-file reference needs its own require() here, including
between the free-standing Env/EnvNode/EnvNull/Binding/Bindings classes
themselves -- Env.js requires EnvNode/EnvNull lazily inside methods to
avoid a circular top-level require (EnvNode.js/EnvNull.js require Env.js
at module top).

Refs #005
EOF
)"
```

---

## Task 6: Remove the old V1 files

**Files:**
- Delete: `src/V1/grammar`, `src/V1/code`, `src/V1/prim`, `src/V1/val`, `src/V1/envRN`

- [ ] **Step 1: Remove the old PLCC files**

```bash
git rm src/V1/grammar src/V1/code src/V1/prim src/V1/val src/V1/envRN
```

- [ ] **Step 2: Confirm no stray build artifacts were left behind**

```bash
find src/V1 src/Env/envRN -name plcc-ng -o -name __pycache__
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore(V1): remove old PLCC grammar, code, prim, val, and envRN files

Superseded by grammar.plcc, python/java/javascript/spec.plcc, and the
shared src/Env/envRN/<target>/env.plcc port.

Refs #005
EOF
)"
```

---

## Task 7: Add an Env-lookup test case and rewrite the V1 bats test

**Files:**
- Create: `src/V1/tests/arith-env/V1.input`, `src/V1/tests/arith-env/V1.expected`
- Modify: `src/V1/tests/nested-prims/V1test.bats`
- Create: `src/V1/tests/arith-env/V1test.bats`

The existing `nested-prims` case (`add1(+(2,3))` → `6`) never references any of `envRN`'s preset bindings, so it never actually exercises `Env` lookup — the entire point of this phase. `arith-env` closes that gap and, per the Global Constraints note on division, also pins down truncating-division parity across all three targets.

- [ ] **Step 1: Write the new test case fixtures**

`src/V1/tests/arith-env/V1.input`:
```
+(x,/(-(3,10),2))
```

`src/V1/tests/arith-env/V1.expected`:
```
7
```

- [ ] **Step 2: Rewrite `src/V1/tests/nested-prims/V1test.bats`**

Current content (old PLCC):
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V1 nested-ifs" {
  relocate
  plccmk -c grammar > /dev/null
  RESULT="$(rep -n < ./tests/nested-prims/V1.input)"

  expected_output=$(< "./tests/nested-prims/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]

}
```

New content:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V1 nested-prims (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nested-prims/V1.input)"
  expected_output=$(< "../tests/nested-prims/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 nested-prims (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nested-prims/V1.input)"
  expected_output=$(< "../tests/nested-prims/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 nested-prims (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nested-prims/V1.input)"
  expected_output=$(< "../tests/nested-prims/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

(The old test's name was actually a copy-paste leftover — `"V1 nested-ifs"` in a directory called `nested-prims`, with no `if` anywhere in the input. Fixed here as `"V1 nested-prims"`.)

- [ ] **Step 3: Write `src/V1/tests/arith-env/V1test.bats`**

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V1 arith-env (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/arith-env/V1.input)"
  expected_output=$(< "../tests/arith-env/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 arith-env (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/arith-env/V1.input)"
  expected_output=$(< "../tests/arith-env/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V1 arith-env (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/arith-env/V1.input)"
  expected_output=$(< "../tests/arith-env/V1.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 4: Run the full suite**

Run: `bin/test.bash 2>&1 | head -1`
Expected: `1..21` (16 from Phase 1 + 6 new V1 tests − 1 old V1 test this replaces = 21)

Run: `bin/test.bash 2>&1 | grep 'V1 '`
Expected:
```
ok N V1 nested-prims (python)
ok N V1 nested-prims (java)
ok N V1 nested-prims (javascript)
ok N V1 arith-env (python)
ok N V1 arith-env (java)
ok N V1 arith-env (javascript)
```
(exact `N` values depend on bats' run order — all six must say `ok`.)

Run: `bin/test.bash 2>&1 | grep -c 'plccmk: command not found'`
Expected: `12` (V2–V6, SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ — unchanged, still awaiting their own phases).

- [ ] **Step 5: Commit**

```bash
git add src/V1/tests
git commit -m "$(cat <<'EOF'
test(V1): run against all three plcc-ng targets; add Env-lookup coverage

The existing nested-prims case never referenced any of envRN's preset
bindings, so it never exercised Env lookup at all -- the whole point of
this phase. arith-env closes that gap and also pins down truncating-
division parity across targets (caught as a real risk while writing
this plan: Python's // floors, plain JS / returns a float -- both wrong
without an explicit truncate-toward-zero fixup).

Refs #005
EOF
)"
```

---

## Task 8: Close the V1 issue

- [ ] **Step 1: Close the issue**

Run: `bin/issues/close.bash 5`
Expected: prints `closed: dev-docs/issues/done/005-migrate-v1-to-plcc-ng.md`.

- [ ] **Step 2: Verify consistency**

Run: `bin/issues/check.bash`
Expected: `OK: 2 open issues, roadmap consistent, next id 6` (issues #003/#004 remain open — informational upstream-defect records, unaffected by this work).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs(issues): close issue 5 (migrate V1 to plcc-ng), update roadmap"
```

---

## What's next

`src/Env/envRN/` now exists and works, proving the shared-`Env`-library pattern the design spec called for. V2 is next — same grammar shape plus `IfExp`, reusing `envRN` as-is via the same `%include ../../Env/envRN/<target>/env.plcc` V1 just validated. Per the decision made before writing this plan, V2 (and V3's `envVal` port, and V4–V6) are deliberately **not** planned yet — come back once V1 is merged and its pattern has proven out in practice, the same relationship V0 had to the rest of Phase 1.

# plcc-ng Migration — Phase 2 (V3) Implementation Plan

> **⛔ PAUSED (2026-07-28) — blocked on [issue #10](../issues/010-plcc-ng-arbno-drops-mid-body-terminal.md).**
> Task 1 (file issue #9) is done. Task 2 halted: V3's `let` grammar
> `<LetDecls> **= <SYMBOL> EQUALS <Exp>` does not parse under plcc-ng 2.0.0
> — a `**=` rule drops a non-capturing terminal (`EQUALS`) between two
> captures. The decision was to keep the grammar in its faithful original
> shape and resume once plcc-ng fixes #10, rather than restructure around
> it. When resuming, restart the subagent-driven loop at Task 2.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port V3's grammar and Python/Java/JavaScript semantics to `plcc-ng`, introducing the `envVal` Env variant. V3 is `V2 + let`: same seven `Prim`s and `Val`/`IntVal`, plus the `LetExp`/`LetDecls` grammar productions and their semantics in all three targets. Also close issue #8 (the completed 2.0.0 update) as bookkeeping.

**Architecture:** V3 is the first language to need `envVal`, so this plan ports it once into `src/Env/envVal/<target>/env.plcc` (deleting the flat old-PLCC `src/Env/envVal` duplicate first), to be reused by V4–V6 later — the same port-once/reuse pattern V1 established for `envRN`. `envVal` is structurally `envRN` **plus** `checkDuplicates` and a two-list `Bindings(idList, valList)` constructor (which `envRN` correctly trimmed but `let` needs), and **minus** `envRN`'s Roman-numeral presets: `envVal.initEnv()` starts empty, so every V3 variable is `let`-bound. All V2 semantics (`Val`, `IntVal`, seven `Prim`s, `Rands`, `Program`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`) are reused verbatim; only `LetExp` and `LetDecls` are new.

**Tech Stack:** `plcc-ng` CLI (`plcc-scan`, `plcc-parse`, `plcc-rep`), `bats-core` (via `bin/test.bash`), bash, Python 3.12+, Java JDK 21+, Node.js 18+. All already available in this devcontainer.

**Design of record:** [dev-docs/specs/2026-07-28-plcc-ng-v3-design.md](../specs/2026-07-28-plcc-ng-v3-design.md), which extends the overarching [migration design](../specs/2026-07-22-plcc-ng-migration-design.md).

## Global Constraints

- Scope is V3 only. Do not touch V4–V6 or `envRef` in this plan.
- Follow the **current** (post-2.0.0) conventions established by V0–V2: capitalized nonterminals, the `SYMBOL` token captured as `symbol`, **camelCase** `IfExp` alt-names (`testExp`/`trueExp`/`falseExp`), and a `_run()` that **returns** a string (Python/JS `return`, Java `String _run()`) — never prints.
- `Val`/`IntVal`/`Prim` (all seven: `AddPrim`, `SubPrim`, `MulPrim`, `DivPrim`, `Add1Prim`, `Sub1Prim`, `ZeropPrim`) and `Rands`/`Program`/`LitExp`/`VarExp`/`IfExp`/`PrimappExp`: copy the current `src/V2/<target>/spec.plcc` versions **verbatim**. Do not modify them.
- `envVal` differs from `envRN` in exactly three deliberate ways, all required by `let`: (1) keep `checkDuplicates`, (2) keep the two-list `Bindings(idList, valList)` constructor, (3) `initEnv()` returns an **empty** `EnvNode(new Bindings(), new EnvNull())` — no Roman-numeral presets.
- **Token keys via `.lexeme`, never `.toString()`.** Under plcc-ng 2.0.0 a token's string form is the scan format (`source:line:col TOKEN 'lexeme'`), so `checkDuplicates` and the two-list `Bindings` constructor read `sym.lexeme` to build their string keys — the same switch V0–V2's `VarExp` already made. Errors raise `LanguageError` (the 2.0.0 runtime class), not the old `PLCCException`.
- Structural fidelity across targets: method names (`eval`, `apply`, `evalRands`, `addBindings`, `checkDuplicates`, `extendEnv`, `applyEnv`) stay identical across Python, Java, and JavaScript.
- JavaScript: grammar-derived classes (`LetExp`, `LetDecls`, etc.) get `Node`/`Token`/`LanguageError` auto-injected — never add an `:import` for those three names on them. Requiring genuinely free-standing classes (`Env`, `Bindings`) from a grammar-derived class is fine and required.
- Every test case gets one shared `V3.input` / `V3.expected` pair, asserted by one `@test` block per target in a single `.bats` file. Value cases only — no duplicate-id/error-path test.
- Any change affecting course material gets logged in [dev-docs/course-material-impact.md](../course-material-impact.md) under a `## V3` heading, in the same commit that makes the change.

---

## Task 1: File the V3 issue

**Files:**
- Create: `dev-docs/issues/NNN-migrate-v3-to-plcc-ng.md` (id assigned by the script)
- Modify: `dev-docs/roadmap.md`

- [ ] **Step 1: Generate the issue file**

Run: `bin/issues/new.bash migrate-v3-to-plcc-ng feat`

This reads `.next-id.txt` (currently `9`), creates the file, and increments the id. Note the exact path it prints (expected `dev-docs/issues/009-migrate-v3-to-plcc-ng.md`) and use that path in the steps below.

- [ ] **Step 2: Fill in the issue's Description and Notes**

Edit the generated file — replace the `## Description` body and delete the `## Steps to Reproduce` section (not a bug):

```markdown
## Description

Port V3's grammar and Java semantics (today under old PLCC) to plcc-ng
syntax, and add Python and JavaScript semantics alongside it. V3 is
V2 + let: it introduces the envVal Env variant (ported once here and
reused by V4-V6), keeping checkDuplicates and the two-list Bindings
constructor that envRN dropped, and adds the LetExp/LetDecls productions
and their semantics. V4-V6 are explicitly out of scope for this issue.

## Notes

See [dev-docs/specs/2026-07-28-plcc-ng-v3-design.md](../specs/2026-07-28-plcc-ng-v3-design.md)
and [dev-docs/plans/2026-07-28-plcc-ng-phase2-v3.md](../plans/2026-07-28-plcc-ng-phase2-v3.md).
```

- [ ] **Step 3: Add the roadmap entry**

Edit `dev-docs/roadmap.md`. Add under the `### Feat` group (create the group if it isn't present):

```markdown
- **[#9](issues/009-migrate-v3-to-plcc-ng.md) — Migrate V3 to plcc-ng**
  Ports V3's grammar and Java semantics to plcc-ng, adds Python and JavaScript semantics, and introduces the envVal Env variant (empty initEnv, checkDuplicates, two-list Bindings constructor) reused by V4-V6.
```

- [ ] **Step 4: Commit**

```bash
git add dev-docs/issues/009-migrate-v3-to-plcc-ng.md dev-docs/roadmap.md
git commit -m "$(cat <<'EOF'
docs(issues): file 009 - migrate V3 to plcc-ng

Refs #9
EOF
)"
```

---

## Task 2: Create the shared V3 grammar and verify scan/parse

**Files:**
- Create: `src/V3/grammar.plcc`
- Modify: `dev-docs/course-material-impact.md`

**Interfaces:**
- Produces: nonterminals `Program`, `Exp` (alts `LitExp`/`VarExp`/`IfExp`/`PrimappExp`/`LetExp`), `Prim` (seven alts), `Rands`, `LetDecls`. `LetDecls` captures produce fields `symbolList` (list of `SYMBOL` tokens) and `expList` (list of `Exp`). `LetExp` captures produce `letDecls` and `exp`.

- [ ] **Step 1: Write `src/V3/grammar.plcc`**

```text
# Language V3
#   Language V2 + let
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
token SYMBOL '[A-Za-z]\w*'
%
<Program>        ::= <Exp>
<Exp:LitExp>     ::= <LIT>
<Exp:VarExp>     ::= <SYMBOL>
<Exp:IfExp>      ::= IF <Exp:testExp> THEN <Exp:trueExp> ELSE <Exp:falseExp>
<Exp:PrimappExp> ::= <Prim> LPAREN <Rands> RPAREN
<Exp:LetExp>     ::= LET <LetDecls> IN <Exp>
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

The keyword tokens (`IF`/`THEN`/`ELSE`/`LET`/`IN`) are declared before `SYMBOL`, whose `[A-Za-z]\w*` pattern would otherwise also match those literals. `<LetDecls>` uses `**=` (zero-or-more) with no separator token — bindings are whitespace-separated (`x = 1 y = 2`), and the parser distinguishes "another binding" (`SYMBOL`) from "done" (`IN`) by one token of lookahead.

- [ ] **Step 2: Verify the lexical + syntactic sections alone (LL(1) + parse tree)**

```bash
cd src/V3
echo "let three = 2 four = 5 in +(three, four)" | plcc-parse -s grammar.plcc
```

Expected: a clean parse tree rooted at `Program` → `LetExp`, whose `LetDecls` holds two `SYMBOL`/`Exp` pairs and whose body is a `PrimappExp`. It MUST NOT print an LL(1) conflict or a `command not found`. If plcc-parse reports an LL(1) conflict on `<LetDecls>`, stop and file an issue (`bin/issues/new.bash`, `Target: ourPLCC/plcc-ng`) before proceeding — do not silently restructure the grammar.

Clean up and return:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng/.claude/worktrees/v3-migration
```

- [ ] **Step 3: Log the course-material impact**

Add to `dev-docs/course-material-impact.md`, after the existing `## V2` section:

```markdown
## V3

- Same `SYMBOL`/`symbol` convention as V0-V2 (the identifier token is
  `SYMBOL`, captured as `symbol`; in `let` LHS positions it is captured
  as the list `symbolList`).
- New `let` productions: `<Exp:LetExp> ::= LET <LetDecls> IN <Exp>` and
  `<LetDecls> **= <SYMBOL> EQUALS <Exp>`. Course material walking through
  `LetDecls` should refer to its `symbolList` / `expList` fields.
- `envVal.initEnv()` is **empty** (no preset bindings) — unlike V1/V2's
  `envRN`, which preset the Roman-numeral values. Every V3 example must
  `let`-bind the variables it uses; there is no ambient `x`/`v`/`m`.
- Duplicate-detection and the two-list binding construction now read a
  token's value via `.lexeme` (not `.toString()`, which under plcc-ng
  2.0.0 yields the `source:line:col TOKEN 'lexeme'` scan format), and
  raise `LanguageError` rather than the old `PLCCException`.
- `LetExp.toString()` / `LetDecls.toString()` are the original course
  material's placeholder stubs (`"... LetExp ..."` / `"... LetDecls ..."`)
  and are preserved verbatim, not "finished".
```

- [ ] **Step 4: Commit**

```bash
git add src/V3/grammar.plcc dev-docs/course-material-impact.md
git commit -m "$(cat <<'EOF'
feat(V3): add plcc-ng grammar (lexical + syntactic sections)

V2 + let: adds LET/IN/EQUALS tokens and the LetExp/LetDecls productions.
LetDecls captures symbolList/expList.

Refs #9
EOF
)"
```

---

## Task 3: Port the envVal Env variant (delete flat file, create three targets)

**Files:**
- Delete: `src/Env/envVal` (flat old-PLCC file — pure duplicate; occupies the path the new directory needs)
- Create: `src/Env/envVal/python/env.plcc`
- Create: `src/Env/envVal/java/env.plcc`
- Create: `src/Env/envVal/javascript/env.plcc`

**Interfaces:**
- Produces (all three targets): `Env.initEnv()` → empty `Env`; static `Env.checkDuplicates(symbolList[, msg])`; `Env.extendEnv(bindings)` → `Env`; `Env.applyEnv(symString)` → `Val`; `Bindings()` (empty) and `Bindings(idList, valList)` (two parallel lists: `SYMBOL` tokens and `Val`s, keyed by `.lexeme`); `Binding(idString, val)` with fields `.id`/`.val`.

- [ ] **Step 1: Delete the flat old-PLCC envVal file**

```bash
git rm src/Env/envVal
```

(Confirmed safe by the migration design: it is a byte-duplicate of the per-language `envVal` copies, exactly like the `envRN` flat file V1 deleted.)

- [ ] **Step 2: Write `src/Env/envVal/python/env.plcc`**

```text
Env
%%%
from Bindings import Bindings
from runtime.base import LanguageError

# Environment-related classes
#
# envVal is structurally identical to envRN (same Env/EnvNode/EnvNull/
# Binding/Bindings classes) but KEEPS checkDuplicates and the two-list
# Bindings(idList, valList) constructor that envRN trimmed as dead weight --
# V3's `let` (and later V4's `proc`) need both. Unlike envRN, initEnv()
# starts EMPTY: V3 programs have no preset bindings; every variable is
# let-bound.

class Env:

    @staticmethod
    def checkDuplicates(symbolList, msg=""):
        seen = set()
        for sym in symbolList:
            s = sym.lexeme
            if s in seen:
                raise LanguageError("duplicate ID " + s + msg)
            seen.add(s)

    @staticmethod
    def initEnv():
        from EnvNode import EnvNode
        from EnvNull import EnvNull
        return EnvNode(Bindings(), EnvNull())

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
from Binding import Binding
from runtime.base import LanguageError


class Bindings:

    def __init__(self, idList=None, valList=None):
        self.bindingList = []
        if idList is not None:
            if valList is None or len(idList) != len(valList):
                raise LanguageError("list sizes mismatch")
            for sym, v in zip(idList, valList):
                self.bindingList.append(Binding(sym.lexeme, v))

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

- [ ] **Step 3: Write `src/Env/envVal/java/env.plcc`**

```text
Env
%%%
import java.util.*;
import runtime.Token;
import runtime.LanguageError;

// Environment-related classes
//
// envVal is structurally identical to envRN (same Env/EnvNode/EnvNull/
// Binding/Bindings classes) but KEEPS checkDuplicates and the two-list
// Bindings(idList, valList) constructor that envRN trimmed as dead weight --
// V3's `let` (and later V4's `proc`) need both. Unlike envRN, initEnv()
// starts EMPTY: V3 programs have no preset bindings; every variable is
// let-bound.
//
// This is a free-standing class in the default package, so it must import
// runtime.Token explicitly (grammar-derived classes get it auto-injected).

public abstract class Env {

    public static void checkDuplicates(List<Token> symbolList, String msg) {
        Set<String> seen = new HashSet<String>();
        for (Token sym : symbolList) {
            String s = sym.lexeme;
            if (seen.contains(s))
                throw new LanguageError("duplicate ID " + s + msg);
            seen.add(s);
        }
    }

    public static void checkDuplicates(List<Token> symbolList) {
        checkDuplicates(symbolList, "");
    }

    public static Env initEnv() {
        return new EnvNode(new Bindings(), new EnvNull());
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
import runtime.Token;
import runtime.LanguageError;

public class Bindings {

    public List<Binding> bindingList;

    public Bindings() {
        bindingList = new ArrayList<Binding>();
    }

    public Bindings(List<Token> idList, List<Val> valList) {
        if (idList.size() != valList.size())
            throw new LanguageError("list sizes mismatch");
        bindingList = new ArrayList<Binding>(idList.size());
        for (int i = 0; i < idList.size(); i++)
            bindingList.add(new Binding(idList.get(i).lexeme, valList.get(i)));
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

- [ ] **Step 4: Write `src/Env/envVal/javascript/env.plcc`**

```text
Env
%%%
const { Bindings } = require('./Bindings');
const { LanguageError } = require('./runtime/base');

// Environment-related classes
//
// envVal is structurally identical to envRN (same Env/EnvNode/EnvNull/
// Binding/Bindings classes) but KEEPS checkDuplicates and the two-list
// Bindings(idList, valList) constructor that envRN trimmed as dead weight --
// V3's `let` (and later V4's `proc`) need both. Unlike envRN, initEnv()
// starts EMPTY: V3 programs have no preset bindings; every variable is
// let-bound.

class Env {

    static checkDuplicates(symbolList, msg = "") {
        const seen = new Set();
        for (const sym of symbolList) {
            const s = sym.lexeme;
            if (seen.has(s))
                throw new LanguageError("duplicate ID " + s + msg);
            seen.add(s);
        }
    }

    static initEnv() {
        const { EnvNode } = require('./EnvNode');
        const { EnvNull } = require('./EnvNull');
        return new EnvNode(new Bindings(), new EnvNull());
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
const { Binding } = require('./Binding');
const { LanguageError } = require('./runtime/base');

class Bindings {

    constructor(idList, valList) {
        this.bindingList = [];
        if (idList !== undefined) {
            if (idList.length !== valList.length)
                throw new LanguageError("list sizes mismatch");
            for (let i = 0; i < idList.length; i++)
                this.bindingList.push(new Binding(idList[i].lexeme, valList[i]));
        }
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

- [ ] **Step 5: Commit (verification happens in Tasks 4–6, when a spec first `%include`s these)**

```bash
git add src/Env/envVal
git commit -m "$(cat <<'EOF'
feat(Env): port envVal variant to plcc-ng (python/java/javascript)

Structurally envRN plus checkDuplicates and a two-list Bindings(idList,
valList) constructor (keyed by .lexeme), minus the Roman-numeral presets:
initEnv() starts empty. Replaces the flat old-PLCC src/Env/envVal file,
reused first by V3's let and later by V4-V6.

Refs #9
EOF
)"
```

---

## Task 4: Add V3 Python semantics (first consumer of envVal)

**Files:**
- Create: `src/V3/python/spec.plcc`

**Interfaces:**
- Consumes: `src/V3/grammar.plcc` (Task 2); `src/Env/envVal/python/env.plcc` (Task 3).
- Produces: `LetExp.eval(env)` / `LetDecls.addBindings(env)` for later structural parity checks.

Reuses `src/Env/envVal/python/env.plcc` and copies `Val`/`IntVal`/all seven `Prim`s/`Rands`/`Program`/`LitExp`/`VarExp`/`IfExp`/`PrimappExp` verbatim from `src/V2/python/spec.plcc`. Only `LetExp` and `LetDecls` are new.

- [ ] **Step 1: Write `src/V3/python/spec.plcc`**

```text
%include ../grammar.plcc
%
Python

%include ../../Env/envVal/python/env.plcc

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
    return str(self.exp.eval(Program.env))
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
    return env.applyEnv(self.symbol.lexeme)

def __str__(self):
    return self.symbol.lexeme
%%%

IfExp
%%%
def eval(self, env):
    if self.testExp.eval(env).isTrue():
        return self.trueExp.eval(env)
    else:
        return self.falseExp.eval(env)

def __str__(self):
    return f"if {self.testExp} then {self.trueExp} else {self.falseExp}"
%%%

PrimappExp
%%%
def eval(self, env):
    args = self.rands.evalRands(env)
    return self.prim.apply(args)

def __str__(self):
    return f"{self.prim}({self.rands})"
%%%

LetExp
%%%
def eval(self, env):
    nenv = self.letDecls.addBindings(env)
    return self.exp.eval(nenv)

def __str__(self):
    return "... LetExp ..."
%%%

LetDecls:import
%%%
from Env import Env
from Bindings import Bindings
%%%

LetDecls:init
%%%
Env.checkDuplicates(self.symbolList, " in let LHS identifiers")
%%%

LetDecls
%%%
def addBindings(self, env):
    valList = [e.eval(env) for e in self.expList]
    bindings = Bindings(self.symbolList, valList)
    return env.extendEnv(bindings)

def __str__(self):
    return "... LetDecls ..."
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

- [ ] **Step 2: Verify manually (also the first end-to-end test of envVal-python and the `:init`/`:import` on `LetDecls`)**

```bash
cd src/V3/python
echo "let three = 2 four = 5 in +(three, four)" | plcc-rep
```

Expected output: `7`

```bash
echo "let x = 1 in let x = add1(x) in x" | plcc-rep
```

Expected output: `2` (inner `let`'s RHS `add1(x)` evaluates in the outer scope where `x=1` → `2`; the inner body then sees the shadowed `x=2`).

If `plcc-rep` errors on the `LetDecls` `:init` block (e.g. a class carrying `:import` + `:init` + a default block isn't accepted), stop and file an issue (`Target: ourPLCC/plcc-ng`) before working around it. The design's addendum lists `:init` as confirmed-supported, so this is expected to work.

Clean up:

```bash
rm -rf plcc-ng __pycache__
cd /workspaces/languages-ng/.claude/worktrees/v3-migration
```

- [ ] **Step 3: Commit**

```bash
git add src/V3/python/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V3): add Python semantics

Reuses envVal and V2's Val/IntVal/Prim/Rands classes unchanged. New:
LetExp (extends env via letDecls.addBindings) and LetDecls (checkDuplicates
in :init, zips symbolList/expList into a two-list Bindings). toString of
LetExp/LetDecls preserves the original placeholder stubs.

Refs #9
EOF
)"
```

---

## Task 5: Add V3 Java semantics

**Files:**
- Create: `src/V3/java/spec.plcc`

**Interfaces:**
- Consumes: `src/V3/grammar.plcc` (Task 2); `src/Env/envVal/java/env.plcc` (Task 3).

Copies `Val`/`IntVal`/all seven `Prim`s/`Rands`/`Program`/`Exp`/`LitExp`/`VarExp`/`IfExp`/`PrimappExp` verbatim from `src/V2/java/spec.plcc`. Only `LetExp` and `LetDecls` are new.

- [ ] **Step 1: Write `src/V3/java/spec.plcc`**

```text
%include ../grammar.plcc
%
Java

%include ../../Env/envVal/java/env.plcc

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

public String _run() {
    return exp.eval(env).toString();
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
    return env.applyEnv(symbol.lexeme);
}

public String toString() {
    return symbol.lexeme;
}
%%%

IfExp
%%%
public Val eval(Env env) {
    Val testVal = testExp.eval(env);
    if (testVal.isTrue())
        return trueExp.eval(env);
    else
        return falseExp.eval(env);
}

public String toString() {
    return "if " + testExp + " then " + trueExp + " else " + falseExp;
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

LetExp
%%%
public Val eval(Env env) {
    Env nenv = letDecls.addBindings(env);
    return exp.eval(nenv);
}

public String toString() {
    return "... LetExp ...";
}
%%%

LetDecls:import
%%%
import java.util.ArrayList;
%%%

LetDecls:init
%%%
Env.checkDuplicates(symbolList, " in let LHS identifiers");
%%%

LetDecls
%%%
public Env addBindings(Env env) {
    List<Val> valList = new ArrayList<Val>(expList.size());
    for (Exp e : expList)
        valList.add(e.eval(env));
    Bindings bindings = new Bindings(symbolList, valList);
    return env.extendEnv(bindings);
}

public String toString() {
    return "... LetDecls ...";
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

`LetDecls` carries three blocks for one class — `:import` (adds `ArrayList`), `:init` (the duplicate check spliced into the constructor), and the default (methods). `LetExp` needs no `:import`: `Env`/`Bindings`/`Val` are all same-package (package-less) classes.

- [ ] **Step 2: Verify manually**

```bash
cd src/V3/java
echo "let three = 2 four = 5 in +(three, four)" | plcc-rep
```

Expected output: `7`

```bash
echo "let x = 1 in let x = add1(x) in x" | plcc-rep
```

Expected output: `2`

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng/.claude/worktrees/v3-migration
```

- [ ] **Step 3: Commit**

```bash
git add src/V3/java/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V3): add Java semantics

Reuses envVal and V2's Val/IntVal/Prim/Rands classes unchanged. New:
LetExp and LetDecls (checkDuplicates in :init, two-list Bindings in
addBindings). toString of LetExp/LetDecls preserves the placeholder stubs.

Refs #9
EOF
)"
```

---

## Task 6: Add V3 JavaScript semantics

**Files:**
- Create: `src/V3/javascript/spec.plcc`

**Interfaces:**
- Consumes: `src/V3/grammar.plcc` (Task 2); `src/Env/envVal/javascript/env.plcc` (Task 3).

Copies `Val`/`IntVal`/all seven `Prim`s/`Rands`/`Program`/`LitExp`/`VarExp`/`IfExp`/`PrimappExp` verbatim from `src/V2/javascript/spec.plcc`. Only `LetExp` and `LetDecls` are new. `LetExp`/`LetDecls` are grammar-derived, so `Node`/`Token`/`LanguageError` are auto-injected — `LetDecls` requires only the free-standing `Env`/`Bindings`; `LetExp` needs no `:import`.

- [ ] **Step 1: Write `src/V3/javascript/spec.plcc`**

```text
%include ../grammar.plcc
%
javascript

%include ../../Env/envVal/javascript/env.plcc

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
    return env.applyEnv(this.symbol.lexeme);
}

toString() {
    return this.symbol.lexeme;
}
%%%

IfExp
%%%
eval(env) {
    if (this.testExp.eval(env).isTrue())
        return this.trueExp.eval(env);
    else
        return this.falseExp.eval(env);
}

toString() {
    return `if ${this.testExp} then ${this.trueExp} else ${this.falseExp}`;
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

LetExp
%%%
eval(env) {
    const nenv = this.letDecls.addBindings(env);
    return this.exp.eval(nenv);
}

toString() {
    return "... LetExp ...";
}
%%%

LetDecls:import
%%%
const { Env } = require('./Env');
const { Bindings } = require('./Bindings');
%%%

LetDecls:init
%%%
Env.checkDuplicates(this.symbolList, " in let LHS identifiers");
%%%

LetDecls
%%%
addBindings(env) {
    const valList = this.expList.map(e => e.eval(env));
    const bindings = new Bindings(this.symbolList, valList);
    return env.extendEnv(bindings);
}

toString() {
    return "... LetDecls ...";
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

- [ ] **Step 2: Verify manually**

```bash
cd src/V3/javascript
echo "let three = 2 four = 5 in +(three, four)" | plcc-rep
```

Expected output: `7`

```bash
echo "let x = 1 in let x = add1(x) in x" | plcc-rep
```

Expected output: `2`

Clean up:

```bash
rm -rf plcc-ng
cd /workspaces/languages-ng/.claude/worktrees/v3-migration
```

- [ ] **Step 3: Commit**

```bash
git add src/V3/javascript/spec.plcc
git commit -m "$(cat <<'EOF'
feat(V3): add JavaScript semantics

Reuses envVal and V2's Val/IntVal/Prim/Rands classes unchanged. New:
LetExp and LetDecls; LetDecls requires the free-standing Env/Bindings
(Node/Token/LanguageError are auto-injected). toString of LetExp/LetDecls
preserves the placeholder stubs.

Refs #9
EOF
)"
```

---

## Task 7: Remove the old V3 files

**Files:**
- Delete: `src/V3/grammar`, `src/V3/code`, `src/V3/prim`, `src/V3/val`, `src/V3/envVal`

- [ ] **Step 1: Remove the old PLCC files**

```bash
git rm src/V3/grammar src/V3/code src/V3/prim src/V3/val src/V3/envVal
```

(`src/V3/envVal` was V3's old flat local Env include; the shared per-target `envVal` created in Task 3 supersedes it.)

- [ ] **Step 2: Confirm no stray build artifacts remain**

```bash
find src/V3 -name plcc-ng -o -name __pycache__
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
chore(V3): remove old PLCC grammar, code, prim, val, and envVal files

Superseded by grammar.plcc, the three python/java/javascript/spec.plcc
files, and the shared src/Env/envVal/<target> port.

Refs #9
EOF
)"
```

---

## Task 8: Rewrite the V3 bats test and add nested-let + single-let cases

**Files:**
- Modify: `src/V3/tests/let/V3test.bats`
- Create: `src/V3/tests/nested-let/V3.input`, `src/V3/tests/nested-let/V3.expected`, `src/V3/tests/nested-let/V3test.bats`
- Create: `src/V3/tests/single-let/V3.input`, `src/V3/tests/single-let/V3.expected`, `src/V3/tests/single-let/V3test.bats`

The existing `let/` case (`let three = 2 four = 5 in +(three, four)` → `7`) covers a multi-binding `let`. `nested-let/` adds scoping/shadowing coverage; `single-let/` adds the one-binding case.

- [ ] **Step 1: Capture the current "command not found" baseline**

The old `src/V3/tests/let/V3test.bats` still calls `plccmk`/`rep`, so it currently fails as a `command not found`. Record the count before rewriting:

```bash
BASELINE_CNF=$(bin/test.bash 2>&1 | grep -c 'command not found'); echo "baseline=$BASELINE_CNF"
```

Note the number — after this task it must drop by exactly 1 (the single old V3 `@test` this replaces).

- [ ] **Step 2: Rewrite `src/V3/tests/let/V3test.bats` for the three targets**

Replace the whole file with:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V3 let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/let/V3.input)"
  expected_output=$(< "../tests/let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 let (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/let/V3.input)"
  expected_output=$(< "../tests/let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 let (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/let/V3.input)"
  expected_output=$(< "../tests/let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

(The existing `src/V3/tests/let/V3.input` and `V3.expected` are unchanged — `let three = 2 four = 5 in +(three, four)` → `7`.)

- [ ] **Step 3: Write the `nested-let` case**

`src/V3/tests/nested-let/V3.input`:
```
let x = 1 in let x = add1(x) in x
```

`src/V3/tests/nested-let/V3.expected`:
```
2
```

`src/V3/tests/nested-let/V3test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V3 nested-let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/nested-let/V3.input)"
  expected_output=$(< "../tests/nested-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 nested-let (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/nested-let/V3.input)"
  expected_output=$(< "../tests/nested-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 nested-let (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/nested-let/V3.input)"
  expected_output=$(< "../tests/nested-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 4: Write the `single-let` case**

`src/V3/tests/single-let/V3.input`:
```
let five = 5 in add1(five)
```

`src/V3/tests/single-let/V3.expected`:
```
6
```

`src/V3/tests/single-let/V3test.bats`:
```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'

@test "V3 single-let (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/single-let/V3.input)"
  expected_output=$(< "../tests/single-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 single-let (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/single-let/V3.input)"
  expected_output=$(< "../tests/single-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}

@test "V3 single-let (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/single-let/V3.input)"
  expected_output=$(< "../tests/single-let/V3.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 5: Run the full suite**

Run: `bin/test.bash 2>&1 | grep 'V3 '`
Expected — all nine `ok`:
```
ok N V3 let (python)
ok N V3 let (java)
ok N V3 let (javascript)
ok N V3 nested-let (python)
ok N V3 nested-let (java)
ok N V3 nested-let (javascript)
ok N V3 single-let (python)
ok N V3 single-let (java)
ok N V3 single-let (javascript)
```
(exact `N` values depend on bats' run order — all nine must say `ok`, and none may say `not ok` or reference `command not found`.)

Run: `bin/test.bash 2>&1 | grep -c 'command not found'`
Expected: `BASELINE_CNF - 1` (from Step 1). The old V3 `@test` was the only V3 test hitting `plccmk`; V4–V6, SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ still await their own phases and remain unchanged.

Run: `bin/test.bash 2>&1 | grep -E '^(ok|not ok) .* V[012] '`
Expected: every V0/V1/V2 line says `ok` — V3's changes (including the shared `src/Env/envVal` port and the removal of the flat `src/Env/envVal`) did not disturb earlier languages.

- [ ] **Step 6: Commit**

```bash
git add src/V3/tests
git commit -m "$(cat <<'EOF'
test(V3): run against all three plcc-ng targets; add scoping coverage

Rewrites the let case to run python/java/javascript, and adds nested-let
(inner binding's RHS sees the enclosing scope, body sees the shadow) and
single-let cases.

Refs #9
EOF
)"
```

---

## Task 9: Close issue #8 (plcc-ng 2.0.0 update — now complete)

Issue #8's technical work (devcontainer pin, `_run()`-returns-string, `SYMBOL`/`symbol` rename, camelCase `IfExp` restored, and closing #3/#4/#6) all landed before this branch. The green V0/V1/V2 results from Task 8 Step 5 are exactly the regression guard #8 asked for, so it can now be closed as bookkeeping.

- [ ] **Step 1: Sanity-check that #8's reversions are actually in place**

```bash
grep -rl 'testExp' src/V2/grammar.plcc          # camelCase IfExp restored
grep -rl 'token SYMBOL' src/V2/grammar.plcc      # SYMBOL rename in place
grep -Rl '_run' src/V2/java/spec.plcc            # _run present
```
Expected: each prints its file (non-empty). If any is empty, stop — #8 is not actually complete and must not be closed.

- [ ] **Step 2: Close the issue**

Run: `bin/issues/close.bash 8`
Expected: prints `closed: dev-docs/issues/done/008-update-plcc-ng-2.0.0.md` and updates the roadmap.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs(issues): close issue 8 (plcc-ng 2.0.0 update complete), update roadmap"
```

---

## Task 10: Close the V3 issue

- [ ] **Step 1: Close the issue**

Run: `bin/issues/close.bash 9`
Expected: prints `closed: dev-docs/issues/done/009-migrate-v3-to-plcc-ng.md` and updates the roadmap.

- [ ] **Step 2: Verify consistency**

Run: `bin/issues/check.bash`
Expected: reports the roadmap consistent with `done/` and the open set (issues #3/#4/#6 remain — upstream-defect records kept open until their local workarounds are reverted; #8 and #9 now closed).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs(issues): close issue 9 (migrate V3 to plcc-ng), update roadmap"
```

---

## What's next

V3 establishes `envVal` (empty `initEnv`, `checkDuplicates`, two-list `Bindings`) as the shared Env variant for V4–V6, and confirms the `let`/`LetDecls` `:init`+`:import` pattern across all three targets. V4 is next (`V3 + proc`), reusing `envVal` unchanged — the same zero-touch reuse V2 got from `envRN`. Per the phase-by-phase discipline, V4–V6 are deliberately **not** planned yet; return once V3 is merged.

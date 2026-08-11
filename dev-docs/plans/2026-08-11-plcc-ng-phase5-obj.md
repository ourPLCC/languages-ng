# plcc-ng Phase 5 — OBJ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port OBJ (`SET + lists, characters, strings, classes, and objects`) to plcc-ng in Python, Java, and JavaScript, closing Phase 5 and the migration as a whole.

**Architecture:** OBJ is SET plus four feature clusters — lists/characters/strings, classes/objects, output expressions, and environment reflection. `src/OBJ/grammar.plcc` is the existing `src/OBJ/grammar` converted to plcc-ng syntax; the conversion is reproduced verbatim in Task 2 and has been validated against `plcc-scan` and `plcc-parse`. Each target's `spec.plcc` starts from `src/SET/<target>/spec.plcc` and adds fourteen free-standing classes on top of the five inherited through `%include ../../Env/envRef/<target>/env.plcc`, which is reused **unchanged**. The one structural departure from old PLCC is output buffering: `plcc-rep` uses the generated program's stdout as a private protocol channel, so `display`/`display#`/`newline`/`putc`/`puts`/`@@` accumulate into `Program.out` and are emitted by `_run()`.

**Tech Stack:** plcc-ng (`plcc-rep`, `plcc-scan`, `plcc-parse`), bats, Python 3, Java, Node.js.

**Design of record:** [dev-docs/specs/2026-08-11-plcc-ng-obj-design.md](../specs/2026-08-11-plcc-ng-obj-design.md). Read it before Task 1.

**Provenance of the material in this plan — read this before trusting anything below.**

This plan is **directive, not transcribed**, and that is a deliberate departure from the TYPE0, TYPE1, and SET plans. Those phases spiked a complete three-target port during design, so their plans could splice in measured, known-good `spec.plcc` text. OBJ's design spiked only the seven unknown mechanics. Consequently:

- **Verbatim and validated:** `grammar.plcc` (Task 2, Step 2 — measured through `plcc-scan` and `plcc-parse`); the `Program`/`Eval`/`Define` output-buffering blocks (measured byte-identical in all three targets); the factory-method shape; the generated-constructor signatures.
- **Verbatim but *not* measured:** `Reserved`, the six output expressions, `Methods.addMethodBindings`, and the test inputs. These are written out in full so no one has to invent them, but they have not been run.
- **Directive:** the bulk transliteration — roughly 74 semantic blocks per target — is specified as source-block references plus a validated rule set, not reproduced. The source of truth is the old-PLCC files in `src/OBJ/`, which are still in the working tree until Task 6 deletes them.
- **Expected test outputs are *derived by reading the sources*, not measured.** Where an expected value below turns out to be wrong, the burden is on determining which side is wrong by reading `src/OBJ/*`, **not** on editing `.expected` until the suite goes green. Record any correction in an `**Amended:**` block in this plan, in the same commit — the convention CLAUDE.md describes for issue #25.

If reality contradicts this plan, assume the plan is wrong. That happened three times on issue #25 and the implementer was right every time.

## Global Constraints

- **Work in the existing worktree** `/workspaces/languages-ng/.claude/worktrees/obj-migration`, branch `worktree-obj-migration`. Do not create a new worktree. Do not `cd` to the main checkout. This branch was created from `origin/main` (`d572089`), which is current; the design commit `d9a299c` is already on it.

- **Copy from `src/SET/<target>/spec.plcc`, never from `src/OBJ/`'s flat files alone.** OBJ descends from SET — its `AppExp.eval` uses call-by-value `rands.evalRands(env)`, not the REF/TYPE0 `evalRandsRef`. `src/SET/<target>/spec.plcc` is the base for the shared core; `src/OBJ/{code,prim,val,listVal,listPrim,class,ref}` are the reference for **what OBJ adds**.

- **Run the full suite with plain `bin/test.bash`.** Everywhere this plan says "run the full suite", that means:

  ```bash
  cd /workspaces/languages-ng/.claude/worktrees/obj-migration
  bin/test.bash > /tmp/obj-<task>.txt 2>&1; echo "EXIT=$?"
  ```

  Read the exit status, not just the counts. `bin/test.bash` has a three-value contract from issue [#31](../issues/031-suite-exhausts-disk-and-reports-spurious-failure.md): **0** every test passed, **1** the run completed with real test failures, **2** the harness itself did not finish. **Exit 2 means the numbers in the file are meaningless — do not count them, and do not report a result.**

  Then count with `grep -c '^ok '` and `grep -c '^not ok '`, and list failures with `grep '^not ok '`.

  Do not pipe `bin/test.bash` through `tail`, `head`, or `grep` directly. A pipeline's exit status is the last command's, which silently discards the three-value contract. (This plan's author made exactly that mistake while measuring the baseline and had to re-run.)

- **The expected exit status changes during this phase, unlike every previous one.** Baseline is exit **1**, because `OBJ class` is red. Task 2 deletes that test, and from the end of Task 2 onward **the expected status is 0** — every test passes. In Tasks 3–6, an exit of **1** means a real failure, not expected churn. This is the first phase where a green suite is the correct end state.

- **Baseline, measured 2026-08-11 in this worktree at `d572089`: 166 tests, 165 passing, 1 failing**, exit status 1. The single failure is `not ok 28 OBJ class`, `plccmk: command not found`. Task 1 re-confirms this before anything is built. Do not carry forward the number 152 or 156 from the TYPE1 plan, and do not derive a count from `grep -c '^@test'` — that gives 174, because `bin/tests/` has `@test` lines inside heredoc fixtures that are not themselves tests.

- **No test that passes may start failing.** Nothing in this phase touches an already-passing language, so a `V`-prefixed, `SET`, `REF`, `NAME`, `NEED`, `TYPE0`, or `TYPE1` failure means a genuine regression.

- **Do not touch `src/Env/`.** SET ported `envRef`; REF, NAME, NEED, TYPE0, and TYPE1 reused it unchanged; OBJ reuses it unchanged again — the sixth consecutive zero-touch reuse across seven users. In particular, do **not** port anything out of `src/OBJ/envRef`; that file is deleted in Task 6, not migrated. Its reserved-ID extension moves to a separate `Reserved` class (Task 2).

- **Never write to stdout from a semantic action.** `plcc-rep` uses the generated program's stdout as a private line-oriented JSON channel. A partial line (no trailing newline) merges with the result record, is printed as unparseable, and then `readline()` blocks forever — a **deadlock with no diagnostic**, measured in Python and JavaScript. All six output expressions append to `Program.out` instead. If a test ever hangs, this is the first thing to suspect.

- **`apply` keeps its `env` parameter** — `apply(args, env)` / `apply(List<Val> valList, Env env)`. It is unread at runtime. It is the seam for a dynamic-scoping homework assignment. **Never remove it as dead code.** OBJ's old `apply(List<Val>)` gains it at both call sites, `AppExp.eval` and `Mangle.eval`. `Prim.apply(args)` stays env-less, as in SET.

- **Canonical instances are static factory methods, not fields**, in all three targets including Java: `Val.nil()`, `ListVal.empty()`, `EnvClass.envClass()`. A class attribute is evaluated when the class body runs, which in Python and JavaScript makes the `Val`/`NilVal` and `ListVal`/`ListNull` cycles load-order dependent. Java adopts the same shape so all three read alike. Do not "optimize" them back into fields or memoize them; the objects are stateless and nothing compares them by identity.

- **These five things are deliberately dropped.** Do not port them, and do not "restore" them on the grounds that the old file had them: `src/OBJ/list` (not `%include`d by the grammar — dead), `ValRORef`/`setRORef` (no callers), `Val.zero` (never read), `Env.empty` (canonical `envRef` inlines `EnvNull()`), and `Bindings(int capacity)` / `Bindings(List<Binding>)` (no callers, already trimmed in the shipped `envRef`).

- **Grammar conventions, unchanged since V0:** identifier token is `SYMBOL` (never `VAR`); nonterminals are PascalCase; multi-capture alt-names are camelCase (`<Exp:testExp>`, `<Exp:vExp>`), not the obsolete lowercase workaround from issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md). **`SYMBOL` keeps OBJ's own broader regex** `[A-Za-z\&\?\$][\w\?\&\$]*` — not the V-languages' `[A-Za-z][\w?]*`. `$`, `&`, and `?` are legal identifier starts in OBJ and appear in its examples.

- **Input and expected files carry no trailing newline.** Use `printf`, never `echo` or a bare heredoc.

- **Course-material impact entries go in the same commit as the change they describe**, under a `## OBJ` heading in [dev-docs/course-material-impact.md](../course-material-impact.md), added after the existing `## TYPE1` section. Never batch them.

- **Every `.bats` file loads both helpers**, in this order, as its only two `load` lines:

  ```bash
  load '../../../../bin/relocate.bash'
  load '../../../../bin/bats-tmpdir.bash'
  ```

  `bats-tmpdir.bash` is the `teardown` that empties a passing test's `BATS_TEST_TMPDIR`; omitting it silently reintroduces the per-test disk accumulation of issue #31. Only Task 2 writes these headers; Tasks 3 and 4 append `@test` blocks to files that already have them and must not add a second `load` pair.

- **Never assign issue numbers by hand.** Use `bin/issues/new.bash` and `bin/issues/close.bash`.

- Every target writes build artifacts to a `plcc-ng/` subdirectory; `.gitignore` already covers `plcc-ng/`, `__pycache__/`, and `*.class`. Never commit them.

---

## File Structure

| Path | Responsibility |
|---|---|
| `src/OBJ/grammar.plcc` | shared lexical + syntactic sections; `%include`d by all three specs |
| `src/OBJ/python/spec.plcc` | `%include ../grammar.plcc`, `%include ../../Env/envRef/python/env.plcc`, Python semantics |
| `src/OBJ/java/spec.plcc` | same shape, Java semantics |
| `src/OBJ/javascript/spec.plcc` | same shape, JavaScript semantics |
| `src/OBJ/tests/<case>/OBJ.input` | shared input, one per case |
| `src/OBJ/tests/<case>/OBJ.expected` | shared expected output — all three targets must agree |
| `src/OBJ/tests/<case>/OBJtest.bats` | three `@test` blocks, one per target |
| `src/OBJ/{Prog,Examples,PPP,BST}/` | 56 example programs — **unchanged**, verified in Task 5 |

Deleted in Task 6: `src/OBJ/{grammar,code,prim,envRef,val,ref,class,list,listVal,listPrim,FILES}`.

---

## The Transliteration Rule Set

Tasks 2–4 refer to these rules by number. They are the validated conversion from old-PLCC Java blocks to each target. Rules 1–7 were confirmed live during the design spike; rules 8–12 are inherited unchanged from the TYPE0 and TYPE1 ports.

**R1 — `PLCCException` → `LanguageError`.** Old PLCC's `throw new PLCCException(msg)` becomes `raise LanguageError(msg)` / `throw new LanguageError(msg)`. The two-argument form `PLCCException("Semantic error", msg)` keeps only the message.

**R2 — `Token.toString()` → `.lexeme`.** Old PLCC's `var.toString()` on a token becomes `self.symbol.lexeme` / `symbol.lexeme` / `this.symbol.lexeme`. Field names come from the grammar: `<SYMBOL>` captures as `symbol`, and in a `**=` rule as `symbolList`.

**R3 — `$run()` → `_run()`, returning a string.** Never printing. See Task 2 Step 4 for the exact buffered form.

**R4 — Field renames from the grammar.** `var` → `symbol`, `varList` → `symbolList` everywhere, including in `Formals`, `LetDecls`, `Statics`, `Fields`, and `Methods`.

**R5 — Static fields → static factory methods** with deferred imports: `Val.nil` → `Val.nil()`, `ListVal.empty` → `ListVal.empty()`, `EnvClass.envClass` → `EnvClass.envClass()`.

**R6 — `apply` gains `env`.** `Val.apply(valList)` → `Val.apply(valList, env)`. `Prim.apply(va)` is unchanged.

**R7 — Output goes to `Program.out`.** Never `print`, `System.out.print`, or `process.stdout.write`.

**R8 — Python:** every class naming a free-standing class needs its own `:import` block; there is no file-wide import. Omitting one is a runtime `NameError` in that one file only.

**R9 — JavaScript:** free-standing classes need explicit `require`s and a `module.exports`. Grammar-derived classes must **not** re-require `Node`, `Token`, or `LanguageError` — those are auto-injected, and redeclaring one fails with `Identifier 'X' has already been declared`.

**R10 — Java:** no `:import` needed for same-directory classes, but `List` is auto-injected while `ArrayList` is **not**. Any grammar-derived class that constructs an `ArrayList` needs its own `:import` block with `import java.util.ArrayList;`. Reading the sources that is at least `Rands` (`evalRands`) and `Methods` (`addMethodBindings`); add others wherever `javac` demands. Omitting one is a compile error, not a silent failure.

**R11 — Java needs a `Prim` block** declaring `public abstract Val apply(Val [] va);`. Python and JavaScript need no `Prim` block.

**R12 — `Val.toArray` is Java-only.** Java prims take `Val []`, so `PrimappExp.eval` converts. Python and JavaScript pass lists directly and have no `toArray`.

**R13 — Java has no partial implementations.** Every `Exp` subclass must implement `eval`, or `javac` rejects the whole build. Found live during the spike. If building Java incrementally is useful, temporarily give `Exp.eval` a throwing body, but **restore `public abstract Val eval(Env env);` before committing** — the abstract declaration is the shipped shape.

**R14 — JavaScript has no typed `catch`.** Any handler that means to catch a `LanguageError` must guard with `if (!(e instanceof LanguageError)) throw e;` so a real `TypeError` is not swallowed. This applies to `Define._run`, which catches a missing-binding error.

---

### Task 1: File the issues and confirm the baseline

Pure bookkeeping plus the gate every later task's expected counts depend on.

**Files:**
- Create: `dev-docs/issues/0NN-migrate-obj-to-plcc-ng.md`, and two more for the plcc-ng defects (numbers assigned by the script)
- Modify: `dev-docs/roadmap.md`
- Test: the existing suite, via `bin/test.bash`

**Interfaces:**
- Consumes: nothing.
- Produces: the issue number `NN` for OBJ, used in every later task's commit trailer and by `bin/issues/close.bash` in Task 6. Also `PP` and `QQ`, the two plcc-ng issue numbers, referenced by comments in the specs.

- [ ] **Step 1: Create the OBJ issue**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
bin/issues/new.bash migrate-obj-to-plcc-ng feat
```

Note the number it prints. Everywhere below, `NN` means that number.

- [ ] **Step 2: Fill in the OBJ issue body**

Write its `## Description` section. Cover: OBJ is `SET + lists, characters, strings, classes, and objects`, the last language in the keep list and the last old-PLCC user in the repository; the port adds fourteen free-standing classes per target, reuses `envRef` unchanged for the sixth consecutive time, moves the reserved-ID check into a `Reserved` class, and buffers all output through `Program.out` because `plcc-rep`'s stdout is a protocol channel. Link the design doc.

Leave `**Target:**` as this repo.

- [ ] **Step 3: Create the plcc-ng deadlock issue**

```bash
bin/issues/new.bash plcc-rep-deadlocks-on-partial-stdout-line chore
```

Note the number as `PP`. Set `**Target:** ourPLCC/plcc-ng`.

Body: a semantic action that writes a partial line (no trailing newline) to stdout deadlocks `plcc-rep` with no diagnostic. Mechanism: `plcc/cmd/rep.py::_read_response` treats the interpreter's stdout as line-oriented JSON; a non-JSON line is printed and skipped, but a partial line merges with the following result record, so the merged line is unparseable *and* the result is destroyed, after which `readline()` blocks forever. Measured in Python and JavaScript, via stdin and via a SOURCE file: exit 124 under `timeout`, no output, no error. A newline-terminated write survives, but only via the unparseable-line fallback, which is an accident rather than a supported channel. Note the impact: a student who puts a `print` in a semantic action gets a hang with no message.

- [ ] **Step 4: Create the plcc-ng protocol-affordance issue**

```bash
bin/issues/new.bash plcc-rep-lacks-output-and-clean-exit-records chore
```

Note the number as `QQ`. Set `**Target:** ourPLCC/plcc-ng`.

Body: semantic actions have no supported way to emit user-visible output, nor to end the session cleanly. Both are missing record kinds. `_render_record` already dispatches on `record['kind']` (`result` / `error` / `specification_error`, else a hard error), so the fix shape is a new kind handled there plus a hook in each target runtime for `_run` to emit it. Give the two concrete cases: OBJ buffers all output into `Program.out` as a workaround for the first, and OBJ's `exit` currently ends `plcc-rep` with `interpreter exited unexpectedly` on stderr and status 1 for want of the second. Cross-link `PP`.

- [ ] **Step 5: Add the roadmap entries**

Add three bullets to `dev-docs/roadmap.md` under the appropriate headings, matching the format of the entries already there: a bold link line and one indented continuation line.

- [ ] **Step 6: Verify issue bookkeeping is consistent**

```bash
bin/issues/check.bash
```

Expected: no errors.

- [ ] **Step 7: Confirm the baseline**

Run the full suite per Global Constraints, writing to `/tmp/obj-task1.txt`.

Expected: `EXIT=1`, **166 tests, 165 passing, 1 failing**. The single failure is `not ok 28 OBJ class` with `plccmk: command not found`.

If the counts differ, stop. Do not proceed on a baseline that does not match — every later task's arithmetic depends on this number.

- [ ] **Step 8: Commit**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): open OBJ migration and two plcc-ng defects"
```

---

### Task 2: Grammar + Python target + all seven test cases

The largest task. It produces a complete, working Python OBJ and the seven test cases, with only the Python `@test` block in each `.bats` file.

**Files:**
- Create: `src/OBJ/grammar.plcc`, `src/OBJ/python/spec.plcc`, and seven `src/OBJ/tests/<case>/{OBJ.input,OBJ.expected,OBJtest.bats}`
- Delete: `src/OBJ/tests/class/OBJtest.bats` (replaced)
- Modify: `dev-docs/course-material-impact.md`
- Reference (do not modify): `src/SET/python/spec.plcc`, `src/OBJ/{code,prim,val,listVal,listPrim,class,ref,envRef,grammar}`

**Interfaces:**
- Consumes: issue number `NN` from Task 1.
- Produces: `src/OBJ/grammar.plcc`, `%include`d unchanged by Tasks 3 and 4; the seven `OBJ.input`/`OBJ.expected` pairs, which Tasks 3 and 4 reuse without modification; and the class inventory below, which Tasks 3 and 4 mirror.

**Class inventory — fourteen free-standing classes per target**, each its own `%%%` block: `Val`, `IntVal`, `NilVal`, `ProcVal`, `ListVal`, `ListNode`, `ListNull`, `ClassVal`, `EnvClass`, `StdClass`, `ObjectVal`, `Ref`, `ValRef`, `Reserved`. Five more — `Env`, `EnvNode`, `EnvNull`, `Binding`, `Bindings` — arrive through `%include` and must **not** be redeclared.

The method additions that `src/OBJ/listVal:1-14` makes to `Val` (`listNode`, `listVal`, `isList`) merge into the single `Val` block. Old PLCC allowed a class to be reopened across `%include`d files; here there is exactly one `Val` block per spec.

Grammar-derived classes needing semantic blocks: `Program`, `Define`, `Eval`, `Exp` and its 30 alternatives, `ClassDecl`, `Mangle`, `Ext`/`Ext0`/`Ext1`, `Loc`/`ObjLoc`/`SimpleLoc`, `Statics`, `Fields`, `Methods`, `SeqExps`, `Proc`, `Formals`, `LetDecls`, `Rands`, `Prim` and its 24 alternatives — plus the five `:init` blocks from Step 12.

- [ ] **Step 1: Confirm the starting point**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
ls src/SET/python/spec.plcc src/Env/envRef/python/env.plcc
head -3 src/SET/python/spec.plcc
```

Expected: both files exist; SET's spec begins with its `%include` of `envRef`.

- [ ] **Step 2: Create `src/OBJ/grammar.plcc`**

This text is **validated** — it was round-tripped through `plcc-scan` and `plcc-parse` during design. Transcribe it exactly. If a later step's parse output disagrees, the transcription is wrong before the grammar is.

```
# Language OBJ
#   Language SET with lists, characters, strings, classes, and objects.
#   Includes comparison primitives '<?', '<=?', '>?', '>=?', '<>?', and '=?'
#   for IntVals.
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
token NILP 'nil\?'
token LTP '<\?'
token LEP '<=\?'
token GTP '>\?'
token GEP '>=\?'
token NEP '<>\?'
token EQP '=\?'
token LENOP 'len'
token LISTP 'list\?'
token OBJECTP 'object\?'
token CLASSP 'class\?'
token FIRSTOP 'first'
token RESTOP 'rest'
token ADDLISTOP 'add'
token SHUTTLEOP 'shuttle'
token REVERSEOP 'reverse'
token APPENDOP 'append'
token IF 'if'
token THEN 'then'
token ELSE 'else'
token LET 'let'
token LETREC 'letrec'
token DEFINE 'define'
token IN 'in'
token EQUALS '='
token EXIT 'exit'
token PROC 'proc'
token SET 'set'
token CLASS 'class'
token EXTENDS 'extends'
token STATIC 'static'
token FIELD 'field'
token METHOD 'method'
token END 'end'
token NEW 'new'
token NIL 'nil'
token DISPLAY 'display'
token DISPLAY1 'display#'
token NEWLINE 'newline'
token PUTC 'putc'
token PUTS 'puts'
token ERROR 'error'
token PERROR 'perror'
token AT '@'
token ATAT '@@'
token DOT '\.'
token LBRACE '\{'
token RBRACE '\}'
token LBRACK '\['
token RBRACK '\]'
token LANGLE '<'
token RANGLE '>'
token LLANGLE '!<'
token RRANGLE '!>'
token BANGAT '!@'
token SEMI ';'
token CHR "'."
token STRNG '\"(\\.|[^\"\\])*\"'
token SYMBOL '[A-Za-z\&\?\$][\w\?\&\$]*'
%
<Program:Define> ::= DEFINE <SYMBOL> EQUALS <Exp>
<Program:Eval>   ::= <Exp>
<Exp:ExitExp>    ::= EXIT
<Exp:LitExp>     ::= <LIT>
<Exp:ChrExp>     ::= <CHR>
<Exp:StrngExp>   ::= <STRNG>
<Exp:VarExp>     ::= <SYMBOL>
<Exp:IfExp>      ::= IF <Exp:testExp> THEN <Exp:trueExp> ELSE <Exp:falseExp>
<Exp:PrimappExp> ::= <Prim> LPAREN <Rands> RPAREN
<Exp:LetExp>     ::= LET <LetDecls> IN <Exp>
<Exp:LetrecExp>  ::= LETREC <LetDecls> IN <Exp>
<Exp:ProcExp>    ::= <Proc>
<Exp:AppExp>     ::= DOT <Exp> LPAREN <Rands> RPAREN
<Exp:SeqExp>     ::= LBRACE <Exp> <SeqExps> RBRACE
<Exp:SetExp>     ::= SET <Loc> <SYMBOL> EQUALS <Exp>
<Exp:ListExp>    ::= LBRACK <Rands> RBRACK
<Exp:ClassExp>   ::= <ClassDecl>
<Exp:NilExp>     ::= NIL
<Exp:NewExp>     ::= NEW <Exp>
<Exp:EnvExp>     ::= LANGLE <Exp:vExp> RANGLE <Exp:eExp>
<Exp:BangAtExp>  ::= BANGAT
<Exp:AtExp>      ::= AT
<Exp:AtAtExp>    ::= ATAT
<Exp:DisplayExp> ::= DISPLAY <Exp>
<Exp:Display1Exp> ::= DISPLAY1 <Exp>
<Exp:NewlineExp> ::= NEWLINE
<Exp:PutcExp>    ::= PUTC <Exp>
<Exp:PutsExp>    ::= PUTS <Exp>
# !<obj>msg1(rands1)>msg2(rands2)>msg3(rands3)...!>
# is the same as .<.<.<obj>msg1(rands1)>msg2(rands2)>msg3(rands3) ...
<Exp:EenvExp>    ::= LLANGLE <Exp> <Mangle> RRANGLE
<Exp:ErrorExp>   ::= ERROR <Exp>
<Exp:PerrorExp>  ::= PERROR <STRNG>
<ClassDecl>      ::= CLASS <Ext> <Statics> <Fields> <Methods> END
<Mangle>         **= RANGLE <Exp> LPAREN <Rands> RPAREN
<Ext:Ext1>       ::= EXTENDS <Exp>
<Ext:Ext0>       ::=
<Loc:ObjLoc>     ::= LANGLE <Exp> RANGLE
<Loc:SimpleLoc>  ::=
<Statics>        **= STATIC <SYMBOL> EQUALS <Exp>
<Fields>         **= FIELD <SYMBOL>
<Methods>        **= METHOD <SYMBOL> EQUALS <Proc>
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
<Prim:NilpPrim>  ::= NILP
<Prim:LTPrim>    ::= LTP
<Prim:LEPrim>    ::= LEP
<Prim:GTPrim>    ::= GTP
<Prim:GEPrim>    ::= GEP
<Prim:NEPrim>    ::= NEP
<Prim:EQPrim>    ::= EQP
<Prim:ObjectpPrim> ::= OBJECTP
<Prim:ClasspPrim>  ::= CLASSP
<Prim:ListpPrim>   ::= LISTP
<Prim:LenPrim>     ::= LENOP
<Prim:FirstPrim>   ::= FIRSTOP
<Prim:RestPrim>    ::= RESTOP
<Prim:AddListPrim> ::= ADDLISTOP
<Prim:ShuttlePrim> ::= SHUTTLEOP
<Prim:ReversePrim> ::= REVERSEOP
<Prim:AppendPrim>  ::= APPENDOP
```

- [ ] **Step 3: Verify the grammar parses and scans correctly**

```bash
mkdir -p /tmp/objgram
cp /workspaces/languages-ng/.claude/worktrees/obj-migration/src/OBJ/grammar.plcc /tmp/objgram/spec.plcc
cd /tmp/objgram
printf 'add add1 addx rest rests first len lens list? listy nil? zero? classy $x &y ?z self this\n' > toks.txt
plcc-scan toks.txt
```

Expected, exactly — this is the tie-breaking rule the whole grammar depends on:

```
toks.txt:1:1 ADDLISTOP 'add'
toks.txt:1:5 ADD1OP 'add1'
toks.txt:1:10 SYMBOL 'addx'
toks.txt:1:15 RESTOP 'rest'
toks.txt:1:20 SYMBOL 'rests'
toks.txt:1:26 FIRSTOP 'first'
toks.txt:1:32 LENOP 'len'
toks.txt:1:36 SYMBOL 'lens'
toks.txt:1:41 LISTP 'list?'
toks.txt:1:47 SYMBOL 'listy'
toks.txt:1:53 NILP 'nil?'
toks.txt:1:58 ZEROP 'zero?'
toks.txt:1:64 SYMBOL 'classy'
toks.txt:1:71 SYMBOL '$x'
toks.txt:1:74 SYMBOL '&y'
toks.txt:1:77 SYMBOL '?z'
toks.txt:1:80 SYMBOL 'self'
toks.txt:1:85 SYMBOL 'this'
```

Then confirm the two empty alternatives and the `**=` rule with two captures:

```bash
printf 'define c = class static x = 3 static f = proc(t) t end\n' > t1.txt
plcc-parse t1.txt
printf '!<o>m(1)>n(2,3)!>\n' > t2.txt
plcc-parse t2.txt
```

Expected: the first tree contains `Ext0 (empty)`, and a `Statics` node listing **both** `SYMBOL`s before **both** value expressions — the parallel-list shape `Statics.addStaticBindings` iterates. The second contains a `Mangle` node with two `VarExp`s followed by two `Rands`, in source order.

If either fails, stop and fix the grammar before writing any semantics.

- [ ] **Step 4: Create `src/OBJ/python/spec.plcc` — the header and top level**

Start the file with the two includes and the language header, then the top level. The `Program`/`Eval`/`Define` blocks below are **measured** — this exact buffering shape was run in all three targets.

```
%include ../grammar.plcc
%include ../../Env/envRef/python/env.plcc
%
Python

Program
%%%
env = Env.initEnv()
# Output is buffered rather than printed. plcc-rep uses this program's
# stdout as a private line-oriented JSON channel, so a partial line
# written here merges with the result record and deadlocks the tool with
# no diagnostic. See issue PP. Every output expression appends to `out`;
# only _run() emits it, as part of its return value.
out = []
%%%

Eval
%%%
def _run(self):
    Program.out = []
    v = self.exp.eval(Program.env)
    return "".join(Program.out) + str(v)
%%%

Define:import
%%%
from Binding import Binding
from ValRef import ValRef
%%%

Define
%%%
def _run(self):
    Program.out = []
    env = Program.env
    s = self.symbol.lexeme
    val = self.exp.eval(env)
    ref = ValRef(val)
    b = env.lookup(s)
    if b is not None:
        b.ref = ref
    else:
        env.add(Binding(s, ref))
    return "".join(Program.out) + s
%%%
```

Note `Define` buffers too — a `define`'s right-hand side can produce output. Its redefinition behaviour (rebind in place if already bound) is SET's and is unchanged.

Replace `PP` in the comment with the issue number from Task 1.

- [ ] **Step 5: Port the SET-inherited core**

From `src/SET/python/spec.plcc`, carry over these blocks essentially unchanged, applying R2 and R4: `Exp`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`, `LetrecExp`, `ProcExp`, `AppExp`, `SeqExp`, `LetDecls`, `LetDecls:init`, `Formals:init`, `Proc`, `Rands`, `Prim`, and the seven arithmetic prims `AddPrim` … `ZeropPrim`, plus `Val`, `IntVal`, `ProcVal`, `Ref`, `ValRef`.

Four edits against SET's versions:

1. `AppExp.eval` — apply R6: `return v.apply(args, env)` is already SET's shape; keep it.
2. `SetExp` is **not** SET's. OBJ's has a `<Loc>`. Port from `src/OBJ/code:289-318` — `SetExp`, `Loc`, `ObjLoc`, `SimpleLoc`.
3. `Val` gains OBJ's additional methods — see Step 7.
4. `ProcVal.apply` gains `env` per R6 and keeps its formals/args count check.

Then add the seven comparison prims `LTPrim`, `LEPrim`, `GTPrim`, `GEPrim`, `NEPrim`, `EQPrim`, and `NilpPrim` from `src/OBJ/prim:136-224` and `123-134`, and `ObjectpPrim`/`ClasspPrim` from `src/OBJ/prim:226-244`.

- [ ] **Step 6: Port the list cluster**

Free-standing classes `ListVal`, `ListNode`, `ListNull` from `src/OBJ/listVal`, applying R1 and R5. `ListVal.empty` becomes a static factory:

```python
class ListVal(Val):

    @staticmethod
    def empty():
        from ListNull import ListNull
        return ListNull()
```

`ListVal.add`, `shuttle`, `reverse`, `append`, `puts`, and the two-argument `toString(sep)` all carry over. Name the separator-taking method `toStr(self, sep)` in Python and JavaScript, since `__str__`/`toString` cannot be overloaded; Java keeps `toString(String sep)` as an overload. `ListNode.buildString` catches the not-an-Int failure and re-raises `puts ...<list>... : not a string` per R1.

`ListVal.len` is a plain instance attribute set in each constructor (`ListNode` computes `rest.len + 1`, `ListNull` sets `0`) — not a method. `LenPrim` reads it.

Then the eight list prims from `src/OBJ/listPrim`: `FirstPrim`, `RestPrim`, `AddListPrim`, `ShuttlePrim`, `ReversePrim`, `AppendPrim`, `LenPrim`, `ListpPrim`.

Then `ListExp.eval` from `src/OBJ/code:194-209` and the `Val` list methods (`listNode`, `listVal`, `isList`) from `src/OBJ/listVal:1-14` — these merge into the single `Val` block, not a second one.

- [ ] **Step 7: Port the character and string cluster**

`ChrExp.eval` from `src/OBJ/code:81-90`: the value is the **character code** of the second character of the lexeme — `IntVal(ord(self.chr.lexeme[1]))` in Python, `charCodeAt(1)` in JavaScript, `charAt(1)` in Java.

`StrngExp.eval` from `src/OBJ/code:92-129`: strip the surrounding quotes, process backslash escapes (`a`→7, `b`→8, `t`→9, `n`→10, `f`→12, `r`→13, anything else → itself), and build a `ListVal` of character codes in source order. The Java original builds a reversed `LinkedList` and then folds it; a direct reverse iteration is equivalent and clearer in Python and JavaScript. Keep the same result.

`Val.putc` and `Val.puts` (the throwing defaults) from `src/OBJ/val:57-63`, `IntVal.putc` from `src/OBJ/val:95-97`, and `ListVal.puts` from `src/OBJ/listVal:65-69`.

- [ ] **Step 8: Port the class and object cluster**

Free-standing classes `ClassVal`, `EnvClass`, `StdClass`, `ObjectVal` from `src/OBJ/class`, applying R1, R2, R4, and R5.

`EnvClass.envClass` becomes a factory that reaches the grammar-derived `Program` — **measured working**:

```python
class EnvClass(ClassVal):

    @staticmethod
    def envClass():
        from Program import Program
        return EnvClass(Program.env)
```

`StdClass.__init__` keeps the ordering from `src/OBJ/class:75-98` exactly — `staticEnv` extends the superclass environment, then `!@`, `myclass`, and `superclass` are bound, and only then does `statics.addStaticBindings(staticEnv)` run, so static right-hand sides can see those three. `makeObject` keeps the ordering from `src/OBJ/class:104-134`: parent object first, then static bindings, then fields, then methods, and `super`/`self`/`this` bound **after** `fields.addFieldBindings`. That ordering is what the reserved-ID check protects; do not tidy it.

Then the grammar-derived blocks `ClassExp`, `ClassDecl`, `Statics`, `Ext`, `Ext0`, `Ext1`, `NewExp` from `src/OBJ/code:211-257` and `449-469`, and `Fields`, `Methods` from `src/OBJ/class:180-205`.

`Methods.addMethodBindings` constructs generated classes by hand. The constructor signatures are **measured**: `ProcExp(proc)` and `LetDecls(symbolList, expList)`. Note `symbolList`, not `varList` (R4):

```python
def addMethodBindings(self, env):
    if len(self.symbolList) == 0:
        return env
    expList = [ProcExp(p) for p in self.procList]
    return LetDecls(self.symbolList, expList).addLetrecBindings(env)
```

This needs a `Methods:import` block for `ProcExp` and `LetDecls` per R8.

- [ ] **Step 9: Port the environment-reflection cluster**

`EnvExp`, `EenvExp`, `Mangle`, `BangAtExp`, `AtExp`, `AtAtExp` from `src/OBJ/code:320-383`.

`Mangle.eval` iterates the two parallel lists — the field names are **measured** as `expList` and `randsList` — and applies R6:

```python
def eval(self, v, env):
    for e, rands in zip(self.expList, self.randsList):
        p = e.eval(v.env())
        args = rands.evalRands(env)
        v = p.apply(args, env)
    return v
```

Note the asymmetry, which is deliberate and load-bearing: the message expression is evaluated in the **receiver's** environment `v.env()`, while its operands are evaluated in the **caller's** environment `env`.

`AtAtExp.eval` appends `str(env)` to `Program.out` per R7 — it must not print.

- [ ] **Step 10: Port the output cluster**

All six append to `Program.out`. Each needs a `:import` for `Program` and `Val` per R8. From `src/OBJ/code:385-430`:

```python
DisplayExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    Program.out.append(str(v))
    return Val.nil()
%%%

Display1Exp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    Program.out.append(str(v) + " ")
    return Val.nil()
%%%

NewlineExp
%%%
def eval(self, env):
    Program.out.append("\n")
    return Val.nil()
%%%

PutcExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    Program.out.append(v.putc())
    return Val.nil()
%%%

PutsExp
%%%
def eval(self, env):
    v = self.exp.eval(env)
    Program.out.append(v.puts())
    return Val.nil()
%%%
```

- [ ] **Step 11: Port the remaining expressions**

`NilExp`, `ErrorExp`, `PerrorExp` from `src/OBJ/code:361-367` and `431-447`, applying R1. `PerrorExp` strips the surrounding quotes from its `STRNG` lexeme before raising.

`ExitExp` from `src/OBJ/code:42-49`. Give it this comment, since the behaviour is a known divergence:

```python
ExitExp
%%%
def eval(self, env):
    # Under old PLCC, rep *was* this process, so exit(0) was a clean quit.
    # Under plcc-ng the interpreter is a subprocess, so this closes the
    # protocol pipe: plcc-rep prints "interpreter exited unexpectedly" on
    # stderr and exits 1. Language semantics are unchanged. A clean-exit
    # record kind is requested upstream in issue QQ.
    import sys
    sys.exit(0)
%%%
```

Replace `QQ` with the issue number from Task 1.

- [ ] **Step 12: Create the `Reserved` class and wire the five `:init` blocks**

`Reserved` is new — it holds the extension that OBJ's old `envRef` fork buried inside `Env.checkDuplicates`.

```
Reserved
%%%
from runtime.base import LanguageError


class Reserved:
    """Identifiers the object system binds implicitly.

    Binding one of these in user code does not shadow harmlessly: Bindings
    are appended and looked up first-match, and StdClass.makeObject binds
    fields *before* super/self/this, so a user `field self` silently wins
    every lookup and displaces the real self inside every method. The same
    goes for a method named self and for a static named myclass. Each is a
    silent wrong answer rather than an error, which is why this check
    exists and why it is called explicitly at each site rather than hidden
    inside Env.checkDuplicates.
    """

    ids = ["self", "myclass", "superclass", "this", "super"]

    @staticmethod
    def check(symbolList):
        for sym in symbolList:
            if sym.lexeme in Reserved.ids:
                raise LanguageError("reserved ID: " + sym.lexeme)
%%%
```

Then five `:init` blocks, each calling both checks. Each needs a `:import` for `Reserved` (and `Env` where SET's version did not already import it) per R8:

```
Formals:init
%%%
Env.checkDuplicates(self.symbolList, " in proc formals")
Reserved.check(self.symbolList)
%%%

LetDecls:init
%%%
Env.checkDuplicates(self.symbolList, " in let/letrec LHS identifiers")
Reserved.check(self.symbolList)
%%%

Statics:init
%%%
Env.checkDuplicates(self.symbolList, " in static variables")
Reserved.check(self.symbolList)
%%%

Fields:init
%%%
Env.checkDuplicates(self.symbolList, " in field variables")
Reserved.check(self.symbolList)
%%%

Methods:init
%%%
Env.checkDuplicates(self.symbolList, " in method names")
Reserved.check(self.symbolList)
%%%
```

- [ ] **Step 13: Smoke-test the Python target**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration/src/OBJ/python
printf 'define f = proc(t) *(2,t)\ndefine c =\n    class\n    static x = 3\n    static f = proc(t) t\n    end\nlet\n    x=5\nin\n    .<c>f(x)\n' | plcc-rep
```

Expected:

```
f
c
5
```

This is the existing `class` test case, and it is the first end-to-end proof that classes, statics, `<c>f` environment lookup, and application all work.

If `plcc-rep` **hangs**, something writes to stdout — check every output expression and `AtAtExp` for a stray `print` (R7).

Then check how a `:init` failure surfaces, because the `errors/` case in Step 14 depends on it and it is **not** something this phase measured:

```bash
printf 'proc(self) 1\n1\n' | plcc-rep; echo "EXIT=$?"
```

TYPE1 measured that a `LanguageError` raised during *evaluation* prints to stdout, exits 0, and lets evaluation continue. `Reserved.check` runs from an `:init` block, i.e. during tree construction rather than evaluation, so that finding does not automatically transfer.

Expected: `reserved ID: self` on stdout, then `1` from the second line, `EXIT=0`.

If instead it reports a `Specification error` and exits 1, `_render_record` is treating the raise as a spec failure rather than a language error, and **`errors/` cannot include the three reserved-ID lines** — split them out and drop them from the suite, record the finding in an `**Amended:**` block here and in the design doc, and add it to plcc-ng issue `PP` as a second symptom of the same protocol area. Do not try to force it green.

- [ ] **Step 14: Write the seven test cases**

Create `src/OBJ/tests/<case>/OBJ.input` and `OBJ.expected` for each. Use `printf`, no trailing newline (Global Constraints).

**The expected values below are derived by reading `src/OBJ/*`, not measured.** If the implementation disagrees, read the source to decide which is wrong before changing either, and record the outcome in an `**Amended:**` block in this plan.

`class/` — unchanged. `OBJ.input` and `OBJ.expected` already exist and must not be edited; only the `.bats` file is replaced.

`lists/` — input:

```
[1,2,3]
len([1,2,3])
first([1,2,3])
rest([1,2,3])
add(0,[1,2])
append([1,2],[3,4])
reverse([1,2,3])
shuttle([1,2],[3,4])
list?([1])
list?(1)
nil?(nil)
nil?(1)
[]
```

expected:

```
[1,2,3]
3
1
[2,3]
[0,1,2]
[1,2,3,4]
[3,2,1]
[2,1,3,4]
1
0
1
0
[]
```

`shuttle([1,2],[3,4])` giving `[2,1,3,4]` is the one to check carefully: `shuttle` walks the source pushing each element onto the destination, so the source ends up reversed in front. That is also why `reverse` is `shuttle` onto empty.

`strings-chars/` — input:

```
'a
"hi"
puts "hi"
putc 'a
display 7
newline
display# 7
```

expected:

```
97
[104,105]
hinil
anil
7nil

nil
7 nil
```

Note `puts` and `putc` are **expressions**, not prims — `puts "hi"`, not `puts("hi")`. Each returns `nil`, which is why the value follows the output on the same line. This case is what pins the buffering mechanism: if someone reverts to printing, this test hangs rather than failing.

`objects/` — input:

```
define c = class field x method init = proc(v) {set <this>x = v ; self} method get = proc() x end
define o = .<new c>init(5)
.<o>get()
object?(o)
object?(5)
class?(c)
```

expected:

```
c
o
5
1
0
1
```

`inheritance/` — input:

```
define shape = class field name method init = proc() {set name = "s" ; self} method area = proc() 0 end
define sq = class extends shape field side method init = proc(n) {set <this>side = n ; self} method area = proc() *(side,side) end
define s = .<new sq>init(4)
.<s>area()
.<<s>super>area()
```

expected:

```
shape
sq
s
16
0
```

The last line reaches the parent object through the `super` field and calls the inherited `area`, confirming that `makeObject` built the parent chain and that `super` resolves.

`env-ops/` — input:

```
define c = class static x = 7 static f = proc(t) *(2,t) end
<c>x
.<c>f(3)
!<c>f(3)!>
let y = 9 in <@>y
```

expected:

```
c
7
6
6
9
```

`!<c>f(3)!>` is the mangle form of `.<c>f(3)` and must produce the identical value — that equivalence is the point of the case.

`errors/` — input:

```
proc(self) 1
let this = 1 in this
class field super end
let x = 1 in let x = 2 in x
error "boom"
perror "bang"
```

expected:

```
reserved ID: self
reserved ID: this
reserved ID: super
2
[98,111,111,109]
bang
```

The last two lines are the point of including both forms. `ErrorExp` **evaluates** its operand, and a string literal evaluates to a list of character codes, so `error "boom"` raises with `[98,111,111,109]`. `PerrorExp` takes the `STRNG` token's lexeme directly and strips the quotes, so `perror "bang"` raises with `bang`. If both came out as words, `ErrorExp` is wrongly reading the lexeme instead of evaluating.

`let x = 1 in let x = 2 in x` is **not** a duplicate — the duplicate check is per `LetDecls`, and these are two nested `let`s, so it evaluates to `2`. A single `let x = 1, x = 2 in x` would raise `duplicate ID x in let/letrec LHS identifiers`; include that form instead if the nested one proves uninteresting, but do not assume the nested one raises.

TYPE1 measured that a language error goes to **stdout**, `plcc-rep` exits **0**, and evaluation continues, so error lines sit in the same file as value lines and need no harness change. **That was measured for evaluation-time errors only**; the first three lines here fail in an `:init` block instead, which Step 13 checks separately. If that check failed, drop those three lines per its instructions before writing this case.

- [ ] **Step 15: Write the seven `.bats` files, Python block only**

Delete `src/OBJ/tests/class/OBJtest.bats` and write a fresh one. Each of the seven files gets exactly this shape, with `<case>` substituted:

```bash
#!/usr/bin/env bats

load '../../../../bin/relocate.bash'
load '../../../../bin/bats-tmpdir.bash'

@test "OBJ <case> (python)" {
  relocate
  cd python
  RESULT="$(plcc-rep < ../tests/<case>/OBJ.input)"
  expected_output=$(< "../tests/<case>/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 16: Run the OBJ tests alone**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
bats --recursive src/OBJ
```

Expected: 7 tests, all passing. Fix any failure per Step 14's rule — read the source, do not edit `.expected` reflexively.

- [ ] **Step 17: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/obj-task2.txt`.

Expected: **`EXIT=0`, 172 tests, 172 passing, 0 failing.** That is the baseline's 166, minus OBJ's 1 old test, plus 7 new Python tests.

**This is the first green suite in the project's history** — the `plccmk: command not found` failure is gone because the last old-PLCC test was just deleted. An exit of 1 from here on means a real failure.

- [ ] **Step 18: Add the course-material impact entries**

Append a `## OBJ` section to `dev-docs/course-material-impact.md`, after the existing `## TYPE1` section, matching the prose style of the sections already there. Cover, one bullet each:

- The `VAR` → `SYMBOL` token rename and the `var` → `symbol` field rename, the standing convention since V0. Note that OBJ's `SYMBOL` keeps its own broader regex, so `$`, `&`, and `?` remain legal identifier starts.
- `$run()` → `_run()`, which **returns** its output string rather than printing it, in `Define` as well as `Eval`.
- `Program.initEnv` → `Program.env`, matching the six shipped predecessors.
- `Val.nil` → `Val.nil()`, `ListVal.empty` → `ListVal.empty()`, `EnvClass.envClass` → `EnvClass.envClass()`. Explain why: a class attribute is evaluated at class-definition time, which makes the `Val`/`NilVal` and `ListVal`/`ListNull` import cycles load-order dependent in Python and JavaScript; Java adopts the same shape so all three read alike.
- `Val.apply(valList)` → `Val.apply(valList, env)`, matching SET and its successors. The parameter is unread and is the seam for a dynamic-scoping exercise.
- **Buffered output.** `display`, `display#`, `newline`, `putc`, `puts`, and `@@` now accumulate into `Program.out` and are emitted by `_run()`. Observable behaviour is unchanged — the interleaving is identical to old PLCC — but the mechanism is not, and anyone extending OBJ with a new output form must append to `Program.out` rather than print. Explain the reason: `plcc-rep` uses the interpreter's stdout as a protocol channel, so a partial line deadlocks it (issue `PP`).
- **`exit`** now ends `plcc-rep` with `interpreter exited unexpectedly` on stderr and status 1, where old PLCC's `rep` ended cleanly. Language semantics are unchanged; a clean-exit record kind is requested upstream in issue `QQ`.
- The reserved-ID check moving out of `Env.checkDuplicates` into a `Reserved` class called explicitly at five sites. Give the reason — it is an OBJ-specific extension of a shared `envRef` used by seven languages, and burying it made the divergence invisible.
- The seven-case test suite replacing the single `class` case.

- [ ] **Step 19: Commit**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
git add src/OBJ/grammar.plcc src/OBJ/python src/OBJ/tests dev-docs/course-material-impact.md
git commit -m "feat(OBJ): port grammar and Python target to plcc-ng

Refs #NN"
```

Replace `NN` with the number from Task 1.

---

### Task 3: Java target

Adds `src/OBJ/java/spec.plcc` and a Java `@test` block to each of the seven `.bats` files.

**Files:**
- Create: `src/OBJ/java/spec.plcc`
- Modify: the seven `src/OBJ/tests/<case>/OBJtest.bats`
- Reference (do not modify): `src/OBJ/python/spec.plcc`, `src/SET/java/spec.plcc`, `src/OBJ/*` old-PLCC files

**Interfaces:**
- Consumes: `src/OBJ/grammar.plcc` and the seven input/expected pairs from Task 2, all unchanged; the class inventory from Task 2.
- Produces: `src/OBJ/java/spec.plcc`. Nothing later depends on its internals.

- [ ] **Step 1: Create `src/OBJ/java/spec.plcc`**

Work from **two** sources in parallel: `src/OBJ/python/spec.plcc` for the structure and method set (Task 2 settled every design question), and `src/SET/java/spec.plcc` for Java conventions. The old-PLCC files in `src/OBJ/` are already Java, so most method bodies transcribe nearly verbatim — but they are *old-PLCC* Java, so R1, R2, R4, R5, R6, and R7 all still apply.

Header:

```
%include ../grammar.plcc
%include ../../Env/envRef/java/env.plcc
%
Java
```

Java-specific requirements, per the rule set:

- **R10** — add an `:import` block with `import java.util.ArrayList;` to every grammar-derived class that constructs one. At minimum `Rands` and `Methods`; add more wherever `javac` demands.
- **R11** — include a `Prim` block declaring `public abstract Val apply(Val [] va);`.
- **R12** — keep `Val.toArray`, and keep `PrimappExp.eval` converting the list before calling `prim.apply`.
- **R13** — `Exp` declares `public abstract Val eval(Env env);`. If you build incrementally with a throwing body instead, restore the abstract form before committing.
- **R5** — `Val.nil()`, `ListVal.empty()`, and `EnvClass.envClass()` are `public static` methods here too, even though Java could use `static final` fields. Add a short comment on each saying why, so the next reader does not "fix" it.
- `ListVal` keeps `public abstract String toString(String sep)` as a genuine overload; Python and JavaScript use `toStr`.
- Java needs no `:import` for same-directory classes.

- [ ] **Step 2: Smoke-test the Java target**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration/src/OBJ/java
printf 'define f = proc(t) *(2,t)\ndefine c =\n    class\n    static x = 3\n    static f = proc(t) t\n    end\nlet\n    x=5\nin\n    .<c>f(x)\n' | plcc-rep
```

Expected:

```
f
c
5
```

A compile error naming a missing `ArrayList` is R10; one naming an unimplemented abstract `eval` is R13.

- [ ] **Step 3: Cross-check every test case against Python**

Before touching the `.bats` files, confirm the two targets agree on all seven inputs:

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration/src/OBJ
for c in class lists strings-chars objects inheritance env-ops errors; do
  printf '=== %s ===\n' "$c"
  diff <(cd python && plcc-rep < "../tests/$c/OBJ.input") \
       <(cd java   && plcc-rep < "../tests/$c/OBJ.input") \
    && printf 'identical\n'
done
```

Expected: `identical` for all seven. Any difference is a Java porting bug — Python is the reference, since Task 2 validated it against the expected files.

- [ ] **Step 4: Append the Java `@test` block to each of the seven `.bats` files**

Append to each existing file, without adding a second `load` pair:

```bash
@test "OBJ <case> (java)" {
  relocate
  cd java
  RESULT="$(plcc-rep < ../tests/<case>/OBJ.input)"
  expected_output=$(< "../tests/<case>/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 5: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/obj-task3.txt`.

Expected: **`EXIT=0`, 179 tests, 179 passing, 0 failing** — Task 2's 172 plus 7 Java tests.

- [ ] **Step 6: Commit**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
git add src/OBJ/java src/OBJ/tests
git commit -m "feat(OBJ): port Java target to plcc-ng

Refs #NN"
```

---

### Task 4: JavaScript target

Adds `src/OBJ/javascript/spec.plcc` and a JavaScript `@test` block to each of the seven `.bats` files.

**Files:**
- Create: `src/OBJ/javascript/spec.plcc`
- Modify: the seven `src/OBJ/tests/<case>/OBJtest.bats`
- Reference (do not modify): `src/OBJ/python/spec.plcc`, `src/SET/javascript/spec.plcc`

**Interfaces:**
- Consumes: `src/OBJ/grammar.plcc` and the seven input/expected pairs, unchanged.
- Produces: `src/OBJ/javascript/spec.plcc`.

- [ ] **Step 1: Create `src/OBJ/javascript/spec.plcc`**

Work from `src/OBJ/python/spec.plcc` for structure and `src/SET/javascript/spec.plcc` for conventions.

Header:

```
%include ../grammar.plcc
%include ../../Env/envRef/javascript/env.plcc
%
javascript
```

Note the lowercase language name — that is what the shipped specs use.

JavaScript-specific requirements:

- **R9** — free-standing classes need explicit `require`s and a `module.exports`; grammar-derived classes must **not** re-require `Node`, `Token`, or `LanguageError`.
- **R14** — `Define._run` has no typed `catch`. Guard any `LanguageError` handler with `if (!(e instanceof LanguageError)) throw e;` and comment why.
- **R5** — `static nil()`, `static empty()`, `static envClass()` with `require`s inside the method body, deferring the load exactly as Python's deferred imports do.
- `Program.out` is a `static out = [];` class field, and `Program.env` a `static env = ...` — both legal in the default (no-modifier) block, landing after the generated constructor.
- Character handling: `charCodeAt(1)` for `ChrExp`; `String.fromCharCode` for `IntVal.putc`.
- Integer division: `DivPrim` must use `Math.trunc(i0 / i1)`, not `/`. JavaScript numbers are doubles, and the other two targets do integer division. Check what `src/SET/javascript/spec.plcc` does and match it exactly.

- [ ] **Step 2: Smoke-test the JavaScript target**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration/src/OBJ/javascript
printf 'define f = proc(t) *(2,t)\ndefine c =\n    class\n    static x = 3\n    static f = proc(t) t\n    end\nlet\n    x=5\nin\n    .<c>f(x)\n' | plcc-rep
```

Expected:

```
f
c
5
```

An `Identifier 'LanguageError' has already been declared` failure is R9 — delete the redundant require from a grammar-derived class.

- [ ] **Step 3: Cross-check all three targets**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration/src/OBJ
for c in class lists strings-chars objects inheritance env-ops errors; do
  printf '=== %s ===\n' "$c"
  a="$(cd python     && plcc-rep < "../tests/$c/OBJ.input")"
  b="$(cd java       && plcc-rep < "../tests/$c/OBJ.input")"
  d="$(cd javascript && plcc-rep < "../tests/$c/OBJ.input")"
  [[ "$a" == "$b" && "$b" == "$d" ]] && printf 'all three identical\n' || printf 'DIVERGENCE\n'
done
```

Expected: `all three identical` for all seven.

- [ ] **Step 4: Append the JavaScript `@test` block to each of the seven `.bats` files**

```bash
@test "OBJ <case> (javascript)" {
  relocate
  cd javascript
  RESULT="$(plcc-rep < ../tests/<case>/OBJ.input)"
  expected_output=$(< "../tests/<case>/OBJ.expected")
  [[ "$RESULT" == "$expected_output" ]]
}
```

- [ ] **Step 5: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/obj-task4.txt`.

Expected: **`EXIT=0`, 186 tests, 186 passing, 0 failing** — the final count for the whole migration.

- [ ] **Step 6: Commit**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
git add src/OBJ/javascript src/OBJ/tests
git commit -m "feat(OBJ): port JavaScript target to plcc-ng

Refs #NN"
```

---

### Task 5: Verify all 56 example programs

The design commits to running every example under all three targets and asserting byte-identity. This is the strongest fidelity evidence available, because old PLCC is not installed here and there is no pre-migration oracle to diff against.

**Files:**
- Create: nothing tracked. The script below is throwaway; put it in `/tmp`.
- Modify: `dev-docs/specs/2026-08-11-plcc-ng-obj-design.md` (record the results), and `src/OBJ/*/spec.plcc` only if a genuine bug is found.

**Interfaces:**
- Consumes: all three `spec.plcc`s from Tasks 2–4.
- Produces: a recorded verification result in the design doc.

- [ ] **Step 1: Write the comparison script**

```bash
cat > /tmp/obj-examples.sh <<'SH'
#!/usr/bin/env bash
# Run every OBJ example under all three targets and compare.
# Not committed: this is one-shot verification evidence.
cd /workspaces/languages-ng/.claude/worktrees/obj-migration/src/OBJ || exit 1
pass=0; diverge=0; failed=0
for f in Prog/* Examples/* PPP/* BST/*; do
  [[ -f "$f" ]] || continue
  a="$(cd python     && timeout 60 plcc-rep < "../$f" 2>&1)"; ra=$?
  b="$(cd java       && timeout 60 plcc-rep < "../$f" 2>&1)"; rb=$?
  c="$(cd javascript && timeout 60 plcc-rep < "../$f" 2>&1)"; rc=$?
  if (( ra != 0 || rb != 0 || rc != 0 )); then
    printf 'NONZERO  %-28s python=%d java=%d js=%d\n' "$f" "$ra" "$rb" "$rc"
    failed=$((failed+1))
  elif [[ "$a" == "$b" && "$b" == "$c" ]]; then
    printf 'ok       %s\n' "$f"
    pass=$((pass+1))
  else
    printf 'DIVERGE  %s\n' "$f"
    diverge=$((diverge+1))
  fi
done
printf '\nidentical=%d diverged=%d nonzero=%d\n' "$pass" "$diverge" "$failed"
SH
chmod +x /tmp/obj-examples.sh
```

- [ ] **Step 2: Run it**

```bash
/tmp/obj-examples.sh 2>&1 | tee /tmp/obj-examples.txt
tail -3 /tmp/obj-examples.txt
```

There is no predetermined expected count here — 56 files exist, but some are fragments (`BST/123` is a single expression; `Prog/List(1)` and `Prog/String(1)` look like editor backups) and may legitimately not stand alone.

- [ ] **Step 3: Triage every non-`ok` line**

For each `DIVERGE`, the three targets disagree — that is always a porting bug in one of them. Find it and fix it, then re-run. Python is the reference.

For each `NONZERO`, determine which of three causes applies before doing anything:

1. The example needs input the harness does not supply, or is a fragment rather than a whole program — expected, record it.
2. It hits a known inherited issue: [#16](../issues/016-cross-target-integer-divergence.md) (Java 32-bit overflow), [#19](../issues/019-python-recursion-ceiling.md) (Python recursion ceiling), [#22](../issues/022-plcc-rep-parses-each-source-independently.md) (multi-file programs). Record which.
3. A real defect in the port. Fix it.

**Do not edit any file under `Prog/`, `Examples/`, `PPP/`, or `BST/` to make it pass.** They are course material and the point of the exercise is that they run unmodified. If one genuinely cannot, that is a finding to record, not to paper over.

- [ ] **Step 4: Record the results in the design doc**

Add a short subsection under `## Example Programs` in `dev-docs/specs/2026-08-11-plcc-ng-obj-design.md` giving the measured counts and listing, by name, every example that diverged or exited nonzero with its cause. If everything ran identically, say so plainly with the count.

- [ ] **Step 5: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/obj-task5.txt`.

Expected: **`EXIT=0`, 186 tests, 186 passing** — unchanged from Task 4 unless Step 3 required a spec fix.

- [ ] **Step 6: Commit**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
git add dev-docs/specs/2026-08-11-plcc-ng-obj-design.md src/OBJ
git commit -m "test(OBJ): verify all example programs across three targets

Refs #NN"
```

---

### Task 6: Remove OBJ's old-PLCC files and close the issue

**Files:**
- Delete: `src/OBJ/{grammar,code,prim,envRef,val,ref,class,list,listVal,listPrim,FILES}`
- Modify: `dev-docs/issues/0NN-migrate-obj-to-plcc-ng.md`, `dev-docs/roadmap.md` (both via `close.bash`)

**Interfaces:**
- Consumes: everything from Tasks 2–5.
- Produces: the final state of the branch.

- [ ] **Step 1: Confirm nothing still references the old files**

```bash
cd /workspaces/languages-ng/.claude/worktrees/obj-migration
grep -rn "%include code\|%include prim\|%include envRef\|%include val\|%include listVal\|%include listPrim\|%include class\|%include ref\|%include list" src/ || echo "no references"
grep -rln "plccmk" --include=*.bats src/ || echo "no plccmk tests remain"
```

Expected: `no references` and `no plccmk tests remain`. The second is the milestone this whole phase exists for.

- [ ] **Step 2: Delete the old-PLCC files**

```bash
git rm src/OBJ/grammar src/OBJ/code src/OBJ/prim src/OBJ/envRef src/OBJ/val \
       src/OBJ/ref src/OBJ/class src/OBJ/list src/OBJ/listVal src/OBJ/listPrim \
       src/OBJ/FILES
```

Note `src/OBJ/grammar` (old) and `src/OBJ/grammar.plcc` (new) are different files; only the extensionless one is removed. `src/OBJ/list` and `src/OBJ/FILES` are the two dead files identified in the design — `list` was never `%include`d, and `FILES` is a stale manifest naming an `env` file that no longer exists.

- [ ] **Step 3: Run the full suite**

Run `bin/test.bash` per Global Constraints, writing to `/tmp/obj-task6.txt`.

Expected: **`EXIT=0`, 186 tests, 186 passing, 0 failing.** Deleting the old files must change nothing — if a test breaks here, something was still reading them.

- [ ] **Step 4: Commit the deletion**

```bash
git commit -m "refactor(OBJ): remove old-PLCC sources superseded by the plcc-ng port

Refs #NN"
```

- [ ] **Step 5: Close the issue**

```bash
bin/issues/close.bash NN
bin/issues/check.bash
```

Leave the two plcc-ng issues (`PP`, `QQ`) **open** — they are upstream defects, not resolved by this phase.

- [ ] **Step 6: Verify and commit the close**

```bash
git add dev-docs/issues dev-docs/roadmap.md
git commit -m "docs(issues): close issue NN (migrate OBJ to plcc-ng)"
git log --oneline -8
```

- [ ] **Step 7: Final confirmation**

```bash
bin/test.bash > /tmp/obj-final.txt 2>&1; echo "EXIT=$?"
grep -c '^ok ' /tmp/obj-final.txt
grep -c '^not ok ' /tmp/obj-final.txt
```

Expected: `EXIT=0`, `186`, `0`.

Every language in the keep list is now on plcc-ng and the repository contains no old-PLCC sources. Note in the closing commit or the issue that this unblocks issue [#12](../issues/012-ci-cannot-run-plcc-ng-migrated-languages.md), which was explicitly deferred until every language had migrated, and that issue [#27](../issues/027-use-spec-flag-instead-of-copying-tree.md)'s "3 legacy `plccmk` languages" is now zero, so `relocate` could be retired entirely rather than coexisting with `plcc-rep -s`.

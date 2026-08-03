# plcc-ng Migration — High-Level Design

## Background

This repository (`languages-ng`) was forked from the original PLCC `languages` repository. It needs to be reimplemented against [plcc-ng](https://github.com/ourPLCC/plcc-ng), the successor to PLCC, using the syntax and CLI documented in its [migration guide](https://raw.githubusercontent.com/ourPLCC/plcc-ng/refs/heads/main/docs/migration.md).

The current `src/` contains many languages accumulated over the life of the original repository, most of which are not used in the courses this repository actually supports. Only a subset is in active use, and that subset should get semantics in three target languages (Python, Java, JavaScript) instead of the single Java implementation each has today, since `plcc-ng` supports Python, Java, JavaScript, and Haskell as target languages (Haskell is explicitly out of scope for this effort).

`Env` is not itself a language — it's a shared library providing an environment/symbol-table data structure (bindings, scoping, lookup) that several of the kept languages depend on.

The existing `.bats` test suite (14 of its 31 tests belong to the kept languages, one per language) is this repository's comprehensive regression suite: it exists to make sure the languages used in course materials keep working as `plcc-ng` itself evolves. It needs to be ported and, where a language's current coverage is thin, extended.

Note: this devcontainer only has `plcc-ng` installed, not the original PLCC (`plcc`/`plccmk`). All 31 existing tests currently fail here with `command not found` — a pre-existing environment gap, not something this migration introduces. Every test for a language stays broken until that language is actually migrated to plcc-ng; there's no way to "keep the lights on" for the old-syntax languages in the meantime.

## Scope

**Keep and migrate (14 languages + Env):** V0, V1, V2, V3, V4, V5, V6, SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ.

**Remove entirely** (recoverable from the original PLCC `languages` repo's history if ever needed): ABC, ARRAY, BF, CHAR, CONT, GINGER, HANDLER, INFIX, LAMBDA, LAMBDAQ, LIST, LON, LON2, LONN, Misc, PROP, RANDSCONT, REFCONT, THREADCONT, and the top-level `src/Examples/` scratch directory. (`src/OBJ/Examples/` is unaffected — that directory holds OBJ's own example programs and is part of the OBJ language being kept.)

Of `Env`'s five existing variants (`envSimple`, `envRef`, `envRefCD`, `envRN`, `envVal`), only three are actually used by a kept language — `envRN` (V1, V2), `envVal` (V3–V6), and `envRef` (SET, REF, NAME, NEED, TYPE0, TYPE1, OBJ). `envSimple` and `envRefCD` are dropped along with the languages that would have used them.

## Phasing

Work proceeds **language-first**: for a given language, its grammar port and all three semantic implementations (Python, Java, JavaScript) are built and tested together, and the language's issue closes only once all three targets pass. One issue and one roadmap entry per language keeps the roadmap at a manageable ~14 entries instead of ~42.

1. **Phase 0 — Repository cleanup and tooling prep** (single PR)
   - Delete all languages/directories not in the keep list, along with their `.bats` tests.
   - Add a `Target` field to the issue template and document it in `issue-conventions.md` (see [Defect Tracking](#defect-tracking-for-plcc-ng--migration-guide-issues) below).

2. **Phase 1 — V0 syntax spike**
   - V0 has no semantic actions and no `Env` dependency, making it the cheapest place to work out real, validated `plcc-ng` spec syntax (lexical/syntactic/semantic section conventions, `%include` behavior, per-target `spec.plcc` structure) before that pattern fans out to 13 more languages.
   - Any `plcc-ng` bugs or migration-guide inaccuracies found here are filed per the Defect Tracking process, not just worked around silently.

3. **Phase 2 — V1 through V6, in order**
   - V1/V2 introduce the `envRN` Env variant; V3–V6 introduce `envVal`. Each is ported once, the first time it's needed, and reused afterward.
   - V2 is `V1 + IfExp`, reusing `envRN` and V1's `Prim`/`Val` unchanged (confirmed byte-identical to V1's pre-port `prim`/`val` files) — no new Env work, only a new grammar production and its test coverage.
   - V2's `IfExp` is the first rule to capture the same nonterminal more than once in one alternative (`testExp`/`trueExp`/`falseExp`), and doing so with camelCase alt-names hits a live `plcc-ng` parser/codegen mismatch (issue #6): the generated class keeps the alt-name's case, but the parser always lowercases it when building the runtime tree, so lookup fails. Confirmed workaround: spell the alt-name entirely in lowercase in the grammar (`<Exp:testexp>`, not `<Exp:testExp>`) — one fix in the shared `grammar.plcc`, inherited automatically by V3–V6, all of which reuse this exact `IfExp` shape (confirmed via `grep -rn "testExp" src/V*/grammar`).
     **Superseded:** issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md) was fixed in plcc-ng 2.0.0 (see the [2.0.0 update design](2026-07-27-plcc-ng-2.0.0-update-design.md)). V3–V6 all ship camelCase `<Exp:testExp>`; the lowercase workaround was reverted and must not be reintroduced.
   - `src/Env/envVal` (like `src/Env/envRN` before it) pre-exists as a flat old-PLCC file at the exact path the new `src/Env/envVal/<target>/` directory needs — V3's plan should budget deleting it up front (confirmed safe: it's a pure duplicate of the per-language `envVal` copies, same as `envRN` was), not rediscover the collision live.
   - `envVal`'s port must **keep** `checkDuplicates` and the two-list `Bindings(idList, valList)` constructor that `envRN`'s port correctly dropped as dead weight — V1/V2 never call either, but V3's `let` and V4's `proc` formals both do. Don't carry V1's trimmed shape forward by reflex.
   - V6's `<program>` grammar has two alternatives (`Define`/`Eval`), and `plcc-rep` reads and evaluates one at a time from stdin in a loop, with `define` mutating a `Program`-level environment that later reads in the same run must see. Whether `plcc-ng`'s equivalent REP loop preserves that persistent state across multiple parses in one process is unvalidated — worth a live smoke test early in V6's own phase, the same way V0 and V1 spiked their own novel mechanics before committing to a full port.
   - V2's implementation confirms `envRN` reuse required literally zero changes to the shared file — the Env-sharing pattern holds in practice, not just in theory. V3–V6 should expect the same zero-touch reuse once `envVal` is ported, the first time V3 needs it.
   - V2's implementation also confirms the lowercase-alt-name workaround (issue #6) end-to-end in production code across all three targets, not just the Python/Java smoke test done during V2's own planning — V3–V6 can adopt `<Exp:testexp>`/`<Exp:trueexp>`/`<Exp:falseexp>` directly without re-validating it themselves.
     **Superseded:** issue [#6](../issues/006-multi-capture-alt-name-case-mismatch.md) was fixed in plcc-ng 2.0.0 (see the [2.0.0 update design](2026-07-27-plcc-ng-2.0.0-update-design.md)). V3–V6 all ship camelCase `<Exp:testExp>`; the lowercase workaround was reverted and must not be reintroduced.
   - `Val`/`IntVal`/`Prim` are duplicated verbatim per language per target (unlike `Env`, they are not shared via `%include`) — confirmed this mirrors the *original* pre-migration repo's own structure (each language already had its own flat `prim`/`val` files, not a shared one), so it is not new duplication this migration introduced. Unifying it into a shared location is out of scope, the same way the design already rules out unifying `Env`'s variants beyond faithful porting (see Out of Scope) — don't "fix" this mid-phase.
   - A future phase's plan should recompute its expected `plccmk: command not found` test count fresh, not copy the prior phase's plan and manually decrement it — V2's plan had this count off by one (10 instead of 11), caught only because an implementer subagent actually ran the command instead of trusting the copied-and-adjusted number.

4. **Phase 3 — SET, REF, NAME, NEED**
   - Introduces the `envRef` Env variant, ported once and reused by all four.
   - Same `src/Env/envRef` flat-file-vs-directory collision as `envRN`/`envVal` — delete the flat file as part of whichever of these four languages goes first.

5. **Phase 4 — TYPE0, TYPE1**

6. **Phase 5 — OBJ**
   - OBJ currently forks `envRef` with additional reserved-identifier checks (`self`, `myclass`, `superclass`, `this`, `super`) whose `checkDuplicates` signature also diverges from canonical `envRef`, not just adds to it. This phase ports OBJ's fork as a documented, explicit extension of the canonical `envRef` (in each of the 3 targets) rather than continuing the current silent copy-paste divergence — with a check on whether OBJ's exact divergence is still needed or was accidental drift.

## File/Directory Architecture

`plcc-scan`, `plcc-parse`, and `plcc-rep` all default to a `spec.plcc` file in the current directory, and a spec's semantic section names exactly one target language. Since each language needs three semantic implementations, each language gets one shared grammar file plus three target subdirectories, each holding its own `spec.plcc`:

```
src/V1/
  grammar.plcc          # shared lexical + syntactic sections (plcc-ng syntax)
  python/spec.plcc       # %include ../grammar.plcc, then the Python semantic section
  java/spec.plcc         # %include ../grammar.plcc, then the Java semantic section
  javascript/spec.plcc   # %include ../grammar.plcc, then the JavaScript semantic section
  tests/
    <case>/V1.input
    <case>/V1.expected    # one shared expected output — all 3 targets must agree
    <case>/V1.bats        # one @test per target, each cd's into python/, java/, or javascript/
```

`%include` is confirmed to still exist in `plcc-ng` (relative-path based, same idea as old PLCC), so the grammar stays DRY across the three targets instead of being triplicated.

`Env`'s three needed variants live under `src/Env/<variant>/<target>/env.plcc`, each ported once — the first time a language in the phase order needs it — and `%include`'d by every language that shares that variant afterward.

## Structural Fidelity Across Targets

The existing Java implementations are the reference shape: one class per grammar alternative, `eval(Env)` / `toString()` methods, `$run()` (renamed `_run()` under `plcc-ng`) as the program entry point. Porting to `plcc-ng` syntax should preserve that structure as closely as the new syntax allows, and the Python and JavaScript implementations should mirror the same class boundaries, method names, and control flow — rather than being rewritten in a more idiomatic style native to each language.

This is deliberate: the goal is a single textbook that discusses "how `LetExp.eval` works" once, with the reader able to follow along in whichever of the three target-language appendices they're using, rather than three differently-structured explanations.

## Testing Strategy

- Keep `bin/test.bash` (`bats --recursive`) as the runner; no new test framework.
- Each existing test case keeps one shared `<LANG>.input` / `<LANG>.expected` pair (not one per target), since all three targets must produce identical output for the same input. Each case's `.bats` file holds three `@test` blocks, one per target directory, each asserting against the same expected file.
- Expected outputs need updating independent of the multi-target work, because `plcc-ng`'s scan/parse output format differs from old PLCC (`source:line:col TOKEN 'lexeme'` instead of `TOKEN(lexeme)`; full parse tree always shown; no `-t` trace flag on `plcc-parse`).
- Where a language's current test coverage is thin, add cases during that language's phase — not as a separate catch-all pass.
- `bin/relocate.bash` copies the **whole `src/` tree** into each `@test`'s isolated tmpdir, not just the language under test — required starting with V1, whose `spec.plcc` `%include`s a sibling top-level directory (`../../Env/envRN/<target>/env.plcc`); a narrower copy leaves that include with nothing to resolve against once relocated. Don't narrow this back to a per-language copy — every later phase's cross-directory `%include`s depend on it.

## Defect Tracking for plcc-ng / Migration Guide Issues

A live smoke test against the installed `plcc-ng` CLI (during design) already turned up gaps in the migration guide's summary (lexical rules require an explicit `token`/`skip` keyword per line, not just `NAME 'regex'`) and a `plcc-ng` parser error that emitted an unformatted template string (`{blockLines[0].file}:{blockLines[0].number}`) instead of a real message — a likely tooling bug, not just a spec mistake. This confirms the Phase 1 spike is necessary, not optional.

Any `plcc-ng` bug or migration-guide inaccuracy found during this work is filed as an issue in **this** repository (`languages-ng`), using the normal `bin/issues/new.bash` workflow, type `docs` or `chore` (it's not a defect in our own shipped `src/` languages). The issue template gains a `**Target:**` field identifying which repository the defect actually belongs to (e.g. `languages-ng` or `ourPLCC/plcc-ng`), defaulting to this repo. This lets every defect be tracked in one place now, and migrated to its real upstream home later — with explicit confirmation before anything is filed publicly outside this repo.

## Addendum: Validated Syntax Facts (from live smoke testing)

The summary above undersold several concrete details, confirmed by round-tripping a full V0 grammar through the installed `plcc-ng` CLI (`plcc-scan`, `plcc-parse`, `plcc-rep`) for all three targets:

**Read with the [2.0.0 update design](2026-07-27-plcc-ng-2.0.0-update-design.md) alongside this section.** These facts were validated against the plcc-ng release current in July 2026. Four of them were later superseded by the 2.0.0 update and are marked inline below. Anything here that a live run contradicts should be treated as stale and corrected in place, not worked around.

- **Section separators are bare `%` lines** — lexical % syntactic % semantic. `token`/`skip` lines take their pattern inline (`token NAME 'pattern'`), same as old PLCC.
- **The semantic section's language header is a bare line, not a code block** — `Python` (or `Java` / `javascript`), then a blank line, then `ClassName` / `%%%` blocks. Putting `%%%` directly after the language name is a syntax error.
- **`_run()` returns a string in all three targets.** *(Corrected — this bullet originally described an asymmetry in which Python and Java printed and only JavaScript returned. That was true before the [2.0.0 update](2026-07-27-plcc-ng-2.0.0-update-design.md) and is now wrong.)* Returning `None` from Python's `_run()` is a hard `Specification error: TypeError: _run() must return a string, got NoneType`. The structure is uniform: `return` the output, never print it.
- **~~Returning a plain string from Python's `_run()` prints it with quotes~~** — fixed upstream. Issue [#3](../issues/003-python-run-return-value-quoted.md) closed 2026-07-28; returning a plain string now prints it unquoted, as the quick-start example always showed. The `print()`-instead-of-`return` workaround this bullet recommended is now itself an error — see the bullet above.
- **A token named `VAR` auto-captured as `<VAR>` breaks JavaScript code generation** — the auto-generated field name `var` collides with the reserved word `var`, producing invalid JS (`constructor(var) {`) that fails to load. Every language in the keep list uses a `VAR` token for identifiers, so **every grammar must rename this capture** (e.g. `<VAR:name>`) in the one shared `grammar.plcc`, which fixes it uniformly across all three targets at no extra cost. This is a load-bearing rule for every remaining phase, not just V0.
  **What was actually done:** the *token* was renamed to `SYMBOL` (captured as `symbol`, `symbolList` in list positions) rather than the capture being aliased. Every migrated language V0–V6 uses `SYMBOL`; Phases 3–5 should follow suit.
- **`%include` works exactly as documented**, resolved relative to the file containing the directive — validated by splitting V0 into `grammar.plcc` + `python/spec.plcc` with `%include ../grammar.plcc`.
- **`plcc-rep` writes build artifacts to a `plcc-ng/` subdirectory** next to `spec.plcc` (generated/compiled code, `spec.json`, `ll1.json`, `model.json`, `__pycache__/`, etc.), regenerated on every run. This needs a `.gitignore` entry (`plcc-ng/`, `__pycache__/`) so it never gets committed.
- **A semantic-section class block whose name doesn't match any grammar nonterminal becomes a free-standing file**, emitted verbatim (you write the full `class X: ...` / `public class X {...}` / `class X {...}` yourself, including its own imports/`module.exports`) rather than merged into an auto-generated scaffold. This is how `Env`, `EnvNode`, `EnvNull`, `Binding`, `Bindings`, `Val`, `IntVal` — none of which correspond to a grammar production — get ported: each is just its own `ClassName %%% ... %%%` block. Confirmed working identically in all three targets (`plcc-rep` produced correct output end-to-end for Python, Java, and JavaScript versions of the same free-class scenario).
- **A class-name header can carry a `:modifier` suffix** — `ClassName:import`, `ClassName:init`, `ClassName:top` (Python/JS only), `ClassName:class` (Python/Java only) — that changes where the block's content is spliced in, instead of merging as a method body:
  - `:import` — placed as import/`require` lines near the top of that specific class's generated file. **Needed per file that references a free-standing class** — e.g. if both `Program` and `LitExp` call into `Env`, both `Program:import` and `LitExp:import` need their own `%include`/import block; there's no way to import once and have it apply file-wide. (Confirmed the failure mode too: omitting it on one class produces a runtime `NameError: name 'X' is not defined` in Python, or the JS/Java equivalent, only in that one file.)
  - `:init` — spliced into the generated constructor, after field assignment. This is the direct `plcc-ng` equivalent of old PLCC's `ClassName:init` action hook (e.g. `LetDecls:init`'s duplicate-check call) — confirmed supported, not just carried over from the migration guide's silence on the subject.
  - Java needs neither `:import` (same-directory, package-less classes reference each other with no import statement at all) nor a Python-style `:top`.
  - **JavaScript auto-injects `const { Node, Token, LanguageError } = require('./runtime/base');` into every grammar-derived class file already** — an explicit `:import` for any of those three names on a *grammar-derived* class (not a free-standing one) redeclares the same identifier and fails with `Identifier 'X' has already been declared`. Only free-standing classes (which get no auto-injected requires at all) need to require them explicitly. Found live while porting V1's seven `Prim` subclasses, each of which throws `LanguageError` — the fix was deleting the redundant require, not adding one.
  - **A class attribute/static field doesn't need its own modifier** — a plain assignment statement (Python `env = Env.initEnv()`, Java `public static Env env = Env.initEnv();`, JS `static env = Env.initEnv();`) placed in the default (no-modifier) block is legal directly in the class body alongside method definitions, landing textually after the generated constructor but still valid at class-definition time.

## Out of Scope

- Haskell semantics (explicitly excluded by course usage).
- Any language not in the keep list (removed in Phase 0, recoverable from the original `languages` repo).
- Redesigning `Env`'s variants beyond what's needed to port them faithfully (e.g., no attempt to unify `envRN`/`envVal`/`envRef` into a single variant).

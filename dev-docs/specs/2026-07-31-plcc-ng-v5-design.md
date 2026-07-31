# plcc-ng Migration — V5 Design

This is a focused design of record for the V5 phase. It **extends**, and does
not repeat, the overarching
[plcc-ng Migration design](2026-07-22-plcc-ng-migration-design.md) — read that
first for the file/directory architecture, structural-fidelity rules, testing
strategy, and Env-sharing pattern that apply to every language. It builds
directly on the [V4 design](2026-07-30-plcc-ng-v4-design.md), whose grammar,
semantics, and `envVal` reuse V5 inherits almost entirely unchanged. This
document captures only the decisions and porting subtleties specific to V5,
settled in brainstorming on 2026-07-31.

## Goal

Port V5 (`V4 + letrec`) to plcc-ng: one shared `grammar.plcc` plus three target
`spec.plcc`s (Python, Java, JavaScript). The phase closes when all three
targets pass their bats suite.

V5 is the smallest delta of the migration so far. Diffing V5's old-PLCC files
against V4's shows `prim`, `val`, and `envVal` are **byte-identical**, and the
whole language difference is one token, one production, one new `Exp`
subclass, one new `LetDecls` method, and a one-word change to a
`checkDuplicates` message. The design's job is mostly to say precisely what
`letrec` means here, since that semantics is the one genuinely new idea.

## Grammar

`src/V5/grammar.plcc` is V4's grammar plus exactly two lines, keeping V5's
original token order (the new keyword goes directly after `LET`, well ahead of
the `SYMBOL` catch-all):

```
token LETREC 'letrec'
```

```
<Exp:LetrecExp>  ::= LETREC <LetDecls> IN <Exp>
```

Generated fields: `LetrecExp.letDecls` / `.exp`. Everything else — the token
list, `<Program>`, the other eight `<Exp>` alternatives, `<LetDecls>`,
`<Rands>`, `<Proc>`, `<Formals>`, `<SeqExps>`, and the seven `<Prim>`s — is
carried over from V4 unchanged.

V5's old `grammar` file carries a header comment claiming variable names "now
can have a `?` in them". That comment is stale: the widening to
`[A-Za-z][\w?]*` already happened at V4 (V4's design records why — `Prog/oe`
names procedures `even?`/`odd?`). The comment is not carried forward.

### No smoke test needed — the one novel risk was checked during design

`LETREC` is declared *after* `LET`, and `letrec` has `let` as a proper prefix.
If plcc-ng's scanner resolved token conflicts by declaration order rather than
by longest match, `letrec` would scan as `LET` followed by `SYMBOL 'rec'` and
the whole phase would need a grammar reorder. That was inference, not evidence,
so it was run against the installed CLI before this design was written:

```
$ echo 'letrec f = g in letx' | plcc-scan
-:1:1 LETREC 'letrec'
-:1:8 SYMBOL 'f'
-:1:10 EQUALS '='
-:1:12 SYMBOL 'g'
-:1:14 IN 'in'
-:1:17 SYMBOL 'letx'
```

**plcc-ng's scanner is maximal-munch.** `letrec` wins over `let` regardless of
declaration order, and `letx` stays a single `SYMBOL`. A companion `plcc-parse`
run confirmed `LetExp` and `LetrecExp` coexist as sibling `<Exp>` alternatives
with no LL(1) complaint. V5's token order therefore ports verbatim, and this
phase introduces no other unvalidated mechanic — no new arbno shape, no new
capture pattern, no new class modifier. Unlike V0, V1, and V4, **V5 needs no
spike of its own.**

## envVal Reuse

Zero-touch, for the third consecutive language. `src/V5/envVal` is byte-identical
to V4's, so each target's `spec.plcc` does `%include ../grammar.plcc` then
`%include ../../Env/envVal/<target>/env.plcc`, and no file under `src/Env/` is
modified in this phase.

Both facilities V5's `letrec` needs are already in the port: `EnvNode.add(binding)`
(which mutates the node's `Bindings` in place and returns the node) and the
no-argument `Bindings()` constructor.

One deliberate divergence from the Java original. `addLetrecBindings` calls
`new Bindings(varList.size())`, a capacity-taking constructor the port never
carried — V3's `envVal` port comment says so explicitly. Capacity is a JVM
`ArrayList` pre-allocation hint with no observable semantics, and Python and
JavaScript have no equivalent, so **V5 uses the no-arg `Bindings()`** rather
than adding a constructor to the shared `envVal` for one caller's benefit. The
resulting empty `Bindings` is exactly what the Java version produces.

## Semantics

Every V4 semantic class — `Val`, `IntVal`, `ProcVal`, the seven `Prim`s,
`Rands`, `Program`, `LitExp`, `VarExp`, `IfExp`, `PrimappExp`, `LetExp`,
`ProcExp`, `Proc`, `Formals`, `AppExp`, `SeqExp` — is reused verbatim. New work
is confined to three places.

**`LetrecExp`** — `eval(env)` rebinds `env` to `letDecls.addLetrecBindings(env)`
and returns `exp.eval(env)`. No `toString()`: the original has none, and the
port does not invent one (the same call V4 made for `ProcExp`).

**`LetDecls.addLetrecBindings(env)`** — extends `env` with an **empty**
`Bindings`, then walks `symbolList` and `expList` in lockstep, evaluating each
right-hand side **in the already-extended env** and mutating that same node via
`env.add(Binding(sym.lexeme, val))`. The extended env is returned.

**`LetDecls:init`** — the `checkDuplicates` message changes from
`" in let LHS identifiers"` to `" in let/letrec LHS identifiers"`. Faithful to
the original, and V5-local: V4 keeps its own wording.

**`LetDecls:import`** — Python and JavaScript gain `Binding` alongside the
existing `Env` and `Bindings` imports, since `addLetrecBindings` constructs
`Binding`s directly (V4's `addBindings` only ever built a whole `Bindings`).
Java needs no import, its free-standing classes being same-directory and
package-less.

### What `letrec` actually means here — recursion by mutation, not by fixpoint

This is the one idea in V5 that a reader has to be told rather than shown, and
it is what an instructor explains at the board, so the design states it
precisely.

When a `proc` right-hand side is evaluated, `Proc.makeClosure` captures the env
*object* — which at that moment is the node `addLetrecBindings` just created,
still holding zero bindings. Later iterations `add` to that same node. By the
time anything is ever *called*, the node holds every binding in the group, so
each closure's body can see its siblings and itself. Recursion falls out of
aliasing a mutable node, not out of computing a fixpoint or pre-seeding
placeholder bindings.

The flip side is that the binding pass itself is **eager and sequential**. A
non-`proc` right-hand side is evaluated on the spot, against a node that so far
holds only the bindings to its left. So:

- `letrec f = proc(n) ... .g(n) ..., g = proc(n) ... .f(n) ... in .f(5)` works —
  neither right-hand side *looks anything up* while binding.
- `letrec a = b, b = 1 in a` fails with `no binding for b` — `a`'s right-hand
  side is evaluated before `b` exists.

That is faithful to the original V5, not a porting artifact, and it is the kind
of divergence-from-intuition that belongs in the course-material-impact log.

### Alternative considered and rejected

The conventional textbook implementation of `letrec` is a two-pass one: bind
every name to a placeholder first, then evaluate the right-hand sides and patch
the placeholders. It removes the eager/sequential wrinkle above and is arguably
the better language design. It is rejected here because it would restructure
`addLetrecBindings` away from the Java reference for no behavioral gain on any
program the course actually runs, against the overarching design's
structural-fidelity rule — the same reasoning that keeps V4's placeholder
`toString()` stubs verbatim.

## Tests

`src/V5/tests/<case>/`, each case a shared `V5.input` + `V5.expected` (all three
targets must produce identical output) plus one `V5test.bats` with three `@test`
blocks, one per target directory, driven by `plcc-rep` — the same shape V3 and
V4 use. V5 ships one test today and has no `Prog/` directory to mine further
cases from, so the rest are written by hand. Four cases:

- **`letrec/`** — the existing case, ported off the old `plccmk`/`rep`
  invocation: `letrec fact = proc(x) if zero?(x) then 1 else *(x,.fact(sub1(x)))
  in .fact(5)` → `120`. Direct self-recursion, which V4 could only reach through
  the self-application trick in its `recursion/` case.
- **`mutual-recursion/`** — `even?` and `odd?` defined in a single `letrec` and
  calling each other. This is the case that exercises the env-node-mutation
  mechanism described above, and the reason `letrec` exists as a language
  feature: V4's `multi-formals/` had to simulate mutual recursion by passing the
  procedures to each other as arguments.
- **`nested-letrec/`** — an inner `letrec` shadowing an outer binding of the
  same name, confirming that scope layering still works when both layers are
  recursive.
- **`sequential-binding/`** — `letrec a = 1 b = +(a,1) in b` → `2`. Added after
  the whole-branch review observed that the other three cases bind only `proc`
  right-hand sides, so nothing asserted the left-to-right ordering that
  `addLetrecBindings` depends on. This is the positive half of the
  eager/sequential behavior described above; the negative half
  (`letrec a = b b = 1 in a`, which fails) stays out under the value-cases-only
  rule.

Value cases only — no error-path test for the duplicate-identifier check or the
forward-reference failure — keeping the one-shared-expected model clean, the
same call V3 and V4 made.

Recursion depths and magnitudes stay small in every case. Two live constraints
make this a rule rather than a preference: Python's recursion ceiling (which
forced V4 to shrink `Prog/oe`), and the 32-bit Java `IntVal` overflow of open
issue [#16](../issues/016-cross-target-integer-divergence.md). `.fact(5)` →
`120` is comfortably inside the safe range for both.

On the first of those: this design originally cited "Python's default
1,000-frame recursion limit", which is the right mechanism but the wrong
number. Measured during the whole-branch review, a V5 `letrec` self-recursion
dies in Python at roughly **N=330**, not 1,000 — each language-level call costs
several Python interpreter frames — while Java and JavaScript survive past
N=2,700. That threefold divergence is now tracked as open issue
[#19](../issues/019-python-recursion-ceiling.md), a sibling of #16: inherited
from V0/V4 rather than introduced here, but `letrec` is what makes deep
recursion the natural thing for a student to write.

## Bookkeeping (in the same commits as the work)

- File a V5 issue with `bin/issues/new.bash <slug> feat` and add its roadmap
  entry in the same commit; close it with `bin/issues/close.bash` as the
  branch's final commit.
- Delete the old flat old-PLCC files `src/V5/{grammar,code,prim,envVal,val}`
  once the three targets pass. As with V4, none of them collides with a new
  path (`src/V5/grammar` vs `src/V5/grammar.plcc`), so the deletion comes at the
  end rather than up front.
- Log V5 entries in
  [dev-docs/course-material-impact.md](../course-material-impact.md), each in
  the commit that makes the change: the `LETREC` token and `<Exp:LetrecExp>`
  production; `LetrecExp`'s missing `toString()`; the mutation-based
  `addLetrecBindings` semantics **and** its eager/sequential forward-reference
  limitation; `LetDecls`' fields being `symbolList`/`expList` rather than
  `varList`/`expList`; and the `checkDuplicates` message becoming
  `" in let/letrec LHS identifiers"`.
- The implementation plan lands under [dev-docs/plans/](../plans/) (via
  writing-plans).

### Expected test counts

Recomputed fresh against the installed CLI on this branch, not decremented from
V4's plan — V2's plan got this wrong precisely by copying and adjusting.

These figures were themselves corrected mid-execution. The first version of this
section claimed 46 of 48 passing, derived from a `bin/test.bash` run piped
through `tail -40`: the seven non-V languages sort alphabetically *before* `V0`,
so their seven failures fell outside the window and were never seen. Count from
the whole run, or from `grep -c`, not from a tail.

The suite today is **48 tests: 39 passing and 9 failing**, every failure a
`plccmk: command not found` from a language still on old PLCC — NAME, NEED,
OBJ, REF, SET, TYPE0, TYPE1, V5, and V6. (Only the V-series has been migrated
so far; the seven non-V languages are Phases 3–5 and are untouched here.)

After this phase: **59 tests** — 48, minus V5's 1 old test, plus 12 new (4 cases
× 3 targets) — **51 passing and 8 failing**, the same `command not found` set
minus V5. (The fourth case, `sequential-binding/`, was added after the
whole-branch review; the suite stood at 56 tests / 48 passing before it.)

The load-bearing invariant is the delta, not the totals: the
`command not found` count must drop by **exactly 1**, and no test that passed
before may fail after.

## Out of Scope

- V6, including `define`, its `Prog/` directory, and the unvalidated
  `plcc-rep`-loop persistent-state question the overarching design flagged for
  it.
- Issue [#16](../issues/016-cross-target-integer-divergence.md) — repo-wide and
  inherited from V0, not V5's to fix.
- Error-path / diagnostic tests.
- Any change to `envVal`, including adding the capacity-taking `Bindings`
  constructor, or any unification of the Env variants.
- Replacing the mutation-based `letrec` with a two-pass placeholder
  implementation.
- Unifying the per-language `Val`/`IntVal`/`Prim` duplication — ruled out
  repo-wide by the overarching design.

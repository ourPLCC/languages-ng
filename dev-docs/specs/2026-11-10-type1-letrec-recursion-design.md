# TYPE1 recursive `letrec` — design

Date: 2026-11-10
Reported in: [ourPLCC/languages-ng#23](https://github.com/ourPLCC/languages-ng/issues/23)

## Problem

TYPE1's type checker rejects any `letrec` whose right-hand side refers to
its own name or to a name bound later in the same `letrec`:

```text
letrec fact = proc(n : int) : int if zero?(n) then 1 else *(n, .fact(sub1(n))) in .fact(5)
```

gives `no type binding for fact` instead of `120`, and mutual recursion
(`even`/`odd`) fails the same way. TYPE1 therefore cannot type-check
recursion through `letrec` at all; only top-level `declare`/`define`
recursion works. The bug is in all three targets and predates the port.

It surfaced while preparing TYPE1 lecture notes: the recursive examples a
lecture on static typing would naturally use do not run. That preparation is
waiting on this fix.

The cause is `LetDecls.addLetrecTypeBindings`, which types each right-hand
side *before* binding its name. `Proc.evalType` checks the proc's body, so a
reference in the body to the name being bound, or to a later one, finds no
type binding.

## Decision

A proc's type comes from its annotations alone — formal parameter types and
declared return type — so it is known before any body is checked.
`addLetrecTypeBindings` becomes two passes over the declarations, in a fresh
type environment extending `tenv`:

1. For each right-hand side that is a `ProcExp`, bind its name to the proc's
   defined type.
2. For each right-hand side in order, compute its type with `evalType` in
   that environment (for a proc this checks its body). Bind the name of each
   right-hand side that is **not** a `ProcExp` to its computed type, as
   today.

`Proc` gains `definedType()`, returning
`ProcType(formals.formalTypeList(), typeExp.toType())` without checking the
body. The original Java had this method; the TYPE1 port dropped it for having
no callers.

The change is made identically in `src/TYPE1/python/spec.plcc`,
`src/TYPE1/java/spec.plcc` and `src/TYPE1/javascript/spec.plcc`, each in that
file's own idiom.

### Consequence: recursive calls are type-checked

A recursive call is now checked against the proc's declared parameter and
return types. `letrec f = proc(n : int) : int .f(true) in 0` becomes
`type mismatch: bool != int`, where today it is `no type binding for f`.

### Unchanged on purpose: declaration order

`letrec` evaluates its declarations in order. Mutual recursion works because
a proc's body is not evaluated until the proc is first applied, after it has
captured the `letrec` environment. A name used before its declaration has
run is unbound — at runtime, and for a non-proc, at check time. This is the
same in every language in the repository that has `letrec`, is not a typing
question, and is out of scope. In particular, these keep their behavior
under the fix:

- `letrec f = proc() : int y  y = 3 in .f()` is rejected by the checker with
  `no type binding for y` (`y` is not a proc, so pass 1 does not bind it).
- `letrec y = .f() f = proc() : int 3 in y` passes the checker and fails at
  runtime with `no binding for f`.

Neither gets a test; they are recorded here so that no one "fixes" them as
part of this change.

## Tests

A new suite `src/TYPE1/tests/letrec/`, shaped like the other TYPE1 suites
(`TYPE1.input`, `TYPE1.expected`, `TYPE1test.bats` running all three
targets). One program per input line, so a type error does not stop later
lines.

| Program | Expected |
| --- | --- |
| `fact` via self-recursive `letrec`, applied to 5 | `120` |
| `even`/`odd` via mutually recursive `letrec`, `.even(4)` | `true` |
| `odd?`, `even?` and `fact` in one `letrec` | that program's result |
| `letrec f = proc(n : int) : int .f(true) in 0` | `type mismatch: bool != int` |
| `letrec f = proc(n : int) : bool add1(n) in .f(3)` | `type mismatch: int != bool` |
| `letrec f = proc(n : int) : int n in .f(3)` | `3` |
| `letrec x = 3 y = add1(x) in y` | `4` |

The first three fail before the fix; the last four pin behavior the fix must
keep, plus the new checking of recursive calls. The full suite
(`bin/test.bash`) must still pass.

## Course materials

The change gets an entry under TYPE1 in
[`dev-docs/course-material-impact.md`](../course-material-impact.md), in the
same commit as the fix: recursive `letrec` now type-checks, recursive calls
are checked against declared types, and `Proc` has `definedType()`.

The textbook's TYPE1 chapter in `course-materials-ng`
(`textbook/20-type1.md`) describes this approach in prose but shows the old
loop; it needs the same correction, as separate work in that repo.

## Left to the builder

- The exact text of the three-proc `odd?`/`even?`/`fact` test program, and
  its expected result.
- How each target tests "is a `ProcExp`" (`isinstance`, `instanceof`, or an
  equivalent idiomatic to that spec file).

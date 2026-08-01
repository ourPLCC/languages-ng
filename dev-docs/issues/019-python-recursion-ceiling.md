---
type: docs
target: this repo
opened: 2026-07-31
closed:
---

# 019 - python-recursion-ceiling

<!--
Classify by user-facing impact, not by whether something was "broken".
`fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.
-->

## Description

The three targets diverge sharply on how deep language-level recursion
can go before the interpreter itself gives up, and the divergence is
not tracked anywhere. Python's ceiling is roughly an order of magnitude
lower than Java's or JavaScript's, because each language-level call
costs several Python interpreter frames (one for `eval`, one for
`Proc.apply`, one or more for the primitive dispatch, etc.), where the
V5 design's own wording — "Python's default 1,000-frame recursion
limit" — describes the underlying CPython constant but understates its
effect on this interpreter about eightfold.

**This is inherited, not introduced by V5** — V4's self-application
recursion trick hits the exact same ceiling, since the divergence lives
in how deeply each target's `eval`/`apply` call chain nests per
language-level call, not in anything `letrec` adds. But `letrec` is
what makes deep recursion the natural, obvious thing to write (direct
self-recursion via `.f(...)` instead of V4's self-application
workaround), so V5 is where a student or instructor is first likely to
trip over it live.

The Python failure also reports
`Specification error: RecursionError: maximum recursion depth exceeded`
followed by `Fix the errors in your specification and re-run.` — wording
that blames the language *specification* (i.e., the grammar/semantics
files under `src/V5/python/`) rather than the student's program, which
is doubly misleading right at the point a student most needs a clear
signal.

Sibling issue to [#16](016-cross-target-integer-divergence.md): same
shape of defect (a cross-target divergence inherited from an earlier
V-language, newly reachable at the language currently being migrated),
filed at the same point in that branch's life — the whole-branch review
after implementation was otherwise judged ready to merge.

## Steps to Reproduce

1. Using `src/V5/{python,java,javascript}/spec.plcc`, run the following
   program through `plcc-rep` for each target, varying `N`:

   ```
   letrec f = proc(x) if zero?(x) then 0 else .f(sub1(x)) in .f(N)
   ```

2. Measured results (this branch, 2026-07-31):

   | Target | Last `N` that returns `0` | First `N` that fails | Failure |
   |---|---|---|---|
   | Python | 329 | 330 | `Specification error: RecursionError: maximum recursion depth exceeded` |
   | Java | 2700 | 2800 | `Specification error: StackOverflowError:` |
   | JavaScript | 2800 | 2900 | `Specification error: RangeError: Maximum call stack size exceeded` |

   So the practical ceiling is roughly **330 language-level calls in
   Python vs. roughly 2800 in Java and JavaScript** — Python's ceiling is
   about an eighth of the other two targets', not the threefold gap a
   naive reading of "1,000-frame limit" would suggest.

3. Clean up any `plcc-ng/` and `__pycache__/` build directories left in
   the target directory afterward (`rm -rf plcc-ng __pycache__`).

## Notes

Found during the whole-branch review of the V5 migration (the branch
that added `letrec`), the same review pass that produced the
sequential-binding test gap. V5 did not introduce the divergence — V4's
`recursion/` test already runs at the same per-language-level-call cost
on all three targets — but V5's design explicitly reasons about Python's
recursion limit (see
[dev-docs/specs/2026-07-31-plcc-ng-v5-design.md](../specs/2026-07-31-plcc-ng-v5-design.md),
"Tests" section) while keeping all shipped test cases small enough to
stay far below any of these ceilings, so the actual numbers were never
measured until now.

An earlier pass at this measurement (not this branch's own, but a
figure quoted in the initial ask that prompted filing this issue) guessed
Java and JavaScript would only fail "near N=10000." That guess was
re-measured and found wrong: both fail around N=2800–2900 here, not
N=10000. The table above is this branch's own direct measurement — if
re-measuring on different hardware or interpreter versions, expect the
exact crossover to move, but expect Python's ceiling to remain roughly
an order of magnitude below Java's and JavaScript's.

No fix is proposed here. Plausible directions for a future issue:
raising Python's recursion limit for the generated interpreter, making
the "Specification error" wording distinguish an interpreter-resource
error from an actual specification defect, or documenting the ceiling
so course material stays inside it (tracked separately in
[dev-docs/course-material-impact.md](../course-material-impact.md)).

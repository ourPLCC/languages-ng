---
type: docs
target: this repo
opened: 2026-07-30
closed:
---

# 016 - cross-target-integer-divergence

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

Java's `IntVal.val` is a 32-bit `int`; Python's integers are
arbitrary-precision and JavaScript's are IEEE-754 doubles. The three
targets therefore diverge on large values: Java silently wraps
(two's-complement overflow) where Python and JavaScript keep computing
the exact integer.

**This is inherited from V0 and is not a V4 defect** — every migrated
language shares the same `IntVal` shape in each target, so every one of
them has this divergence. **V4 is where it becomes trivially reachable,
though**: three lines of recursion get you there (see `Steps to
Reproduce`), and this branch promoted factorial into the automated test
suite as `src/V4/tests/recursion/`. An instructor demonstrating
`Prog/fact-acc` past `.fact(12)` gets a different answer depending on
which target is on the projector, with no error or warning on the Java
side — it just silently wraps.

The `recursion/` test itself is unaffected: it uses `.fact(5)` → `120`,
well inside the 32-bit-safe range (`13!` is the first factorial to
overflow a signed 32-bit `int`).

This belongs to the **overarching** migration design
([dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)),
not to V4's, since it is a repo-wide property of the `IntVal` shape used
by every language, not something V4 introduced. Also note that
Python and JavaScript only agree in the range tested below — JavaScript's
doubles lose exact-integer precision above 2^53
(9007199254740992), so "Python and JS agree" is not a general claim.

## Steps to Reproduce

1. Take `src/V4/Prog/fact-acc` (do not edit it in place — copy it to a
   scratch directory) and change its final call.
2. Run it through `plcc-rep` for each of the `python`, `java`, and
   `javascript` targets. Measured results:

   | program | Python | JavaScript | Java |
   |---|---|---|---|
   | `.fact(13)` | `6227020800` | `6227020800` | `1932053504` |
   | `.fact(20)` | `2432902008176640000` | `2432902008176640000` | `-2102132736` |

3. Clean up any `plcc-ng/` and `__pycache__/` build directories left in
   the scratch copy afterward.

## Notes

Found during the whole-branch review of the V4 migration (issue #14,
already closed). V4 did not introduce the divergence — it is present in
every language back to V0 — but V4's `Prog/fact-acc` and the new
`recursion/` test are the first place in the repo where a shipped example
program is close enough to the overflow boundary (`.fact(5)` vs. a
plausible classroom `.fact(13)`+) that an instructor could stumble into
it live.

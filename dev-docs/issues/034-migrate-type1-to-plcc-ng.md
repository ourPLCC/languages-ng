---
type: feat
target: this repo
opened: 2026-08-10
closed: 2026-08-10
---

# 034 - migrate TYPE1 to plcc-ng

<!--
`type` is a conventional commit type: fix, feat, refactor, perf, docs,
test, chore. Classify by user-facing impact, not by whether something was
"broken". `fix` and `feat` bump the release version (see .releaserc.yaml);
reserve them for changes to the shipped languages (src/). A bug in a
test, script, or CI workflow (bin/, .github/) is still a bug, but it's
not user-facing — classify it `test` or `chore` instead so it doesn't
spin the version. `docs` is for documentation content, and never bumps
the version either way.

`target` is the repository the issue is actually about. It defaults to
this repo; set it to the upstream repository (e.g. ourPLCC/plcc-ng) when
the defect is there rather than in this repo's own src/.

`closed` stays empty until bin/issues/close.bash fills it in.
-->

## Description

Port TYPE1 (`TYPE0 + declare + and/or/not + strong type checking`) to
plcc-ng: one shared `src/TYPE1/grammar.plcc` plus three target `spec.plcc`s
(Python, Java, JavaScript). This is the last language of Phase 4, and the
first migrated language whose central feature is *rejecting* programs
rather than computing values.

The port starts from TYPE0's three shipped `spec.plcc`s, not from TYPE1's
own pre-migration flat files — those fork from *pre-migration* TYPE0 and
never received the fixes the migration made. It adds nine free-standing
classes for the type and type-environment hierarchies (`Type`, `IntType`,
`BoolType`, `ProcType`, `TypeEnv`, `TypeEnvNode`, `TypeEnvNull`,
`TypeBinding`, `TypeBindings`), an `evalType` pass that runs before every
evaluation, and `definedType()` on every prim. `envRef` is reused
unchanged for its fifth consecutive language.

The port also reverts four drift items where TYPE1's pre-migration fork
diverged from shipped TYPE0 for no coherent reason: `Val.isTrue()` raises
rather than silently returning `false`; the prim arity guards and
`ProcVal.apply`'s formals/args count check are kept rather than deleted;
and, the substantive one, **call-by-reference is restored** —
pre-migration TYPE1 rewrote `evalRandsRef` to always allocate a fresh
cell, silently dropping the aliasing behavior that is REF's entire
namesake feature.

## Notes

See
[dev-docs/specs/2026-08-10-plcc-ng-type1-design.md](../specs/2026-08-10-plcc-ng-type1-design.md),
which extends
[dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)
and builds directly on
[dev-docs/specs/2026-08-06-plcc-ng-type0-design.md](../specs/2026-08-06-plcc-ng-type0-design.md).

Three targets, five test cases (`proc-types/`, `boolean-ops/`,
`declare-define/`, `call-by-reference/`, and `type-errors/` — the last a
scoped exception to the value-cases-only rule, since type errors are the
one thing no value-only suite can reach), and the four existing `Prog/`
examples carried forward unchanged.

Out of scope: OBJ; any change to `envRef` or `src/Env/`; factoring
`TypeEnv` into a shared `src/Env/` variant; type inference, subtyping, or
any relaxation of `checkEquals`'s exact structural equality; error-path
tests other than type errors; and issue
[#16](016-cross-target-integer-divergence.md) (cross-target integer
divergence), issue [#19](019-python-recursion-ceiling.md) (Python
recursion ceiling), issue
[#22](022-plcc-rep-parses-each-source-independently.md) (plcc-rep parses
each SOURCE argument independently), and issue
[#27](027-use-spec-flag-instead-of-copying-tree.md) (use `-s` instead of
copying the tree) — all repo-wide and inherited.

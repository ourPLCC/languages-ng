---
type: docs
target: this repo
opened: 2026-08-05
closed: 2026-08-05
---

# 026 - apply-env-comment-missing-from-most-targets

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

`ProcVal.apply` takes an environment as its second parameter and does not
read it — a proc resolves free variables in the environment it captured
when it was created. Every migrated language that has `proc` declares it
this way: V4, V5, V6, SET, and REF, in all three targets. That is
15 files.

Only **2 of those 15** carry any comment explaining it: `src/SET/java`
and `src/REF/java`. In the other 13 — including all of V4, V5, and V6,
and the Python and JavaScript appendices of SET and REF — a reader meets
a declared parameter that is never used, with nothing saying why.

That is a live hazard rather than a cosmetic gap. The obvious "cleanup"
is to delete the parameter, and doing so is a signature change rippling
through every call site. The [migration design](../specs/2026-07-22-plcc-ng-migration-design.md)
also asks that the three targets read alike so one explanation can serve
a reader following along in any appendix; an explanation present in one
target and absent in two is exactly the divergence that section exists to
prevent.

Separately, **the wording in those two Java files is wrong for shipped
course material.** It currently reads:

```java
// `e` is the calling environment (unused); `env` above is the one
// captured at proc-evaluation time. A dynamic-scoping reimplementation
// of `proc` would resolve free variables against `e` instead.
```

These files are read by students as textbook appendices, so a comment
describing a homework assignment telegraphs the exercise. The comment
should state the semantics instead: application, like evaluation, takes
place in the context of an environment, which arrives as the second
parameter; a proc may use or ignore it as its own semantics require; this
one ignores it. It should **not** mention dynamic scoping.

## Notes

The parameter itself must not be removed — see the *`apply` keeps its
`Env` parameter* section of the
[SET design](../specs/2026-08-04-plcc-ng-set-design.md).

The two existing comments are rewritten, not merely copied outward, so
the 13 additions and the 2 rewrites all land on the same text.

`Val.apply` also declares the parameter, but it only throws "cannot
apply" — nothing is applied there and no environment is consulted, so the
comment belongs on `ProcVal.apply` alone. The `Prim.apply` methods take no
environment at all and are out of scope.

Any language migrated after this (NAME, NEED, TYPE0, TYPE1, OBJ) should
carry the same comment from the start.

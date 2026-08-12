---
type: chore
target: ourPLCC/plcc-ng
opened: 2026-08-11
closed: 2026-08-12
---

# 038 - FOLLOW set omits the nullable tail, breaking empty alternatives

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

plcc-ng 2.0.1 computes an under-approximated FOLLOW set for a nonterminal
that is followed by a nullable symbol. The predict set of an **empty
alternative** is exactly FOLLOW of its nonterminal, so the generated parse
table silently loses entries and valid programs fail to parse — while
`plcc-ll1` still reports `is_ll1: true` and no conflicts.

The defect is in
`plcc/spec/syntax/validations/ll1/build_follow_sets.py`,
`FollowSetBuilder._updateWithSingleOccuranceOfNonterminalInProduction`:

```python
else:
    self._addFirstOfNextSymbol(rules[index + 1], nonterminal)
    if self._canDeriveEmpty(rules[index + 1:]):
        self._addFollowOfLHS(lhs, nonterminal)
```

It adds FIRST of the **single** next symbol, then jumps straight to the
"whole remainder is nullable" case. The standard algorithm walks forward
from `index + 1`, adding `FIRST(X_j) \ {ε}` and stopping at the first
`X_j` that is not nullable. When `X_{i+1}` is nullable but the remainder
is not, every symbol between them is skipped.

A repeating (`**=`) nonterminal makes this easy to hit, because it is
nullable by construction and is a natural thing to place in a sequence.

## Steps to Reproduce

1. Grammar (this is OBJ's, reduced):

   ```
   <ClassDecl>     ::= CLASS <Ext> <Statics> <Fields> <Methods> END
   <Ext:Ext1>      ::= EXTENDS <Exp>
   <Ext:Ext0>      ::=
   <Statics>       **= STATIC <SYMBOL> EQUALS <Exp>
   <Fields>        **= FIELD <SYMBOL>
   <Methods>       **= METHOD <SYMBOL> EQUALS <Proc>
   ```

2. `plcc-ll1` reports `is_ll1: true`, no conflicts, and
   `FOLLOW(Ext) = ['STATIC']`. The correct set is
   `{STATIC, FIELD, METHOD, END}`.

3. `printf 'class static x = 3 end\n' | plcc-parse` — parses.

4. `printf 'class field x end\n' | plcc-parse` — fails:

   ```
   plcc-parser-table: -:1:7: error: unexpected 'FIELD', no production for 'Ext'
   ```

   Same for `class method m = proc() 1 end` and for the empty `class end`.

## Notes

Two things make this worse than an ordinary parse bug.

**It is silent.** `plcc-ll1` reports the grammar LL(1)-clean, so nothing
warns the spec author. The failure appears later, on one particular input
shape, as an error pointing at the nonterminal with the empty
alternative rather than at the real cause.

**The diagnosis is inverted.** The message names the token that *is*
there (`unexpected 'FIELD'`) and the nonterminal that has no entry for it,
which reads like a grammar-ambiguity problem. The actual cause is several
rules away, in a symbol the author never looked at.

Suggested fix, replacing the `else` branch above:

```python
else:
    for j in range(index + 1, len(rules)):
        self._addFirstOfNextSymbol(rules[j], nonterminal)
        if not self._canDeriveEmpty([rules[j]]):
            break
    else:
        self._addFollowOfLHS(lhs, nonterminal)
```

Found while porting OBJ
([dev-docs/specs/2026-08-11-plcc-ng-obj-design.md](../specs/2026-08-11-plcc-ng-obj-design.md)).
The design measured `<Ext:Ext0>` working, but only on
`class static x = 3 …` — the one class shape whose next token happens to
be in the truncated FOLLOW set. `src/OBJ/grammar.plcc` works around it by
splitting the class body into a non-nullable `<ClassBody>` nonterminal, so
that the symbol immediately after `<Ext>` has a correctly computed FIRST
set. The accepted language is unchanged. When this is fixed upstream the
workaround can be reverted, as issue
[#006](006-multi-capture-alt-name-case-mismatch.md) was.

Per issue-conventions.md, upstream-targeted issues stay in this repo and
are reported upstream manually, with explicit go-ahead.

**Filed upstream 2026-08-11** as `ourPLCC/plcc-ng` issue #188
(`dev-docs/issues/188-follow-set-omits-nullable-tail.md`), typed `fix`. The
quoted `else` branch was re-verified against plcc-ng's current
`build_follow_sets.py` and is unchanged, so the suggested forward-walk fix
still applies as written. The upstream issue also distinguishes this from
its already-fixed #170, which was the first-registered-production
nullability check in the same function — `_canDeriveEmpty` now consults the
FIRST sets, and this forward-walk defect survived that fix. This issue
stays open while `src/OBJ/grammar.plcc`'s `<ClassBody>` workaround lives in
the grammar.

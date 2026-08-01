# 010 - plcc-ng-arbno-drops-mid-body-terminal

**Type:** chore
**Target:** ourPLCC/plcc-ng
**Date:** 2026-07-28

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

A `**=` (arbno) repeated-rule body **silently loses any non-capturing
terminal that appears between two capturing symbols** when no separator is
declared. The grammar analyzes as LL(1) (`is_ll1: True`, `conflicts: []`),
but the generated runtime parse table omits the terminal, so parsing fails
at runtime.

This blocks V3's `let` grammar, whose natural (and original course-material)
shape is:

```
<LetDecls> **= <SYMBOL> EQUALS <Exp>
```

Here `EQUALS` is a non-capturing terminal sitting between the capturing
`<SYMBOL>` and `<Exp>`, with no declared separator. Parsing
`let three = 2 four = 5 in +(three, four)` dies immediately after the first
`SYMBOL`:

```
Program
  LetExp
    LET 'let' [-:1:1]
    LetDecls
      SYMBOL 'three' [-:1:5]
plcc-parser-table: -:1:11: error: unexpected 'EQUALS', no production for 'Exp'
```

V0–V2 never hit this: their only `**=` rule is `<Rands> **= <Exp> +COMMA`,
where `COMMA` is a **separator** (a different, working code path), not a
mid-body terminal.

## Steps to Reproduce

1. Write a grammar containing an arbno rule with a mid-body non-capturing
   terminal and no separator, e.g.:
   ```
   token SYMBOL '[A-Za-z]\w*'
   token EQUALS '='
   token LIT '\d+'
   ...
   <LetDecls> **= <SYMBOL> EQUALS <Exp>
   ```
2. `plcc-parse -s grammar.plcc` (or `plcc-rep`) on input that exercises the
   rule (`x = 1 y = 2`).
3. Observe `unexpected 'EQUALS', no production for '<next capture>'` — the
   `EQUALS` is never shifted.

## Notes

**Root cause** (confirmed against the installed 2.0.0 CLI by inspecting the
generated `plcc-ng/ll1.json` and the plcc-ng sources):

- LL(1) table *analysis* is correct — it expands
  `LetDecls -> SYMBOL EQUALS Exp LetDecls# | ε`, `EQUALS` included.
- The bug is in the *runtime* arbno metadata built by
  `plcc/ll1/spec_json_decoder.py::_handle_arbno`, which filters the repeated
  body to capturing symbols only:
  ```python
  arbno_rhs = [
      {"field": _arbno_field(s), "symbol": s["name"],
       "is_terminal": bool(s.get("isTerminal", False))}
      for s in rhs
      if s.get("isCapturing", False)   # <-- drops non-capturing EQUALS
  ]
  ```
  The resulting `ll1.json` "arbno" entry for `LetDecls` lists only
  `symbolList` (SYMBOL) and `expList` (Exp); `EQUALS` is gone.
- At runtime, `plcc/parser/predictive_parser.py::_parse_arbno` walks exactly
  that `rhs` list per iteration, so after consuming `SYMBOL` it tries to
  parse `Exp` and chokes on the unshifted `EQUALS`.

**Suggested fix:** `_parse_arbno`'s per-iteration walk should consume *all*
rhs symbols (shifting non-capturing terminals, appending only capturing ones
to their field lists), rather than only the capturing subset — mirroring how
a non-arbno `::=` rule consumes its full RHS.

**Impact on this repo:** V3's `let` migration was **paused** on this. The
decision (see roadmap / issue #9) was to keep V3's grammar in its faithful
original shape rather than restructure around the bug, and resume once
plcc-ng fixed this upstream. Per [dev-docs/issue-conventions.md](../issue-conventions.md),
this issue stays open until the upstream fix lands and any local change is
reconciled. Confirm before filing this publicly in `ourPLCC/plcc-ng`.

**Fixed upstream in plcc-ng 2.0.1** (verified 2026-07-29 against the exact
V3 grammar). `_handle_arbno` now emits an entry for *every* rhs symbol,
tagging non-capturing ones `"field": null` instead of dropping them:

```python
arbno_rhs = [
    {"field": _arbno_field(s) if s.get("isCapturing", False) else None,
     "symbol": s["name"], "is_terminal": bool(s.get("isTerminal", False))}
    for s in rhs
]
```

and `_parse_arbno` shifts those `field: null` terminals per iteration
without appending them to a list field — the fix suggested above.
`let three = 2 four = 5 in +(three, four)` now parses cleanly, with
`LetDecls` yielding `symbolList` and `expList`. Since no local workaround
was ever committed, nothing needs reverting; this issue closes once the
devcontainer is rebuilt on 2.0.1 and V3's real grammar parses (V3 plan,
Task 1b → Task 2).

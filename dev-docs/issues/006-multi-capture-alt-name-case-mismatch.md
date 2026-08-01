---
type: docs
target: ourPLCC/plcc-ng
opened: 2026-07-23
closed: 2026-07-28
---

# 006 - multi-capture-alt-name-case-mismatch

## Description

When a grammar alternative captures the same nonterminal more than once
with camelCase alt-names (e.g. `<Exp:testExp>`, `<Exp:trueExp>`,
`<Exp:falseExp>` in an `if...then...else` rule), the generated Python/Java
class fields keep the alt-name's original case (`testExp`, `trueExp`,
`falseExp`), but the parser always lowercases alt-names when building the
runtime parse tree it hands to the registry. The two disagree, so
`plcc-rep`/`plcc-parse` fail at runtime with e.g.:

```
Specification error: KeyError: "No class for rule 'IfExp' with fields {'testexp', 'trueexp', 'falseexp'}"
```

Root cause (found by reading the installed package,
`plcc/spec/syntax/CapturingSymbol.py`):

```python
def getAttributeName(self):
    if self.altName is None:
        return self.name.lower()
    else:
        return self.altName.lower()   # always lowercased
```

versus code generation (`plcc/model/build_model.py`), which uses the
alt-name as written, uncased:

```python
field_name = symbol.get('altName') or symbol.get('name', '').lower()
```

## Steps to Reproduce

1. `grammar.plcc`:
   ```
   skip WHITESPACE '\s+'
   token LIT '\d+'
   token IF 'if'
   token THEN 'then'
   token ELSE 'else'
   %
   <Program>    ::= <Exp>
   <Exp:LitExp> ::= <LIT>
   <Exp:IfExp>  ::= IF <Exp:testExp> THEN <Exp:trueExp> ELSE <Exp:falseExp>
   ```
2. `spec.plcc` (Python), with `IfExp.eval()` referencing `self.testExp`,
   `self.trueExp`, `self.falseExp` — matching the grammar's declared
   alt-names exactly.
3. `echo "if 1 then 2 else 3" | plcc-rep`
4. Actual: `Specification error: KeyError: "No class for rule 'IfExp'
   with fields {'testexp', 'trueexp', 'falseexp'}"`. Expected: `2`.

Reproduced identically against the Java target (same error, "No class
for rule 'IfExp' with fields [testexp, trueexp, falseexp]"), consistent
with the root cause living in the shared, language-agnostic
`plcc/spec/syntax` module rather than in either target's code generator.
JavaScript wasn't separately reproduced but is presumably affected for
the same reason.

## Notes

**Workaround confirmed working in both Python and Java:** write the
alt-name entirely in lowercase in the grammar (`<Exp:testexp>`,
`<Exp:trueexp>`, `<Exp:falseexp>`) so the generated field name and the
parser's lowercased attribute name already agree. Semantic-section code
then reads `self.testexp` / `self.trueexp` / `self.falseexp` (all
lowercase) instead of the camelCase the old PLCC grammar used.

This is load-bearing for V2 and every later phase: V2 introduces
`IfExp`'s `testExp`/`trueExp`/`falseExp` shape, and V3–V6 all reuse the
identical grammar rule verbatim (confirmed via
`grep -rn "testExp" src/V*/grammar`). V2's plan should adopt the
all-lowercase alt-name spelling in the shared `grammar.plcc` from the
start, the same way `VAR` needed renaming to `name` for the JavaScript
reserved-word collision (see issue #4) — one fix in the grammar,
inherited by every later phase automatically.

Found while spiking V2's `IfExp` mechanics for
[dev-docs/plans/2026-07-22-plcc-ng-phase2-v1.md](../plans/2026-07-22-plcc-ng-phase2-v1.md)'s
successor plan. Not filed upstream yet — needs the repo owner's
go-ahead first.

**Resolved in plcc-ng 2.0.0:** alt-name casing is preserved, so `IfExp`'s
`testExp`/`trueExp`/`falseExp` work as written. The all-lowercase workaround
was reverted. Upstream shipped the fix, so filing upstream is moot.

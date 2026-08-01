---
type: chore
target: this repo
opened: 2026-07-27
closed: 2026-07-29
---

# 008 - update-plcc-ng-2.0.0

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

Adopt `plcc-ng` 2.0.0 (and the matching `plcc-ng` devcontainer image),
which fixes the upstream defects we worked around while building V0–V2,
and use the adoption to restore the **original course materials'
camelCased identifiers** wherever a workaround forced a different
spelling.

Per the 2.0.0 [What's new](https://ourplcc.github.io/plcc-ng/latest/whats-new/):

- **`_run()` return behavior (BREAKING).** The entry point now returns
  its output as a string and the runtime prints it; direct stdout
  printing is no longer permitted. Java's `_run()` goes `void` → `String`;
  Python/JS must `return` a string, not `print`. This **inverts** our
  issue [#3](003-python-run-return-value-quoted.md) workaround — the repo
  currently `print()`s everywhere and must switch back to returning.
- **Alt-name casing fixed.** camelCase alt-names are no longer flattened,
  and multi-word nonterminal captures decapitalize only the first letter.
  This fixes issue [#6](006-multi-capture-alt-name-case-mismatch.md), so
  `IfExp`'s `testExp`/`trueExp`/`falseExp` can go back to camelCase.
- **Reserved-word detection added.** The tool now reports a field name
  colliding with a target-language reserved word as a *specification
  error* at emit/run time (rather than silently generating broken code).
  This means issue [#4](004-js-var-field-reserved-word.md)'s `<VAR>` →
  `var` collision is now a hard error, so an explicit field name is still
  required — TBD in brainstorming what the original course materials call
  it.
- **LL(1) FOLLOW-set fix** for late-registered nullable productions.
- Docs examples verified LL(1)/compiling/running as written.

## Scope

- Bump the devcontainer image (`.devcontainer/devcontainer.json`) to the
  2.0.0-bearing `plcc-ng` image and pin it reproducibly (the base image
  is currently the floating `:1` tag and is not captured in
  `devcontainer-lock.json`).
- Rebuild; re-run the V0/V1/V2 bats suites as a regression guard.
- Revert the workarounds to the original course-material spellings where
  2.0.0 allows it (issues #3 and #6 for sure; #4 subject to the
  reserved-word constraint), updating the shared grammars/specs and
  `dev-docs/course-material-impact.md` accordingly.
- Close issues #3, #4, #6 as resolved-upstream where 2.0.0 resolves them;
  reconcile their "pending approval to file upstream" notes.

## Notes

Exact approach — sequencing, how far to pin, and precisely which
identifiers revert to what — to be settled in brainstorming; a design
spec and plan will follow under `dev-docs/`.

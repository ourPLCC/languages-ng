# 004 - js-var-field-reserved-word

**Type:** docs
**Target:** ourPLCC/plcc-ng
**Date:** 2026-07-22

## Description

A grammar token captured with its auto-generated field name colliding
with a JavaScript reserved word produces JavaScript that fails to load.
Specifically, `<VAR>` (no explicit `:fieldname`) auto-names its field
`var`, and the JavaScript target's generated constructor uses that name
as a parameter (`constructor(var) { ... }`), which is a `SyntaxError` in
JavaScript (`var` is reserved).

## Steps to Reproduce

1. Grammar with `token VAR '[A-Za-z]\w*'` and `<Exp:VarExp> ::= <VAR>`
   (no explicit field name), targeting `javascript`.
2. `echo "x" | plcc-rep`
3. Actual: `SyntaxError: Unexpected token 'var'` while loading the
   generated `VarExp.js`. Expected: it runs, same as the Python/Java
   targets do with the same grammar.

Renaming the capture (e.g. `<VAR:name>`) works around it. Since `VAR` is
the conventional token name for identifiers across all of this repo's
languages, this repo now renames it everywhere a grammar is shared across
targets, rather than special-casing JavaScript.

## Notes

Found while validating [dev-docs/plans/2026-07-22-plcc-ng-phase0-phase1.md](../plans/2026-07-22-plcc-ng-phase0-phase1.md).
`plcc-ng` might reasonably want to either reject/rename reserved-word
field names at generation time, or document the restriction. Not filed
upstream yet — needs the repo owner's go-ahead first.

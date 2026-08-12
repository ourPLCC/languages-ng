---
type: fix
target: this repo
opened: 2026-08-12
closed:
---

# 039 - putc/puts diverge across targets; Python fails session-fatally

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

`putc`/`puts` behave differently on all three OBJ targets for an
out-of-range character code, and Python's failure is session-fatal
rather than a catchable language error.

Two separate problems:

**(a) Silent divergence on wide codes.** Java's `(char)` cast and
JavaScript's `String.fromCharCode` truncate to 16 bits; Python's `chr()`
does not. The same program prints a different character on different
targets, with no error on any of them.

**(b) Python crashes the session on a negative code.** Python's `chr()`
raises `ValueError` for a negative argument, which is not a
`LanguageError`, so it escapes as a session-fatal "Specification error"
— reading as "your grammar is broken" when the real cause is a bug in
the student's program — and kills the rest of the REPL session. The
`except LanguageError` guard adjacent to the call does not cover it.

## Steps to Reproduce

Reproduced by the controller during the final branch review:

| input | Python | Java | JavaScript |
|---|---|---|---|
| `putc -(0,1)` | `Specification error: ValueError: chr() arg not in range(0x110000)` — session aborts | `￿nil` (U+FFFF) | `￿nil` (U+FFFF) |
| `putc 66000` | U+101D0 | U+01D0 | U+01D0 |
| `puts [66000]` | U+101D0 | U+01D0 | U+01D0 |

Sites: `src/OBJ/python/spec.plcc:139` (`IntVal.putc`) and `:315`
(`ListNode.buildString`); `src/OBJ/java/spec.plcc:183`/`:392`;
`src/OBJ/javascript/spec.plcc:113`/`:337`.

## Notes

Why it matters and why it survived: `putc`/`puts` are how students build
character output, and off-by-one arithmetic producing a negative code is
the ordinary route in. No test catches it because
`tests/strings-chars/OBJ.input` only ever uses `'a` (97).

Fix direction: make Python raise a catchable `LanguageError` for an
out-of-range code, and mirror that into Java and JavaScript so all three
agree — better teaching behavior than silently truncating.

This is the plcc-ng port's own behavior, not inherited from old PLCC.
Whichever way it is resolved, all three targets must move together.

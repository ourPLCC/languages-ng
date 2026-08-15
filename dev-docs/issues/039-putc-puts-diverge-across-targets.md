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

## Summary

Java's `(char)` cast and JavaScript's `String.fromCharCode` silently
truncate wide character codes to 16 bits where Python's `chr()` doesn't, so
the same program prints different characters on different targets;
separately, Python's `chr()` raises `ValueError` (not a catchable
`LanguageError`) on a negative code, which escapes as a session-fatal
"Specification error" and kills the rest of the REPL session. `putc`/`puts`
are how students build character output, so off-by-one arithmetic is the
ordinary route in.

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

**Independently confirmed by GitHub Copilot** on the migration PR
(2026-08-12), which flagged both Python sites separately: `IntVal.putc`
calling `chr(self.val)` directly, and `ListNode.buildString` catching only
`LanguageError` from `intVal()` so that a valid `IntVal` holding an
out-of-range code still escapes as a crash.

**Careful with the obvious fix.** Copilot's suggestion — wrap the Python
`chr()` calls and re-raise `LanguageError` — is correct but is only half
the issue, and doing just that half makes the *other* half worse. It
resolves the session-fatal crash while leaving Java and JavaScript
silently truncating to 16 bits, so `putc 66000` would then raise an error
in Python and quietly print U+01D0 in the other two. That is a sharper
divergence than exists today, and one no test would catch. Fix both sites
in Python **and** the corresponding Java/JavaScript sites in the same
change, then add a case to `tests/strings-chars/` covering a negative code
and one above 0xFFFF — those two inputs are what would have caught this.

**This defect straddles two repositories.** The 16-bit truncation in Java
and JavaScript is this repo's — it is the `(char)` cast and
`String.fromCharCode` in the specs above, and the fix is local. But
Python's `ValueError` escaping as a session-fatal "Specification error" is
plcc-ng's error handling: the string appears nowhere in `src/**/*.plcc`.
Per "Upstream defects" in [issue-conventions.md](../issue-conventions.md),
the local half stays here and the upstream half is reported separately;
this issue keeps `target: this repo` because its fix is local.

**Upstream half reported 2026-08-15** as `ourPLCC/plcc-ng`
`190-rep-kills-session-on-program-errors.md`, with a self-contained
reproduction built against plcc-ng alone rather than against this repo's
specs. That issue is about the classification — every non-`LanguageError`
exception from a semantic action becomes a session-fatal
`specification_error` — so it covers this defect's Python symptom without
naming `putc`. What stays here is unchanged and unblocked: the 16-bit
truncation in the Java and JavaScript specs, the Python range guard, and
the `tests/strings-chars/` cases. Read upstream for its current state; it
is deliberately not cached here.

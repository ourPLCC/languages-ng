# Roadmap

## Open Issues

### Chore

- **[#12](issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) — CI cannot run plcc-ng-migrated languages**
  CI's test image only installs old-PLCC with no Node.js, so plcc-ng-migrated languages (V0-V3) fail in CI with `command not found` while passing locally — the opposite of local dev. Deferred until every language has migrated: the job is `on: pull_request` and no PRs are opened yet, and the fix collapses to basing CI on the devcontainer image once old-PLCC is needed nowhere.

### Docs

- **[#13](issues/013-dev-docs-link-checker-not-fence-aware.md) — dev-docs link checker is not fence-aware**
  The plan-embedded link checker reports 19 broken links, but 15 are Markdown links inside fenced code blocks that were never meant to resolve; its "all links resolve" gate is unsatisfiable until it skips fences, and the 4 real breaks come from a `close.bash` link-rewriting gap.
- **[#16](issues/016-cross-target-integer-divergence.md) — cross-target integer divergence**
  Java's 32-bit `IntVal.val` silently overflows where Python's arbitrary-precision and JavaScript's double integers don't (measured: `.fact(20)` gives `2432902008176640000` in Python/JS, `-2102132736` in Java). Inherited from V0 and repo-wide, not a V4 defect, but V4's `Prog/fact-acc` and its new `recursion/` test make the boundary trivially reachable in a live demo.
- **[#19](issues/019-python-recursion-ceiling.md) — Python recursion ceiling far below Java/JavaScript**
  Direct language-level recursion (`letrec f = proc(x) ... .f(sub1(x)) ... in .f(N)`) dies in Python around `N=330` but survives past `N=2700` in Java and JavaScript, since each language-level call costs several Python interpreter frames; the Python failure also mislabels the cause as a specification error. Inherited from V0/V4, not a V5 defect, but `letrec` makes deep recursion the natural thing to write.

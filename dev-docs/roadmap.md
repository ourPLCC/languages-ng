# Roadmap

## Open Issues

### Chore

- **[#12](issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) — CI cannot run plcc-ng-migrated languages**
  CI's test image only installs old-PLCC with no Node.js, so plcc-ng-migrated languages (V0-V3) fail in CI with `command not found` while passing locally — the opposite of local dev. Deferred until every language has migrated: the job is `on: pull_request` and no PRs are opened yet, and the fix collapses to basing CI on the devcontainer image once old-PLCC is needed nowhere.
- **[#15](issues/015-gitignore-java-pattern-shadows-source-dirs.md) — `.gitignore`'s `Java/` pattern shadows source dirs**
  On a case-insensitive filesystem, `.gitignore`'s `Java/` line (meant for old PLCC's build output) also matches every `src/*/java/` source directory, forcing `git add -f` (already hit by V3 and V4) and invisible in case-sensitive CI. No gitignore pattern fixes it in place; recommended fix is to drop the line, since `plcc-rep` only ever writes the already-ignored `plcc-ng/`.

### Docs

- **[#13](issues/013-dev-docs-link-checker-not-fence-aware.md) — dev-docs link checker is not fence-aware**
  The plan-embedded link checker reports 19 broken links, but 15 are Markdown links inside fenced code blocks that were never meant to resolve; its "all links resolve" gate is unsatisfiable until it skips fences, and the 4 real breaks come from a `close.bash` link-rewriting gap.
- **[#16](issues/016-cross-target-integer-divergence.md) — cross-target integer divergence**
  Java's 32-bit `IntVal.val` silently overflows where Python's arbitrary-precision and JavaScript's double integers don't (measured: `.fact(20)` gives `2432902008176640000` in Python/JS, `-2102132736` in Java). Inherited from V0 and repo-wide, not a V4 defect, but V4's `Prog/fact-acc` and its new `recursion/` test make the boundary trivially reachable in a live demo.

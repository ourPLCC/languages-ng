# Roadmap

## Open Issues

### Chore

- **[#12](issues/012-ci-cannot-run-plcc-ng-migrated-languages.md) — CI cannot run plcc-ng-migrated languages**
  CI's test image only installs old-PLCC with no Node.js, so plcc-ng-migrated languages (V0-V3) fail in CI with `command not found` while passing locally — the opposite of local dev. Deferred until every language has migrated: the job is `on: pull_request` and no PRs are opened yet, and the fix collapses to basing CI on the devcontainer image once old-PLCC is needed nowhere.
- **[#20](issues/020-close-bash-roadmap-awk-edge-cases.md) — close.bash's roadmap awk has two dormant edge cases**
  The `END` block collapses blank-line runs across the whole roadmap rather than just the removed entry's span, and the bullet-removal skip state ends on a blank line, so a multi-paragraph Open Issues entry would leave an orphaned fragment. Both predate #18 and were inherited verbatim by its rewrite; neither fires against the roadmap's current shape, where every entry is a bullet plus one indented continuation line.

### Docs

- **[#16](issues/016-cross-target-integer-divergence.md) — cross-target integer divergence**
  Java's 32-bit `IntVal.val` silently overflows where Python's arbitrary-precision and JavaScript's double integers don't (measured: `.fact(20)` gives `2432902008176640000` in Python/JS, `-2102132736` in Java). Inherited from V0 and repo-wide, not a V4 defect, but V4's `Prog/fact-acc` and its new `recursion/` test make the boundary trivially reachable in a live demo.
- **[#19](issues/019-python-recursion-ceiling.md) — Python recursion ceiling far below Java/JavaScript**
  Direct language-level recursion (`letrec f = proc(x) ... .f(sub1(x)) ... in .f(N)`) dies in Python around `N=330` but survives past `N=2700` in Java and JavaScript, since each language-level call costs several Python interpreter frames; the Python failure also mislabels the cause as a specification error. Inherited from V0/V4, not a V5 defect, but `letrec` makes deep recursion the natural thing to write.
- **[#22](issues/022-plcc-rep-parses-each-source-independently.md) — plcc-rep parses each SOURCE argument independently**
  A program split across two files no longer parses, where old PLCC's `rep` joined its file arguments into one stream; V6's `Prog/p1`/`Prog/p2` course example depends on the old behavior and now needs `cat p1 p2 | plcc-rep`. Targeted at ourPLCC/plcc-ng, not reported externally yet.

### Feat

- **[#30](issues/030-migrate-need-to-plcc-ng.md) — migrate-need-to-plcc-ng**
  Port NEED (NAME + memoization) to plcc-ng in Python, Java, and JavaScript: an `ERROR` token and `ErrorPrim` production, a memoizing `ThunkRef`, a read-only `ValRORef`, and four value-only test cases.

### Test

- **[#27](issues/027-use-spec-flag-instead-of-copying-tree.md) — use `plcc-rep -s` instead of copying `src/` into each test tmpdir**
  `plcc-rep -s <abs spec path>` resolves `%include` from the spec's real location while writing build output to the current directory, so the 30 migrated test files need no copied tree at all — isolation becomes structural rather than a filtered copy. The 5 legacy `plccmk` languages still need `relocate`, so both mechanisms coexist until they migrate.
- **[#28](issues/028-relocate-filter-hides-permission-errors.md) — relocate's `[[ -e ]]` filter hides permission errors**
  `relocate_copy_tree`'s existence filter can't tell "deleted with `rm`" from "exists but unreadable" (`chmod 000` on a tracked file's parent directory reproduces it), so an `EACCES` path is silently dropped from the copy instead of failing loudly — the same silent-corruption class as issue #25, reintroduced one layer down. Dormant: nothing in this repo `chmod`s a spec directory today.

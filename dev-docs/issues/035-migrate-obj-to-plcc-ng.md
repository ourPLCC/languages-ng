---
type: feat
target: this repo
opened: 2026-08-11
closed:
---

# 035 - migrate OBJ to plcc-ng

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

Port OBJ (`SET + lists, characters, strings, classes, and objects`) to
plcc-ng: one shared `src/OBJ/grammar.plcc` plus three target `spec.plcc`s
(Python, Java, JavaScript). OBJ is the last language in the keep list and,
once it lands, the last old-PLCC user in the repository — `src/` will
contain no old-PLCC sources at all.

OBJ is the largest language by a wide margin: 30 `Exp` alternatives, 24
prims, 5 `:init` blocks, and fourteen free-standing classes per target on
top of the five inherited through `%include`. `envRef` is reused
unchanged for the sixth consecutive language, retiring the variant as
settled after six consecutive zero-touch reuses across seven users. The
reserved-ID check that canonical `envRef` does not carry moves into a
free-standing `Reserved` class, called explicitly at each of the five
binding sites rather than folded invisibly into `Env`.

The port also buffers all output through a new `Program.out` list rather
than writing it directly to stdout: `plcc-rep` uses the interpreter's
stdout as a private, line-oriented JSON protocol channel, and OBJ's
`display`, `display#`, `putc`, `puts`, and `newline` are partial-line
writers by design, which deadlocks that channel with no diagnostic. See
the design doc's stdout Protocol Finding for the measurement.

## Notes

See
[dev-docs/specs/2026-08-11-plcc-ng-obj-design.md](../specs/2026-08-11-plcc-ng-obj-design.md),
which extends
[dev-docs/specs/2026-07-22-plcc-ng-migration-design.md](../specs/2026-07-22-plcc-ng-migration-design.md)
and builds directly on
[dev-docs/specs/2026-08-04-plcc-ng-set-design.md](../specs/2026-08-04-plcc-ng-set-design.md).

Three targets, seven test cases (`class/`, `objects/`, `inheritance/`,
`lists/`, `strings-chars/`, `env-ops/`, `errors/`) replacing the single
8-line `class/` case OBJ ships today, and the 56 example programs across
`Prog/`, `PPP/`, `Examples/`, and `BST/` verified for cross-target
byte-identity.

Out of scope: any change to `envRef` or `src/Env/`; implementing the
plcc-ng protocol extension the stdout finding motivates (filed upstream,
not blocking); consolidating the four example directories; and issues
[#16](016-cross-target-integer-divergence.md) (cross-target integer
divergence), [#19](019-python-recursion-ceiling.md) (Python recursion
ceiling), [#22](022-plcc-rep-parses-each-source-independently.md)
(plcc-rep parses each SOURCE argument independently), and
[#27](027-use-spec-flag-instead-of-copying-tree.md) (use `-s` instead of
copying the tree) — all repo-wide and inherited.

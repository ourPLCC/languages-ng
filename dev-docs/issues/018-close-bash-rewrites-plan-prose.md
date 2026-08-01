---
type: chore
target: this repo
opened: 2026-07-31
closed: 2026-08-01
---

# 018 - close-bash-rewrites-plan-prose

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

`bin/issues/close.bash`'s pass 3 repoints inbound links with a blind,
global `sed` over every `dev-docs/**/*.md`:

```bash
sed -i "s|issues/${basename}|issues/done/${basename}|g" "${f}"
```

It matches the raw string anywhere in the file — inside prose, inside
backticked code spans, inside fenced code blocks — not just in Markdown
link targets. So closing an issue silently edits **the plan that
described how to file it**, rewriting instructions that were correct at
the time and are correct as history.

The result is text that contradicts itself. After closing #17, the V5
plan's Task 1 read:

> The script prints the path it created — expected
> `dev-docs/issues/done/017-migrate-v5-to-plcc-ng.md`, in the **open**
> issues directory. It does not and cannot create the file under
> `done/` ...

and its commit step became `git add
dev-docs/issues/done/017-migrate-v5-to-plcc-ng.md`, an instruction that
cannot succeed — `new.bash` never creates a file there.

**This is not cosmetic: it propagates.** Each language's plan is written
by adapting the previous language's, so a plan corrupted at close time
becomes the template for the next one. That is exactly what happened:

- V4's plan Task 1 says `dev-docs/issues/done/014-...`. V4's execution
  actually filed to the **open** directory (see commit `e99df48`, which
  creates `dev-docs/issues/014-migrate-v4-to-plcc-ng.md`) — only the plan
  text was wrong, rewritten after the fact by `close.bash`.
- V5's plan inherited that wrong path, and the Task 1 implementer hit it
  live: following it would have made Task 8's `close.bash 17` hard-fail,
  since that script errors out if the issue file is already under
  `done/`. The implementer filed it correctly and reported the conflict;
  the plan text was then corrected (`4ffa9c7`).
- `close.bash` then re-corrupted the same four lines when #17 closed,
  which is how this issue was found. They were restored by hand
  afterward, and will be re-corrupted again if #17 is ever reopened and
  reclosed.

Left alone, V6's plan will be adapted from V5's and inherit the same
error a third time.

## Steps to Reproduce

1. In any `dev-docs/plans/*.md`, write a line mentioning an open issue's
   path in prose or a code span, e.g.
   `` `dev-docs/issues/018-close-bash-rewrites-plan-prose.md` ``.
2. Run `bin/issues/close.bash 18`.
3. Re-read that line. The path now says `issues/done/018-...`, even
   though the surrounding sentence describes the pre-close state.

## Notes

Related to, but distinct from,
[#13](013-dev-docs-link-checker-not-fence-aware.md). That issue's
suggested fix direction #3 also concerns `close.bash` pass 3, but the
defect there is the *opposite* failure — pass 3 matching **too little**
(it never recognizes the `../NNN-*.md` spelling that files already inside
`done/` use, so their inbound links dangle). This issue is pass 3
matching **too much**. A fix should address both; they are the same
substitution needing to become target-aware rather than textual.

Fix direction: restrict the rewrite to actual Markdown link targets —
i.e. only substitute inside `](...)` — and skip fenced code blocks, the
same fence-awareness [#13](013-dev-docs-link-checker-not-fence-aware.md)
wants for the link checker. Prose and code spans should never be touched:
a plan's description of the filing step is a historical record, not a
live link.

Worth considering as a companion change: plans are history once their
branch merges, so arguably `close.bash` should not rewrite
`dev-docs/plans/` at all, only `dev-docs/issues/` and `dev-docs/roadmap.md`.

Found during the V5 migration branch (issue
[#17](017-migrate-v5-to-plcc-ng.md)), which caused none of the breaks
but tripped over V4's inherited one and then watched the mechanism produce
a fresh instance.

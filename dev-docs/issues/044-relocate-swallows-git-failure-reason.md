---
type: test
target: this repo
opened: 2026-08-13
closed:
---

# 044 - relocate swallows git's reason for refusing a checkout

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

`relocate_copy_tree`'s opening guard sends git's stderr to `/dev/null` and
replaces it with "is not in a git checkout", which is the least likely of
the reasons `rev-parse --git-dir` can fail under `src/`. It cost a CI
round-trip on issue #12: all 165 language tests failed against a perfectly
good checkout that git was refusing as dubious ownership, and git's own
message naming the `safe.directory` remedy had been discarded. Same shape as
#28.

## Description

`relocate_copy_tree`'s opening guard discards git's stderr and replaces
whatever git actually said with a single fixed sentence:

```bash
git -C "${from}" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "relocate: ${from} is not in a git checkout" >&2; return 1; }
```

`rev-parse --git-dir` fails for more reasons than the one the message
names, and the message asserts the one reason it is least likely to be.
A path under `src/` that is genuinely outside a checkout is close to
impossible in this repository; the realistic failures are a checkout git
declines to use.

That is not hypothetical. It cost a full CI round-trip on issue #12. The
first run of the new `container:` workflow failed all 165 language tests
with:

```
relocate: /__w/languages-ng/languages-ng/src is not in a git checkout
```

The tree was a perfectly good checkout. Git was refusing it as *dubious
ownership* — the workspace belongs to the runner's uid, not the
container user's — because `actions/checkout` adds its `safe.directory`
entry under a `HOME` it overrides for the duration of its own step and
then discards. Git says exactly that, in a message naming the condition
and the command that fixes it. `2>&1` threw it away, and the diagnosis
had to be reconstructed from the checkout step's log instead.

This is the same shape as issue
[#28](028-relocate-filter-hides-permission-errors.md): a `relocate`
guard that cannot distinguish the condition it names from a different
condition it silently reports as that one.

## Steps to Reproduce

The real-world trigger is a uid mismatch, which needs root to stage. A
broken worktree pointer reaches the same guard unprivileged and shows
the same swallowing. Verified 2026-08-13:

```bash
mkdir -p /tmp/repro/sub
printf 'gitdir: /nonexistent/path/to/gitdir\n' > /tmp/repro/.git
git -C /tmp/repro/sub rev-parse --git-dir
```

Git says:

```
fatal: not a git repository: (null)
```

and exits 128. Call `relocate_copy_tree` with `/tmp/repro/sub` as
`from` and all of that is replaced by `relocate: /tmp/repro/sub is not
in a git checkout`.

For the CI case specifically, git's discarded message is the
"detected dubious ownership" one, which names both the condition and
the `safe.directory` command that fixes it — the single most useful
sentence available at that moment, and the one the guard throws away.

## Notes

Suggested direction: capture git's stderr instead of discarding it, and
include it in the failure. Something of the shape

```bash
local git_err
if ! git_err="$(git -C "${from}" rev-parse --git-dir 2>&1 >/dev/null)"; then
  echo "relocate: git will not read ${from}: ${git_err}" >&2
  return 1
fi
```

keeps the guard's behavior identical while letting git explain itself.
Note the redirection order — `2>&1 >/dev/null` captures stderr and drops
stdout, which is the opposite of what the current `>/dev/null 2>&1`
does. Verify it in a scratch directory before writing it into a plan,
per [CLAUDE.md](../../CLAUDE.md).

Worth checking the other `bin/` guards for the same pattern while in
there, rather than fixing this one site in isolation.

The CI symptom that surfaced this is already fixed on issue #12's branch
by a "Trust the workspace" step that re-adds `safe.directory` under the
persistent `HOME`. This issue is only about the misleading message, not
about that failure recurring.

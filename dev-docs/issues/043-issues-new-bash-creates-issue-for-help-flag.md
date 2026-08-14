---
type: chore
target: this repo
opened: 2026-08-12
closed:
---

# 043 - new.bash treats --help as a slug, creating a spurious issue

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

`bin/issues/new.bash --help` prints no usage: its guard only catches the
zero-argument case, so `--help` becomes the slug, creating `NNN---help.md`
and silently incrementing `.next-id.txt`. A defect in the one mechanism the
repo's "never assign issue numbers by hand" convention rests on.

## Description

`bin/issues/new.bash --help` does not print usage. It creates an issue
file named `NNN---help.md` and increments `.next-id.txt`, silently
consuming an issue number and leaving a stray file.

The guard at `bin/issues/new.bash:19` is

```bash
[[ $# -lt 1 ]] && usage
```

which only catches the *zero-argument* case. `--help` is one argument, so
it flows straight through to `SLUG="$1"` and the script proceeds normally.
There is no flag parsing at all.

This matters more than an ordinary usage nit because of what it corrupts.
CLAUDE.md's issue convention is emphatic that numbers come only from
`.next-id.txt` via this script — "Never assign issue numbers by hand or by
scanning the directory." A silent counter bump is therefore a defect in
the one mechanism the convention rests on: the person who typed `--help`
to find out how the script works has now skipped a number and created a
file they did not intend, and nothing says so. If they do not notice,
`bin/issues/check.bash` will later flag an issue that has no roadmap
entry, at which point the cause is several steps behind them.

## Steps to Reproduce

1. `bin/issues/new.bash --help`
2. Observe: no usage text. The script prints
   `dev-docs/issues/0NN---help.md` and exits 0.
3. `git status` shows the new file; `dev-docs/issues/.next-id.txt` has
   been incremented.

Found 2026-08-12 during the OBJ migration's final fix wave, by an agent
that ran `--help` to check the argument order before filing real issues.
It caught and reverted the spurious issue, so the sequence stayed clean —
but only because it happened to look.

## Notes

Two things to fix, and they are separable:

- **Handle `-h` / `--help` explicitly**, printing `usage` and exiting 0
  rather than 1. (`usage` currently always `exit 1`, which is right for a
  misuse but wrong for an explicit help request.)
- **Reject slugs that start with `-`** as a general guard, so a mistyped
  flag can never become a filename. A slug is documented as
  "hyphen-separated short name"; a *leading* hyphen is never valid.

`bin/issues/close.bash` guards differently — `[[ $# -ne 1 ]] && usage` at
`close.bash:24` — so `close.bash --help` also skips usage, but it then
fails harmlessly on the ID lookup instead of creating anything. Worth
giving both scripts the same explicit flag handling while in there, even
though only `new.bash` is destructive.

Both scripts predate this and the defect has presumably always been
present; nothing in the repository's history depends on the current
behavior.

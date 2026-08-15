---
type: docs
target: this repo
upstream:
opened: 2026-08-15
closed:
---

# 053 - `#N` is ambiguous in commit messages and PR bodies, and GitHub acts on it

## Summary

[#52](052-upstream-issues-track-local-work-only.md) established that an
upstream issue is named by repository plus filename, never `owner/repo#N`,
because GitHub numbers issues and pull requests in one sequence. But that
rule was written for the `upstream:` frontmatter field only. A bare `#N` in
a commit message or pull request body is ambiguous in exactly the same way,
and worse: GitHub resolves it against *this* repository's numbering and acts
on closing keywords like `Closes #52`, so a reference to a file-based issue
can silently close an unrelated pull request once the counter reaches that
number.

## Description

This repository's issues are files. `dev-docs/issues/052-…md` is issue 52,
and its status is the `closed:` frontmatter field. GitHub knows nothing
about any of it.

GitHub, meanwhile, maintains its own single number sequence covering both
issues and pull requests in `ourPLCC/languages-ng`. Those two numbering
systems overlap completely and mean entirely different things.

Two distinct failure modes follow.

**Ambiguity.** A reader of `git log` seeing "fixes #36" cannot tell whether
that means the file `036-plcc-rep-deadlocks-on-partial-stdout-line.md` or
GitHub pull request 36. Today the repository's PR counter is around 17, so
most low numbers resolve to nothing — but the counter only moves one way.

**Action.** GitHub treats `Closes #N`, `Fixes #N`, and `Resolves #N` in a
pull request body as instructions, executed on merge. A body written to
reference a file-based issue therefore carries a live directive against an
unrelated object.

## Steps to Reproduce

Observed directly on 2026-08-15, while preparing the pull request for
[#52](052-upstream-issues-track-local-work-only.md). The suggested body
included:

```
Closes #52. Closes #36.
```

Both numbers currently 404 against
`https://api.github.com/repos/ourPLCC/languages-ng/issues/{36,52}`, so
nothing would have closed on merge. The reference is inert **today** and
becomes live as the pull request counter advances past those numbers.

Note what this took: the branch that wrote the "never use `#N`" rule
produced a `#N` reference in its own pull request body, minutes after
committing the rule. The rule is stated in a section about frontmatter, so
nothing connected it to prose written outside an issue file.

## Notes

The gap is narrow and the fix is probably a short subsection under
"Upstream defects" or "Closing an issue" in
[issue-conventions.md](../issue-conventions.md), extending the existing
`#N` prohibition to commit messages and pull request bodies. Worth settling
alongside it:

- **What replaces it.** The filename is unambiguous but long for a commit
  subject line. `issue 36` in prose reads clearly and GitHub does not
  linkify it, which is the property wanted. Existing commit messages in
  this repository already use that form — for example "close issue 36
  (plcc-rep deadlocks on a partial stdout line)".
- **Whether closing keywords are ever wanted.** They have no legitimate use
  while issues are files, since `bin/issues/close.bash` performs the close
  in-tree and the merge carries it. A blanket "never write a GitHub closing
  keyword" is simpler than a conditional rule.
- **Whether anything can check it.** `check.bash` reads issue files, not
  commit messages, so this is a convention rather than an invariant unless
  a commit-msg hook is added. Probably not worth one for a solo repository,
  but the trade-off should be recorded rather than left implicit.

Related: `#N` inside an **issue file** is already fine and widely used —
those render as plain text in a Markdown file that GitHub is not
interpreting as a pull request body, and the surrounding prose disambiguates.
The problem is specifically prose that GitHub parses.

Read these, in order, before making changes:

- @../dev/ORG-AGENTS.md
- @../dev/CONTRIBUTING.md
- @CONTRIBUTING.md

## Agent rules for this repo

### Shell and config embedded in a plan

Review snippets inside a plan as rigorously as code going into the repo.
They read as prose and get transcribed as-is, so a defect in one survives
into `bin/` unless someone catches it first.

CR-525 is the cautionary case: five defects were found across its eight
tasks, and **every one originated in the plan's own snippets** rather than
in the implementation — a false claim about when `tar` aborts, an
`[[ -e ]] && printf` inside a `while` loop that left the loop at exit
status 1 and broke a newly added `set -o pipefail`, `set -euo pipefail`
placed after the `cd` in a destructive script, `.dockerignore` patterns
written with `.gitignore` semantics, and a commit message that ignored
this repo's own issue conventions. The plan's `Amended`/`Corrected` blocks
record each one.

Two habits catch these: mentally execute a snippet for exit-status
propagation, subshell boundaries, and pattern semantics before dispatching
it; and when a snippet asserts a factual claim about tool behavior
("`tar` aborts", "this pattern matches"), verify it in a scratch directory
rather than asserting it. If someone implementing the plan reports being
blocked because reality contradicts it, assume they are right until shown
otherwise — that happened three times on CR-525 and they were correct
every time.

### Verifying a subagent's commits

A subagent's reported SHA is not evidence of which branch the commit is
on. When dispatching implementation agents while working in a git
worktree, check that each commit actually landed on the intended branch
before accepting a DONE report — `git branch --contains <sha>`, or
`git log --oneline -1` in the worktree, not the SHA the agent hands back.

On CR-531 (2026-08-06), a subagent told "do NOT cd to the parent repo" did
exactly that and committed to `main` in `/workspaces/languages-ng`. Its
return looked completely normal — status DONE, a real SHA, a plausible
summary. The commit was real; it was just on the wrong branch, and the
worktree's HEAD had not moved. Nothing in the report could reveal this,
since the SHA exists and resolves either way. Left undetected it would
have merged a phantom commit into `main` and left the branch's history
incomplete.

Put the branch name in the dispatch prompt and require the agent to
confirm `git branch --show-current` before committing, then verify it
yourself afterward. Recovery is cheap when caught early: cherry-pick onto
the correct branch, then `git reset --hard` the parent back to its prior
commit — safe while unpushed, and it stays in the reflog — but confirm
before resetting anyone's checkout.

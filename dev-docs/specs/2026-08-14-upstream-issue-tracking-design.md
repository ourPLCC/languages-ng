# Upstream issue tracking: local issues track local work

**Issue:** [#50](../issues/050-upstream-issues-track-local-work-only.md)
**Date:** 2026-08-14

Extends [Issue status as frontmatter, not
location](2026-07-31-issue-status-frontmatter-design.md), which
established that an issue's status is a frontmatter field rather than its
directory, and that the block stays flat scalars so `grep` and `awk`
suffice. This design adds one field within those constraints and does not
revisit them.

## The principle

> An issue in `dev-docs/issues/` tracks work in **this** repository.
> Whether upstream has fixed something is a fact about upstream — read on
> demand, never recorded.

This generalizes the reasoning that closed
[#22](../issues/022-plcc-rep-parses-each-source-independently.md) while
upstream #185 was still open: "what remains is a documentation task in
someone else's tracker, so tracking it as an open issue here overstated
what was outstanding."

`target` keeps its current meaning — the repository the **defect** is in.
What changes is that open/closed now answers **"is there local work?"**,
and that question is answerable entirely from inside this repository. No
field records another repo's state.

## The three cases

An upstream defect falls into exactly one of these at any moment.

### A1 — found, not yet reported; no local consequence

There *is* local work: obtain the reporter's go-ahead and file it
upstream. The issue stays **open** with `upstream:` empty. It closes when
the report is filed.

### A2 — reported; no local consequence

Nothing in this repository changes when upstream ships a fix. **Close
it**, with `upstream:` naming the ref. The closed file keeps its full
reproduction detail permanently — issues never move, so links to it never
break.

This is the case that #22 discovered and that
[#36](../issues/036-plcc-rep-deadlocks-on-partial-stdout-line.md) turns
out to be in (see *Data fixes*).

### B — reported; local workaround lives in `src/`

The issue stays **open**, and its subject is *the revert*. It closes when
the workaround is gone. This is the
[#6](../issues/006-multi-capture-alt-name-case-mismatch.md) lifecycle,
unchanged: workaround ships, upstream fixes the root cause, workaround is
reverted with an impact-log note.

### C — the defect straddles both repositories

[#39](../issues/039-putc-puts-diverge-across-targets.md) and
[#19](../issues/019-python-recursion-ceiling.md) are both this shape: part
of the defect is in this repo's specs, part is in plcc-ng's error
reporting. **Split by repository.** The local half is an ordinary local
issue with `target: this repo`; the upstream half follows A1/A2. There is
no third "blocked on upstream" issue and no dependency placeholder.

## The `upstream:` field

One new frontmatter key:

```yaml
upstream: ourPLCC/plcc-ng 187-plcc-rep-lacks-output-and-clean-exit-records.md
```

Two space-separated tokens: the **repository**, then the **filename**
within that repository's `dev-docs/issues/`. Multiple refs are separated
by commas.

**Empty or absent means not reported.** Non-empty means tracked upstream.
The ref *is* the evidence of reporting, which is why there is no separate
`reported:` date — two fields recording one fact can disagree, and this
one cannot.

### Why not `owner/repo#N`

GitHub numbers issues and pull requests in a single sequence.
`ourPLCC/plcc-ng#187` resolves to a **closed pull request** titled "069
improve parse trace" — not to the issue this repo's #37 depends on. The
`#N` form is not merely unhelpful here; it points at the wrong object.

### Why not a URL

Upstream closes an issue by `git mv`-ing it into `dev-docs/issues/done/`,
so a URL naming the open path returns 404 the moment they close it — the
reference rots exactly when its state changes. Repository-plus-filename
names the *issue* rather than its location, and survives both upstream's
current convention and the migration proposed in their
`189-align-issue-system-with-languages-ng.md`.

### Fields deliberately not added

- `reported:` — redundant with a non-empty `upstream:`.
- `upstream-fixed:` — a cached copy of another repository's state. It is
  wrong by default, needs periodic sweeps to stay honest, and cannot
  represent an issue naming two refs whose fixes land separately.
- `workaround:` — unnecessary. Under this design an **open** issue whose
  `target` is not `this repo` means there is local work by definition;
  that is what open/closed now carries. The body says where the
  workaround lives.

## Rejected: a script that queries upstream

`bin/issues/upstream.bash` was designed and dropped. It would derive
upstream state from directory position (`dev-docs/issues/` vs `done/`),
which is precisely the convention upstream's own open issue #189 proposes
to replace with frontmatter. Building it would mean shipping a tool whose
correctness depends on an unresolved proposal in someone else's
repository, and the design already conceded this by specifying that the
script handle both conventions.

Scale settles it: after #36 closes there is **one** open upstream-targeted
issue. A durable pointer plus a human click is the right size for that,
and it couples to nothing external.

## Rejected: switching to GitHub Issues

Considered seriously, because the friction was real. The evidence is
against it:

- **Upstream's GitHub tracker is unused.** `ourPLCC/plcc-ng` reports
  `has_issues: true` with `open_issues_count: 0`; its issues are files in
  `dev-docs/issues/`, exactly like this repo's. The strongest argument for
  switching — native cross-repo issue linking showing live state — does
  not apply, because there is nothing in GitHub to link to.
- **The reference syntax would be wrong**, per *Why not `owner/repo#N`*
  above.
- **Upstream is migrating toward this system, not away from it.** Their
  `189-align-issue-system-with-languages-ng.md` proposes adopting the
  never-move/frontmatter-status shape, documenting 14 links broken by
  their `done/` move and noting this repo's `close.bash` is shorter
  despite validating more.
- **Branch-scoped issue state would be lost.** A worktree's branch can
  open and close issues independently, and `list.bash` deliberately reads
  the tree it lives in
  ([issue-conventions.md](../issue-conventions.md), §"Listing open
  issues"). GitHub Issues are global; there is no per-branch issue state.
- **Atomicity would be lost.** Closing in the branch's final commit means
  work and bookkeeping merge — and revert — together.

One case would genuinely favor a tracker: **inbound reports from people
who cannot open a pull request**, such as students hitting a bug in a
course language. That is a different job from tracking development work,
and would be a hybrid (GitHub Issues for inbound triage, files for tracked
work) rather than a migration. It is out of scope here and deserves its
own decision.

## Changes

| File | Change |
|---|---|
| [issue-conventions.md](../issue-conventions.md) | Replace §"The `target` field" with §"Upstream defects": the principle, the three cases, the field format, the never-cache rule. Preserve the existing "reported upstream manually, with explicit go-ahead" norm. |
| [issues/TEMPLATE.md](../issues/TEMPLATE.md) | Add `upstream:` with an explanatory comment. |
| [bin/issues/check.bash](../../bin/issues/check.bash) | Validate `upstream:` **when present and non-empty**: each comma-separated ref is `owner/repo` plus a filename. Never required, so no backfill across the 42 local issues. |
| `bin/tests/issues-check.bats` | Coverage for the validation, including a malformed ref and the absent-field case. |
| `src/OBJ/{python,java,javascript}/spec.plcc` | Reattribute the `Program.out` buffering comment to #37. |

`bin/issues/new.bash` needs no change — it copies the template.

The `src/` edits are comments only: type `docs`, no version bump, and no
[course-material-impact.md](../course-material-impact.md) entry, since
nothing an instructor's materials reference changes.

## Data fixes

**#37** — add `upstream: ourPLCC/plcc-ng 187-…`. Stays open (case B). Its
text already claims both the buffering and the `exit` divergence, which
is correct: both are released by upstream #187 alone.

**#36** — add `upstream: ourPLCC/plcc-ng 186-…` and **close** it (case
A2). Verified against the source: the buffering exists because plcc-rep's
stdout *is* the JSON protocol channel, so emitting output at all requires
an output record kind — upstream #187, this repo's #37. Upstream #186
landing alone would convert the deadlock into a diagnostic without giving
OBJ anywhere to emit output, so #36 gates nothing locally.

**#22** — backfill `upstream:` retroactively. Optional and cheap.

**#39** — no structural change. Note in its text that the session-fatal
escape of a non-`LanguageError` as "Specification error" is plcc-ng's
error handling, while the truncation divergence is this repo's.

**#19** — open decision, recorded here rather than assumed: the
"Specification error: RecursionError" wording belongs to plcc-ng (the
string appears nowhere in `src/**/*.plcc`), while documenting the ceiling
is local. Reporting the wording upstream needs the reporter's go-ahead.

## Commit sequence

1. `docs(issues)` — conventions + template
2. `chore(issues)` — `check.bash` validation + bats coverage
3. `docs(obj)` — reattribute the buffering comments in the three specs
4. `docs(issues)` — data fixes to #37, #22, #39; then close #36 via
   `bin/issues/close.bash 36`, which fills its `closed:` date and removes
   its roadmap entry
5. `docs(issues): close issue 50 …` — final commit, via `close.bash 50`

Two issues close on this branch. #36 closes as *work product* — case A2
applied to it is part of the change — while #50 closes last as the
branch's own bookkeeping, per
[issue-conventions.md](../issue-conventions.md).

## Interaction with #49

[#49](../issues/049-retire-roadmap-open-issues-section.md) retires the
roadmap's Open Issues section. Closing #36 and #50 both edit that section
via `close.bash`, so the two touch the same machinery. They do not
conflict, but landing #49 first would remove the roadmap churn from this
branch entirely. Sequencing is a deliberate choice, not a blocker.

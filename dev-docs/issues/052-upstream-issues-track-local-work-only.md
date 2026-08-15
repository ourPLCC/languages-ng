---
type: docs
target: this repo
opened: 2026-08-14
closed: 2026-08-14
---

# 052 - upstream-targeted issues should track local work, not upstream status

## Summary

An upstream-targeted issue conflates a defect report owed to upstream with
local work in this repository that is blocked on it, so `target:
ourPLCC/plcc-ng` reads as "nothing for us here" while #37 quietly carries a
revert of OBJ's `Program.out` buffering. It also invites caching upstream's
status locally, which goes stale unnoticed, and no scalar status field
survives an issue naming two upstream refs. Resolved by a rule: an issue
tracks work in *this* repo, and upstream status is read on demand rather
than recorded.

## Description

An upstream-targeted issue currently conflates two different things: a
defect report that belongs in upstream's tracker, and local work in this
repository that is blocked on upstream fixing it. Conflating them has
produced four concrete problems.

**It hides pending local work.** Reading [#36](036-plcc-rep-deadlocks-on-partial-stdout-line.md)
and [#37](037-plcc-rep-lacks-output-and-clean-exit-records.md) as
"upstream's problem, nothing for us here" is the natural reading of
`target: ourPLCC/plcc-ng`, and it is wrong — #37 carries a revert of
OBJ's `Program.out` buffering plus two
[course-material-impact.md](../course-material-impact.md) caveats. That
state lives in prose ninety lines into the file, where nothing surfaces
it.

**It caches state this repository does not own.** Commit `4f48b1f`
recorded a careful manual check of upstream's tracker into three issue
files. That record began going stale the moment it was committed, and
nothing detects the drift.

**It miscites the workarounds.** All three OBJ specs attribute the
`Program.out` buffering to issue 36 ([python:18](../../src/OBJ/python/spec.plcc),
[java:14](../../src/OBJ/java/spec.plcc),
[javascript:618](../../src/OBJ/javascript/spec.plcc)), but the buffering
can only be removed once plcc-rep gains an **output record kind**, which
is upstream #187 — this repo's #37. Upstream #186 landing alone would
turn the deadlock into a diagnostic without giving OBJ anywhere to emit
output. So #36 gates nothing locally, and both workarounds belong to #37.

**No scalar field can express multi-dependency.** An attempt to add an
`upstream-fixed:` date broke immediately on #36, which names two upstream
refs whose fixes have different local consequences.

## Notes

The resolution generalizes [#22](022-plcc-rep-parses-each-source-independently.md)'s
closing rationale, which closed that issue while upstream #185 was still
open, on the grounds that "what remains is a documentation task in
someone else's tracker, so tracking it as an open issue here overstated
what was outstanding." That reasoning is right and should be the rule:

> An issue in `dev-docs/issues/` tracks work in **this** repository.
> Whether upstream has fixed something is a fact about upstream — read on
> demand, never recorded.

`target` keeps its meaning (where the defect is); open/closed becomes the
answer to "is there local work," answerable entirely from inside this
repo.

**A tracker switch was considered and rejected.** GitHub Issues would not
help: upstream `ourPLCC/plcc-ng` reports `has_issues: true` but
`open_issues_count: 0` — its GitHub tracker is enabled and unused, and
its issues are files in `dev-docs/issues/` exactly like ours. So native
cross-repo issue linking, the strongest argument for switching, does not
apply. Worse, GitHub numbers issues and pull requests in one sequence:
`ourPLCC/plcc-ng#187` resolves to a **closed pull request** titled "069
improve parse trace," not to the issue our #37 means. Upstream is also
migrating *toward* this repo's system — their open issue
`189-align-issue-system-with-languages-ng.md` proposes adopting the
never-move/frontmatter-status shape, citing 14 links broken by their
`done/` directory move.

A `bin/issues/upstream.bash` that queried upstream state live was
designed and dropped: it would depend on upstream's directory convention,
which upstream's own #189 proposes to change. With one open
upstream-targeted issue remaining after #36 closes, a durable pointer
plus a human click is the right size.

Design spec:
[dev-docs/specs/2026-08-14-upstream-issue-tracking-design.md](../specs/2026-08-14-upstream-issue-tracking-design.md).

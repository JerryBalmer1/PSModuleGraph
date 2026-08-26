---
id: facet-health
version: 0.0.1
kind: scalar
separator: ":"
paths:
  - path: facet-health:coverage:none
    since: 0.0.1
    description: The facet has no assignments. It is decoration until something carries it.
  - path: facet-health:coverage:partial
    since: 0.0.1
    description: Some subjects in scope carry a path on it; others that plausibly should do not.
  - path: facet-health:coverage:complete
    since: 0.0.1
    description: Every subject in scope carries at least one path.
  - path: facet-health:evidence:asserted
    since: 0.0.1
    description: Assignments carry evidence that is a restatement of the assignment. The weakest state and the easiest to miss.
  - path: facet-health:evidence:inferred
    since: 0.0.1
    description: Evidence exists but is indirect - a name, a convention, a heuristic. Confidence should be well below 1.
  - path: facet-health:evidence:observed
    since: 0.0.1
    description: Evidence was read directly off the artefact. The only state in which confidence 1 is honest.
  - path: facet-health:depth:consistent
    since: 0.0.1
    description: Sibling paths sit at comparable depths.
  - path: facet-health:depth:ragged
    since: 0.0.1
    description: Some branch runs markedly deeper than its siblings, which usually means the hierarchy is wrong rather than the subject unusual.
supersedes: []
meta: true
---

# facet-health

**A facet that classifies facets.**

This is the recursion, and it is load-bearing rather than decorative. `facet:structure`
and `facet:surface` are subjects — the `facet:` namespace exists precisely so
they can be — and this facet assigns paths to them like any other. That is how
the taxonomy grades its own health, and it is the first thing that will say the
store is degrading before a human notices.

The three axes are the three ways a facet rots, and they rot independently:

**Coverage** — a facet nobody assigns is a facet nobody uses. This is the
cheapest signal and the one most worth watching, because a dimension created in
enthusiasm and never populated looks identical to a healthy one until you count.

**Evidence quality** — the dangerous one. `evidence:asserted` means the evidence
block restates the assignment instead of supporting it: "this is a function
because it is a function". Such assignments carry high confidence and no
information, and they accumulate quietly. The Skeptic persona exists mostly to
catch this.

**Depth consistency** — a branch three levels deeper than its siblings is a
signal the hierarchy is wrong. The temptation is to read it as the subject being
unusual. It almost never is.

## What belongs here

Judgements about a facet *as a facet*: is it used, is it evidenced, is it
shaped consistently. Nothing about what the facet means.

## What does not belong here

- **Whether the facet is a good idea.** That is a question for the Taxonomist
  and belongs in prose, in the facet's own body, or in a ledger entry. A store
  that scores its own dimensions on usefulness will optimise for the score.
- **Assignment counts as such.** Coverage is a bucketed judgement, not a metric.
  The number belongs in whatever computes the assignment, not in a path.
- **Ordinary subjects.** Assigning `facet-health` to a PowerShell function is a
  category error. This facet's subjects are always in the `facet:` namespace, and
  a reader finding otherwise has found a bug.

## Why it is scalar rather than hierarchical

The paths are ordered within each axis: `none` < `partial` < `complete`, and
`asserted` < `inferred` < `observed`. That ordering is the point — it is what
lets a reader say the store got worse — and `scalar` is the `kind` that declares
it. The colon-separated shape is not a hierarchy here; it is an axis name and a
value on that axis.

**This is the weakest part of the design and is recorded as such in `ledger/0001`.**
A facet carrying three independent axes in one path space is arguably three
facets. It is left as one for v0.0.1 because splitting a facet nothing has yet
assigned would be reorganising an empty room, and because the reflection pass is
supposed to propose that split from evidence rather than from a hunch.

## Not yet assigned

No assignments exist for this facet. That is deliberate and is itself the finding:
by its own scale it is `facet-health:coverage:none`, and writing that assignment
in the same breath as defining the facet would be exactly the `evidence:asserted`
failure it exists to detect. The first honest assignments come from the next
implementation, computed from the store rather than declared alongside it.

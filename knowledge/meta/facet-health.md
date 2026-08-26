---
id: facet-health
version: 0.1.0
kind: categorical
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

## Why it is categorical, and why it is one facet rather than three

**Version 0.1.0 corrected `kind` from `scalar` to `categorical`.** Not a rename,
so nothing aliases; the paths are unchanged and every one still resolves.

`scalar` asserts that a facet's paths are *ordered*. These paths are ordered
**within** each axis — `none` < `partial` < `complete`, `asserted` < `inferred`
< `observed` — and **undefined across** them. There is no answer to whether
`facet-health:coverage:complete` is greater than `facet-health:evidence:asserted`,
and `scalar` was claiming there was. Ordering within an axis is not ordering
across axes, and declaring the stronger property was simply wrong.

That correction was proposed by the reflection pass in `ledger/0002` as an
evidenced defect and applied by `ledger/0003`, which is the discipline working:
reflection proposes, the next implementation disposes.

**Three axes, one facet — deliberately.** `ledger/0001` proposed splitting this
into three facets and `ledger/0002` withdrew the proposal under the evidence
rule, for a reason that is worth keeping written down here:

> **Facets are multi-valued.** A subject can already carry
> `facet-health:coverage:partial` *and* `facet-health:evidence:inferred`
> simultaneously, as two paths on one facet. Three separate facets would hold
> exactly the same information. Two subjects with identical assignments before
> the split have identical assignments after it. **The split separates nothing.**

A split that separates no two subjects is a rename that produces extra files.
If someone later finds a pair of facets that three separate facets would
distinguish and this one cannot, that is the evidence to reopen it — and naming
the pair is the whole requirement.

## Assignments

Computed by `Update-KnowledgeStore`, never declared. Writing these by hand would
be precisely the `facet-health:evidence:asserted` failure this facet exists to
detect, which is why `v0.0.1` shipped it with no assignments rather than with
flattering ones.

Confidence differs by axis because the three are different kinds of claim.
Coverage is counted; depth is measured; evidence quality is a judgement encoded
as a rule, and carries the lowest confidence by some distance. **Read the
evidence axis as a prompt to look, not as a finding.**

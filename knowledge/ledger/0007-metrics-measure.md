---
id: "0007"
tag: v0.5.0
date: 2026-08-26
prompt_intent: Make the thing the owner saw in the report - that some nodes obviously matter more than others - into a measured, coloured property, and give it metadata general enough that facets can join it later rather than needing a second control.
personas: [taxonomist, integrator, skeptic]
open_threads: [0007-t1, 0007-t2]
closes: []
carries_forward: [0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0007 — a facet classifies, a metric measures

## What changed

**The payload measures every node.** `Get-GraphNodeMetric` computes four numbers
per node, in pairs — two local and two transitive, because the local ones
systematically understate:

| | direct | transitive |
| --- | --- | --- |
| inbound | `dependents` | **`blastRadius`** |
| outbound | `dependencies` | `reach` |

`ConvertTo-GraphJson` emits them, and it is still the only serialiser, so the
JSON export and the HTML payload cannot drift.

**`ColorBy` takes a facet id or a metric id.** `structure` is today's
one-colour-per-kind; a metric id paints a heat ramp instead. The radio list is
built from the ids the *payload* carries, so adding a metric is a change in
`Get-GraphNodeMetric`, a value in the enum, and two strings — no branch in any
script.

**`HeatRamp` is five colours in `theme.psd1`**, behind a new `ColorList` schema
type. Colours as data was an open extraction-checklist item; this advances it
rather than working around it.

**The legend redraws with the choice**, showing the ramp with the real minimum
and maximum, and the Details panel gained blast radius and reach.

## What I learned

**The thing the owner pointed at was not the thing the architecture had a design
for.** `docs/html-architecture.md` has carried a heatmap design since `0001`:
two facets crossed with a count, a matrix. What the screenshots showed was
something else entirely — magnitude painted onto the graph, `Get-HashtableValue`
sitting at the foot of the foundation view with everything above it. Building
the recorded design would have shipped a correct feature nobody had asked for.
**A written design is evidence about what was once decided, not about what is
now wanted**, and the two are easy to confuse precisely because the vocabulary
matches.

**Rank beats magnitude, and the number says so.** Blast radius is heavily
skewed: 14 distinct values across ~100 nodes, one scoring 30, and 73% scoring
three or less. Linear normalisation puts almost three quarters of the graph in
the coldest band and answers no question at all. Rank spreads the ramp across
the values that occur. The cost is that colour stops being proportional — which
is why the raw number is in Details and the legend labels its ends with actual
values.

**The measure the code already claimed to have was not the one it had.**
`borderFor` was commented "the blast radius: how many things break if this
changes" and counted direct callers. It was the label that was wrong, and the
gap between the two is exactly where the interesting nodes live: a node with two
direct dependents that each have thirty is far hotter than one with five leaf
dependents. Border now says direct callers, honestly, and fill carries the
transitive measure — two channels, two facts.

**Adding a schema TYPE is not adding a setting, and the rule survives the
distinction.** A ramp is one decision, so it is one entry, so it is a list, so
it needed a validator — which is a `.ps1` edit, which the rule says to report as
a design bug. It is not one: every type in that switch was added the same way,
and the rule is about *settings*. The test still holds — `HeatRamp` and
`ColorBy` are both pure data changes.

**`0001-t7` got its seam without being closed.** The facet seam in the report
has been designed and unbuilt for six entries. `colorByOptions` is that seam:
when a facet arrives it becomes an entry in the same registry rather than a
second control. What is missing is not the mechanism any more — it is a facet
worth colouring by.

## What I could not verify

The Skeptic's section. It is never empty.

- **That anyone can read the ramp.** I checked every stop carries the near-black
  node label by computing contrast ratios, not by looking at it, and I have not
  seen the page rendered at all. Five bands on a dark canvas next to a blue
  focus highlight and a white export border is a lot of colour language at once,
  and it may simply be busy.
- **That red is the right hue.** It was asked for and it is conventional for
  heat, but red already means `Unresolved` in this report — the dotted edges and
  the `External` fill are `#ff7043`, which sits inside the hot end of the new
  ramp. A hot node and an external node are now nearly the same colour, and I
  did not notice until writing this section. Opened as `0007-t1`.
- **That four metrics are the right four.** Cyclomatic-ish measures, file size,
  age from git — none considered. The pairing of local and transitive is
  principled; the choice of *what* to measure is convention.
- **That rank is right rather than merely better.** I compared it against linear
  and stopped. A square-root or a log scale would keep some proportionality
  while still spreading the tail, and I did not try either.
- **That `blastRadius` is well-defined inside a cycle.** Every member counts
  every other member, which is defensible — changing one does break the others —
  but it means a three-node cycle has a floor of two for all three, and a reader
  seeing three warm nodes cannot tell that from three genuinely depended-on ones.
- **The whole of `0006`'s claim** still stands unverified; see `0006-t1`. The
  report generated this iteration was never opened.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**Yes — and the honest finding is that it is not a facet.** The pair is named
and it is real: `psmodule:PSModuleGraph/function/Get-HashtableValue`
(blastRadius 30) against
`psmodule:PSModuleGraph/function/ConvertTo-DotId` (blastRadius 2). `structure`
says both are `function`; `surface` says both are `internal`. **No existing
facet distinguishes them, and every reader wants them distinguished** — that is
the whole reason this iteration happened.

But a facet has *paths*, and a measurement has none. Banding it —
`blast-radius:high` / `:medium` / `:low` — would produce paths, at the cost of
inventing thresholds nobody has argued for and freezing them into identifiers
that renames-never-delete then makes permanent.

**The proposal is therefore not a facet. It is that the store should learn to
hold measurements alongside classifications**, as a second record type with a
value and a unit rather than a path. Proposed, not built: reflection proposes
and the next implementation disposes, and a new record type in the same turn its
need was discovered is the exact hazard that discipline exists to prevent.
Opened as `0007-t2`.

**2. Is an existing facet doing two jobs?** No. No facet was read or written.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No —
nothing was classified.

**5. Could this facet classify facets?** Not applicable, and worth noting for
`0007-t2`: a metric absolutely could measure a facet. `facet-health` already
computes coverage as a count and then bands it into a path, which is the
banding trade above, already made once, in the direction I am declining to
repeat. That is evidence on both sides and I am not pretending it settles it.

### Prune, this iteration

A move: none needed — every new fact landed in the HTML charter. A deletion
proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## Open threads

1. **[0007-t1] Hot and external are nearly the same colour.** `External` fills
   are `#ff7043` and unresolved edges are the same; the hot end of `HeatRamp` is
   `#ff3b2f`. Colouring by a metric therefore makes a heavily depended-on
   internal function look like an unresolved external one, which is the opposite
   of a useful distinction. Both are data, so the fix is a data change — but
   deciding which one moves is a design call, not a value edit.
2. **[0007-t2] Should the store hold measurements as well as classifications?**
   A facet classifies; a metric measures. The pair in question 1 is named and
   real, and no facet separates it. Banding a measurement into paths buys facet
   machinery at the cost of thresholds nobody argued for, frozen permanently by
   the rename rule. Decide together with `0004-t1` and `0003-t3`: all three are
   the same question about what the store is allowed to contain.

Carried: **[0006-t1]** the http-origin editor-link claim is unverified;
**[0005-t1]** skill descriptions are unbudgeted; **[0005-t2]** the ceiling's
headroom is a guess; **[0005-t3]** nothing measures whether an on-demand file is
read; **[0004-t1]** should patterns be subjects; **[0004-t4]**
`iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report — which now has its
mechanism and needs a facet.

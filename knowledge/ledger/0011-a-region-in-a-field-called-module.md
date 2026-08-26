---
id: "0011"
tag: v0.9.0
date: 2026-08-26
prompt_intent: Emit the renamed contract fields, stop sending the renderer three fields nothing reads, and replace the byte-identity check that this rename makes impossible.
personas: [integrator, skeptic]
open_threads: [0011-t1, 0011-t2]
closes: []
carries_forward: [0010-t1, 0010-t2, 0009-t1, 0009-t3, 0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0011 — a region in a field called module

## What changed

**`meta` emits the contract's names.** `title`, `version`, `rootPath`, and
`contractVersion` declared alongside them. The renderer still reads
`moduleName`, `moduleVersion` and `moduleRoot` and warns naming both — a rename
never deletes — but a producer emitting a name it was told to stop using keeps
the alias alive for nobody.

**Three fields left the HTML payload.** `data.moduleName`,
`data.moduleVersion` and `data.moduleBase` duplicated `meta`, and `moduleBase`
was literally the same string as `meta.moduleRoot`. Checked before changing:
nothing in either backend had ever read any of them. They stay in
`ConvertTo-GraphJson`, because `-Format Json` wants them at the top of the
document it produces, which is a different question from what a renderer needs
embedded.

**`tests/Extraction.Semantic.Tests.ps1`** replaces byte-identity for this
iteration. The byte comparison is re-recorded and still runs, covering the next
one.

## What I learned

**The Terraform fixture made the argument that prose could not.** `moduleName`
was holding `"prod-eu-west-1"`. A field named for one producer's domain does not
look wrong until something else has to fill it, and then it looks absurd — which
is why the fixture was worth writing an iteration before the rename that needed
it.

**Renaming a duplicate is agreeing that a reader needs both copies.** The
instinct on finding `data.moduleBase` and `meta.moduleRoot` holding the same
string was to rename both to `rootPath`. The right question was which one
anything reads, and the answer was neither.

**Positional line diffing is the wrong instrument for a document with generated
data in it.** Removing three keys from a pretty-printed JSON block reported 78%
of lines changed, because an insertion shifts every line after it. The same
cascade fires when a two-line comment becomes three. Comparing which lines
*exist* is insertion-tolerant and still catches a line that changed or vanished
— and the list of vanished lines turned out to be exactly the edits made,
nothing more.

**An absolute path cannot be compared across two checkouts.** The semantic test
first asserted the new `rootPath` equalled the old `moduleRoot`, and failed
because the reference document was recorded in a temporary worktree. What is
assertable is that the field MOVED, not that two machines agree — the same
lesson the byte test learned in `0009` and the same one arriving in a new place.

## What I could not verify

The Skeptic's section. It is never empty.

- **That semantic equivalence proves what byte-identity proved.** It does not.
  Six dimensions were chosen and compared; a difference outside all six passes,
  and the list has no principle behind it beyond judgement. This is a real loss,
  taken deliberately because the alternative was not verifying the rename at
  all.
- **That the deprecated-name path works.** Nothing here emits the old names any
  more, so the fallback in the renderer is exercised only by tests that exist to
  exercise it. The first real proof would be an older producer, and there is no
  older producer.
- **That `-Format Json` keeping the three fields is right.** It is defended as
  "a different question", and that is an argument rather than a measurement.
  Nobody has asked a JSON consumer whether they read `moduleBase`. Opened as
  `0011-t1`.
- **That the golden is still worth what it costs.** It is re-recorded, so it now
  proves the renderer produces what it produced this afternoon. Every iteration
  that changes the output re-records it, and a check that is re-recorded
  whenever it fails is a check that only catches accidents. It catches
  accidents, which is not nothing, and it is not the guarantee it was in `0009`.
  Opened as `0011-t2`.
- **That `SampleModule.v0.2.0.html` will stay meaningful.** It is kept as the
  before-image for the semantic test. Two contract changes from now it will be
  compared through a rename map with a dozen entries, and the map itself will
  become the thing nobody checks.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**No.** The candidate is `read-by` — the fact that separated the three removed
fields from the kept ones was *nothing reads this*, and no facet expresses
reachability. But it is a property of an edge, not of a subject, and the graph
already answers it directly: that is what `blastRadius` and `dependents`
measure. A facet duplicating what a metric measures is the `0007` mistake in
reverse.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable this iteration.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## Open threads

1. **[0011-t1] Nobody has asked what a JSON consumer reads.** The three fields
   were kept in `-Format Json` on the argument that an export document wants a
   header. That may be true and it is untested; `-Format Json` has no consumer
   anyone has spoken to.
2. **[0011-t2] A golden that gets re-recorded when it fails only catches
   accidents.** It caught a stale checkout in `0009` and it will catch an
   unintended change, which is worth keeping. It is no longer evidence that
   behaviour is unchanged, because the procedure for a deliberate change is to
   overwrite it.

Carried: **[0010-t1]** nothing tells this repository the renderer's surface
moved; **[0010-t2]** a test scoped to a module that no longer holds what it
tests still passes; **[0009-t1]** one fixture proves the move; **[0009-t3]**
nothing proves the dependency is really required; **[0008-t1]** nothing has been
trained on the corpus; **[0008-t2]** the section headings are hardcoded;
**[0008-t3]** `corpus/` is outside lint and the charter test; **[0007-t1]** hot
and external are nearly the same colour; **[0007-t2]** should the store hold
measurements; **[0006-t1]** the http-origin editor-link claim is unverified;
**[0005-t1]** skill descriptions are unbudgeted; **[0005-t2]** the ceiling's
headroom is a guess; **[0005-t3]** nothing measures whether an on-demand file is
read; **[0004-t1]** should patterns be subjects; **[0004-t4]**
`iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.

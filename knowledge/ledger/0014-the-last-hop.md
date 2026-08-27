---
id: "0014"
tag: v0.12.0
date: 2026-08-27
prompt_intent: Carry the edge resolution into the payload so a reader can see it, and measure what the knowledge store actually does with 32 functions sharing a name rather than predicting it from the code.
personas: [integrator, taxonomist, skeptic]
open_threads: [0014-t1, 0014-t2, 0014-t3]
closes: [0013-t1]
carries_forward: [0013-t2, 0013-t3, 0012-t1, 0012-t2, 0012-t3, 0012-t4, 0011-t1, 0011-t2, 0010-t2, 0009-t1, 0009-t3, 0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0014 — the last hop

## What changed

**`links[].resolution` is in the payload.** `Unique`, `SameFile` or `Ambiguous`,
one per edge. The producer has known it since v0.11.0 and dropped it one step
before anyone could see it.

**`meta.contractVersion` stays `1.0.0`.** `links[]` already allows additional
properties, so the field is valid against the contract as it stands. The
declaration moves when the contract does, in the tag that moves the pin.

**Nothing else.** The renderer, the contract document and the pin are the next
two tags, in that order, and the order is the point.

## What I learned

**A payload that gains a field the renderer does not read renders identically.**
The whole suite passes against the pinned v0.3.0 with one exception, the golden,
whose diff is five `"resolution": "Unique"` lines and a timestamp — one per edge,
all `Unique`, because SampleModule has no duplicated name. That is the
compatibility claim the additive-minor rule makes, and it is now tested in the
direction that matters rather than asserted.

**The knowledge store collapses, and it is worse than collapsing.** `0013-t1`
predicted this from reading the code; run against SqlServerDsc 17.5.1 it is
measurable:

| | |
| --- | --- |
| function definitions in the graph | 469 |
| distinct function names | 327 |
| function subject files written | 327 |
| **definitions with no subject at all** | **142** |
| names carried by more than one definition | 51, covering 193 definitions |

One subject survives per name and it carries a `source:` — so
`subjects/psmodule/SqlServerDsc/function/Get-TargetResource.md` exists once,
for 32 definitions, and says

```
source: "DSCResources/DSC_SqlWindowsFirewall/DSC_SqlWindowsFirewall.psm1"
```

That is not a collapse into something vague. It is a **confidently wrong path**:
a reader following it lands in `DSC_SqlWindowsFirewall` for a function they were
reading in `DSC_SqlAG`, with nothing saying the other 31 exist. Same shape as the
roots finding in `0013` — an answer, not a gap. `Set-TargetResource` and
`Test-TargetResource` name the same file for the same reason, last write wins.

**The fix is authorised and I did not take it, which needs saying plainly.**
The subject URN is built in one function, `Get-KnowledgeSubjectId`, and adding
the qualified path to it is a small edit. What follows it is not: the store's
third rule is that renames never delete, so every existing subject needs an alias
with a `since` marker, and **270 record files in this repository's own store move
on disk**. That is a store migration with its own correctness question — whether
an alias trail survives a tree that is regenerated rather than edited — and
bolting it onto a two-repository contract change would be doing it badly. The
measurement was the thing that could not wait, and it is done. Opened as
`0014-t1` with the numbers attached rather than as a prediction.

**What the golden still proves, in one paragraph.** It no longer proves anything
about the extraction: every id changed at v0.11.0, the payload changed again
here, and it has been re-recorded from the output of the code it is meant to
check twice in two tags. What it proves now is *the size and shape of a
deliberate change* — this iteration's diff was six lines, and reading them was
how I confirmed the field reaches every edge exactly once and that v0.3.0 emits
it untouched. The semantic comparison cannot do that: it asserts a list of
properties someone thought to name, so a field arriving in the wrong place, twice,
or html-escaped would pass it and show up in the golden immediately. **It earns
its place as a change detector and has stopped earning it as an acceptance
test**, and the honest fix is not to delete it but to stop the test name and the
fixture path implying provenance they no longer have. Not renamed in this pass —
a rename in the middle of a payload change is one thing too many. Opened as
`0014-t2`.

**`Resolution` is not in the CSV export and that is now an inconsistency.**
`ConvertTo-GraphCsv` writes a fixed header, so adding a column is a breaking
change for anything parsing it positionally, and JSON and CSV now describe the
same graph differently. Logged rather than taken. Opened as `0014-t3`.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**The same candidate as `0013`, now one step closer.** `resolution` is a
classification of an edge and it is now in the payload, which is where a facet
would eventually have to reach. It is still not in the store, because the store
classifies subjects and an edge is not one. Third iteration in a row that wants
to classify a relationship; not created, and the reason it is not created has not
changed.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?**
**Yes, and it is now measured rather than predicted.** A subject is a name, so
142 of SqlServerDsc's 469 function definitions get no record and the 327 that do
name one arbitrary file. See above; `0013`'s prediction was right and understated.

**5. Could this facet classify facets?** Not applicable this iteration.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the field is right on more than one module.** SqlServerDsc is the only
  corpus member with ambiguity at any scale — 702 edges. The next largest is
  ImportExcel at 30, then Crescendo at zero. Every `resolution` value in seven of
  the eight results is `Unique` or `SameFile`, so the interesting value is
  exercised by one module.
- **That the renderer will not break on it.** What is tested is that v0.3.0
  renders a document containing the field. v0.3.0 does not read it; a renderer
  that does is the next tag, and "an unread field is harmless" is a weaker claim
  than "the field is correct".
- **That leaving `meta.contractVersion` at 1.0.0 is right.** It is defensible —
  the payload is valid against 1.0.0 and 1.1.0 does not exist yet — and it means
  a payload carrying a 1.1.0 field declares 1.0.0 for one tag. A consumer
  switching on the declared version would not know to look.
- **That 142 missing subjects is the whole loss.** It counts function subjects
  against function nodes. Classes, enums and script nodes were not checked the
  same way, and the assignment tree was only spot-checked.
- **That the store measurement generalises past DSC.** One module, whose whole
  architecture is the same three function names repeated 32 times. No corpus
  module has been run through `Update-KnowledgeStore` except this one.

## Open threads

1. **[0014-t1] The knowledge store gives 32 definitions one subject and one
   wrong path.** Measured, not predicted: 142 of 469 function definitions get no
   record, and `Get-TargetResource` names `DSC_SqlWindowsFirewall`. The fix is
   the qualified identity `0013` gave the graph; what makes it its own iteration
   is the store's rename rule, which puts an alias on every one of 270 existing
   records.
2. **[0014-t2] The golden's name and location claim a provenance it lost.** It
   is a change detector and a good one; the test says "as it was last recorded"
   and the fixture still sits where the extraction artefact sat.
3. **[0014-t3] JSON and CSV now describe the same graph differently.** `-Format
   Csv` has a fixed header and no `resolution` column; adding one breaks
   positional parsing.

Carried: **[0013-t2]** the renderer requirement is a floor treated as a pin;
**[0013-t3]** an ambiguous edge is drawn like a certain one — the payload half is
closed here, the drawing is the renderer's next tag; **[0012-t1]** the corpus is
a hypothesis with eight instances; **[0012-t2]** `timeout` and `missing` have
never executed; **[0012-t3]** nothing validates a result against its schema;
**[0012-t4]** the lock has only been checked by the session that wrote it;
**[0011-t1]** nobody has asked what a JSON consumer reads; **[0011-t2]** a
re-recorded golden only catches accidents; **[0010-t2]** a test scoped to a
module that no longer holds what it tests still passes; **[0009-t1]** one fixture
proves the move; **[0009-t3]** nothing proves the dependency is really required;
**[0008-t1]** nothing has been trained on the corpus; **[0008-t2]** the section
headings are hardcoded; **[0008-t3]** `corpus/` and `gallery/` are outside lint
and the charter test; **[0007-t1]** hot and external are nearly the same colour;
**[0007-t2]** should the store hold measurements; **[0006-t1]** the http-origin
editor-link claim is unverified; **[0005-t1]** skill descriptions are unbudgeted;
**[0005-t2]** the ceiling's headroom is a guess; **[0005-t3]** nothing measures
whether an on-demand file is read; **[0004-t1]** should patterns be subjects;
**[0004-t4]** `iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.

Closed: **[0013-t1]** the store was predicted to collapse what the graph stopped
collapsing. It does, and it also writes a wrong path rather than an absent one.
Closed as a question; reopened as `0014-t1`, which is a different thread because
it carries a measurement instead of a guess.

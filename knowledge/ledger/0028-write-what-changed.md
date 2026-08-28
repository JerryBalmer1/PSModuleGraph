---
id: "0028"
tag: v0.18.0
date: 2026-08-27
prompt_intent: Rule 0027-t2 by accepting v0.17.1 as a pass whose subject readings do not stand, record the argument and both refusals where it will be had again, correct what the drift finding is allowed to claim, and then stop measuring - take a logged improvement instead, so the next transcript is work rather than another measurement session.
personas: [integrator, skeptic]
open_threads: [0028-t1, 0028-t2, 0028-t3]
closes: [0027-t2]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3, 0025-t1, 0025-t3, 0026-t1, 0026-t2, 0027-t1, 0027-t3]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0028 — write what changed

## What changed

**`0027-t2` is ruled: `v0.17.1` is a pass whose subject readings do not stand.**
The rule from `0026` says a control that moves invalidates the subject readings
in the same pass. `schema` moved. So they do not stand. **The rule survives and
the data point does not.** The argument is in `docs/corpus-architecture.md`
under *Decisions made and why*, append-only, with both refusals recorded because
this is the argument that will be had again: demoting `schema` fits the roles to
the observation, widening what "control" permits changes the rule after seeing
the number, and **both make the design unfalsifiable by adjusting it.**

**`schema` stays a control in `predictions.json`, predicted to hold.** If it
rises again next pass against that prediction, that is the honest way round.

**What the drift finding is allowed to claim is corrected.**
`docs/corpus-architecture.md` read as though the specificity result stood on
`v0.17.1`. It does not. What survives: **the mechanism is argued, the instrument
exists, and the first admissible reading has not been taken** — it is `v0.17.3`
scored against predictions written before the population existed.

**`ledger/0026` cites `schema` rising as "the strongest single piece of evidence
that the drift is specific". That citation is invalid under this ruling.** The
ledger is append-only, so `0026` stands as written and **this entry carries the
correction** — named here and named in the decision log, which is what `0003`
owed `0002-t4` and did not pay.

**Then the measuring stopped.** From `docs/improvements.md`, the unconditional
writer, logged Small in `0024`.

**A build that changes nothing now writes nothing.** `Write-KnowledgeRecord`
renders, compares the rendered bytes ordinally against the file, and returns 0
without touching it if they match. `Remove-UnwrittenKnowledgeRecord` is the
other half: replacement is now write-what-should-exist then
delete-what-should-not, and it prunes the directories that leaves empty.
`Update-KnowledgeStore` and `Update-KnowledgePatternSubject` both use it and
both report `RecordsWritten`, `RecordsKept` and `RecordsPruned`.

## What I learned

**The improvement was logged with the wrong fix, and the wrongness was
structural rather than careless.** The backlog entry — written by me in `0024`
— said the guard belonged in `Write-KnowledgeRecord`. **That guard alone would
never have fired.** `Update-KnowledgeStore` removed the entire owned subtree
before writing anything, so every record was new by the time the writer saw it.
The writer was never the cause; the replacement strategy was, and the writer
merely looked unconditional because it is where the write happens.

This is `pattern:0025-a-record-counts-conclusions-not-incidents` at a scale it
was not written for. The *record* of the defect named the place the symptom
appeared. The *incident* was two functions away, in a line that reads as
housekeeping.

**Measured, before and after, on the same command:**

| | records | rewritten on an unchanged rebuild |
| --- | --- | --- |
| before | 252 + 24 + 8 | **all of them, every build** |
| after | 252 + 24 + 8 | **0** |

The first `Knowledge` run after the change wrote 3 of 252 — the subject and two
assignments for `Remove-UnwrittenKnowledgeRecord` itself, which is a new node in
the module it was added to. The second wrote 0 of 252, 0 of 24, 0 of 8. Working
tree afterwards: **4 files touched instead of 282**, and two of those four are
the `facet-health` coverage counts, which moved for a real reason.

**The test that matters reads the filesystem, not the return value.** `RecordsWritten`
is the command's own report of itself. What was actually wrong was a stat cache,
and a rewrite with identical bytes still moves an mtime and still makes git
report the file modified. So the assertion compares `LastWriteTimeUtc.Ticks`
across a run.

**Both halves were broken on purpose and both went red.** Disabling the
skip-if-identical guard turned three tests red — *writes nothing at all on the
second*, *leaves every file untouched*, *writes nothing the second time*.
Disabling the prune turned five red, including two that look like they are about
something else: *rewrites a record whose bytes were changed underneath it* and
*rewrites when the stamp moves*, because a prune that deletes nothing leaves the
fixture in a state those tests then read. Restored, green, coverage 77.99%.

**Losing the removal-first shape means the "replaced, not merged" invariant now
rests on a list rather than on a deletion.** Before, correctness was structural:
the tree was gone, so nothing stale could survive. Now it depends on `$kept`
containing every path the run wrote, at five call sites, computed by repeating
the path expression the writer uses. **A sixth write added without a matching
`$kept.Add` would silently orphan its record**, and no test would see it,
because the orphan would be a record that should exist and does.

## What I could not verify

**That the five `$kept` sites are all of them.** I found them by reading, and
the invariant they carry used to be enforced by the filesystem. A test that
plants a stray file catches a record that should *not* exist; nothing catches a
write whose path was not registered, because that record *should* exist and
does. The failure mode is a record that stops being pruned when it later becomes
stale, which surfaces an unknown number of iterations later.

**That the ordinal path comparison is right on this platform for the reason I
gave.** `Remove-UnwrittenKnowledgeRecord` compares `GetFullPath` results
ordinally, which is correct on a case-sensitive filesystem and, on Windows,
means a record whose path differs only in case from the one written would be
deleted rather than kept. That is `0023-t2` — path case-sensitivity is a
decision nobody has made — and I inherited it rather than resolving it.

**That skipping is faster.** I did not measure. The guard adds a full file read
before every write; the old shape did a recursive delete and then wrote
everything. Both `Knowledge` runs took about ten seconds and I did not
instrument either, so "the churn is gone" is a claim about bytes on disk and
about nothing else.

**That accepting `v0.17.1` cost anything.** The Skeptic's candidate is right and
I want it recorded rather than answered: refusing my own data point is cheap
when the rule is mine to interpret, and `v0.17.1` was already a pass I had
described as directional-only in `0027`. **The first real test of that rule is a
pass where refusing costs something I wanted**, and this was not it.

**That `docs/corpus-architecture.md` now reads consistently.** I corrected the
paragraph that claimed specificity and added the ruling above it. I did not
re-read the whole file against the new position, and the decision log is
append-only, so earlier entries in it may still assume the reading that has just
been withdrawn.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No.** The
candidate is *enforcement kind* — whether an invariant is structural, gated, or
carried by a list — which `0028-t1` is about and which would classify code
rather than subjects. `NAMING.md`'s criterion refuses it: a line of code has no
identity that is a pure function of its own properties. Third consecutive
iteration where that criterion answered without a debate.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. Recorded: the store
gained one node, `Remove-UnwrittenKnowledgeRecord`, and the two `facet-health`
coverage records moved from 92-of-94 to 93-of-95 as a result. That is the
grading working; it is also the only reason two records changed in a pass whose
whole point was that records stop changing.

### Prune, this iteration

A move: none. Nothing entered the always-loaded tier. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## Open threads

1. **[0028-t1] The replacement invariant now rests on a list, not on a
   deletion.** Every write must be matched by a `$kept.Add` at the same site,
   five today. A write added without one orphans its record permanently and
   nothing detects it: the orphan is a record that should exist, so no prune
   test sees it, and the freshness gate compares whole trees and would find the
   record present and correct. The cheap check is that `$kept.Count` equals the
   number of records the run intended, asserted rather than inspected — and
   deriving "intended" without re-deriving the writes is the part that is not
   obvious.
2. **[0028-t2] Nothing measures whether the guard is worth its cost.** It adds a
   read of every record before every write. The old shape deleted a tree and
   wrote everything. Neither was timed. The change is justified entirely on
   diff noise, which is a real cost, and "faster" was never claimed and is not
   known.
3. **[0028-t3] The correction in this entry is carried by one sentence in one
   entry.** `0026`'s invalid citation is named here and in the decision log.
   Nothing links forward from `0026` itself, because the ledger is append-only
   and correctly so — but that means a reader who finds `0026` by grep, which is
   how these are found, reads the withdrawn claim with no marker on it. Whether
   a superseded ledger claim needs a forward pointer, and where it would live
   without editing the entry, is a design question rather than an edit.

Carried: **[0027-t1]** the instrument is more sensitive than the effect it
measures; **[0027-t3]** clause 4 of the gate condition has no implementation;
**[0026-t1]** the foreground classifier depends on a signal the tooling can
destroy; **[0026-t2]** one series file holds two populations; **[0025-t1]**,
**[0025-t3]**, **[0024-t1]**, **[0024-t2]**, **[0024-t3]**, **[0023-t1]**,
**[0023-t2]** — now load-bearing for `Remove-UnwrittenKnowledgeRecord`'s path
comparison; **[0023-t3]**, **[0023-t4]**, **[0023-t5]**, **[0022-t4]**,
**[0022-t5]**, **[0021-t1]**, **[0020-t1]**, **[0019-t1]**, **[0019-t2]**,
**[0019-t3]**, **[0018-t1]**, **[0018-t2]**, **[0018-t3]**, **[0015-t1]**,
**[0014-t2]**, **[0014-t3]**, **[0013-t2]**, **[0012-t2]**, **[0012-t3]**,
**[0012-t4]**, **[0010-t2]**, **[0009-t3]**, **[0008-t2]**, **[0008-t3]**,
**[0006-t1]**, **[0005-t1]**, **[0003-t1]**, **[0003-t2]**, **[0001-t7]**.

Closed: **[0027-t2]**. Ruled by accepting the cost rather than adjusting the
rule.

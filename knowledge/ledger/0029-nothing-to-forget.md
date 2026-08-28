---
id: "0029"
tag: v0.18.1
date: 2026-08-27
prompt_intent: Rule 0028-t1 by making the replacement bookkeeping checkable rather than remembered - pick one of three shapes, argue it before building it, and prove it can fail by staging the exact omission. Then give pattern 0025 a further scale rather than writing a fourth pattern, because a pattern gaining a scale is stronger than a pattern being written and nothing here has done that deliberately.
personas: [integrator, skeptic]
open_threads: [0029-t1, 0029-t2, 0029-t3]
closes: [0028-t1]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3, 0025-t1, 0025-t3, 0026-t1, 0026-t2, 0027-t1, 0027-t3, 0028-t2, 0028-t3]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0029 — nothing to forget

## What changed

**The shape, and the argument for it before it was built.** Of the three
offered — one door, reconcile after the fact, assert the count — **the write
site is now the only way to record.** `Write-SubjectRecord` and
`Write-AssignmentRecord` take a mandatory `-Kept` write log and add to it *the
same variable they pass to the writer*, so the path is computed once and
registered from the computation rather than beside it. The five call sites in
`Update-KnowledgeStore` and the one in `Update-KnowledgePatternSubject` no
longer register anything.

The reason is the one the Skeptic named rather than the one that reads best:
**the write site added six months from now is added by someone who has not read
this entry.** Reconciliation and a count assertion both act on that person
through a test — which has to still exist, still run, and still be believed when
it goes red, and which they will meet after they have written the code. A
mandatory parameter acts on them through the language, at the moment of writing,
with a message naming the thing they left out. It also removes the second
declaration that shapes 2 and 3 both need and that is itself forgettable.

**Facet grading stopped deleting what it was about to rewrite.** Making `-Kept`
mandatory forced every writer's caller into the open, and the third caller was
`Update-FacetHealthRecord`, which still removed each facet's `facet-health`
directory before writing it. That is the delete-first shape v0.18.0 replaced
everywhere else, and it has the same consequence: the file is gone by the time
the skip guard looks at it. It writes through the log and prunes after now, and
the prune is driven from the facet directories **on disk** rather than from the
facets read this run, so a facet that has been deleted still loses its records.

**The mtime test measures the store rather than the subtree the change was made
in.** That is how nine records churned through a version that claimed they did
not.

**Pattern `0025-a-record-counts-conclusions-not-incidents` gained two scales**
rather than a fourth pattern being written: the improvement backlog against the
code path it named, and an open thread against the failure it was finally staged
against. Both are in `knowledge/patterns/`, and the handoff gained a paragraph
that is really about this iteration — if the sentence you are writing is
"nothing would catch this", it is a prediction and you are holding the apparatus
that tests it.

## What I learned

**`0028-t1` was wrong about its own failure mode, and one build said so.** It
claimed a write site added without its `$kept.Add` would orphan a record and
that **nothing would detect it**. Staged — a sixth write site in
`Update-KnowledgeStore`, committed to nothing:

| | what the omission did | what went red |
| --- | --- | --- |
| **claimed in `0028-t1`** | orphans a record for ever | nothing |
| **v0.18.0, measured** | written, then deleted by the prune at the end of the same run, every run | **4 tests** |
| **v0.18.1, measured** | cannot be expressed; fails at parameter binding | **17 tests, 3 blocks** |

The record never reached the store and the run never became idempotent, so
`RecordsWritten` stuck at 1 for ever and the tests about *churn* fired. **The
detection was real and accidental.** It came from tests whose names are about
replacement and about writing nothing, it names the wrong thing when it fires,
and it survives only as long as nobody relaxes `Should-Be 0`. That is a
different argument for the same fix, and it is a weaker one than I had.

I only know it because the ruling said to stage the defect. I would have shipped
the thread's claim.

**The version that closed the churn left nine records churning.** v0.18.0
measured "0 of 252, 0 of 24, 0 of 8" — three commands reporting on themselves —
and a test that read mtimes under `subjects/psmodule`. Across the whole store,
**9 of 39 records in the fixture moved their mtime on every run**, all of them
facet-health assignments, and 9 of 336 in the real store. Same defect, one
subtree over, invisible because both instruments were pointed at the subtree the
change was made in. After this pass: **0 of 39**.

**A mandatory collection parameter rejects an empty collection.** `-Kept` is
supplied empty by every caller, on the first write of a run, and PowerShell
refused to bind it until `[AllowEmptyCollection()]` was added beside
`[Parameter(Mandatory)]`. Worth writing down because the pair reads like a
contradiction and is not: mandatory is about whether the caller supplied it,
`AllowEmptyCollection` about whether what they supplied may be empty.

**Grading is recursive, so the store converges rather than settling at once.**
facet-health grades a population that includes the previous run's facet-health
assignments, so run two legitimately differs from run one and stillness can only
be measured from run three. The test now runs it twice before it starts looking
and says why. Two runs is what was observed, not what was proved.

## What I could not verify

**That the door is the only door.** `-Kept` is mandatory on the two wrappers.
Nothing stops a new generator calling `Write-KnowledgeRecord` directly, which
takes a path and no log, and a record written that way is deleted by the next
prune of that subtree. The wrappers are the door by convention, and the
convention is not checked. That is `0029-t1`, and it is the honest residual of
choosing shape 1: the omission it makes impossible is the one I staged, and the
one it leaves open is the one I did not.

**That the Skeptic's candidate is answered rather than deflected.** The claim
was that whichever shape I picked would be verified by a staged omission I wrote
myself, which is the failure I already know about. True, and the staging still
earned its cost — it falsified the thread. What I claim is narrower than an
answer: shape 1 is the only one of the three whose enforcement does not depend
on the newcomer encountering a test, because the binder runs for them whether or
not anything else does. That is an argument about mechanism, not evidence that
it works on a person who does not exist yet.

**That the facet prune is scoped right.** It removes unwritten records from
`subjects/facet` and from each `assignments/facet/<id>/facet-health`, matching
what the delete-first shape removed. An assignment placed under
`assignments/facet/<id>/` by some other facet is deliberately left alone, and
nothing in the store exercises that case today because no such assignment
exists. The narrow scope is a decision defended by an empty population.

**That two runs is the fixed point.** Observed on one fixture and on the real
store. Not proved, and a grade that depends on its own value could oscillate
without bound; the only symptom would be a store that never stops churning,
which is now exactly what the widened test would report — but as "the mtimes
moved", not as "this does not converge".

**That the writers are the whole write path.** I found the callers by grep for
two function names. `Update-FacetHealthRecord` was the one I had missed a
version earlier by reading rather than by running, and the method I used to find
the third caller this time is the method that missed it last time. The
difference is that the compiler found it for me — every call site had to change
to compile — which is a property of the fix and not of my searching.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No**, and the
candidate is the same one `0028` refused: *enforcement kind* — structural,
gated, carried by a list, or carried by a mandatory parameter. This pass added a
fourth value to a facet that does not exist, which is mild evidence the facet is
real, and `NAMING.md`'s criterion still refuses it for the same reason: the
thing classified would be a call site, and a call site has no identity that is a
pure function of its own properties. Fourth consecutive iteration where that
criterion answered without a debate.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. Recorded: the store
gained no nodes. Nine facet-health assignment records stopped being rewritten,
which changes no grade and no content — only how often git is told something
happened.

### Prune, this iteration

A move: none. Nothing entered the always-loaded tier. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## Open threads

1. **[0029-t1] The wrappers are the door by convention.** `-Kept` is mandatory
   on `Write-SubjectRecord` and `Write-AssignmentRecord`, and
   `Write-KnowledgeRecord` beneath them takes a path and no log. A generator
   that calls it directly writes a record the next prune deletes, and no
   parameter and no test says otherwise. The cheap check is a static one — that
   nothing outside `Write-SubjectRecord.ps1` calls `Write-KnowledgeRecord` —
   which is shape 3 from the ruling applied one layer down, and it is crude in
   the same way and makes someone look in the same way.
2. **[0029-t2] The facet prune reports to nobody.** `Update-FacetHealthRecord`
   now deletes records and returns only the number of facets graded.
   `RecordsPruned` in the summary means the module subtree, and says so nowhere.
   A deletion that nothing counts is how a store loses a record quietly, which
   is the failure this whole pass is about, one function over.
3. **[0029-t3] Convergence is observed, not proved.** facet-health grades a
   population containing its own output, the tests run it twice before measuring
   stillness because that is what was seen to work, and nothing establishes that
   two is enough in general or that a fixed point exists. The instrument that
   would notice a store that never converges is now in place; the claim that it
   always does is not.

Carried: **[0028-t2]** nothing measures whether the skip guard is worth its
cost; **[0028-t3]** the correction to `0026` is carried by one sentence with no
forward pointer; **[0027-t1]** the instrument is more sensitive than the effect
it measures; **[0027-t3]** clause 4 of the gate condition has no implementation;
**[0026-t1]** the foreground classifier depends on a signal the tooling can
destroy; **[0026-t2]** one series file holds two populations; **[0025-t1]**,
**[0025-t3]**, **[0024-t1]**, **[0024-t2]**, **[0024-t3]**, **[0023-t1]**,
**[0023-t2]**, **[0023-t3]**, **[0023-t4]**, **[0023-t5]**, **[0022-t4]**,
**[0022-t5]**, **[0021-t1]**, **[0020-t1]**, **[0019-t1]**, **[0019-t2]**,
**[0019-t3]**, **[0018-t1]**, **[0018-t2]**, **[0018-t3]**, **[0015-t1]**,
**[0014-t2]**, **[0014-t3]**, **[0013-t2]**, **[0012-t2]**, **[0012-t3]**,
**[0012-t4]**, **[0010-t2]**, **[0009-t3]**, **[0008-t2]**, **[0008-t3]**,
**[0006-t1]**, **[0005-t1]**, **[0003-t1]**, **[0003-t2]**, **[0001-t7]**.

Closed: **[0028-t1]**. Ruled by making the omission unexpressible, and falsified
on the way: the thread said nothing would detect it, and four tests did.

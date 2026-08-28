---
id: "0030"
tag: v0.18.2
date: 2026-08-27
prompt_intent: Close 0029-t1 one layer down by making the direct call impossible rather than discouraged, staging the omission before claiming it is caught. Then test a candidate pattern against a second instance before writing it - a measurement scoped to where the author was looking reading as a measurement of the whole - and write it only if a second scale survives the check.
personas: [integrator, skeptic]
open_threads: [0030-t1, 0030-t2, 0030-t3]
closes: [0029-t1]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3, 0025-t1, 0025-t3, 0026-t1, 0026-t2, 0027-t1, 0027-t3, 0028-t2, 0028-t3, 0029-t2, 0029-t3]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0030 — a scope nobody chose

## What changed

**The registration moved one layer down, to the last function in this
repository that touches the filesystem.** `-Kept` is mandatory on
`Write-KnowledgeRecord` now, and that is where the path is added to the log;
`Write-SubjectRecord` and `Write-AssignmentRecord` keep their own mandatory
`-Kept` and pass it through.

The choice was between that and making the low-level writer unreachable —
nesting it inside the wrappers' scope so nothing else could call it. **Reaching
one layer down is right and hiding it is not**, for three reasons. Every
function under `Private/` is already module-internal, so "private" is not a
thing PowerShell can make more private without a closure, and a closure would
cost the file its testability and its docstring for a guarantee no stronger than
the parameter's. The wrappers are not actually special — they are two of a kind,
and a third could be added tomorrow — so making *them* the door meant defending
a boundary that is not the real one. And the real one is legible: **the door is
the last function here that opens a file**, which is a rule someone can restate
without reading this entry.

**A new pattern, and only because a second instance survived being checked.**
`knowledge/patterns/0030-the-scope-defaults-to-where-you-stood.md`. Three
scales, one of them live and unfixed.

## What I learned

**The bypass was already caught, and that changed what the fix is for.**
Staged — a generator calling `Write-KnowledgeRecord` directly, committed to
nothing:

| | what went red | what it said |
| --- | --- | --- |
| **before** | **5 tests** | `Expected 25, but got 24` on `RecordsKept` against `RecordsWritten`; two more about counts; one about the prune |
| **after** | **17 tests** | `ParameterBindingException: missing mandatory parameters: Kept`, every time |

So I did not write "nothing would catch this" a second time, and I would have
been wrong again if I had. Two of the five even diagnosed it correctly:
`RecordsKept` against `RecordsWritten` is exactly *more was written than was
registered*. **The fix is therefore not about detection.** It is about when: the
old five fire after the code is written, committed and run, from tests named
after churn; the new seventeen fire on the author's first attempt, naming the
parameter they left out.

**The candidate pattern's second instance is not either of the two that were
offered, and the offered ones had to be checked rather than assumed.**

The **golden path normaliser** fits and is recorded as a third scale, with its
overlap named: `ledger/0019` read it as `0017-nothing-could-have-said-otherwise`
and that reading is correct. The two answer different questions — `0017` says
why it stayed green, this says why the population was wrong — and the first two
scales separate them cleanly, because those measurements *could* have failed,
one directory over.

The **drift controls do not fit**, and the reason is worth as much as a fit
would have been: `watchlist.json`'s own note says a prediction written by the
session that assigned the roles "tests internal consistency and little else",
and the unclassified cohort exists to break exactly that. **A narrowing that was
announced is not this pattern**, however narrow it is. The shape there is
selection on the outcome; the shape here is scope silently becoming claim.

**The second scale was found in this repository, live, while looking for it.**
Code coverage runs against `output/PSModuleGraph.psm1` — one file, the built
module, which is what the tests import and which was the whole repository when
the line was written. `corpus/PSCorpus` is **1,936 lines of the repository's
7,687**, has **741 lines of its own tests running in the same suite**, and
contributes nothing to the number. The gate prints `Line coverage: 77.97%` and
throws with *"Raise coverage"*. Neither says which code. The scope *is* written
down, in `docs/testing.md` — in the sentence that explains why line numbers
refer to a generated file.

That is the pattern with its own tell intact: the scope recorded as an
incidental, never beside the result.

## What I could not verify

**That the depth question has an answer rather than a stopping point.** The
Skeptic's candidate says the layer below `Write-KnowledgeRecord` is
`System.IO.File.WriteAllText` and nothing makes that impossible to call either.
True, and I will not pretend the parameter closed it. What I claim is smaller
and checkable: **the closable depth is the last function this repository owns**,
and what remains as convention is now one line inside one function rather than a
whole internal API. Nothing prevents a new function calling `WriteAllText` into
the store, and the only thing that would notice is a static check that nobody
has written. That is `0030-t2` and it is where I would stop, not where the
regress does.

**That staging a defect I already understand proves anything about the next
person.** The Skeptic's other candidate lands: this fix was verified by the
session that had just learned the lesson, staged carefully, and passed. The
staging did earn its cost — it falsified "nothing would catch this" for the
second iteration running — but it is a test of the mechanism, not of the
mechanism's effect on somebody who has not read any of this.

**That three scales is what the record holds rather than what I found.** I
checked two candidates because they were named, found the third because I was
looking at a build log with the pattern in mind, and ran no systematic sweep. If
this shape is as common as it now looks, "three" is a floor discovered by hand
and the count says more about my attention than about the repository.

**That the coverage number is wrong rather than merely unqualified.** I did not
measure what coverage would be with `corpus/PSCorpus` included, because doing so
means deciding what happens when the answer is below 75, and that is a gate
decision rather than an edit. So the finding is precisely "the number's
population is not the one its sentence implies" — not "the code is less tested
than it looks", which I have no measurement for.

**That the wrappers still earn their `-Kept`.** It is mandatory on all three
writers now, and on the two wrappers it does nothing but pass through. That is
either a redundant parameter or a second lock on the same door, and I chose to
read it as the second lock without evidence either way.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No.** *Enforcement
kind* came up for the third consecutive iteration, gained a fifth value — "the
deepest function that owns the resource" — and is still refused by `NAMING.md`'s
criterion for the same reason: the thing classified is a call site, and a call
site has no identity that is a pure function of its own properties. Three
iterations, one criterion, no debate.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. Recorded: the store
gained one `pattern:` subject and no `psmodule:` nodes. Pattern subjects carry
no assignments by construction — `docs/constraints.md` — so the grades did not
move.

### Prune, this iteration

A move: none. Nothing entered the always-loaded tier. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## Open threads

1. **[0030-t1] The coverage gate measures one module and speaks for the
   repository.** `corpus/PSCorpus` is a quarter of the repository's PowerShell,
   is exercised by 741 lines of tests in the same suite, and is outside the
   number every build prints. Including it is not an edit: the target is a
   throwing gate, nobody knows what the combined figure is, and finding out
   commits somebody to a decision if it lands below 75. Logged Medium in
   `docs/improvements.md`, not taken.
2. **[0030-t2] The door closes at the last function this repository owns, and
   nothing says so but a comment.** `Write-KnowledgeRecord` cannot write without
   registering. A new function calling `[System.IO.File]::WriteAllText` into the
   store can, and the parameter cannot reach it. The check would be static —
   nothing outside `Write-KnowledgeRecord.ps1` writing to the store directly —
   which is the same crude shape as `0029-t1`'s answer, one layer further down
   again, and at some depth the crude check is the whole of what is available.
   Where that depth is has been named here for the first time and not agreed.
3. **[0030-t3] The new pattern's population was not swept.** Three scales, found
   by being handed two candidates and noticing a third in a build log. No search
   was run over the ledger, the docs or the build configuration for other
   measurements whose scope is their author's working set. If the sweep is worth
   doing it is cheap; if it is not worth doing, the confidence of 0.6 is resting
   on that judgement rather than on the evidence.

Carried: **[0029-t2]** the facet prune reports to nobody; **[0029-t3]**
convergence is observed, not proved; **[0028-t2]** nothing measures whether the
skip guard is worth its cost; **[0028-t3]** the correction to `0026` has no
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

Closed: **[0029-t1]**. Ruled by moving the registration to the deepest writer
rather than by hiding it, and staged first: the bypass it describes was already
caught by five tests, which changed the fix from detection to when.

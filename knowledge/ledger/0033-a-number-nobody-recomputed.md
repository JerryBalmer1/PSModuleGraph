---
id: "0033"
tag: v0.18.5
date: 2026-08-27
prompt_intent: Fix the bookkeeping the v0.18.4 audit found and nothing else - correct the false statistic in docs/constraints.md and keep the argument by making it the honest one, say whether a ruling built on the bad number survives, un-double-book 0024-t1 by retiring it from the thread list, resolve the two twice-retired threads to one verb each, strike the constraint that was answered eight entries ago, correct the byte figure forward, and mark in the file which constraints were measured and which were only read.
personas: [archivist, skeptic]
open_threads: [0033-t1, 0033-t2, 0033-t3]
closes: []
accepts_threads: [0024-t1]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t2, 0024-t3, 0025-t1, 0025-t3, 0026-t1, 0026-t2, 0027-t1, 0027-t3, 0028-t2, 0028-t3, 0029-t2, 0029-t3, 0030-t1, 0030-t3, 0031-t2, 0031-t3, 0031-t4, 0032-t1, 0032-t2, 0032-t3, 0032-t4]
recovers_threads: []
prune_proposals: []
supersedes: ["0019", "0024", "0030", "0031", "0032"]
---

# 0033 — a number nobody recomputed

## What changed

Bookkeeping only. No code, no gate, no new constraint.

### The statistic, corrected and kept

`docs/constraints.md` opened by arguing for itself with *"twenty-one of
twenty-three closures happened in the very next entry and none has ever happened
after four carries."* Recomputed over this repository's 32 entries:

| basis | retirements | in the next entry | past four carries |
| --- | --- | --- | --- |
| as recorded | 50 | 23 (46%) | **18** |
| entry `0019` alone | 19 | — | 14 |
| **excluding the `0019` sweep** | **31** | **23 (74%)** | **4** |

The two halves of the old claim failed in opposite directions and for one
reason. **Entry `0019` is 19 of the 50 retirements and 14 of the 18 long ones** —
the deliberate sweep that created the file, commit *"Retire twelve limitations
as chosen rather than pending"*. The statistic was measured before that sweep
and never recomputed, so the file's own creation is what falsified the argument
the file opens with.

The honest argument is better than the false one and is now what the file says:
**retirement is something a deliberate pass does, and almost nothing else does
it.** 74% of organic retirements happen in the very next entry; four of
thirty-one run past four carries; and the largest single act of retirement in
the project is one pass that sat down and decided about nineteen threads. A
thread not answered immediately is not on its way to being answered — it is
waiting for somebody to do what `0019` did, which is what this file is for.

One thing the correction cannot reach: the original count was taken **across
both repositories**, at `PSGraphRender` ledger `0010`. Only this repository's
half is recomputed. The other half is not touched and is not this iteration's.

### The ruling built on it — survives, restated

`docs/improvements.md` carried: *"…so carry count is a measure of how long ago
something was noticed and not a priority."* That inference came from the bad
figure, and the figure's second clause — *nothing has ever closed after being
carried four times* — is simply false.

**The ruling survives.** On the corrected organic numbers the shape it needs is
still there and is sharper: 74% in the next entry, 4 of 31 past four carries. So
carry count still measures how long ago something was noticed rather than what
it is worth. What goes is the absolute. Things **do** get retired after four
carries — four times organically, and a fifth here, `0024-t1` after nine — and
every one of them took a deliberate pass. That is the same claim with a working
mechanism attached instead of an exceptionless law, and it is a stronger
argument for the file than the one it replaces.

Said plainly, because the prompt asked for it plainly: **a ruling was made on a
number nobody had checked, and it happened to survive.** It survived on a
recomputation done eight entries later by a session that went looking. Nothing
in the loop would have raised it.

### `0024-t1` un-double-booked

The paragraph ends *"recorded here rather than as an open thread deliberately"*
and the id was in `carries_forward` of every entry from `0024` to `0032`. It is
retired from the thread list here.

**No fifth verb is needed, and this is the argument for why four suffice.**
`accepts_threads` already means exactly *retired as an accepted constraint,
written down in `docs/constraints.md`* — the schema says so in those words, and
`LedgerContinuity` already removes accepted ids from the open set alongside
`closes` and `supersedes_threads`. The gate could always express "moved to
constraints". Nobody used the verb. **The defect was never in the vocabulary; it
was that `0024` opened `0024-t1` as an ordinary thread, wrote the constraint in
the same entry, and never retired the thread.** A fifth verb would have been
built to fix a habit.

### The twice-retired threads, resolved to one verb each

`0004-t1` and `0007-t2` are in `0019`'s `accepts_threads` and in `0024`'s
`closes`. `0032` reported that as a bare double-retirement and **that report was
incomplete**: `0024` also names both in `recovers_threads`, so the sequence is
accept → recover → close, which the schema permits.

The error is one layer in. `0024`'s body says both were *"carried to `0019` and
dropped from `0020` without being closed"*. They were not dropped. They were
**accepted at `0019`**, which is a retirement, so their absence from `0020` was
correct. `0024` recovered two threads that had never been lost, and the gate
allowed it because `recovers_threads` adds an id back unconditionally and never
asks whether it was missing.

Resolved, each to one verb, naming the earlier:

- **`0004-t1` — closed at `0024`.** The question was *should patterns be subjects
  with URNs*, and `0024` answered **yes** by making them so; nine records now
  carry `pattern:` URNs. Work finished is a closure. **`0019`'s acceptance does
  not stand**, and the constraint it wrote is struck below.
- **`0007-t2` — accepted at `0019`.** The question was *should the store hold
  measurements as well as classifications*, and the answer is no, for reasons
  now in `NAMING.md`. *"The answer is no and this project chooses to have it"* is
  the schema's definition of an acceptance, not a closure. **`0024`'s recovery
  and closure do not stand.** Its constraint paragraph is correct where it is.

### `0004-t1`'s constraint struck

*"Two pattern files after eighteen entries… ask again when there are ten."* It
was answered on the same day, by the ruling recorded three sections above it in
the same file, and there are nine. Struck, and recorded under "Closed rather
than accepted" with the reason and the entry that answered it.

### The byte figure, corrected forward

**`0030` and `0031` both report the always-loaded tier as 18,546 bytes. It is
18,869.** That is what `tests/Instructions.Tests.ps1` computes and what
`docs/constraints.md` has said all along. `CLAUDE.md` has not changed since
before `0030`, so the figure was wrong when `0030` wrote it and `0031` — mine —
carried it forward without measuring. `0032` measured and reported it; this is
the correction naming both entries, since the ledger is append-only and the
entries cannot be edited.

Nothing was at risk: the ceiling is 19,000 and the true figure is under it
either way. What was wrong was the record, for two entries, in the field whose
whole job is to be the record.

### What was measured and what was only read

`docs/constraints.md` gains a section marking it. **Nineteen constraints: nine
re-measured against a value in the paragraph, ten re-read.**

`0032` said *four of twenty*. That was wrong too, and undercounted its own work —
nine paragraphs were measured, not four. The corrected split is in the file.

The one worth naming is `0024-t2`, which sits in the **re-read** group. It
carries more numbers than any other constraint here — 517 files, 28 and 57
redactions, six counts of what survived a pass — and it is the constraint that
forbids publishing the corpus. None of those numbers has been re-measured since
the day they were taken, because re-measuring means re-running the redactor,
which is not a reading.

## What I learned

**A file written to be trusted without re-reading needs something that re-reads
it.** Every defect fixed here was invisible for eight entries, and none of them
was subtle: a statistic off by half, an id in two places, a paragraph answered by
another paragraph three sections above it. The front matter caught none of them
because the front matter cannot see prose, and the prose caught none because
nobody read it. That is the cost of the move that made this file worth having.

**The correction did not need a new mechanism, it needed the existing verb.**
The first instinct on finding `0024-t1` in two homes was that the vocabulary was
short one word. It was not: `accepts_threads` had meant this since `0019`
invented it. Reaching for a fifth verb would have added machinery to cover a
habit, and the habit is that the entry which writes a constraint has to also
retire the thread, in the same front matter, in the same pass.

**Reporting a defect one layer shallower than it is makes the fix wrong.**
`0032` called `0004-t1` and `0007-t2` *retired twice* and stopped. Had that been
acted on directly, the fix would have been to delete one of the two retirements.
The actual defect is that `0024` recovered two threads that were never lost, on
a premise about `0020` that is false — and the fix is a ruling about which verb
each takes, plus the observation that `recovers_threads` is unchecked.

## What I could not verify

**Who could check the corrected statistic, and how long it would take.** The
prompt's own candidate, and it lands: the number that was wrong and the number
that replaces it were computed by the same session, in the same pass, from the
same script, and it now sits in a file whose stated purpose is to be trusted
without re-reading. It has exactly the standing the false one had.

What makes it checkable is that it is derived from front matter and nothing
else. **Anyone with the repository can recompute it: read `closes`,
`accepts_threads` and `supersedes_threads` from each of `knowledge/ledger/*.md`,
subtract the four-digit entry id from the thread's own prefix, and count.** That
is about fifteen lines in any language and a few minutes for someone who has
never seen this project — no build, no module import, no PowerShell. The value
is arithmetic over data that is already in the repository, which is the only
property that distinguishes it from the claim it replaces. **It has not been
independently recomputed, and until it is, it is one session's arithmetic
repeated with more decimals.**

**Whether the two-basis presentation is fair or is fitting the frame to the
answer.** I report "as recorded" and "excluding the `0019` sweep" and lead the
argument with the second, because the sweep is a different kind of act. That is
a judgement about what counts as an event, made by the party who wanted the
argument to survive. The raw figure is in the same table and contradicts the old
claim on its own, so a reader can decline the framing — but I chose the framing.

**Whether a gate should catch a thread retired twice, and I say it should not be
built now.** It is expressible: track retired ids and validate that a
`recovers_threads` entry names something the accounting actually lost. But there
is **one incident** — `0024`, taking both threads in a single act — and this
project's own rule is that one instance does not ground a generalisation. Worse,
the instance is in an append-only record, so the gate would be red on history
forever or start at the entry after its only counterexample, which is a gate
with no evidence it works. The mechanism is written down here so the second
instance is cheap to catch. `0033-t3`.

**Whether `0007-t2` is genuinely an acceptance.** I ruled it so from the
schema's own wording, against `0024` having put it in `closes`. `0024`'s author
thought it was a closure. Two readings of one entry, and I have preferred mine
because the constraint paragraph exists and constraints are where acceptances
live — which is an argument from where the prose ended up rather than from what
was decided.

**That striking `0004-t1` is the only strike owed.** I struck it because the
prompt named it. `0007-t2` resolved to accepted, so its paragraph stands
correctly. I did not re-examine the other seventeen for the same defect, and the
audit that found this one was looking for it.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No, and the
candidate was refused twice over.** *Retirement verb* is already modelled, as
four front-matter arrays, and the finding was that one of the four was going
unused rather than that a fifth was missing. Nothing to classify.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. The store gained no
subjects and no assignments. `pattern:` remains at nine subjects and zero
assignments, unchanged by `0024-t1` leaving the thread list — the exclusion is a
fact about the grader, not about where the thread is filed.

### Prune, this iteration

`instruction-prune` invoked. **A move: none. A deletion proposal: none.**
`CLAUDE.md` was not edited. Nothing this iteration produced belongs in the
always-loaded tier: it is all corrections to on-demand files, which is the tier
split working.

### Always-loaded bytes

**18,869 / 19,000.** Measured, not carried. One file, `CLAUDE.md`, unchanged
since before `0030` — see the correction above.

## Open threads

1. **[0033-t1] The corrected statistic has the standing the wrong one had.**
   Same session, same pass, same script, and it now sits in the file that exists
   to be trusted without re-reading. It is recomputable from front matter in
   about fifteen lines by anyone with the repository and no build, which is what
   makes it different in kind from the claim it replaces — and nobody has done
   that. Closing this means somebody else's arithmetic agreeing, once.
2. **[0033-t2] `recovers_threads` is unchecked.** `LedgerContinuity` adds a
   recovered id back to the open set without asking whether it was ever lost.
   `0024` used it on two threads that had been properly retired, which is how
   both came to be retired twice. The gate builds the lost set already, in
   `$lostAt`, so the comparison exists a few lines from where it would go.
3. **[0033-t3] One incident is not enough to gate double retirement.** The
   mechanism is stated in this entry. It is not built, because the only instance
   is unrewritable and a gate starting after its own counterexample cannot show
   it works. The next instance is what grounds it, and the cost of waiting is
   that the next instance happens.

Carried: **[0032-t1]** nothing recomputes the statistic — *partially answered
here and deliberately still open, because a recomputation that happens once is
not a mechanism*; **[0032-t2]** three paragraphs disagree with the front matter —
*the three named are resolved; the thread stays for the seventeen not examined*;
**[0032-t3]** most constraints were audited by reading — *now marked in the
file, which makes it visible rather than fixed*; **[0032-t4]** `0024-t1` in two
homes — *retired here, and the thread stays only until the next entry confirms
the continuity gate agrees*; **[0031-t2]**, **[0031-t3]**, **[0031-t4]**,
**[0030-t1]**, **[0030-t3]**, **[0029-t2]**, **[0029-t3]**, **[0028-t2]**,
**[0028-t3]**, **[0027-t1]**, **[0027-t3]**, **[0026-t1]**, **[0026-t2]**,
**[0025-t1]**, **[0025-t3]**, **[0024-t2]**, **[0024-t3]**, **[0023-t1]**,
**[0023-t2]**, **[0023-t3]**, **[0023-t4]**, **[0023-t5]**, **[0022-t4]**,
**[0022-t5]**, **[0021-t1]**, **[0020-t1]**, **[0019-t1]**, **[0019-t2]**,
**[0019-t3]**, **[0018-t1]**, **[0018-t2]**, **[0018-t3]**, **[0015-t1]**,
**[0014-t2]**, **[0014-t3]**, **[0013-t2]**, **[0012-t2]**, **[0012-t3]**,
**[0012-t4]**, **[0010-t2]**, **[0009-t3]**, **[0008-t2]**, **[0008-t3]**,
**[0006-t1]**, **[0005-t1]**, **[0003-t1]**, **[0003-t2]**, **[0001-t7]**.

Accepted: **[0024-t1]** the `facet-health` exclusion, retired from the thread
list into `docs/constraints.md`, where it has been written down since `0024` and
where its own paragraph said it deliberately lived. Nine carries. No verb was
missing; the verb was never used.

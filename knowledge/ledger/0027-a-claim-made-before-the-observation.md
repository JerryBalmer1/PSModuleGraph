---
id: "0027"
tag: v0.17.3
date: 2026-08-27
prompt_intent: Write the predictions down as data before the next pass ingests anything, because roles assigned after seeing the numbers are fitting rather than hypothesis. Make Measure-CorpusDrift report the series against those predictions and say when a control moved, without building a gate whose correct state nobody knows. Then bound 0026-t1 by measuring how much of the corpus a piped command could have silently misclassified.
personas: [skeptic, integrator]
open_threads: [0027-t1, 0027-t2, 0027-t3]
closes: [0026-t3]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3, 0025-t1, 0025-t3, 0026-t1, 0026-t2]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0027 — a claim made before the observation

## What changed

**`corpus/analysis/predictions.json`, written before anything new was ingested.**
A direction for each of the twelve classified terms, stated from the role rather
than the last number, plus three aggregate claims with explicit falsifiers, plus
a declared `baselinePass` and `testedByPass`. Where the role and the last
observation disagree the role is what is predicted, and the file says so: it
predicts `pattern` will fall, when the sensitivity test below had it *rising*
by two.

**An unclassified cohort, and it is the only genuinely independent test here.**
Eleven terms selected by a mechanical rule — the term at every rank that is an
exact multiple of 100 in the `v0.17.0` ranking. `looks`, `show`, `menu`,
`callers`, `required`, `analyzer`, `proposes next`, `prior`, `action copy`,
`fixes`, `judgement call`. The first output of the rule was taken and not
adjusted. Nobody labelled them, so aggregate claim `A2` — that they behave like
the controls rather than like the subjects — is the claim that can embarrass the
whole design.

**`Measure-CorpusDrift` scores against predictions and says when a control
moved.** `-Prediction`, `-Baseline`, `-BaselinePass`. Points gain
`PreviousLift`, `Delta`, `Outcome`, `Agrees`, `ControlMoved`. It emits a
warning naming every control that moved and **returns**. Six more tests,
fifteen on the command.

**`0026-t3` is closed by ruling narrower than a gate**, and the condition that
would license one is in `docs/constraints.md` as four numbered clauses.

## What I learned

**The pipe rate is large and the misclassification it can cause is small, and
those are not the same number.** Three measurements, each tightening the one
before:

| bound | count | of |
| --- | --- | --- |
| tool calls whose full command contains a pipe | **682** | 1,357 (50.3%) |
| ...that the ingested `input_summary` can see | 470 | 1,357 (34.6%) |
| background episodes containing any piped call | **17** | 23 (73.9%) |
| piped calls that reported success **and printed a failure marker** | **10** | 627 |
| background episodes containing one of those | **1** | 23 (4.3%) |

The hard upper bound is 73.9% of background episodes and it is useless — it
counts every episode where a pipe was present at all. Narrowing to piped calls
that reported success *and* whose output carries a failure phrase gives 10 calls
out of 1,357, against a false-positive floor of 1 in 656 unpiped successful
calls measured the same way. Seven of the ten land in episodes already
foreground and cannot change anything. **One background episode of 47 could be
misclassified.**

**The `input_summary` sees two thirds of the pipes.** 470 against 682, because
the summary is the first string property truncated to 300 characters. Anyone
bounding this from the ingested corpus rather than the raw transcripts would
have under-reported by a third.

**And then the small number turned out to matter anyway.** Reclassifying that
one episode and re-scoring: **3 of 12 classified watchlist terms move.**
`pattern` +2, `gate` +2, `background` from absent to 3, and the ranking grows
from 1,121 terms to 1,290 because a foreground episode contributes laps to
everything in it. `heredoc`'s Lift held at 7 but its rank moved 98 to 164.

**So the instrument is more sensitive than the effect it measured.** A
one-point Lift move is inside the range a single misclassified episode
produces, which means `heredoc` 7 to 6 and `pattern` 5 to 4 from `0025` are
**directional evidence and not measurements**. That is the finding this
iteration was asked to produce and it goes the uncomfortable way. It is written
into `predictions.json` as an explicit low weight on per-term agreement, into
`docs/constraints.md` as the fourth licensing clause, and it is why the
aggregate claims exist at all.

**One control moved under the worst case, and one control moved for real.**
`gate` moves by two under the reclassification, and `schema` rose by one
between the two real populations. The design says a moving control means every
subject reading in that pass must be re-derived rather than continued. `schema`
rising was cited in `0026` as the *strongest* evidence the drift is specific;
under this iteration's own rule it is equally a control that moved, and both
readings are available from the same number. I did not resolve that.

**The unclassified cohort already behaves like the controls, retrospectively.**
Across the two existing populations: nine of eleven held their Lift exactly,
`proposes next` rose by one, `prior` fell by one. Median delta zero, the same as
the controls. **This is not the test** — it is the same retrospective data the
roles were fitted to, and the cohort was selected from the `v0.17.0` ranking
rather than independently of it. It is weak supporting evidence that the
category is real, and it is recorded as weak.

**The first dry run of the scoring path read 8 of 12 against the wrong
baseline.** `predictions.json` declares `baselinePass: v0.17.1` and I scored it
against `v0.17.0`. The table looked entirely reasonable. The command now warns
when the declared baseline and the supplied one differ, and there is a test for
it — found by reading a plausible output rather than by anything failing, which
is the same way the `$seen.Values` collapse was found.

## What I could not verify

**That predictions written by the session that assigned the roles are worth
much.** They are the same reasoning that produced the labels, so agreement next
pass confirms internal consistency and little else. The unclassified cohort is
the answer to that and it is a partial one: the cohort was drawn from a ranking
I had already seen, by a rule I chose, at a spacing I chose. A genuinely
independent test would draw terms from a population selected before any of this
existed, and none does.

**That the failure-marker heuristic finds hidden failures rather than prose
about failures.** Its false-positive floor is 1 in 656, but at least two of the
ten hits are output from commands that were *grepping build logs for errors* —
the marker is present because I was searching for it. I did not classify all ten
by hand, so the true count is somewhere at or below 10 and I am reporting the
ceiling.

**That one episode is the worst case rather than a worst case.** I flipped the
single background episode the heuristic implicates. I did not test flipping two,
or flipping a different one, or the reverse direction — a foreground episode
that should have been background, which the mechanism cannot produce but a
different defect could.

**That aggregate claim `A3` is falsifiable at a useful rate.** It permits one
control of six to move by more than one point. With six controls and a measured
single-episode sensitivity that already moves one of them by two, `A3` may be
satisfied by an instrument that is telling us nothing. I chose the threshold to
match the measured sensitivity rather than to be demanding, and a threshold set
to what the instrument can currently do is not much of a test.

**That the licensing condition in `constraints.md` can be checked without
re-deriving it.** Clause 4 requires re-running a single-episode reclassification
and counting moved terms. That procedure exists only as a scratch script and a
paragraph in this entry. Nothing in the repository performs it, so the condition
is checkable in principle and manual in practice.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No.** The
candidate is *prediction status* — predicted, unpredicted, scored, unscored —
and it classifies rows in a JSONL series, which are not subjects: a row's
identity is its position in a pass over a population. `NAMING.md`'s criterion
refuses it for the same reason it refused claims, and this is the second
consecutive iteration where that criterion answered a question without a debate.

**2. Is an existing facet doing two jobs?** No. No facet was read or written.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. Recorded: the roles in
`watchlist.json` are a classification with an unclassified control group, which
is the first time anything in this project has held out a population to test
whether its own categories are real. `facet-health` has no such cohort, and
`0003-t1` is exactly the complaint that would surface if it did.

### Prune, this iteration

A move: none. Nothing entered the always-loaded tier. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged. Predictions, watchlist and the licensing
condition are all on-demand.

## Open threads

1. **[0027-t1] The instrument is more sensitive than the effect it measures.**
   One misclassified background episode of 47 moves three of twelve watchlist
   terms by up to two Lift points, so a one-point move is noise. Every reading
   in `ledger/0025` and `ledger/0026` is directional evidence at best. The fix
   is not a better classifier — it is a larger population, because sensitivity
   to one episode falls as episodes accumulate. Nothing should be built on a
   single-point Lift move until clause 4 of the licensing condition in
   `docs/constraints.md` is met.
2. **[0027-t2] `schema` rising is cited as evidence for two opposite readings.**
   `0026` cited it as the strongest sign the drift is specific; `0027`'s own
   rule says a control that moves invalidates the pass. Both follow from the
   same number and the design does not say which wins. The honest resolutions
   are to demote `schema` from control, to widen what control permits, or to
   accept that `v0.17.1` is a pass whose subject readings cannot be continued —
   and all three are decisions rather than edits.
3. **[0027-t3] Clause 4 of the gate condition has no implementation.** It
   requires reclassifying one background episode and counting moved terms.
   That was done once, in a scratch script, and the number in
   `docs/constraints.md` is a claim about a procedure nobody can re-run without
   rewriting it. A condition that cannot be checked cheaply will be checked once
   and then assumed, which is `0017`'s shape.

Carried: **[0026-t1]** the foreground classifier depends on a signal the tooling
can silently destroy — **now bounded: at most 1 background episode of 47, from
682 piped calls, and the bound matters because the instrument is sensitive at
that granularity**; **[0026-t2]** one series file holds points from two
populations; **[0025-t1]** whether a second error signal is worth having — the
measurement it asks for is now half done, 10 candidates identified of 74;
**[0025-t3]** the corpus is 1.1% third-party and nothing enforces it;
**[0024-t1]**, **[0024-t2]**, **[0024-t3]**, **[0023-t1]**, **[0023-t2]**,
**[0023-t3]**, **[0023-t4]**, **[0023-t5]**, **[0022-t4]**, **[0022-t5]**,
**[0021-t1]**, **[0020-t1]**, **[0019-t1]**, **[0019-t2]**, **[0019-t3]**,
**[0018-t1]**, **[0018-t2]**, **[0018-t3]**, **[0015-t1]**, **[0014-t2]**,
**[0014-t3]**, **[0013-t2]**, **[0012-t2]**, **[0012-t3]**, **[0012-t4]**,
**[0010-t2]**, **[0009-t3]**, **[0008-t2]**, **[0008-t3]**, **[0006-t1]**,
**[0005-t1]**, **[0003-t1]**, **[0003-t2]**, **[0001-t7]**.

Closed: **[0026-t3]**. Ruled narrower than a gate. The reporting exists, the
warning names the control, and the condition that would license failing on it is
four clauses with numbers — of which clause 4 fails today and says so.

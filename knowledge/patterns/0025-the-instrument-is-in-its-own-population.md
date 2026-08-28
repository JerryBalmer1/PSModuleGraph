---
ledger: "0025"
tag: v0.17.1
scales: [recurrence finder over the session that runs it, facet-health grading the facets it is one of]
confidence: 0.6
supersedes: []
---

# The instrument is in its own population, and it moves what it measures

## The pattern

An instrument that measures a population **its own operation joins** does not
merely have a blind spot. It biases the result, and **the direction of the bias
is not predictable from the mechanism** — it is set by whatever the act of
measuring happens to look like in the units being counted.

There are two halves and the second is the one that surprises.

**The blind spot is structural and permanent.** A measurement over a record of
work cannot include the occasion of its own measurement, because that record is
still being written when the measurement runs. This is not a gap to be closed by
running again later — the *next* run has the same hole in the same place. Every
run of such an instrument is missing exactly one occasion: its own.

**The bias arrives afterwards, when the occasion is finally included, and it
points in whichever direction the measuring looked.** Measuring is an activity
with a texture. It produces reading, discussion, restatement and reporting; it
produces comparatively little of whatever the instrument treats as *evidence*.
So when the measuring session is ingested, it lands almost entirely in whichever
bucket "talking about it" falls into — and every term the measurement was about
moves.

## Where it was seen

**The recurrence finder, over the session that ran it, v0.17.1.** Measured, not
argued. The heredoc trap fired twice during the iteration that measured the
heredoc trap. Adding that iteration's transcript to the corpus and re-running
the finder unchanged:

| | laps | occurrences | background | Lift | rank |
| --- | --- | --- | --- | --- | --- |
| three sessions, the measuring one absent | 7 | 13 | 0 | **7** | 98 of 1,121 |
| four sessions, the measuring one present | 8 | 20 | **2** | **6** | 148 of 1,198 |

**Adding the session in which the trap fired twice made the trap score worse.**
Laps rose by one and occurrences by seven, and the term still fell fifty places,
because background rose from zero to two and Lift is foreground minus
background.

The two background episodes are the operator's instruction *naming the trap and
asking for its score*, and the reply *reporting the score*. Neither episode
failed a tool call, so neither is foreground; the finder correctly classified
them as domain vocabulary and subtracted them. **The discrimination worked
exactly as designed and the cost of it working was the signal.** Asking for the
measurement lowered the measurement.

Of that session's four episodes, one was foreground and carried ten mentions —
the real incidents. Three mentions sat in two background episodes that were
entirely talk. That ratio is what a measurement session is: mostly talk.

**`facet-health`, grading the facets it is itself one of.** `0003-t1` records
that it grades itself flatteringly. Same structure — an instrument inside its
own population — and the bias runs **the other way**: a facet maintained by the
person writing the grader looks well covered, so the score goes up. The
mechanism is identical and the sign is opposite, which is the whole reason this
cannot be reasoned around. `pattern:` subjects are excluded from facet-health in
`docs/constraints.md` for this reason, and that exclusion is the answer to not
knowing the sign rather than an answer to the question.

## Handoff

**Do not try to predict the direction of the bias. You will get it wrong.** Both
scales above are the same mechanism and they point opposite ways, and in each
case the intuitive answer was the wrong one: the finder "should" have scored the
trap higher after ingesting a session where it fired twice, and it scored lower.
Measure the direction or exclude the population; there is no third move, and
reasoning from the mechanism is the trap rather than the escape.

**Report the run that excludes your own occasion alongside the one that
includes it.** Two numbers, always, and say which is which. One number from an
instrument standing in its own population is not a measurement, and you cannot
tell from the number which way it moved.

**Expect this to get worse rather than settle.** Once measurement sessions are in
the corpus, every later run counts prior measurement sessions as evidence, and
nothing in a lexical finder distinguishes a term recurring because the work keeps
hitting it from one recurring because the measurement keeps discussing it. The
background subtraction is the only thing standing between those two today, it
was not designed for this, and it happens to be load-bearing for it. That is
`0025-t2`, and if you are reading this because a recurrence number moved and
nobody changed the code, this is the first thing to check.

The related failure, pointing the other way, is
[[0025-a-record-counts-conclusions-not-incidents]]. That one says the transcript
is the better population; this one says the transcript is contaminated by
whoever went looking. **Both are true, and the order matters: change the
population first, then discount for your own presence in it.**

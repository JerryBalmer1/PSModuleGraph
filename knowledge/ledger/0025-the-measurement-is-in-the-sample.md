---
id: "0025"
tag: v0.17.1
date: 2026-08-27
prompt_intent: Put this iteration's own transcript into the corpus and re-run the finder over it, because the heredoc trap fired twice during the pass that measured the heredoc trap and neither incident was in the sample. Then make the shipped importer capture the error signal the measurement had to recover by hand, and argue - with a number - whether the corpus needs third-party source in it at all.
personas: [skeptic, integrator, taxonomist]
open_threads: [0025-t1, 0025-t2, 0025-t3]
closes: []
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0025 — the measurement is in the sample

## What changed

**`Import-CorpusTranscript` populates `IsError` and `ResultChars`.** They were
assigned `$null` unconditionally, so the clause in
`corpus/docker/init/01-schema.sql` — *tool results are measured, never stored* —
described an intention rather than the code. A result is always in a later line
than the `tool_use` it answers, so a single forward pass cannot resolve one
against the other; results are now collected by `tool_use_id` and applied to the
file's own calls once the file is read. Over the three sessions the previous
entry measured: **1,357 tool calls, 1,357 matched to a result, 74 `IsError`
true** — the same 74 the hand re-parse found. A call whose result never arrived
keeps `$null`, which is the common case at the tail of a live transcript rather
than a malformation.

**There was no test for `Import-CorpusTranscript` at all, and that is why the
defect lived.** Six now, over a fixture whose `tool_result` blocks are
deliberately in later lines than their calls, so a forward-pass implementation
fails them.

**This iteration's own transcript is in the corpus and the finder was re-run over
it.** Numbers below.

**Two patterns**, and therefore two new subjects:
`pattern:0025-a-record-counts-conclusions-not-incidents` and
`pattern:0025-the-instrument-is-in-its-own-population`. Eight pattern records,
eight subjects.

**The publication constraint is narrowed rather than lifted**, on a measurement,
in `docs/constraints.md`.

## What I learned

**Adding the session in which the trap fired twice made the trap score worse.**
The finder, unchanged, over the same episode construction:

| | laps | occurrences | background | Lift | rank |
| --- | --- | --- | --- | --- | --- |
| three sessions, this one absent | 7 | 13 | 0 | **7** | 98 of 1,121 |
| four sessions, this one present | 8 | 20 | **2** | **6** | 148 of 1,198 |

Laps rose by one, occurrences by seven, and the term fell fifty places. Lift is
foreground minus background, and background went from zero to two.

Of this session's four episodes, one was foreground and carried ten mentions —
the real incidents. The two background episodes are **the instruction naming the
trap and asking for its score**, and **the reply reporting the score**. Neither
failed a tool call, so neither is foreground, and the finder subtracted them as
domain vocabulary. The discrimination worked exactly as designed and the price
of it working was the signal. **Asking for the measurement lowered the
measurement.**

**The structural half is stronger than the measured half and was stated first by
the operator.** A recurrence measurement can never include its own occasion: the
transcript of the measuring session is still being written while the measurement
runs. That is not a gap a later run closes — the later run has the same hole in
the same place, one occasion wide. What the numbers add is the *direction*: when
the occasion is eventually included it moves the score **down**, because a
measurement session produces mostly talk and talk lands in background.

**The direction is not predictable from the mechanism.** `facet-health` is the
same shape — an instrument inside its own population — and `0003-t1` records it
grading itself *flatteringly*, upward. Identical mechanism, opposite sign. Both
intuitions were wrong in their own case, which is the argument for measuring the
direction or excluding the population rather than reasoning about it. This is
the second scale that made `0025-the-instrument-is-in-its-own-population`
recordable, and it is directly load-bearing for `0024-t1`.

**The measurement that falsified the earlier claim did not come from the shipped
code path.** `Measure-CorpusRecurrence` returned Lift 7 for a term the module's
own docstring said scored nothing, and the foreground that produced it was built
by re-parsing the raw JSONL in a scratch script, because
`Import-CorpusTranscript` was returning `$null` for every error. **The corpus
could not have produced its own correction.** It can now, and the re-run above
reproduced rank 98 exactly through the shipped path before anything was added to
it — which is the only reason the 98-to-148 move can be attributed to the new
session rather than to the fix.

**Two of this iteration's own error signals were invisible for a third reason.**
The `\\`-collapse incidents produced a PowerShell exception, but the command was
piped through `tail`, so the pipeline exited 0 and no `is_error` was recorded.
The episode was foreground anyway, on a different failure. Fixing the importer
does not fix this: **the foreground signal depends on how a command was
invoked**, and a shell pipeline can hide a failure from the corpus without
hiding it from the person watching.

**The corpus contains no third-party source, and the ingester is already why.**
Measured over 2,060 turns and 1,485 tool calls in four sessions. Six literals
that exist only inside the vendored gallery sources appear **zero** times in the
corpus while present on disk — `Add-ConditionalFormatting` 35 to 0,
`Write-VcsStatus` 10 to 0, `Get-GitDirectory` 7 to 0. Twenty-two turns of 2,060
(1.1%) name a gallery module at all, and they are almost all *user* turns using
a public package name in a sentence. File contents reach a session as a **tool
result**, and tool results are the one thing the importer never stores.

## What I could not verify

**That the 98-to-148 move is the property rather than the sample.** One session
was added to three. Four sessions is not a population, and a single background
episode either way would have moved Lift by one. The direction agrees with the
argument, and a direction that agrees with an argument on a sample of one is the
weakest evidence that still counts as evidence.

**That the episode boundary is not doing the work.** An episode is one user
message and everything until the next. My two background episodes are background
because the operator's message that opened them named the trap and no tool
failed before the next message. A different boundary — per turn, per tool call,
per hour — would put those mentions somewhere else and could reverse the sign. I
did not test one.

**That six literals is a search rather than a confirmation.** I chose them
knowing what the modules contain. A literal I did not think of is exactly the
one that would be in the corpus, and the probe cannot find what it did not list.
Zero across six is consistent with zero across all, and it does not establish
it.

**That `IsError` is now right rather than merely populated.** It reproduces the
74 the hand re-parse found, but both readings share my interpretation of the
format: that a `tool_result` block with `is_error` true is the failure of the
`tool_use` naming its `tool_use_id`. Nothing independent confirms that mapping,
and the six new tests assert it against a fixture I wrote to that same
understanding.

**That the two patterns are two.** They could be one pattern about choosing a
population, with the self-observation half as a corollary. I split them because
they point in opposite directions and the second undoes the first if read alone,
and I have no evidence that a future reader will find that split natural rather
than confusing.

**That `pattern:` subjects being generated from files I wrote this pass is not
the thing `0024-t1` warns about.** Two of the eight pattern subjects were
written and then classified in the same iteration. Nothing grades them, so
nothing is flattered, but the shape `0004-t1` was originally declined under is
present again and I did not stop on it.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No, and the
near-miss is worth naming.** The candidate is *observation posture* — whether a
record is an incident, a conclusion, or a report about a measurement. All three
appear in the corpus and the finder's background subtraction currently separates
the third from the first by accident. It is not a facet: it classifies turns and
episodes, which are not subjects, and `0025-a-record-counts-conclusions-not-incidents`
is the right home for it until something addressable needs it. The `namespace`
facet remains proposed and untaken, per the ruling.

**2. Is an existing facet doing two jobs?** No. No facet was read or written.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable — but recorded, because
it is `0024-t1`'s own evidence: `facet-health` and `Measure-CorpusRecurrence`
are now two measured instances of one instrument-inside-its-population failure,
with opposite signs. That asymmetry was hypothetical in `0024` and is measured
here.

### Prune, this iteration

A move: none. Nothing entered the always-loaded tier. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged. Both new patterns are on-demand; the constraint
amendment is in `docs/constraints.md`, which is on-demand.

## Open threads

1. **[0025-t1] The foreground signal depends on how a command was invoked.** A
   failing command piped through `tail`, `head` or `grep` exits 0 and produces no
   `is_error`, so the corpus records no failure. Two of this iteration's own
   incidents were invisible that way and were rescued only by an unrelated
   failure in the same episode. Populating `IsError` does not touch this: the
   information was never in the transcript. Whether a second signal — a
   non-zero exit inside the result text, a known-error phrase — is worth having
   is a design question, and it should be answered by measuring how many of the
   74 would change rather than by adding a regex.
2. **[0025-t2] Every future recurrence figure counts prior measurement sessions
   as evidence.** The corpus now contains the session that measured the corpus.
   Nothing in a lexical finder distinguishes a term recurring because the work
   keeps hitting it from one recurring because the measurement keeps discussing
   it. The background subtraction is the only thing separating them today, it
   was designed for domain vocabulary rather than for this, and it is now
   load-bearing for something it was not built for. Each measurement pass makes
   the next one score the same term lower, which is a drift rather than a fixed
   blind spot, and drift is the harder of the two to notice.
3. **[0025-t3] The corpus is 1.1% third-party by turn count and nobody decided
   that.** Twenty-two turns name a gallery module. Every one measured is this
   project's own prose using a public package name, and no third-party source
   was found in any of them — but that is an observation about the sessions run
   so far, not a property the ingester enforces. A future session that pastes a
   third-party file into a prompt would put it in the corpus, and nothing would
   report it. The measurement is the answer for today and is not a mechanism.

Carried: **[0024-t1]** patterns being subjects may have relocated the
self-reference objection rather than removed it — now carrying two measured
instances with opposite signs; **[0024-t2]** the corpus has never been
independently cleared, narrowed on a measurement but not lifted; **[0024-t3]**
every hashtable keyed by English prose is one collision from the same collapse;
**[0023-t1]**, **[0023-t2]**, **[0023-t3]**, **[0023-t4]**, **[0023-t5]**,
**[0022-t4]**, **[0022-t5]**, **[0021-t1]**, **[0020-t1]**, **[0019-t1]**,
**[0019-t2]**, **[0019-t3]**, **[0018-t1]**, **[0018-t2]**, **[0018-t3]**,
**[0015-t1]**, **[0014-t2]**, **[0014-t3]**, **[0013-t2]**, **[0012-t2]**,
**[0012-t3]**, **[0012-t4]**, **[0010-t2]**, **[0009-t3]**, **[0008-t2]**,
**[0008-t3]**, **[0006-t1]**, **[0005-t1]**, **[0003-t1]** `facet-health` grades
itself flatteringly — the second scale of
`pattern:0025-the-instrument-is-in-its-own-population`; **[0003-t2]**,
**[0001-t7]**.

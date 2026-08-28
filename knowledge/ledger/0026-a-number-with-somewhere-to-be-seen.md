---
id: "0026"
tag: v0.17.2
date: 2026-08-27
prompt_intent: Stop 0025-t2 drifting by deciding it. Either exclude measurement sessions from the population or build an instrument that records the drift, argue one and implement it, name the third failure mode as its own thread without fixing it, and say what the tool-error fix does on its own now that nothing has isolated it.
personas: [skeptic, integrator]
open_threads: [0026-t1, 0026-t2, 0026-t3]
closes: [0025-t2]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5, 0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5, 0024-t1, 0024-t2, 0024-t3, 0025-t1, 0025-t3]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0026 — a number with somewhere to be seen

## What changed

**`0025-t2` is decided: the drift is measured, not excluded.** The argument is
in `docs/corpus-architecture.md` under *Decisions made and why*, append-only,
and the short form is that excluding requires the instrument to classify its own
occasions — which is the failure being described rather than a way out of it.
The mark would be self-declared by the party whose presence is the confound. At
session granularity it would have discarded the v0.17.1 session's one foreground
episode, the ten heredoc mentions that were the real incidents, while at episode
granularity it demands exactly the incident-versus-talk judgement the finder was
supposed to make lexically. Every session is part work and part measurement, so
a binary mark is a blunt instrument on a continuum — and once applied, the drift
is hidden rather than removed, which is the state twenty-seven laps say this
project does not recover from.

**`Measure-CorpusDrift`, `corpus/analysis/watchlist.json`, and an append-only
`corpus/analysis/drift-series.jsonl`.** Twelve terms in three roles, re-scored
per pass, one row per term per pass, with the population written into every row.
Nine tests. `load.ps1` computes the pass and reports it; it appends only when
asked, because writing to an append-only record is a decision rather than a side
effect of looking at one.

**The roles are the design, not decoration.** Subject and instrument terms are
expected to fall. **Controls are expected to hold, and they are what makes a
fall legible at all.**

## What I learned

**The drift is specific, and the controls prove it.** Across the two populations
already recorded in `0025`:

| term | role | Lift | rank |
| --- | --- | --- | --- |
| `heredoc` | subject | 7 → **6** | 98 → 148 |
| `pattern` | subject | 5 → **4** | 196 → 295 |
| `measurement` | instrument | 2 → **1** | 881 → 1057 |
| `corpus` | instrument | – → 1 | – → 1031 |
| `background` | instrument | – → 2 | – → 854 |
| `population` | instrument | – → 3 | – → 560 |
| `seam` | control | 11 → 11 | 6 → 9 |
| `schema` | control | 10 → **11** | 9 → 3 |
| `store` | control | 7 → 7 | 69 → 78 |
| `gate` | control | 6 → 6 | 118 → 123 |
| `ledger` | control | 8 → 8 | 40 → 45 |
| `thread` | control | 6 → 6 | 140 → 146 |

Every term the measurement was *about* fell. Every term the work is about held,
and one rose. Three instrument terms appeared from nothing, which is what the
apparatus entering its own population looks like. **This is no longer a
mechanism argued from one term — it is three falling, six holding, and one
rising in the opposite direction.**

**Rank and Lift are different measurements and it matters here.** Control ranks
all slipped a little — `store` 69 to 78, `ledger` 40 to 45 — while their Lift
held exactly, because the ranking grew from 1,121 terms to 1,198. Rank moves
with corpus size; Lift does not. Had I built the series on rank alone, the
controls would have looked like they drifted too and the specific effect would
have been buried under a uniform one.

**The tool-error fix changes nothing in the numbers, and that is the finding.**
Re-run over the same three sessions with no new session ingested, comparing the
shipped `IsError` against the hand re-parse that produced the original claim:
**74 error-marked turns both ways, zero in either direction only; 24 foreground
and 23 background episodes both ways; 1,121 terms both ways; and 0 of 1,121
terms differ in rank, Lift, laps, occurrences or background.** The two
foreground constructions — `parentUuid` of an `is_error` line, and `tool_use_id`
matched to its result — agree exactly on this corpus.

So the fix did not change what the corpus says. **It changed who could say it.**
Before it, the number that corrected this repository's own claim about lexical
recurrence could only be produced by a scratch script beside the module; after
it, the shipped path produces the identical number. A null result on the values
and a total change in provenance is the honest summary, and it is the reason the
98-to-148 move in `0025` can be attributed to the new session rather than to the
fix — the fix demonstrably moves nothing.

**`0024-t3` fired in this pass, in the script written to measure this pass.**
`$mapA.Count` on a hashtable keyed by terms from English prose returned
`@{Rank=25; Row=}` — the row for the word *count* — instead of 1,121. Found by
the output looking wrong, exactly as `$seen.Values` was. Confirmed in isolation:
a two-key hashtable with a `count` key returns the value from `.Count` and 2
from `.get_Count()`. The thread said the language has more than the three names
its test plants; this is the fourth, found by accident, in throwaway code.
`Measure-CorpusDrift` compares terms with `[System.StringComparison]::Ordinal`
and has a test that plants two watched terms differing only in case.

## What I could not verify

**That two populations are a series.** Every number in the table above is a
first difference between two points. A first difference is a direction, not a
trend, and the controls holding is the only reason I believe it is even that. It
would take a third genuinely new population to say anything about rate, and this
pass could not produce one: the only new session is the one being written now.

**That the roles are assigned correctly rather than conveniently.** I chose
`seam`, `schema`, `store`, `gate`, `ledger` and `thread` as controls **after**
seeing that they held, and `heredoc`, `pattern` and `measurement` as subjects
after seeing that they fell. That is fitting the instrument to the observation,
and the honest defence is only that the roles are argued in the watchlist and
falsifiable in the next pass — not that they were predicted.

**That `schema` rising is signal rather than noise.** It is the single strongest
piece of evidence that the drift is specific and it rests on one term moving one
point in one direction. Its rank move — 9 to 3 — is larger than its Lift move
and rank is the measurement I have just argued is confounded by corpus growth.

**That the third series point means anything.** `v0.17.2` is recorded over the
same four-session population as `v0.17.1` and reproduces it exactly. That
demonstrates the instrument is deterministic and demonstrates nothing about
drift, and a reader scanning the `lift` column will see `7, 6, 6` and may read a
plateau where there is only a re-run. The population fields say otherwise, and
they only work if someone looks at them.

**That `load.ps1`'s drift pass and the numbers in this entry measure the same
thing.** They do not. `load.ps1` scores the ledger claim population; every
number above was taken over transcript episodes by hand, with a stated
population. Both write points into the same series file if asked, distinguished
only by their `sessions` and episode fields. **That is a shape that will
eventually mislead someone**, and I logged it rather than resolving it in the
pass that created it.

**That anything notices when a control moves.** The design rests entirely on
that condition and nothing enforces it. The series records it; no gate reads it.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** **No.** The
candidate is *role* — subject, instrument, control — and it is real, but it
classifies **terms**, and a term is not a subject: its identity is its position
in a ranking over a population, which is precisely what
`knowledge/NAMING.md` refuses under *identity is a pure function of intrinsic
properties*. `watchlist.json` is the right home and a facet would be the wrong
one. This is the first time that criterion has been applied to something new
rather than to the three cases it was written for, and it answered without a
debate, which is what it was for.

**2. Is an existing facet doing two jobs?** No. No facet was read or written.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. Recorded: the drift
series is a third measurement instrument standing partly in its own population,
after `facet-health` and `Measure-CorpusRecurrence`. It differs from both in
being *designed* for that rather than discovered in it, which is the whole
argument of `0026`, and it is `0024-t1`'s third instance.

### Prune, this iteration

A move: none. Nothing entered the always-loaded tier. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged. The drift instrument is on-demand behind
`docs/corpus-architecture.md`.

## Open threads

1. **[0026-t1] The foreground classifier depends on a signal the tooling can
   silently destroy.** Two of `0025`'s own incidents produced no `is_error`
   because the failing command was piped through `tail`, so the pipeline exited
   0. **Populating `IsError` cannot help: the information was never in the
   transcript.** The corpus therefore records a clean run for work that failed,
   and it cannot tell that apart from work that succeeded. Every recurrence
   figure and every drift point inherits this, including the twelve recorded
   this pass. It is worse than the two failure modes it sits beside because
   those are properties of the corpus and this is a property of **how a command
   happened to be typed** — invisible at ingest, invisible at measurement, and
   varying between passes for reasons nothing records. Named, not fixed:
   `0025-t1` proposes measuring how many of the 74 a second signal would change
   before adding one, and that ordering still holds.
2. **[0026-t2] One series file holds points from two different populations.**
   `load.ps1` scores ledger claims; the numbers in this entry are transcript
   episodes. Both append to `drift-series.jsonl` and are distinguished only by
   their `sessions` and episode counts. A reader comparing `lift` down the
   column without reading those fields will compare two different measurements
   and get a number. The fix is probably a population field rather than a
   convention, and it is a data shape, so it is a decision rather than an edit.
3. **[0026-t3] Nothing reads the series.** The whole design rests on a control
   moving being noticed, and noticing is currently a person opening a JSONL
   file. A gate that fails when a control's Lift moves would close it, and it
   must be proved falsifiable — see `.claude/skills/gate-falsifiability` — which
   is more than this pass could do honestly, because two points cannot
   distinguish a control that moved from a control that was never stable.

Carried: **[0025-t1]** whether a second error signal is worth having, to be
answered by measuring how many of the 74 would change; **[0025-t3]** the corpus
is 1.1% third-party by turn count and nothing enforces it; **[0024-t1]** patterns
being subjects may have relocated the self-reference objection — now carrying a
third instance, this one built deliberately; **[0024-t2]** the corpus has never
been independently cleared; **[0024-t3]** every hashtable keyed by English prose
is one collision from the same collapse — **fired again this pass, on the word
`count`, in the measurement script**; **[0023-t1]**, **[0023-t2]**, **[0023-t3]**,
**[0023-t4]**, **[0023-t5]**, **[0022-t4]**, **[0022-t5]**, **[0021-t1]**,
**[0020-t1]**, **[0019-t1]**, **[0019-t2]**, **[0019-t3]**, **[0018-t1]**,
**[0018-t2]**, **[0018-t3]**, **[0015-t1]**, **[0014-t2]**, **[0014-t3]**,
**[0013-t2]**, **[0012-t2]**, **[0012-t3]**, **[0012-t4]**, **[0010-t2]**,
**[0009-t3]**, **[0008-t2]**, **[0008-t3]**, **[0006-t1]**, **[0005-t1]**,
**[0003-t1]**, **[0003-t2]**, **[0001-t7]**.

Closed: **[0025-t2]**. Decided rather than resolved — the drift is still there
and will still move every pass. What changed is that it now has somewhere to be
seen, which was the thing it did not have.

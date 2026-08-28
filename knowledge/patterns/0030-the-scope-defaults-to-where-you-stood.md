---
ledger: "0030"
tag: v0.18.2
scales: [mtime test scoped to the subtree the change was made in, coverage measured on one module and reported as the repository, golden path normalisation recorded in the directory the test runs in]
confidence: 0.6
supersedes: []
---

# A measurement's scope defaults to where you were standing

## The pattern

A measurement is written while a change is being made, and its population
defaults, without anyone choosing it, to the part of the world the author had
open: **the subtree they edited, the file they built, the directory they ran
in.** The number is then quoted with the scope dropped, and it reads as a
statement about the whole.

The measurement is not wrong. Within its population it is exact, and — this is
the part that matters — **it can fail there.** That is what separates this from
[[0017-nothing-could-have-said-otherwise]], where the mechanism had no path to
any other answer. Here the mechanism works. It is pointed at a smaller world
than the sentence it produces.

The tell is that **the scope is written down somewhere, but as an incidental.**
It appears in a config line, or in a doc paragraph explaining why line numbers
look odd, or in the name of a variable. It never appears next to the result.
Nobody hid it; nobody had reason to repeat it, because at the moment it was
written the scope and the world were the same thing.

The correction is not always to widen the measurement. Widening costs
something, and sometimes the narrow population is the right one. The defect is
more often **the missing qualifier than the missing coverage**, and a number
quoted with its population attached stops being this pattern even if nothing
else changes.

## Where it was seen

**The mtime test, scoped to the subtree the change was made in, v0.18.0.**
The claim was *a build that changes nothing writes nothing*, and it rested on
three commands reporting on themselves plus a test that read `LastWriteTimeUtc`
under `subjects/psmodule` — the subtree that had just been changed. Across the
whole store, **9 of 39 fixture records and 9 of 336 real ones moved their mtime
on every run**, all facet-health assignments, because a third generator one
directory over still deleted its records before rewriting them. Found at
v0.18.1, and not by looking: making a parameter mandatory forced every caller of
the writers to compile, and the third caller was the one nothing measured.

**Code coverage, measured on one file and reported as the repository. Live, and
not fixed at the time of writing.** `$config.CodeCoverage.Path` is
`output/PSModuleGraph.psm1` — the built module, which is what the tests import,
which is the reasonable default and was the whole repository when it was
written. `corpus/PSCorpus` is now **1,936 lines of the repository's 7,687**, has
**741 lines of its own tests that run in the same suite**, and contributes
nothing to the number. The gate prints `Line coverage: 77.97%` and throws with
*"Raise coverage"*; neither says which code. The scope is recorded in
`docs/testing.md` — in a sentence whose purpose is to explain why line numbers
refer to a generated file.

**The golden's path normalisation, recorded in the directory the test runs in,
v0.3.0 to v0.13.x.** The byte-identity golden blanks the absolute path a render
embeds. The normaliser matched `meta.moduleRoot`; the field was renamed to
`rootPath` at renderer v0.3.0, and **for six versions the normalisation was a
no-op that nothing could report**, because every re-recording had happened in
the same directory the comparison runs in, so the two paths were identical and
there was nothing to normalise. Found the first time the recording came from a
detached worktree, which a skill demanded and which nobody had done since the
extraction. Recorded in `ledger/0019`.

That third case is **also** `0017`, and both readings are true of it: `0017`
answers *why it stayed green* — the mechanism was structurally unable to say
otherwise — and this pattern answers *why the population was wrong* — every
observation came from where the author was standing. Where the two disagree is
the first two cases, which `0017` does not fit at all: those measurements could
have failed, and would have, one directory over.

## Where it was looked for and was not found

**The drift watchlist's controls.** The candidate was that the control terms
were scored against the same ranking their roles were read off, so the
population was the one the labels were fitted to. **It does not fit**, for two
reasons worth recording. The narrowing was *announced* — `watchlist.json`'s own
note says a prediction written by the session that assigned the roles "tests
internal consistency and little else" — and an unclassified cohort selected by a
mechanical rule was added to break it. And the shape is different: that is
selection on the outcome, where this is scope silently becoming claim. A
measurement whose limits are stated next to it is not this pattern however
narrow it is.

Recorded because a pattern that fits everything fits nothing, and because the
candidate came from outside and had to be tested rather than accepted.

## Handoff

**Say the population in the same sentence as the number.** Not in the config,
not in the doc that explains the mechanism — in the sentence a reader will
quote. If you cannot state it without going to look, you do not know it, and
neither will anyone reading the result.

**Ask what you did not run it over, and expect the answer to be "the part I was
not in".** The scope defaults to your working set every time, and the default is
invisible precisely because it was correct when it was set. Nothing about it
degrades except the world around it.

**Do not wait to be shown.** Two of the three cases above surfaced only because
an unrelated change forced every caller, or every recording, out of its usual
place — a compile error and a detached worktree. That is not a discovery method
you can schedule. What you can do is widen the population at the moment you are
already in the file, which is the cheapest it will ever be, or write the
qualifier if widening is not yours to decide.

And do not confuse this with
[[0025-a-record-counts-conclusions-not-incidents]]. That one is about counting a
population that records conclusions when you meant one that records incidents —
two different populations, both available, the wrong one chosen because it was
legible. This one is about a population **nobody chose at all**.

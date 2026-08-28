---
ledger: "0025"
tag: v0.17.1
scales: [recurrence finder over ledger versus transcript, tool error signal in schema versus code, ledger thread cost versus thread record, improvement backlog versus the code path it named, open thread versus the failure it was staged against]
confidence: 0.7
supersedes: []
---

# A record counts conclusions; the work counts incidents

## The pattern

A record is written **once per conclusion**. An incident happens **once per
occurrence**. Counting the record therefore measures how *memorable* something
was, not how *expensive* it was — and for the traps worth finding those two run
inverse, because the expensive ones are the ones you resolve to stop doing and
then write down a single time.

The shape is not "the documentation is wrong". Every record in the cases below
is accurate. It is that **a population was chosen without anyone noticing it was
a choice**, and the population that is easy to read is the one that has already
been summarised.

The tell is a sentence of the form *"X barely appears, so X is rare"* where the
thing counted is a record of X rather than X. The correction is never a better
method; it is a different population.

## Where it was seen

**The recurrence finder, ledger against transcript, v0.17.0.**
`Measure-CorpusRecurrence`'s own docstring recorded, as a checked limit, that
the quoted-heredoc backslash trap *"cost a round four times and reaches fewer
than two claim sections, so it scores nothing here"* — and concluded that this
was a limit of lexical recurrence, arguing for transcripts as the remedy. Run
against transcript episodes with no change to the finder, the same term scored
**Lift 7, 7 laps, 13 occurrences, background 0, rank 98 of 1,121**. The method
was never blind. It had been pointed at the population that records conclusions.
A pattern written from the docstring's reading would have been confidently wrong
about the instrument.

**The tool error signal, schema against code, v0.17.1.**
`corpus/docker/init/01-schema.sql` records the conclusion — *tool results are
measured, never stored* — and `Import-CorpusTranscript` repeated it in its own
docstring. Neither was false as a statement of intent, and neither was
implemented: `IsError` and `ResultChars` were assigned `$null` unconditionally
for **1,357 tool calls across three sessions**, while the raw transcripts held
**74** `is_error` results. The record of the decision existed in two places and
the count of the incidents existed nowhere, so the corpus reported zero failures
for a year of work that failed seventy-four times.

**A ledger thread, its record against its cost, throughout.**
A thread is written when it is opened and named once per entry that carries it.
Its *cost* is paid every lap it stays open — every session that reads the
carry list, weighs it, and moves on. `0004-t1` was opened once, carried
nineteen laps, silently dropped at `0020`, and recovered four entries later.
Counting the record says "one thread, two sentences". Counting the incidents
says "nineteen laps of attention". Nothing in the store holds the second number,
which is why a thread can go missing without the loss being felt.

**The improvement backlog, the named fix against the code path, v0.18.0.**
A scale this pattern was not written for, and the one that shows it is not only
about counting. The backlog entry said the store rewrote every record on every
build and that the fix was a skip-if-identical guard in `Write-KnowledgeRecord`.
Both halves came from the *record* of the symptom: the writer is where a write
appears in a stack trace. The incident was two functions away, in a line that
reads as housekeeping - `Update-KnowledgeStore` removed the whole owned subtree
before writing anything, so **that guard alone would never have fired.** The
entry was accurate about the defect and wrong about every part of the fix, which
is the same inversion: the place a problem is recorded is not the place it
happens.

**The same pass, twice, v0.18.1.** `0028-t1` then claimed that a write site
added without its registration would orphan a record and that **nothing would
detect it**. That was read off the test names, which are about churn and
replacement and say nothing about registration. Staged - a sixth write site,
committed to nothing, one build - it turned **four tests red**, because the
unregistered record was deleted by the same run that wrote it and the run
therefore never became idempotent. The population that was counted was tests
that *mention* the invariant. The population that mattered was tests that
*fail*. One build separated the two, and the thread had stood for a version
saying the opposite.

## Handoff

**Before you conclude that something is rare, say out loud which population you
counted and which one you meant.** Write the sentence down. If the two are not
the same string, you have found this pattern and the number you are about to
report is about the wrong thing.

You will be tempted to fix the method. Do not start there. In the case that
named this pattern the method was already correct and one parameter change —
which claims to feed it — moved a term from unranked to rank 98. Ask what
population records *incidents* rather than *conclusions*, and check whether you
already have it. Here the transcripts had been ingestible for two iterations and
nobody had pointed the finder at them.

**The specific inversion to expect:** the more expensive a trap is, the more
likely someone stopped and wrote a rule about it, and the *less* often it then
appears in the record. The traps with the highest cost-per-occurrence are the
ones your record is quietest about. That is the opposite of the intuition every
frequency ranking trades on.

And know what this pattern cannot tell you. It says the record and the work are
different populations. It does not say the work is the better one — the work
population is uncurated, is full of restatement, and has a defect of its own
that is written up in
[[0025-the-instrument-is-in-its-own-population]]. Read that one before you trust
a transcript number, because the two failures point in opposite directions and
the second will quietly undo the first.

**And staging is cheap enough that reading is not an excuse.** Two of the five
cases above are a claim about code that nobody ran: one about a guard that could
not fire, one about a test suite that would not notice. Both took a single build
to settle. If the sentence you are about to write is "nothing would catch this",
it is a prediction, and you are holding the apparatus that tests it.

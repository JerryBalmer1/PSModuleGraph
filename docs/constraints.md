# Constraints

**Things this repository has decided to live with.** Each was a real doubt, each
was raised as a ledger thread, each was ruled on, and each is here because the
answer is *"yes, and that is the trade"* rather than *"not yet"*.

This file exists because an accepted limitation that stays in the thread list is
not accepted, it is deferred — and the ledger's own measurement is that deferral
is the state nothing in this project has ever recovered from. Twenty-one of
twenty-three closures happened in the very next entry and **none has ever
happened after four carries**. A thread that will not be worked on and will not
be struck is a line item that costs a reading every iteration and buys nothing.

**Reading this is how you find out something is deliberate before proposing to
fix it.** If you think one of these is wrong, that is a proposal — raise it, do
not quietly reverse it.

Retired at **v0.15.0** unless a later entry says otherwise. The thread id is
kept so the ledger entry that argued it is still findable.

## The corpus

**Eight modules chosen by one person for what they were expected to stress.**
`0012-t1`. That is a sample selected by a hypothesis and it stays one however
many are added — a ninth module would be chosen the same way, by the same
reasoning, for the same predicted failure. What makes the corpus worth having is
not that it is representative but that **the prediction is written down before
the run**, so a wrong prediction is legible. Growing it is a separate decision
from this one.

**Nothing has been trained on the corpus.** `0008-t1`. It measures; it does not
feed anything back. That was never the claim and there is nothing to feed.

## What the goldens can say

**A golden that gets re-recorded when it fails only catches accidents.**
`0011-t2`. Once a change is decided and the golden is brought into line, the
artefact proves the document has not moved since somebody last decided it
should — which is a change detector and not an acceptance test. That is what a
golden is, and `.claude/skills/golden-recording` says so where somebody is about
to write one. The counterweight is procedural, not mechanical: **find the cause
before re-recording, and write down what the recording is a recording of.**

**One fixture proves the move.** `0009-t1`. `SampleModule` is nine nodes with
one class hierarchy and one script top level. A second, deliberately awkward
fixture would prove a second shape rather than the general case, and the
extraction it was recorded for is five versions behind us.

## The store

**The store does not fit a checkout root deeper than 95 characters.** `0022-t1`.
Measured 2026-08-27, on Windows, with `core.longpaths` unset. Qualifying every
subject id with the file it is defined in is what bought identity, and it is
also what spent the path: the longest repo-relative path in the store is **163
characters**, against a `MAX_PATH` of 260. That leaves **95 characters** for
wherever the repository sits, and `C:\__Code\PSModuleGraph` spends 23 of them.

This is not hypothetical. Checking the migration out into a worktree 121
characters deep failed with *"Filename too long"* before git had written a
single record, which is a store missing records — this migration's own version
of the defect it fixed.

`tests/Private/KnowledgeSubjectId.Tests.ps1` gates the store side at **180**
repo-relative characters, so the guarantee that survives future records is
**78** characters of checkout root, not 95. The gate names both numbers when it
fails.

Lifting it is one of two things and neither is free: `git config --system
core.longpaths true`, which is a machine setting this repository cannot ship and
must not assume; or shortening the id grammar, which is a contract change and
undoes what v0.16.0 was for. **Clone somewhere shallow.**

**`structure:external` has no assignments.** `0003-t3`. A facet path nothing
classifies is a hypothesis kept in view. Deleting it is a taxonomy change and
those are proposed, not taken; keeping it costs one line and one reading.

**Should the store hold measurements as well as classifications?** `0007-t2`. A
facet classifies and a metric measures, and the store does the first. Open as a
design question with no forcing event and no pair of subjects the current shape
cannot tell apart — which is the evidence rule saying the answer is no.

**Should patterns be subjects with URNs?** `0004-t1`. Two pattern files after
eighteen entries. URNs, facet assignment and `facet-health` grading would be
machinery for two records, and the machinery is what would then need
maintaining. Ask again when there are ten.

**Nobody has asked what a JSON consumer reads.** `0011-t1`. `-Format Json` is
shaped for the renderer because the renderer is the only consumer. When there is
a second one, its needs are a contract conversation.

## The instruction tier

**The ceiling's headroom is a guess.** `0005-t2`. It is currently 19,000 bytes
against 18,869 used. Every budget's headroom is a guess; what makes this one
work is that it ratchets down and never up, so the guess only ever gets
tighter.

**Nothing measures whether an on-demand file is ever read.** `0005-t3`. The tier
split assumes moving text down a tier reduces what a session reads, and nothing
observes a session. `0017-t2` measured it once by hand — no skill had been
invoked across five iterations — and one hand measurement is the best instrument
that exists here.

**Seven skills load into every session's listing and none has been invoked.**
`0017-t2`. Their procedures were followed correctly from memory across five
iterations, which is the *good* case; the skill is insurance against the tired
session, and `iteration-close` exists because one such session ran `git add -A`
and committed a stray file under the message `asdf`. The cost is the
description text, which is real and unbudgeted.

**A procedure written from memory records what the author remembers doing.**
`0017-t3`. Standing and unfixable: the person who just performed a thing is the
only one who can write it down and the worst-placed one to write it accurately.
The counterweight is in the shape of the artefacts — the gate proofs are a table
of four different acts rather than a paragraph averaging them, because the
paragraph is where the memory smooths.

## Closed rather than accepted

For completeness, because they read the same way in a diff and are not the same
fact. These were **struck**, not accepted — the question had already been
answered and nobody had removed the thread:

- ~~`0001-t7` — *the facet seam in the report, designed in
  `docs/html-architecture.md` and not built.*~~ **Struck at v0.15.0 and
  recovered at v0.15.1.** The reason given was that the file had left this
  repository at v0.9.0. It had not. It is here, it is tracked, and nothing
  emits `nodes[].facets`, so the thread was live the whole time. The oldest
  thread in the project, and it was nearly lost to a sentence nobody checked.
  `knowledge/ledger/0020`.
- `0015-t2` — *the page this whole sequence was for has not been looked at.* It
  has, twice, with committed screenshots — `PSGraphRender` `0008` and `0010`.
- `0001-t4` — *make the store's write path real.* `Update-KnowledgeStore` exists
  and writes. Recovered at v0.14.0 after fifteen entries of silence, purely so
  that it could be closed with a reason instead of having vanished.
- `0007-t1` — *hot and external are nearly the same colour.* A theme fact about
  a report that is now `PSGraphRender`'s `theme.psd1`. **Struck here because
  there is nothing here to fix; it needs raising there, and nothing carries it
  across.** That gap is `0011-t3` in the other repository.

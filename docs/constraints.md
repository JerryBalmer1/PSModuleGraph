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

**The drift series reports and does not fail, and here is what would license a
gate.** `0026-t3`. Ruled 2026-08-27. `Measure-CorpusDrift` warns when a control
term moves and returns; nothing turns red. That is not timidity, it is that
**two points cannot tell a control that moved from a control that was never
stable**, so a gate built today would be a gate whose correct state is unknown —
which is the shape this repository deletes rather than ships. Same split as
`threads.ps1`: it reports and does not rank, for the same reason.

**The condition, with numbers, all four required.** A gate may be built when:

1. **Five consecutive passes** are in `corpus/analysis/drift-series.jsonl`, each
   over a population at least one session larger than the last. Three exist and
   two of them share a population.
2. Across those five, **every control term's Lift stays within ±1** of its
   first recorded value. Stated as a band rather than exactness on purpose —
   see 4.
3. **At least two prediction rounds have been scored** against a baseline they
   were written for, and aggregate claim `A3` in
   `corpus/analysis/predictions.json` — *at most one control moves by more than
   one Lift point* — **held both times.** A prediction written by the session
   that assigned the roles tests internal consistency; two rounds against
   populations that did not exist when the roles were assigned tests the roles.
4. **The single-episode sensitivity is at most 1.** Reclassify one background
   episode as foreground and re-score; count the watchlist terms whose Lift
   moves. **Measured 2026-08-27: 3 of 12** — `pattern` by +2, `gate` by +2,
   `background` from absent to 3. A gate whose threshold is smaller than the
   instrument's sensitivity to one episode fires on noise, and one episode is
   the smallest thing that can be wrong.

**Condition 4 is the one that fails today and it is the important one.** It also
says something about the readings already taken: **a one-point Lift move is
inside the range a single misclassified episode produces**, so the `heredoc` 7
to 6 and `pattern` 5 to 4 in `ledger/0025` are directional evidence and not
measurements. The aggregate claims are what carry the argument, which is why
`predictions.json` weights per-term agreement low and says so in the file.

**This corpus has never been independently cleared and must not be published
until it is.** `0024-t2`. Not a thread and not a backlog item: a limit on what
may be done with the artefact, written down so it cannot become permanent by
drift.

**What was measured, 2026-08-27.** `Protect-CorpusText` was run over
`gallery/modules/` — 517 files, 12.5 million characters of eight real published
modules written by people who had never heard of this project. That is not
clearance. It is the first input the redactor was neither written against nor
tested on, which makes it worth more than the fixture, and it is still one
sample of one kind of text.

It caught what it claims to catch: **28 `<home>` replacements** and **57
`<email>`**, including a developer's home directory inside a Pester stack trace
and an author's OneDrive path in an example. Nothing it is documented to find
was missed.

It missed everything it was never asked to look for, and the quantities are the
point:

| Surviving the pass | Count | Files |
| --- | --- | --- |
| Windows absolute paths outside `Users\` | 284 (103 distinct) | 37 |
| `github.com/<account>` URLs | 355 | 114 |
| IPv4 addresses, including RFC1918 | 107 | 16 |
| UNC shares | 44 | 15 |
| GUIDs | 39 | 18 |
| `Author` / `CompanyName` manifest fields | 22 | 22 |

Eight real human and company names survived in manifest fields alone. The
surviving paths include `C:\GitHub\posh-git`, `C:\zd\` and
`C:\Backup\RSKey.snk` — a signing-key path on somebody's build machine.

**The finding is not that the redactor is weak. It is that its model is "my
machine".** Its rules are the author's home directory, the account names it was
handed, and the repository root. Every one of those is a fact about the person
running it, and none of them can see a third party's identity, because there is
no list of third parties and there cannot be one. A corpus assembled from a
working record contains other people's code, and other people's code carries
other people's paths.

`gallery/modules/` is not itself ingested — the corpus reads the ledger, the
pattern log and, when asked, transcripts. **The exposure is the transcripts**,
which quote whatever was on screen, and what was on screen includes the eight
modules above.

**The condition that lifts it.** Someone who did not write the redactor and did
not assemble the corpus reads a generated training set and says it is clean. Not
a bigger regex, not another pass, not a green test: a second person, because
every miss above was invisible to the rule that produced it and the author of a
rule is the worst reader of its blind spots. Until that has happened the corpus
may be built, queried and argued with locally, and **may not be published,
uploaded, embedded by a hosted service, or used to train anything that leaves
this machine.**

**Narrowed 2026-08-27, `0025`, on a measurement: the corpus does not contain
third-party source, and the ingester is already why.** `Import-CorpusTranscript`
keeps visible turn text, summarises a tool INPUT to its first scalar at 300
characters, and **never stores a tool result** — and a file's contents reach a
session only as a tool result. Reading `SqlServerDsc` therefore cannot put
`SqlServerDsc` into the corpus, which was designed for size and leak reasons and
turns out to answer this. Measured over all four ingested sessions, 2,060 turns
and 1,485 tool calls: six distinctive literals that exist only inside the
vendored sources appear **zero** times in the corpus while present on disk —
`Add-ConditionalFormatting` 35 on disk / 0 ingested, `Write-VcsStatus` 10 / 0,
`Get-GitDirectory` 7 / 0. Twenty-two turns of 2,060 (1.1%) name a gallery module
at all, almost all of them user turns using a public package name in a sentence.
The three third-party absolute paths quoted earlier in this document reached the
transcript exactly once, in a `tool_result`, and did not survive ingestion.

So the exposure is not "transcripts carry third-party bytes by construction".
**It is bounded to what somebody types into prose**, which is a smaller and
differently-shaped risk than a redactor can address anyway.

**What does not follow.** Excluding sessions that touched the gallery costs 4
sessions of 4 and 2,060 turns of 2,060 — every session touched it, so
session-level exclusion deletes the corpus. Turn-level exclusion costs 22 turns
carrying 138,583 of 479,791 characters, and buys nothing, because those turns
contain no third-party content to remove.

**The constraint therefore stands, and its reason changes.** It is no longer
"this may contain other people's code". It is that the redactor's misses were
all in the author's own material — real names, IPs, GUIDs, absolute paths — and
those are still there, in a record written by one person about one machine. A
second reader is still the condition. **No ingester restriction was written:
adding a source filter for a class of content that measures at zero would be
guarding a door nothing came through.** That the seam already holds is worth
knowing and is not worth code.

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

**Patterns are subjects and `facet-health` does not grade them.** `0024-t1`.
Ruled 2026-08-27 with `0004-t1`. Patterns became subjects under `pattern:`, and
they are excluded from facet-health grading until someone measures whether it
grades them flatteringly.

The reason is `0003-t1`, which records that `facet-health` grades *itself*
flatteringly. The objection `0004-t1` was originally declined under was that
*"classifying a population in the turn that creates it is what reflection
discipline exists to prevent"* — and reflection is what writes the pattern log.
Answering `0004-t1` yes does not remove that objection. **It moves it**, from
"may patterns be classified" to "may the thing reflection writes be graded by a
facet that already flatters itself", and asserting the self-reference is gone
because the namespace is new is precisely the confidently-wrong move the split
rule exists to catch.

**The mechanism today is structural, not enforced, and that is why this is
written down.** `Get-FacetHealthAssessment` infers a facet's eligible population
from the namespaces it has actually assigned into, so a namespace carrying no
assignments is invisible to grading. `Update-KnowledgePatternSubject` writes no
assignments, so `pattern:` is invisible. Nothing checks that it stays that way:
**the first assignment written against any `pattern:` subject silently makes
every pattern subject eligible**, and the number would move without anyone
deciding it should.

**The condition that lifts it.** A measurement, not an argument: grade the
`pattern:` population with `facet-health` and compare its coverage and depth
against the `psmodule:` population that no reflection pass authored. If patterns
grade materially higher, the self-reference is real and the exclusion stays with
a number attached. If they do not, the exclusion is lifted and this paragraph is
deleted. Either outcome closes it; **what is not allowed is the exclusion
quietly becoming permanent because nobody ran the comparison.**

This is recorded here rather than as an open thread deliberately. An exclusion
that lives in a thread list becomes permanent by drift; one that lives here has
to be argued with.

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

**An alias is followed once, and only once.** `0022-t3`. Ruled 2026-08-27, and
ruled a limit rather than a defect. `Resolve-KnowledgeSubject` tries the path
the id names, then scans for records claiming it as a former id, and stops. It
does not then take what it found and look *that* up.

The reason it is not a defect is that **chaining is not the fix for a second
rename.** `aliases` is a SET, not a linked list, and the store is generated -
so a subject that has been renamed twice should carry both former ids, written
by the alias builder that already knows the whole history. One hop over N
aliases is the same information as N hops, with a bounded read and no cycles.
Chained aliases turn rename history into a graph: a name renamed away and back
is a cycle, a one-to-many split whose parts are renamed again multiplies the
answer set, and neither has a reading a person can act on.

So the limit is on the resolver and **the obligation is on the writer.** The
next migration's job is to make `Get-LegacyKnowledgeSubjectId` emit every
former shape, not to teach the resolver to hop. Nothing enforces that today -
every subject in this store carries exactly one alias, so the second hop has
never been needed and the obligation has never been tested. `0023-t1`.

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

**Enforcement stops at the last function this repository owns, and below that it
is convention.** `0030-t2`. Ruled 2026-08-27, after the same question had been
asked and deferred in three consecutive entries. The store's write path has
three tiers and they are not interchangeable. **The language enforces the top:**
`-Kept` is `[Parameter(Mandatory)]` on `Write-KnowledgeRecord`, so the binder
refuses the call before any body runs, for every caller, whether or not that
caller ever runs a test. **A test enforces the middle:**
`tests/Private/KnowledgeWriteGuard.Tests.ps1` is the only thing that can see a
*bypass*, because a bypass is by definition not a call to a signature declared
here - no mandatory parameter can reach a caller that never names the parameter.
**Below that is convention:** `[System.IO.File]::WriteAllText` into `knowledge/`
is reachable from any new function and nothing here will ever make it not be.
The boundary sits at the deepest function this repository owns because that is
the deepest signature a binder can be attached to; going further means wrapping
or banning the framework, and owning a wrapper for the BCL costs more than the
defect it would prevent. The consequence to accept is that **the guarantee is
strongest against the caller trying to do the right thing and weakest against
the one who is not** - which is the correct direction, because the failure being
guarded is a generator written in a hurry, not an adversary.

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

## Publishing

**The tag gate reads the remote over the network, and tagging fails when it
cannot.** `0031`. Ruled 2026-08-27. `PreTag` asserts that the tag the *previous*
ledger entry declared is on the remote, at the commit it names here. There is no
offline expression of that question: remote-tracking refs answer from the last
fetch, and that cache would have passed on every one of the three iterations
where this actually failed. Both alternatives are worse than the cost. Skipping
when the remote is unreachable builds a gate that cannot fail in precisely the
condition it exists to detect, which is pattern `0017` and the shape this
repository deletes on sight; approximating with the cached ref builds a gate
that reports on this machine's memory of the remote rather than on the remote.
So the network call stays and the cost is stated rather than hidden: **an
iteration cannot be tagged from a machine that cannot reach the remote.** There
is deliberately no override that turns it off - `PSMODULEGRAPH_PUBLISH_REMOTE`
redirects it at another remote so it can be proven against fixtures, and cannot
disable it.

**It fails one iteration late, and that is the limit rather than an oversight.**
Publishing is the operator's and happens after the tag, so nothing inside the
repository can verify a push that has not been made yet; the previous one is the
most recent thing any gate here can see. Against the failure that produced it,
one late is what it buys: v0.18.0 and v0.18.1 were tagged and never pushed, and
this gate would have turned v0.18.1 red for v0.18.0's absence instead of letting
three iterations accumulate unpublished. `0031-t1` - that a tag can be published
onto a remote whose branch was left behind - was closed at v0.18.4 by asserting
the branch contains the tag's commit. What is left is the lateness itself, and
it does not lift.

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

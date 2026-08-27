---
id: "0018"
tag: v0.14.0
date: 2026-08-27
prompt_intent: Make the continuity gate compare an entry against every thread still open rather than against the last ones raised, recover the thread it lost, and propose a verdict on all thirty-eight open here.
personas: [archivist, skeptic]
open_threads: [0018-t1, 0018-t2, 0018-t3]
closes: [0013-t3, 0016-t3, 0017-t1]
carries_forward: [0001-t4, 0001-t7, 0003-t1, 0003-t2, 0003-t3, 0004-t1, 0004-t4, 0005-t1, 0005-t2, 0005-t3, 0006-t1, 0007-t1, 0007-t2, 0008-t1, 0008-t2, 0008-t3, 0009-t1, 0009-t3, 0010-t2, 0011-t1, 0011-t2, 0012-t1, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t1, 0014-t2, 0014-t3, 0015-t1, 0015-t2, 0016-t1, 0016-t2, 0017-t2, 0017-t3]
recovers_threads: [0001-t4]
prune_proposals: []
supersedes: []
---

# 0018 — a thread survives until something says otherwise

## What changed

**`tests/Private/LedgerContinuity.Tests.ps1` compares an entry against every
thread still open**, not against the ones the previous entry happened to raise.
The open set is carried explicitly and `carries_forward` must equal it exactly.

**Two front-matter fields**, in `knowledge/SCHEMA/ledger-entry.schema.json`:
`supersedes_threads`, for a thread a new one replaces by id, and
`recovers_threads`, for a thread that left the record without being closed and
re-enters with the gap admitted.

**[0001-t4] is recovered.** *Make the store's write path real* — opened in
`0001`, carried by `0002`, gone from `0003` onward with no trace in any body.
It is open again and **it is not continuous**: fifteen entries have no opinion
about it, and the entry that recovers it is the first thing to mention it since
`0002`.

**Three merges applied**, retiring an id in this repository whose twin lives in
`PSGraphRender`. Bookkeeping, and the only verdicts applied here.

**Thirty-eight verdicts proposed and none applied.** They are below.

**Minor.** The ledger schema gained fields and the gate changed shape.

## What I learned

**The gate was guarding the case that never happens.** It compared entry N
against `$previous.OpenThreads` — what the previous entry itself raised — so a
thread was protected for exactly one iteration and was silently droppable ever
after. Dropping a thread the turn after raising it is the mistake nobody makes.
Dropping one carried for six entries is the mistake that happened twice.

**Turning it on found the drop immediately, by name**, which is the whole
argument for a named failure over a counted one:

> thread(s) left the ledger without being closed, superseded or recovered:
> `0001-t4` (dropped by `0003`)

**A drop is judged over the whole chain, and that is a deliberate weakening.**
The alternative — fail at the entry that drops it — cannot be satisfied without
editing sealed entries, and editing a sealed entry to make a gate green is worse
than the defect. So a drop fails only if nothing later recovers it. **This costs
nothing where it matters**: a drop made today has no later entry to recover it,
so it fails today. It costs something where it does not: an entry can now drop a
thread and a much later one can quietly re-admit it, and the record will read as
if the recovery were routine. `0018-t2`.

**`recovers_threads` had to exist, and its name is the honest half.** The
alternative was letting a later entry simply carry a lost id, which the equality
check refuses on purpose — a thread appearing in `carries_forward` without ever
having been open is the same defect pointing the other way. Recovery is a
distinct verb because a recovered thread has a hole in its record and a reader
is entitled to know which.

**A pattern match is not an existence check, and this cost a break to find.**
`Should-BeLikeString "0009-t*"` **passed** on `0009-t9`, a thread that has never
existed, because a fake id of the right shape has the right shape. The mirror
test now looks the id up in the set of everything ever opened. The comment
saying so is in the test, because the next person to reach for a shape assertion
will be reading the test rather than this entry.

**Broken four ways before being trusted, each restored.** The proof belongs
here rather than in a comment, per `.claude/skills/gate-falsifiability`.

| Break | Red said |
| --- | --- |
| the real one: `recovers_threads` absent, so `0001-t4` stays lost | *`0001-t4` (dropped by `0003`)* |
| `0001-t7` removed from this entry's `carries_forward` | *`0001-t7` (dropped by `0018`)* |
| `0002-t9` added to `carries_forward` — a thread nobody opened | *carried by an entry that were not open before it: `0002-t9`*, **and** the existence mirror fired as well |
| `0001-t2` recovered without a word about it in the body | *entry 0018 supersedes or recovers `0001-t2` in its front matter and says nothing about it in its body* |

**One attempted break came back green, and that was the exercise working.**
Recovering `0003-t3` without mentioning it looked like it should fail and did
not — because the body *does* name `[0003-t3]`, in the carried list at the foot
of the entry. The check was right and the break was wrong. Finding that took one
run and would have taken an argument.
**Cross-repository merges cannot be expressed.** A thread id is `NNNN-tN` and
names no repository, so *"`0016-t3` is superseded by `PSGraphRender`'s
`0008-t4`"* has nowhere to live in the front matter. The three merges here are
recorded as closures with the survivor named in prose — which is exactly the
arrangement that lost `0002-t4` in the other repository, where the prose knew
and the machine half did not. `0018-t3`.

## The verdicts

**Proposed. None applied except the three merges.** Sorted by what a reader
wants first inside each bucket, not by id or age.

### Fix — small, clear, worth a pass

| Thread | Carried | Why |
| --- | --- | --- |
| `0004-t4` | 13 | **`iteration-close` is invocable by name and it runs `git push --follow-tags`.** The only item in either repository whose blast radius leaves the machine. Nothing has gone wrong in thirteen versions, which is not the same as it being safe. |
| `0016-t1` | 1 | `-Format Html -IncludeUnresolved` throws for any module that declares a dependency. A user-facing crash on a documented switch. |
| `0016-t2` | 1 | The error from it names `-SkipValidation`, which this command does not expose. Same pass as `0016-t1`. |
| `0013-t2` | 4 | `RequiredModules` declares a floor and the repository treats it as a pin. The gate built for this cannot catch the case that prompted it, and says so. |
| `0014-t1` | 3 | The store gives 32 definitions one subject and one wrong path. **The largest correctness defect open in either repository** — and its own iteration, not a pass. |
| `0012-t3` | 5 | Nothing validates a corpus result against the schema that describes it. |
| `0012-t2` | 5 | Two of three failure outcomes have never executed. `gate-falsifiability` says force them. |
| `0009-t3` | 8 | Nothing proves the renderer dependency is really required. A test that fails when it is absent. |
| `0010-t2` | 7 | A test scoped to a module that no longer holds what it tests still passes. |
| `0008-t3` | 9 | `corpus/` and `gallery/` are outside lint and the charter test. |
| `0008-t2` | 9 | The report's section headings are hardcoded to this repository's five. |
| `0014-t2` | 3 | The golden's name and location claim a provenance it lost. A rename and a sentence. |
| `0015-t1` | 2 | Three whole-document comparisons are skipped and need a decision either way. |
| `0005-t1` | 12 | Skill descriptions are always-loaded and unbudgeted. They are measurable; the ceiling test can count them. |
| `0003-t1` | 14 | `facet-health` grades itself flatteringly. |
| `0003-t2` | 14 | Coverage conflates "unassigned" with "inapplicable". |
| `0012-t4` | 5 | The lock has never been checked by anyone who did not write it. CI can fetch and verify. |
| `0006-t1` | 11 | The editor-link origin claim is unverified, and a README section rests on it. **Needs the machine owner to click a link** — it is a 🙋, not a build. |
| `0014-t3` | 3 | JSON and CSV describe the same graph differently. Adding a column breaks positional parsers, so this is a Fix with a version consequence. |

### Accept — a real limitation this project chooses to have

| Thread | Carried | Why it is a constraint rather than debt |
| --- | --- | --- |
| `0012-t1` | 5 | Eight modules chosen by one person for what they were expected to stress. Any corpus is a hypothesis; growing it does not stop it being one. |
| `0008-t1` | 9 | Nothing has been trained on the corpus. That was never the claim. |
| `0011-t2` | 6 | A re-recorded golden only catches accidents. That is what goldens are, and `golden-recording` now says so where it is needed. |
| `0011-t1` | 6 | Nobody has asked what a JSON consumer reads. There is no JSON consumer. |
| `0009-t1` | 8 | One fixture proves the move. A second awkward fixture would prove a second shape, not the general case. |
| `0005-t2` | 12 | The ceiling's headroom is a guess. Every budget's headroom is. |
| `0005-t3` | 12 | Nothing measures whether an on-demand file is read. `0017-t2` measured it once by hand and that is the best instrument available. |
| `0007-t2` | 10 | Should the store hold measurements? A live design question with no forcing event and no pair to name. |
| `0004-t1` | 13 | Should patterns be subjects with URNs? Two pattern files after eighteen entries. Machinery for two records. |
| `0017-t2` | 0 | Seven skills load into every listing and none has been invoked. The procedures are followed correctly from memory, which is the good case; the skill is insurance. |
| `0017-t3` | 0 | A procedure written from memory records what the author remembers. Standing, unfixable, and the reason the gate proofs are a table rather than a paragraph. |
| `0003-t3` | 14 | `structure:external` has no assignments. Deleting a facet path is a taxonomy change and this one costs nothing to keep. |

### Close — no longer true, superseded, or answered and never struck

| Thread | Carried | Why |
| --- | --- | --- |
| `0001-t7` | **16** | *The facet seam in the report, designed in `docs/html-architecture.md` and not built.* **The report left this repository at v0.9.0 and that file does not exist here.** The oldest thread in the project describes an architecture that has been gone for five versions. |
| `0015-t2` | 2 | *The page this whole sequence was for has not been looked at.* It has, twice — `PSGraphRender` `0008` and `0010`, with committed screenshots. Answered and never struck. |
| `0001-t4` | 1 | *Make the store's write path real.* `Update-KnowledgeStore` exists and writes. Recovered this iteration only so that it could be closed with a reason instead of having vanished. |
| `0007-t1` | 10 | *Hot and external are nearly the same colour.* A theme fact about a report that is now `PSGraphRender`'s `theme.psd1`. **This one needs re-raising there rather than merging** — there is no twin to merge into, and closing it here loses it. That is a decision, not bookkeeping, which is why it is proposed rather than done. |

### Merge — applied

| Retired | Survives as | Why that one |
| --- | --- | --- |
| `0013-t3` | `PSGraphRender` `0007-t1` | *An ambiguous edge is drawn like a certain one.* Closed on the producer side at v0.12.0; the drawing is the renderer's. |
| `0016-t3` | `PSGraphRender` `0008-t4` | *Nothing checks the README.* That thread already says **either** README, so it is the superset. |
| `0017-t1` | `PSGraphRender` `0010-t1` | *The skills are duplicated with nothing keeping them in sync.* The fork was taken there and the drift is theirs to watch. |

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?** No. A thread is not a
subject and `0004-t1` still says so.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No — but two *threads* did,
six times, and there is no facet involved. The merge mechanism is prose.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable.

### Prune, this iteration

A move: none. A deletion proposal: none. The verdict set contains four proposed
closures, which are not prunes — a prune is instruction text and these are
threads.

### Always-loaded bytes

**18,777 / 19,000.** Unchanged.

## What I could not verify

The Skeptic's section. It is never empty.

- **That thirty-eight verdicts proposed in one pass by whoever wrote most of the
  threads are worth reading.** The user's line, adopted, and it is the real risk
  here: reflection-proposes at a scale where getting through the list competes
  with getting it right. The ones I am least sure of are named in the response
  and in `0018-t1`; the ones I am most sure of are the four Closes, because each
  is a fact about a file rather than a judgement.
- **That the gate now catches what it claims.** It catches the two drops that
  exist and was broken twice on purpose. It has never seen a *new* drop, because
  no entry since it was written has dropped anything, and the case it is really
  for — an entry written at the end of a long session — is exactly the case
  nobody can simulate.
- **That recovering `0001-t4` recovered the right thing.** The thread's text is
  one sentence in `0001`; what "real" meant to whoever wrote it in the first
  entry this project ever had is not recoverable, and `Update-KnowledgeStore`
  satisfying it is my reading, not theirs.
- **That the three merges keep the better id.** Each survivor was chosen because
  the artefact lives in the other repository. That is a rule about files and the
  threads are about doubts, which do not always live where their files do.
- **That equality on `carries_forward` is not too strict.** It refuses a carried
  id that was never open, which is right, and it also refuses the ordinary
  typo — so the first person to fat-finger an id will get a phantom failure
  rather than a dropped one. That is the correct direction and it is untested
  against a real mistake.

## Open threads

1. **[0018-t1] Thirty-eight verdicts were proposed in one pass by the author of
   most of the threads.** Reflection proposes and the next implementation
   disposes, but the ratio is new: eighteen entries produced fifty-three threads
   and one produced thirty-eight opinions about them.
2. **[0018-t2] A drop is judged over the whole chain, so an entry can drop a
   thread and a much later one can re-admit it without the record reading as
   unusual.** The gate cannot tell an honest recovery from a cover-up, and the
   weakening was taken because the alternative was editing sealed entries.
3. **[0018-t3] A merge across repositories has no id grammar.** `NNNN-tN` names
   no repository, so the three applied here are closures with the survivor named
   in prose — the same arrangement in which `0002-t4` was lost.

Carried: **[0001-t4]** make the store's write path real — recovered, not
continuous, and proposed for closure; **[0001-t7]** the facet seam in the
report; **[0003-t1]** `facet-health` grades itself flatteringly; **[0003-t2]**
coverage conflates unassigned with inapplicable; **[0003-t3]**
`structure:external` has no assignments; **[0004-t1]** should patterns be
subjects; **[0004-t4]** `iteration-close` is model-invocable and it pushes;
**[0005-t1]** skill descriptions are unbudgeted; **[0005-t2]** the ceiling's
headroom is a guess; **[0005-t3]** nothing measures whether an on-demand file is
read; **[0006-t1]** the origin claim is unverified; **[0007-t1]** hot and
external are nearly the same colour; **[0007-t2]** should the store hold
measurements; **[0008-t1]** nothing has been trained on the corpus;
**[0008-t2]** the section headings are hardcoded; **[0008-t3]** `corpus/` is
outside lint and the charter test; **[0009-t1]** one fixture proves the move;
**[0009-t3]** nothing proves the dependency is really required; **[0010-t2]** a
test scoped to a module that no longer holds what it tests still passes;
**[0011-t1]** nobody has asked what a JSON consumer reads; **[0011-t2]** a
re-recorded golden only catches accidents; **[0012-t1]** the corpus is a
hypothesis with eight instances; **[0012-t2]** two failure outcomes have never
executed; **[0012-t3]** nothing validates a result against its schema;
**[0012-t4]** the lock has only been checked by the session that wrote it;
**[0013-t2]** the renderer requirement is a floor treated as a pin;
**[0014-t1]** the store gives 32 definitions one subject and one wrong path;
**[0014-t2]** the golden's name claims a provenance it lost; **[0014-t3]** JSON
and CSV describe the same graph differently; **[0015-t1]** three whole-document
comparisons are skipped; **[0015-t2]** the page has not been looked at —
answered elsewhere and proposed for closure; **[0016-t1]** `-IncludeUnresolved`
cannot render a module that declares a dependency; **[0016-t2]** an error names
a parameter the command does not have; **[0017-t2]** seven skills and none
invoked; **[0017-t3]** a procedure written from memory.

Closed: **[0013-t3]**, **[0016-t3]** and **[0017-t1]**, all merged rather than
answered — each survives under a `PSGraphRender` id named in the table above.

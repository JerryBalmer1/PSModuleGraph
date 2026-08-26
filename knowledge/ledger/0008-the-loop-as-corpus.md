---
id: "0008"
tag: v0.6.0
date: 2026-08-26
prompt_intent: Stand up a database and a PowerShell module that read the back-and-forth files, find the patterns in them, and store the result in a shape a model could be trained on - working out for myself what the signal actually is.
personas: [taxonomist, archivist, integrator, skeptic]
open_threads: [0008-t1, 0008-t2, 0008-t3]
closes: []
carries_forward: [0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0008 — the loop is the corpus

## What changed

**The mechanism, which was the actual question.** The raw material is not "some
conversations". It is a loop that has run seven times and left a
machine-readable trace of every lap: prompt → implementation → self-assessment →
correction. Four signals fall out of it, and three barely exist in public data:

| kind | weight | what it is |
| --- | --- | --- |
| `exchange` | 1.0 | (prompt, response). Ordinary. |
| `calibration` | 3.0 | a claim about the LIMITS of one's own work, written before anyone checked, with whether the next lap resolved it |
| `critique` | 4.0 | the author criticising the INSTRUCTION they were given |
| `handoff` | 2.5 | advice written to one's next self about what to check first |

The weights are rarity, not quality. A sampler treating them equally drowns the
signal that made the corpus worth assembling.

**`corpus/`** — a second module, `PSCorpus`, six commands, and a
Postgres-plus-pgvector container whose schema is baked into the image. `load.ps1`
is the one command; `docker compose` brings up a database and a loader that
needs nothing installed on the host.

**Run against this repository:** 7 iterations, 24 threads, 178 claims, 4
patterns, 3 sessions, 1,871 turns, 1,351 tool calls, 130 recurring terms, 56
training examples. Loaded, queried, and answering questions the files cannot.

**Nothing opens a socket.** The module writes a `.sql` script and `psql` applies
it, so the whole load is reviewable before it runs and the test suite needs no
container.

## What I learned

**Narrowing the input beat every attempt to be clever about ranking.** The first
recurrence pass read whole ledger entries and returned `store`, `every`,
`nothing` — the subject matter, which of course appears in all seven laps. Three
scoring schemes later the answer was not a better score: trouble is never
recorded in *what changed*, only in *what I learned* and *what I could not
verify*. Reading the right sections and subtracting the wrong one as a baseline
made the stop list unnecessary, which is the tell that it was the right cut.

**A turn pair is not an exchange.** Pairing each assistant turn with the one
before it produced 36 examples of (tool result, narration). A long task puts
dozens of assistant turns between one human message and the next, so the unit is
an *episode* — one human message, everything until the next, and the last
substantial reply as the answer. It also yields a difficulty proxy that exists
nowhere else: how many turns sat between the question and the answer.

**Path-shaped redaction cannot see a bare username.** `ls -la` output carries
the account in its owner column — `drwxr-xr-x 1 name 197121` — with no separator
anywhere near it. Twenty-three survived a full pass, and they were found by
grepping the GENERATED SQL rather than by trusting the pass. The lesson is not
"add a rule". It is that **a redactor must be told what to redact**, not left to
infer it from shapes, and the names now come from `git config` as well as the
environment.

**PowerShell resolves a hashtable KEY before the real member.** On a table keyed
by words from English prose, `$seen.Values` returns the row for the word
"values" and `$seen.Count` returns the count for "count". Both words are in this
corpus. The failure is silent — the pipeline receives one object instead of
eight hundred and the result is simply empty — and it cost a debugging round.
`get_Values()` and `get_Keys()` throughout, and a test that plants the words
deliberately.

**The quoted-heredoc backslash trap fired twice more**, once inside the very
function documenting it and once eating the `\b` word boundaries out of the
redaction regex. That is five iterations running. It is written into
`docs/development.md` and it keeps happening, which says the note is not where
the mistake is made.

## What I could not verify

The Skeptic's section. It is never empty.

- **That any of this trains anything.** The corpus is 56 examples. Nothing was
  fine-tuned, nothing was evaluated, and the claim that `calibration` and
  `critique` are rare and valuable is an argument from what public datasets
  contain, not a measurement. A shaped dataset is a hypothesis about what would
  help, and this one is untested end to end. Opened as `0008-t1`.
- **That redaction is complete.** It is verified against a fixture, which is the
  only honest way — the corpus now ingests this repository's own transcripts, so
  grepping the live corpus for a username finds the test that greps for it. That
  makes the fixture necessary and also means **the live output has never been
  independently cleared.** Anyone publishing this corpus should re-check it with
  a tool that was not written by whoever wrote the redactor.
- **That `Measure-CorpusRecurrence` finds anything worth acting on.** Its top
  rows on real data are `right`, `written`, `number`, `never`, `evidence` — the
  vocabulary of *being wrong*, not any particular bug. That is a real result and
  it may also be a null result dressed up: it says the trouble sections are
  written in a consistent register, which nobody needed a database to learn.
- **That it finds the thing it was built to find.** Checked, and it does not.
  The heredoc trap cost a round four times and reaches fewer than two claim
  sections, so it scores nothing. A trap that fires in sessions and is written
  down once is invisible to anything reading the record rather than the work.
- **That the four kinds are the right four.** They came from looking at one
  repository's record for an afternoon. `exchange` is certainly right because it
  is universal; the other three are one author's account of what was unusual
  about their own process.
- **That `critique` has enough rows to be anything.** Two. It is the highest
  weighted kind and the smallest, which is a bad combination for a sampler.
- **That the schema survives a second project.** The section headings are this
  repository's five, hardcoded in `Import-CorpusLedger`. Pointed at any other
  ledger it would extract nothing and say so quietly. Opened as `0008-t2`.
- **That the container is reproducible.** `pgvector/pgvector:pg16` is a moving
  tag, not a digest, and the init scripts run on first start only — editing the
  schema and running `up` again changes nothing until the volume is dropped,
  which looks exactly like a schema that failed to apply.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**No, and the near-miss is the same one as last time.** The candidate is
`speech act` — a claim is a report, a generalisation, a doubt or a reflection,
and the corpus separates them because they are different acts. The pair would be
two claims from `0007`: "The payload measures every node" and "That anyone can
read the ramp". `structure` and `surface` classify neither, because **claims are
not subjects**: no namespace addresses a sentence, and inventing one to host a
dimension is the failure this rule catches. Third time this exact shape has come
up — `0004-t1` for patterns, `0007-t2` for measurements, now this. They are one
question and it is time it was answered as one.

**2. Is an existing facet doing two jobs?** No. No facet was read or written.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?** No.

**5. Could this facet classify facets?** Not applicable. Worth recording: the
`hedged` flag is a measurement of a sentence, and `facet-health` is a
measurement of a facet. If the store ever holds measurements — `0007-t2` — these
are the same machinery at two scales.

### Prune, this iteration

A move: none needed; every new fact landed in the corpus charter. A deletion
proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged. `CLAUDE.md` gained nothing; `corpus/` is
on-demand behind `docs/corpus-architecture.md`.

## Open threads

1. **[0008-t1] Nothing has been trained on this.** 56 examples, no fine-tune, no
   eval. The weights are an argument, not a result. The smallest honest next
   step is a held-out split and a single comparison, not a bigger corpus.
2. **[0008-t2] The section headings are hardcoded to this repository's five.**
   `Import-CorpusLedger` extracts nothing from any other ledger and says so
   quietly. Making them configuration is the difference between a tool and a
   script that happens to live in a module.
3. **[0008-t3] `corpus/` is outside both the lint task and the charter test.**
   `Lint` scans `src/PSModuleGraph` only, and `SubsystemCharter.Tests.ps1`
   enumerates `Private/` directories only — so a new top-level directory gets a
   charter because a skill said to, not because anything checks. The propagation
   rule from `0004` has a hole exactly the shape of this iteration.

Carried: **[0007-t1]** hot and external are nearly the same colour;
**[0007-t2]** should the store hold measurements; **[0006-t1]** the http-origin
editor-link claim is unverified; **[0005-t1]** skill descriptions are unbudgeted;
**[0005-t2]** the ceiling's headroom is a guess; **[0005-t3]** nothing measures
whether an on-demand file is read; **[0004-t1]** should patterns be subjects;
**[0004-t4]** `iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.

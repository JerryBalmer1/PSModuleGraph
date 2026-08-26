---
id: "0004"
tag: v0.3.0
date: 2026-08-26
prompt_intent: Package the working intent as four skills so it propagates downward on its own instead of waiting for a human to remember a prompt, backfill the two missing subsystem charters and make the rule enforceable, start a pattern log with a two-scale bar, and give CLAUDE.md a counter-force and a written commit rule.
personas: [taxonomist, archivist, integrator, skeptic]
open_threads: [0004-t1, 0004-t2, 0004-t3, 0004-t4]
closes: []
carries_forward: [0003-t1, 0003-t2, 0003-t3, 0001-t7]
supersedes: []
---

# 0004 — the instruction set gains a shape, and a way down

## What changed

**Four skills under `.claude/skills/`.** `iteration-close` holds the eight
actions that end a prompt cycle; `meta-pattern` records a shape seen at two or
more scales; `subsystem-charter` writes a charter for a new child area;
`instruction-prune` asks once per iteration whether anything became obsolete.
`.claude/skills/README.md` is the index, with the dependency graph rendered as
Mermaid — a repository that generates dependency graphs should be able to show
its own instruction set as one.

The front-matter schema was checked against the Claude Code documentation rather
than assumed. It is looser than expected: **every field is optional**,
`description` is only *recommended*, and the command name comes from the
**directory**, not from `name` — for a project skill `name` is a display label
only. `when_to_use` is the one snake_case field among hyphenated siblings and is
appended to `description` under a shared 1,536-character cap. None of the four
declares `allowed-tools`, deliberately: that grant applies in any session that
invokes the skill, including in a folder nobody has trusted, so a checked-in
skill pre-approving `Bash(git *)` is a grant to every future clone.

**`knowledge/patterns/` and `pattern.schema.json`.** Three seeded patterns, all
carrying `0004` because the ledger id is the ordering — dates do not order two
iterations that land on one day. `scales` has `minItems: 2`, which is the
two-scale bar made checkable rather than exhorted, and `confidence` is required
and bounded below 1 exactly as an assignment's is.

**Two charters backfilled.** `docs/editorlink-architecture.md` and
`docs/knowledge-architecture.md`, 119 lines each, and
`tests/Private/SubsystemCharter.Tests.ps1` now fails by name for any directory
under `Private/` with three or more files and no charter in `docs/`.

**A `Commit` section in `CLAUDE.md`**, 26 lines, holding the rules; the skill
holds the order of operations and points at it rather than restating it.

## What I learned

**The charter was the cheap half; stating what it inherited was the work.**
Writing "the seam is X" for EditorLink took ten minutes because the code already
said it. Writing *what the parent rules mean here* took the rest, and it is the
only part that could not have been derived by reading the directory. Two things
fell out that the code does not say anywhere:

*EditorLink has three seams, not one.* Every file sits in exactly one of read,
decide, write, and the band determines whether it may touch machine state. Each
doc-comment carries its own half of this; no file carried the rule, so a
read-band function that wrote would have passed review — and would still pass a
green build, because the tests exercise a fake machine that tolerates it.

*The knowledge store has a hand-authored half and a generated half, and only the
generated half round trips.* `Write-KnowledgeRecord` throws on any nested value,
so facets, ledger entries and now patterns can only be written by hand.
`read_store.py` reads only the flat half for the same reason. The division is
deliberate, it is load-bearing, and nothing anywhere announced it.

**The neutrality guard cannot tell stored data from prose about stored data,
and it caught me twice in one iteration.** A seeded pattern naming the forbidden
type-name attribute was failed by the test that forbids it; then this ledger
entry, describing that failure, was failed by the same test for the same reason.
`NAMING.md` is already exempted, described as "the file that forbids them" —
which is a special case standing in for a principle. I reworded both rather than
widening the exemption, because loosening a guard in the turn it fires is the
move this repository refuses everywhere else. Two hits in one iteration is the
evidence that an exemption list does not scale. Opened as `0004-t3`.

**The Bash tool collapses `\\` to `\` inside a quoted heredoc.** The pattern
schema went to disk with `\.` where it needed `\\.`, and `Test-Json` reported
only "Cannot parse the JSON schema" — no line, no position. The schema had to be
round-tripped through `ConvertFrom-Json` to get an error that named the field.
A validator that will not say *where* costs more than one that says nothing.

**A dependency edge in the skill graph is weaker than it looks.**
`subsystem-charter` depends on `meta-pattern`, but `meta-pattern` produces a file
only when the two-scale bar is met, so most invocations of that edge will
correctly produce nothing. The graph is honest about the call and silent about
the yield, which is precisely the distinction this repository's own reports make
between an edge and a resolved target.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the skills trigger.** The charter test is a mechanism: it fails a build.
  The skill triggers are `when_to_use` prose, which is a hint to a model reading
  a listing, not a mechanism. I verified the schema against the documentation and
  I did not observe `iteration-close` firing on its own at the end of a cycle,
  because this is the cycle. **The propagation problem is solved for charters and
  merely described for everything else** — and the whole premise of the task was
  that description is what failed last time.
- **That the three seeded patterns clear the bar honestly.** I chose the scales
  and I chose what counts as distinct. Three self-certified observations by one
  author on one afternoon is the same weakness `0003` recorded about two readers
  sharing an author, and naming it again does not fix it.
- **That declining to promote the commonality was right.** All three seeded
  patterns can be described as "refusing to collapse a distinction", and I called
  that a rhyme rather than a shape — see the note below. The argument that
  persuaded me is that I named all three in one sitting, so their common
  vocabulary may be an artefact of the naming rather than of the repository. That
  argument is unfalsifiable from inside this iteration.
- **That `iteration-close` should be model-invocable at all.** It commits, tags
  and pushes. The Claude Code documentation names exactly this case — `/commit`,
  `/deploy` — as the reason `disable-model-invocation` exists. I followed the
  brief, which asked for an end-of-cycle trigger. I do not think the brief is
  right. Opened as `0004-t4`.
- **That the charter test's name mapping survives a two-word subsystem.**
  `EditorLink` maps to `editorlink-architecture.md` by lowercasing. A future
  `Private/GraphExport/` would demand `graphexport-architecture.md`, which no
  human would name that way, and the test would then fail against a correctly
  named file. Untested, because no such subsystem exists yet.
- **That a line count measures what `instruction-prune` claims.** 835 → 861 this
  iteration. The number is real and the trend it implies is not: a section can
  double in density while shrinking, and the cost being paid is tokens read per
  session, not lines.
- **That `read_store.py` still describes the store.** It runs and still agrees —
  97 subjects, 188 assignments — but it does not read `patterns/` or `ledger/`,
  so its agreement now covers a smaller fraction of the store than it did at
  `v0.2.0`. The proof did not get weaker; the thing being proved got bigger.

## Dimensional impact

Five questions, under the evidence rule: a yes to 1, 2 or 3 must name two
specific subjects the existing facets cannot distinguish, or that the proposed
split would separate.

**1. Did this reveal a dimension that does not exist yet?**
**No**, and this is the question the brief asked to be answered explicitly.
`knowledge/patterns/` is a new file population but **not a new subject
population**, because patterns were deliberately not given URNs. The pair I
looked hardest at was `0004-could-not-check-is-not-passed` against
`psmodule:PSModuleGraph/function/Test-KnowledgeDocument` — the pattern and one
of the things it was drawn from. `structure` and `surface` cannot classify the
first, but that is because it is not a subject, not because a dimension is
missing. **No pair, so no proposal.** Whether patterns *should* be subjects is
`0004-t1` and is a decision, not a dimension.

**2. Is an existing facet doing two jobs?**
No. No facet was touched, no assignment was written, and no facet was consulted.

**3. Did two facets turn out to be the same thing?**
No.

**4. Did anything classify at a depth the facet did not anticipate?**
No — nothing was classified. `0003`'s finding about `facet-health` paths being
three segments where `structure` is two stands unexamined and carries forward as
part of `0003-t1`.

**5. Could this facet classify facets?**
Not applicable; no facet was added. Worth recording for `0004-t1`: if patterns
became subjects, `facet-health`'s own grading shape is the nearest precedent for
what grading them would look like, and it is currently the facet that grades
itself flatteringly.

### On the commonality of the three seeded patterns

The brief asked whether what the three have in common is itself a pattern.
**Declined.** All three can be phrased as "refuse to collapse a distinction", but
the two-scale bar applied to patterns requires the *scales* to be patterns, and
the three do not sit at distinct scales from one another — they are three
observations of the same era, named in one sitting, by one author. The shared
vocabulary is more likely an artefact of that sitting than a property of the
repository. A pattern about patterns belongs in `knowledge/meta/`; this one does
not exist yet and should be proposed by an iteration that did not also invent
its members.

### `CLAUDE.md` line count

**835 → 861** (+26, the `Commit` section). No line was removed.

**Prune proposal, owed by the brief and not applied:** the two sections both
named **Kaizen**. `## Kaizen: the knowledge substrate` (line 127) and `## Kaizen`
(line 510 after this change) each carry a paragraph whose only job is to explain
that the other exists — the file apologising for its own structure. They are not
redundant: one governs the store and its reflection pass is mandatory, the other
governs the code and its improvement is optional. They are **misnamed**, which is
a different defect and has a cheaper fix. Proposal: rename the second to
`## Improvement loop`, delete both cross-reference paragraphs, and leave one
sentence in the store section pointing at it. **What is lost:** the word "kaizen"
currently signals that both are the same habit pointed at two things, which the
rename drops. **Size: Medium** — its own commit, no contract changes. To be
applied by `0005`, not by this entry.

## Open threads

1. **[0004-t1] Should patterns be subjects with URNs?** `pattern:0004-...`
   classified by facets, gradeable by `facet-health`, addressable in an
   assignment's evidence block. Decided **not** this iteration, deliberately: the
   population was created in this turn, and classifying a population in the turn
   that creates it is what reflection discipline exists to prevent. The question
   is whether a pattern is a thing the store describes or a thing the store is
   made of, and that is the same question `0003-t3` asks about
   `structure:external`. Answer them together.
2. **[0004-t2] The two Kaizen sections.** Proposal above. Rename, do not merge.
   Unapplied by design.
3. **[0004-t3] The neutrality guard cannot distinguish data from prose about
   data.** `NAMING.md` is exempted as "the file that forbids them", which is a
   special case standing in for a principle. Every prose file in the store —
   ledger entries, patterns, and whatever comes next — will eventually trip it.
   The fix is probably to scope the grep to the file kinds that carry data rather
   than to keep adding names to an exemption list.
4. **[0004-t4] `iteration-close` is model-invocable and it pushes.** The
   documentation names this case as the reason `disable-model-invocation` exists.
   The brief asked for an end-of-cycle trigger; the owner should decide whether a
   skill that tags and pushes may fire without them typing anything.

Carried from `0003`: **[0003-t1]** `facet-health` grades itself flatteringly and
the depth axis measures something narrower than its name; **[0003-t2]** coverage
conflates unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments and may not deserve to exist.

Carried from `0001`: **[0001-t7]** the facet seam in the report, still designed
and still unbuilt. Explicitly out of scope here.

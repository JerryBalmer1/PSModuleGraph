---
id: "0005"
tag: v0.4.0
date: 2026-08-26
prompt_intent: Make the counter-force able to win by redefining a prune as a move down a tier rather than a deletion, so nothing needs defending; then cap the always-loaded tier with a build gate, and make a genuine deletion proposal that a second iteration ignores block the annotated tag.
personas: [taxonomist, archivist, integrator, skeptic]
open_threads: [0005-t1, 0005-t2, 0005-t3]
closes: [0004-t2, 0004-t3]
carries_forward: [0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0005 — the counter-force gets a tier to push into

## What changed

**Always-loaded: 46,681 → 18,544 bytes.** A 60% cut with nothing deleted. Every
byte of it moved to a file that is read when the work touches it and costs
nothing otherwise.

| Moved | To | Bytes |
| --- | --- | --- |
| The HTML export, Gravity, the token discipline, the editor/webview findings | `docs/html-architecture.md` | ~11,300 |
| The two commands that write, the origin-default hypothesis | `docs/editorlink-architecture.md` | ~3,300 |
| Pester 6, the verified assertion list, the fixture facts | `docs/testing.md` *(new)* | ~6,400 |
| Build tasks, Layout, Parsing, adding a command, tooling traps | `docs/development.md` *(new)* | ~6,600 |
| The four personas, the reflection pass, the evidence rule | `.claude/skills/iteration-close/SKILL.md` | ~2,900 |
| The improvement loop's method and size rules | `docs/improvements.md` | ~2,400 |

What stayed is principles, protocols, prohibitions and pointers: the core
constraint, the machine-owner protocol, the substrate reframe and its eight
rules, the commit rule, the seams, "report do not drop", the open decisions, and
a table naming where everything else went. My guess landed under the 25,000
predicted, and the reason is that almost everything long turned out to be
procedure.

**`tests/Instructions.Tests.ps1` caps the tier at 19,000 bytes** and fails
naming the size, the ceiling, the overage, and the per-file breakdown. It
enumerates *every* `CLAUDE.md` in the tree plus anything one of them
`@`-imports, rather than hardcoding the one file — a budget defeated by adding a
second always-loaded file is not a budget. It also fails when `CLAUDE.md` points
at a path that does not exist, because a pointer to a missing file is worse than
no pointer: the reader believes the detail is somewhere and stops looking.

**`tests/PreTag.Tests.ps1` blocks the tag, not the build.** Tagged `PreTag`,
excluded from the default `Test` task, run by `./build.ps1 -Task PreTag`. The
ledger schema gained `prune_proposals`, and entry N+1 must **close** every id
entry N listed — carrying one forward is not enough, because carrying is exactly
the idling the gate exists to stop.

**`instruction-prune` was rewritten around the move.** Its question changed from
*"did anything become obsolete"* to **"is anything here that an agent does not
need before it starts?"**, and moves now apply in-turn.

## What I learned

**The reason the first version idled was not the one-turn delay. It was that
deletion has a defender.** The delay was real and I named it in `0004`, but it
was the smaller half. Every line in `CLAUDE.md` was written because something
went wrong, so asked *"may I delete this"* the honest answer is almost always no
— and a mechanism whose only move is one that is almost always correctly refused
does nothing, on schedule, forever. Changing the move to one that loses nothing
removed the resistance rather than overpowering it. **The one-turn delay only
looked like the problem because it was the visible half.**

**Two rules I wrote one iteration apart contradicted each other.** `0004`'s
charter test capped a non-Html charter at 119 lines, to stop a backfilled
charter being padding. `0005` makes charters the *destination* for detail moved
out of the always-loaded tier. A cap on the on-demand tier directly opposes the
move, and I hit it within twenty minutes of starting — `docs/editorlink-architecture.md`
is now 172 lines and correct. The cap went. What it was actually guarding
against is checkable head-on: a charter must **state what the parent rules mean
here**, and the test now asserts that instead of counting lines. Capping the
tier that is free while leaving the charged one uncapped was the wrong control
in the wrong place.

**The heredoc trap fired three more times, once on its own documentation.** The
paragraph in `docs/development.md` warning that a quoted heredoc collapses a
doubled backslash was itself mangled by that collapse on the first attempt, and
the ledger schema's `\n` escapes became literal newlines twice. It is now
written down with the shortest available proof attached. Between them,
`Test-Json`'s bare `Cannot parse the JSON schema` cost more than the trap did:
an error that names no line sends you to read the document instead of the
schema.

**An exemption list was standing in for a principle, and replacing it was three
lines.** `0004-t3` recorded that the store's neutrality guard could not tell
stored data from prose about stored data, and that `NAMING.md` was exempted by
name "because it is the file that forbids them". The principle underneath is
simply that **a rule about the shape of stored data does not apply to prose about
that shape**: the guard now runs over `facets/`, `subjects/`, `assignments/`,
`meta/` and `SCHEMA/`, and `ledger/`, `patterns/` and `NAMING.md` fall outside it
by being what they are rather than by being named. Closed.

**A tier is not a hierarchy, and the table is doing more work than the rule.**
The test — *does an agent need this before it does anything at all?* — decides
whether text leaves `CLAUDE.md`. It does not decide where it goes, and getting
that wrong produces a `docs/` directory nobody has a reason to open, which is
the same disease one tier down. The destination table in the prune skill exists
because the rule alone was not enough to place a single paragraph.

## What I could not verify

The Skeptic's section. It is never empty.

- **That 18,544 is the right size rather than merely a smaller one.** I chose
  every move, and the test I applied is one I also wrote. A second reader would
  almost certainly find something in the substrate section that is procedure —
  the eight numbered rules are half principle and half instruction — and
  something in the machine-owner protocol that could be a pointer. **I moved
  nothing I was unsure about**, which biases the result upward and is the right
  bias, but it means the number is a floor on the tier and not a measurement of
  it.
- **That the ceiling has any headroom worth having.** 19,000 against 18,544 is
  456 bytes, about 2%. Tight enough to force a trade on the next real addition,
  and possibly tight enough that a typo fix plus a clarifying clause fails the
  build for no good reason. I do not know which until it happens.
- **That bytes track tokens.** They track roughly, and I have not measured the
  actual token count of either version. A table costs more tokens per byte than
  prose; this file gained several tables. The proxy is stated as a proxy where
  the ceiling is defined, which is the most I can honestly do.
- **That the `PreTag` gate fires in anger.** It fires against a simulated store —
  proven below — and it has never seen a real ignored proposal, because `0005`
  applied `0004`'s proposal rather than ignoring it. The first genuine test of it
  is an iteration that gets it wrong.
- **That a skill's `description` and `when_to_use` are not part of the
  always-loaded tier.** They are: the skill listing is in context every session,
  and this repository now has four skills whose descriptions total about 800
  bytes. The budget does not count them, so **adding a fifth skill grows the
  always-loaded surface without touching the gate.** That is the hole I said the
  file enumeration closed, still open one layer up. Opened as `0005-t1`.
- **That the two new `docs/` files will be read.** `docs/development.md` and
  `docs/testing.md` are the only two destinations created rather than reused,
  and a doc nobody opens is the on-demand tier's version of the same accretion.
  Nothing measures whether an on-demand file is ever loaded, and nothing can
  from inside the repository.
- **That `prune_proposals` is a schema change worth its bump.** It adds one
  optional array. The alternative was matching prose in the body, which is the
  thing `LedgerContinuity`'s own comment warns against — but the field is
  machinery for a mechanism that has fired zero times outside a simulation.

## Dimensional impact

Five questions, under the evidence rule: a yes to 1, 2 or 3 must name two
specific subjects the existing facets cannot distinguish, or that the proposed
split would separate.

**1. Did this reveal a dimension that does not exist yet?**
**No.** The candidate is real and I looked at it hard: instruction files now
have a **tier** — always-loaded or on-demand — and that is a genuine open-ended,
evidence-backed classification of an addressable thing, which is the definition
of a dimension in this store. The pair would be `CLAUDE.md` against
`docs/testing.md`. But **instruction files are not subjects**: no `doc:` or
`instruction:` namespace exists, nothing in `subjects/` addresses a `.md` file,
and creating a namespace to host a facet is inventing the population to justify
the dimension. Same shape as `0004-t1` and it gets the same answer. **No pair
among existing subjects, so no proposal.**

**2. Is an existing facet doing two jobs?**
No. No facet was read or written this iteration.

**3. Did two facets turn out to be the same thing?**
No.

**4. Did anything classify at a depth the facet did not anticipate?**
No — nothing was classified. `0003`'s finding stands unexamined under
`0003-t1`.

**5. Could this facet classify facets?**
Not applicable; no facet was added. Noted for `0005-t1` and `0004-t1` together:
the tier distinction would classify *facet definition files* as readily as it
classifies instruction files, which is weak evidence that if instruction files
ever become subjects, the tier facet is `meta/` material from the start rather
than after a promotion.

### Prune, this iteration

**A move, applied in-turn:** the whole re-tier above. Nothing was deleted, so
nothing waited.

**A deletion proposal:** none. `prune_proposals` is empty, and that is the
expected answer most iterations — the tier move is the operation that will do
almost all the work, and genuine obsolescence is rare in a file where every line
was written after something went wrong.

**`0004-t2` applied and closed.** The two Kaizen sections: the second is now
`## Improvement loop`, and both cross-reference paragraphs are gone. The
collision did **not** dissolve under Part 1 — both sections stayed in
`CLAUDE.md`, each shorter — so the rename was still owed and this was the turn
to apply it. What was lost is what `0004` said would be lost: the shared word
"kaizen" signalled that both were one habit pointed at two things, and the
rename drops that signal. The substrate section still says so in a sentence.

### Always-loaded bytes

**46,681 → 18,544** (−28,137, −60.3%). Ceiling **19,000**. Nothing deleted.

Reported in bytes rather than lines from here: a section can double in density
while shrinking in lines. Bytes are still a proxy for tokens read per session
and say nothing about comprehensibility — a file that trends down while getting
harder to hold in your head has passed the gate and failed its purpose.

## Open threads

1. **[0005-t1] Skill descriptions are always-loaded and unbudgeted.** Every
   skill's `description` and `when_to_use` sit in the listing in every session,
   whether or not the skill is invoked. Four skills, roughly 800 bytes. The file
   enumeration in `tests/Instructions.Tests.ps1` closed the "add a second
   `CLAUDE.md`" hole and left this one open a layer up, so the budget can still
   be grown by adding a skill. Either count them, or state deliberately that
   they are cheap enough not to.
2. **[0005-t2] The ceiling's headroom is a guess.** 456 bytes, about 2%. It
   should force a trade on a real addition and it may instead fail the build on
   a clarifying clause. Do not raise it on the first annoyance; record what
   actually happened and decide once there is a case.
3. **[0005-t3] Nothing measures whether an on-demand file is ever read.** Two
   new `docs/` files were created rather than reused, and an unread doc is the
   on-demand tier's version of the accretion this iteration exists to stop. The
   only signal available from inside the repository is whether anything links to
   it, which is weak. Decide whether that is worth checking or whether it is
   unmeasurable and should be said so.

Carried from `0004`: **[0004-t1]** should patterns be subjects with URNs —
unchanged by this entry, and question 1 above arrives at the same place from a
second direction, which strengthens the case for answering it and `0003-t3`
together; **[0004-t4]** `iteration-close` is model-invocable and it pushes.

Carried from `0003`: **[0003-t1]** `facet-health` grades itself flatteringly;
**[0003-t2]** coverage conflates unassigned with inapplicable; **[0003-t3]**
`structure:external` has no assignments.

Carried from `0001`: **[0001-t7]** the facet seam in the report. Explicitly out
of scope.

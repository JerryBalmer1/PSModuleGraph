---
id: "0002"
tag: v0.1.0
date: 2026-08-26
prompt_intent: Close the round-trip gap by reshaping the data rather than growing the parser, and replace three instructions I said could not be mechanised - ledger rot, reflection bias, and an ungated coverage target - with mechanisms that fail a build.
personas: [taxonomist, archivist, integrator, skeptic]
open_threads: [0002-t1, 0002-t2, 0002-t3, 0002-t4]
closes: [0001-t5, 0001-t2, 0001-t1]
carries_forward: [0001-t3, 0001-t4, 0001-t6, 0001-t7]
supersedes: [0001]
---

# 0002 — the round-trip, and three mechanisms

## What changed

**The round-trip test passes.** That is the headline. `knowledge/` is read back
by the same code base that wrote it, and the assertions are about content rather
than absence of error.

**The data reshaped; the parser did not grow.** Subjects and assignments were
collection documents whose items held nested lists and mappings, which
`ConvertFrom-KnowledgeFrontMatter` could not parse. That was not an untested
round-trip, it was an impossible one — `0001` filed it as "needs the parser to
handle nested lists", which undersold it. Now: one file per subject, one file per
subject × facet, entirely flat, laid out to mirror the URN. `evidence` became
`evidence_kind` / `evidence_value` / `evidence_source`; `provenance` became three
scalars the same way. 72 subjects, 141 assignments.

**Three readers, one read path.** `Import-KnowledgeSubject` and
`Import-KnowledgeAssignment` join `Import-KnowledgeFacet`, all three over a
shared `Read-KnowledgeFile` that locates the store root by walking up to the
`SCHEMA` directory — so a store lifted elsewhere still validates without being
told where it went. `ConvertFrom-FacetFrontMatter` became
`ConvertFrom-KnowledgeFrontMatter`, since it is no longer facet-specific.

**Ledger continuity is a test, not a hope.** Front matter gained `open_threads`,
`closes` and `carries_forward`; the schema requires all three and permits both
empty for entry `0001` only. `LedgerContinuity.Tests.ps1` fails naming any thread
id that vanished between consecutive entries, and a second test catches the
mirror failure of closing a thread nobody opened.

**The coverage gate fires.** `CoveragePercentTarget` only ever reported; the
`Test` task now throws naming both numbers. Coverage went from 74.88% to 75.23%
without moving the target — the new readers and their tests carried it over.

**Pre-1.0 versioning is decided** in `NAMING.md`, and `CLAUDE.md` gained the
verified Pester assertion list, enumerated from the installed module rather than
remembered.

## What I learned

**The store goes stale the instant the source moves.** Adding the new readers
changed the module, so the freshly generated store was wrong before the first
build finished. The first version of the round-trip test conflated two
questions — *is what was written what is read* and *does the store still describe
the source* — and reported a stale store as a broken reader. They are now two
`Describe` blocks with different names, and the freshness one says what to do
when it fails. Conflating them would have trained a reader to ignore it.

**Flat front matter is a stronger constraint than it looks.** It forbids
`evidence` as a list, which forces "two pieces of evidence" to become two
assignments — and that is the *better* shape, because each then carries its own
confidence. A shared list could never express that. The format constraint
improved the model rather than merely surviving it, which is not what I expected
when I started.

**A schema cannot express "flat".** `additionalProperties: false` plus scalar
types gets close, but a JSON Schema cannot say "no key may hold a mapping"
without enumerating every key. The flatness assertion had to be a *test over the
raw front matter text*, not a schema rule. The store's contract is therefore in
two places, which is a wart.

**`Set-ItResult -Skipped` is the honest form** for the continuity test while only
one entry existed. A test that silently passes when it has nothing to check is
indistinguishable from one that works.

## What I could not verify

The Skeptic's section. It is never empty.

- **That any language other than PowerShell can read the store.** This is the
  central claim and it is still untested. What `0002` proves is that the format
  is readable *by a different code path in the same runtime*, which is strictly
  more than `0001` proved and strictly less than the claim. Thirty lines of
  Python would settle it and none have been written. This is why `1.0.0` is
  defined as "read by a second implementation".
- **That the round-trip is lossless.** The test asserts counts, validity,
  referential integrity, and two spot-checked records. It does not compare every
  field of every record against what the generator held in memory. A field
  mangled identically on write and read would pass.
- **That the continuity mechanism catches what it was built for.** It was proven
  to fire by removing a thread id and watching it fail by name. It has never run
  against a genuinely careless entry, which is a different thing from a
  deliberately broken one.
- **The flatness test against a case it was not written for.** It rejects lines
  starting with a dash and lines whose value is empty. A nested mapping written
  inline — `parent: { id: x }` — would pass it and fail the schema, so the two
  together are sound, but the flatness test alone is not.
- **Whether `confidence: 0.9` is still the right number.** Unchanged from `0001`
  and still uncalibrated. Carried, not resolved.
- **That reshaping was right rather than merely defensible.** 213 files replaced
  2. The argument for it is `git diff` legibility and reader simplicity, and both
  are judgements. A reviewer who finds 213 files worse than 2 has a case, and
  nothing here refutes it — see **One thing I think is wrong** in the report.

## Dimensional impact

Both of `0001`'s proposals were re-tried under the new evidence rule: **a "yes"
to questions 1–3 must name two specific subjects the existing facets cannot
distinguish, or that the split would separate.** Both were withdrawn.

**1. Did this reveal a dimension that does not exist yet?**
**No — and `0001`'s proposal is withdrawn.** `0001` proposed `namespace`. The
rule asks for two subjects it would distinguish that existing facets do not.
Every subject in the store is `psmodule:`. There is no pair. A dimension with one
observed value is not a dimension; it is a constant with ambitions. `namespace`
returns when a second namespace does. Closes `0001-t1` by withdrawal.

**2. Is an existing facet doing two jobs?**
**No — and `0001`'s proposal is withdrawn**, which I did not expect. `0001`
proposed splitting `facet-health` into coverage, evidence and depth.

The rule asks for two subjects the split would *separate*. I could not produce
them, and the reason is structural: **facets are multi-valued.** `facet:surface`
can already carry `facet-health:coverage:partial` *and*
`facet-health:evidence:inferred` simultaneously, as two paths on one facet. Three
separate facets would hold exactly the same information. Two subjects with
identical assignments before the split have identical assignments after it. **The
split separates nothing** — it is a rename that produces two extra files.

That is a better answer than `0001`'s and it came only from being forced to name
a pair. Closes `0001-t2` by withdrawal.

The reflection did surface something adjacent and evidenced, which is recorded as
a defect rather than promoted into a new proposal: **`facet-health` declares
`kind: scalar`, which is wrong.** `scalar` asserts its paths are ordered, and
`facet-health:coverage:complete` has no defined order against
`facet-health:evidence:asserted`. The ordering is real *within* each axis and
undefined *across* them, which is not what `scalar` means. It is a demonstrable
inconsistency in a shipped file, not a hunch. Opened as `0002-t1`.

**3. Did two facets turn out to be the same thing?**
No. Unchanged from `0001`, and the reshape gave no new evidence either way.

**4. Did anything classify at a depth the facet did not anticipate?**
No. Still every path exactly two segments. Still a weak no for the same reason:
nothing in this increment was deep enough to strain a hierarchy, so the question
has not really been asked yet.

**5. Could this facet classify facets?**
No new facets were created, so nothing new is a candidate. `facet-health` remains
the only meta-facet, still with zero assignments — `0001-t3` is carried forward
rather than closed, because computing those assignments needs a store reader,
which now exists but was not the job of this entry.

## Open threads

1. **[0002-t1] `facet-health` declares `kind: scalar` and should not.** Its
   paths are ordered within each axis and unordered across them. Either
   `categorical` is the honest declaration, or the axes become separate facets
   for *this* reason rather than the withdrawn one. Evidenced, not proposed as a
   dimension.
2. **[0002-t2] Read the store from something that is not PowerShell.** Thirty
   lines of Python over the flat front matter settles the central claim and is
   the stated criterion for `1.0.0`. Until then the neutrality claim is
   plausible rather than demonstrated.
3. **[0002-t3] The store's contract lives in two places.** JSON Schema cannot
   express "no value may be a mapping", so flatness is enforced by a test over
   raw text. Either the schema gains an exhaustive scalar-typed key list, or the
   split is documented as deliberate.
4. **[0002-t4] The freshness test pins the store to the source tree.** Any new
   private function fails the build until the store is regenerated, and the
   generator is still a scratch script. Either the generator ships and the build
   runs it, or freshness becomes a warning rather than a failure. This is
   `0001-t4` with teeth and a deadline.

Carried from `0001`: **[0001-t3]** assign `facet-health` to the three facets,
now possible since a store reader exists. **[0001-t4]** make the write path real,
now urgent for the reason in `0002-t4`. **[0001-t6]** exercise
`structure:class`, `structure:enum` and `structure:external`, still with no
assignments. **[0001-t7]** the facet seam in the report, designed and unbuilt.

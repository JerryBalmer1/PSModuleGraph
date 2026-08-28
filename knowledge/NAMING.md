# Naming

**Version 0.3.0.** This document is itself versioned, because a naming
convention that changes silently is worse than one that is merely wrong.
`0.2.0` qualified a definition's URN with the file it is defined in, and added
the split rule below. `0.3.0` states the criterion that decides what may have a
URN at all, and separates the naming rule from the storage rule - see the two
sections immediately below, and `ledger/0024`.

---

## Two rules, not one

**This document makes two separate claims and they were read as one for eight
iterations.** Keeping them apart is the whole of `0.3.0`.

| | The claim | What it governs |
| --- | --- | --- |
| **The naming rule** | A subject is identified by a URN, `<namespace>:<path>`, resolvable without knowing what wrote it. | What may be *named*. |
| **The storage rule** | The file layout mirrors the URN, so a reader finds a file from an identifier without an index. | Where a named thing *lives*. |

The naming rule is a convention and it travels. `corpus/` holds
`thread.thread_id = '0003-t1'` in a Postgres table, which is the same identifier
the ledger front matter carries, adopted rather than imported: nothing wrote it
across, and no code coordinates the two. **The convention is already used by
something that is not this store, which is the naming rule working exactly as
intended.**

The storage rule is narrower and is about `knowledge/` only.

**The consequence, which is the thing that was being got wrong.** "Anything
addressable is a subject" was read as "anything addressable should have a file
under `subjects/`", and that made three separate questions look like one. They
are not one, and their answers differ - see "What may have a URN" below.

**This store is not the index of everything this project knows.** It is one
producer among several that share a naming convention. A thing may be correctly
named without this store holding it.

---

## What may have a URN

**Since 0.3.0.** Two rules. The first decides whether a thing can be named at
all; the second decides where a named thing may live.

### Identity is a pure function of intrinsic properties

**A URN names a thing whose identity is a pure function of its own properties -
never of its position in a document, never of an insertion order.**

This is not new behaviour. It is the rule the store has been applying since the
alias builder was written, stated for the first time: *"The generator computes a
former id rather than reading one... This only works because the old id was a
pure function of fields the new record still carries."* A URN derived from a
position cannot be recomputed after the document moves, so it cannot survive the
regeneration this store performs on every build.

The test in the URN section below - *"someone reading it in a file, in another
language, in another repository, should be able to say what it points at"* - is
the same rule from the reader's side. An identifier whose referent depends on
where a sentence sat when it was last parsed fails it.

### A subject lives where a dependency-free reader can reach it

**Today that means a file.**

The load-bearing claim is not that a subject *is* a file. It is that the store
can be read with no dependencies, and that claim is demonstrated rather than
asserted by `readers/read_store.py`: 51 lines, standard library only, no YAML
package, deliberately outside CI. A subject held in a database breaks that
demonstration and nothing else - reading it would need a driver, credentials and
a running container, and the 51-line proof that makes `1.0.0`'s criterion
meaningful would cover part of the store and be silent about the rest. **That is
worse than not having the proof, because it would still read as a whole-store
claim.**

`corpus/` reached the same conclusion independently and for its own reasons:
*"PSCorpus never opens a socket."* Two subsystems, separately, refused the
socket.

### Three answers, and the reasons are the point

The verdicts settle nothing on their own. **Record the reasons, because only a
reason resolves the fourth instance of this shape without a fourth debate.**

**Patterns are subjects. `pattern:0004-could-not-check-is-not-passed`.**
Iteration plus authored slug: both intrinsic, neither positional, stable across
every regeneration. `corpus/` reached the identical identifier without being
told - `pattern.pattern_id` is a `TEXT PRIMARY KEY` holding exactly that string
rather than a serial. Two independent derivations of one identifier is the
strongest evidence available that the identity is in the thing rather than in
the naming.

**Claims are not subjects. A sentence has no name.** A claim is one bullet from
one section of one entry, and its only natural key is
`(iteration, section, ordinal)` where the ordinal is a position in prose that is
re-parsed on every ingest. Edit a sentence into an earlier entry and
`claim:0007/3` silently names a different sentence. Nothing intrinsic
distinguishes bullet 3 from bullet 4 but where it sits, so there is nothing for
a URN to be a function of.

**Measurements are not subjects. A measurement is a reading about a thing at a
time, not a thing.** `facet:structure` is the subject; *"coverage is 0.72"* is
what one build observed of it. Giving the reading its own URN mints a new
subject every time the number moves, and under *"removal is not an operation
this store has"* the subject population would then grow monotonically with the
build count, forever. Banding the value into facet paths was considered and
declined separately, on the ground that it freezes thresholds nobody argued for;
that objection is real but secondary. **The primary objection is that a reading
is not a thing, and both proposed shapes were answers to the wrong question.**

A measurement is expressed as an assignment's `confidence`, or as a facet-health
record, both of which are already about a subject rather than being one.

---

## The one rule that makes the rest improvable

**A rename never deletes.**

The old name becomes an alias with a `since` marker. Anything that resolved
yesterday resolves today, and will resolve after the next reorganisation. A
taxonomy is only trustworthy if its history is addressable; a store that quietly
drops a name has told every downstream reader that its identifiers are guesses.

This applies to facet ids, to paths on a facet, and to subject URNs. All three
carry an `aliases` array for the purpose, and `deprecated: true` marks a path
that still resolves but should not be assigned to anything new. Removal is not
an operation this store has.

### A split is not a rename, and an alias may resolve to several subjects

**Since 0.2.0.** One name becoming two identifiers is the ordinary rename.
One identifier turning out to have been several things all along is not, and it
is the shape this store actually met: `psmodule:SqlServerDsc/function/Get-TargetResource`
named one record for thirty-two definitions, and the correct outcome is
thirty-two records, each carrying that one former id.

**So an alias resolves to one OR MORE subjects, and a resolver returns all of
them.** Not the first, not the one that used to win. The old identifier meant
"whichever of these was written last", which was never a fact about any of them,
and answering with a single record would keep exactly the confidently-wrong
answer the split exists to remove. Several answers and a choice is worse to read
and correct; one answer is easier to read and wrong.

**An alias equal to the id is not recorded.** A record claiming to be its own
former name says nothing and makes every resolution report two hits for one
file.

**The generator computes a former id rather than reading one.** Subjects are
regenerated, not edited - the tree is removed and rewritten - so by the time a
record is written its predecessor is gone. This only works because the old id
was a pure function of fields the new record still carries. A future rename that
is not derivable this way has to record its aliases some other way, and that is
a design question rather than an edit.

---

## Subjects are URNs

**This is the naming rule. The storage rule is under "Files" below, and they are
two claims - see "Two rules, not one" at the top of this document.** What may
have a URN at all is decided by "What may have a URN", also above.

```
<namespace>:<path>
```

The identifier must be resolvable without knowing what wrote it. That is the
whole test: someone reading `psgallery:Pester` in a file, in another language, in
another repository, should be able to say what it points at.

```
psmodule:PSModuleGraph
psmodule:PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass
psgallery:Pester
concept:static-analysis
facet:structure
```

**A definition's URN carries the file it is defined in**, because a name alone
is not an identity: two functions of the same name in two folders are two
things, and a store that gives them one subject answers for both by naming one
file. See the split rule above.

`facet:structure` is not a special case. A facet is a subject, which is what
lets one facet classify another — see `meta/`.

**Namespace segment** — lowercase, starts with a letter, `[a-z0-9-]`.
**Path segment** — `[A-Za-z0-9._/-]`, case preserved. A PowerShell function is
`Get-PSModuleClass`, not `get-psmoduleclass`; lowercasing it would make the
identifier stop matching the thing it names.

`/` separates containment within a namespace. It is not a facet separator and
carries no hierarchy meaning beyond "this is inside that".

### The namespace set is data

`psmodule`, `psgallery`, `concept`, `facet` and `pattern` are the namespaces in
use today.

**This list is data, not an enum in a `.ps1`, and must never become one.** Any
reader needing to know whether a namespace is valid must read it from data.

**`pattern:` is new in 0.3.0** and it discharges the condition the `namespace`
facet was withdrawn under. That proposal was declined in `ledger/0002` on the
explicit ground that every subject in the store was `psmodule:`, so no pair of
subjects existed that `namespace` would distinguish and the existing facets
would not - *"It returns when a second namespace does. A dimension with one
value is not a dimension."* A second namespace now exists, so **the condition is
met and the proposal is reinstated as a proposal.** It is logged in
`docs/improvements.md` and deliberately not taken: reflection proposes, the next
implementation disposes.

Any reader that needs to know whether a namespace is valid reads the facet. A
reader that hardcodes the list has moved the taxonomy into code, which is the
thing this store exists to prevent.

---

## Facet paths

```
<facet-id><separator><segment><separator><segment>...
```

The separator is declared per facet rather than assumed, because a facet
borrowed from another vocabulary may not use a colon.

```
structure:function
networking:cisco:asa:version:7.4.5
```

- The first segment is always the facet id. A path is self-identifying.
- Segments are lowercase `[a-z0-9.-]`, starting with a letter or digit. Dots are
  allowed so version-like segments do not need escaping.
- **Every path is written out in full** in the facet file, including its
  ancestors, rather than implied by indentation. One line of the file is then
  meaningful on its own — which matters when the reader is a `grep`, a diff, or a
  language that has not been written yet.
- On a `hierarchical` facet, a parent is implied by its children: assigning
  `structure:function` also means `structure`. Nothing needs to say so.

---

## Files

| Directory | Holds | Front matter schema |
| --- | --- | --- |
| `facets/` | one dimension per file | `facet.schema.json` |
| `meta/` | facets that classify facets | `facet.schema.json`, `meta: true` |
| `subjects/` | one classifiable thing per file, flat | `subject.schema.json` |
| `assignments/` | one subject x facet -> path per file, flat | `assignment.schema.json` |
| `ledger/` | one implementation per file | `ledger-entry.schema.json` |
| `patterns/` | one shape seen at two or more scales | `pattern.schema.json` |

Filenames are `<id>.md` for facets and `NNNN-slug.md` for ledger entries and
patterns. Under `subjects/` and `assignments/` the path is the URN with `:`
replaced by `/`, so the tree mirrors the identifier.

**`patterns/` is the source, `subjects/pattern/` is the derived record.** A
pattern file is written by hand and is where the prose lives; its subject record
is generated from the front matter, carries no prose of its own beyond a pointer,
and is removed and rewritten on every build like every other generated subject.
The identifier is the filename - iteration plus authored slug - which is why a
pattern could become a subject at all. See "What may have a URN".

**Every file is Markdown with YAML front matter.** The front matter is for the
machine and is schema-validated; the body is for the human and is not optional.

**Subjects and assignments are FLAT and one record per file.** Every value is a
scalar or a list of scalars; nothing nests. `evidence` was a list of objects in
`v0.0.1`, which meant the store could not be read by its own reader — not an
untested round-trip but an impossible one, and the language-neutrality claim
rests on readability rather than writability. Evidence is now
`evidence_kind`, `evidence_value`, `evidence_source`, and a subject with two
independent pieces of evidence for one path is **two assignments**, which is the
better shape anyway: each then carries its own confidence.

**This is the storage rule.** The file layout mirrors the URN, so a reader finds
a file from an identifier without an index:

```
psmodule:PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass
  -> subjects/psmodule/PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass.md
  -> assignments/psmodule/PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass/structure/function.md
```

**Only subjects carry aliases.** An assignment is keyed by subject, facet and
path rather than by an identifier of its own, so its file moves when its
subject's id moves and there is nothing to preserve. 256 records moved at
v0.16.0 and 87 of them owed an alias.

Facets keep one level of block list for `paths`, which is the only nesting
anywhere in the store and the reason the parser supports exactly that much.
**Do not add a second level.** The rule is that the data reshapes, not that the
parser grows: any language can read flat front matter in about thirty lines, and
that is the neutrality claim being true rather than asserted.

**A facet whose body does not say what *does not* belong on it will absorb its
neighbours**, and that is the failure mode that makes a taxonomy useless. The
prose half of a facet file is not decoration.

---

## What must never appear in `knowledge/`

PowerShell is the first reader and writer of this store. It is not its owner.

- No `.psd1`, no `.ps1`, no PowerShell types, no `PSTypeName`
- No `System.*` type names, no serialised objects from any runtime
- No absolute paths — they leak a username into files meant to be shared
- No assumption that keys are case-insensitive, or that a list of one is a scalar

The test is concrete: **if a Python or Go implementation would have to reshape
the data to read it, the shape is wrong.**

**As of v0.2.0 this is demonstrated rather than asserted.**
`readers/read_store.py` reads `subjects/` and `assignments/` in **51 lines of
Python, standard library only** — `sys` and `pathlib`, no YAML package — and
reports the same 97 subjects and 188 assignments the PowerShell readers do. It
is run by hand and is deliberately **not** in CI: a build dependency on a second
runtime would defeat the thing it exists to prove.

It reads the flat records only. `facets/` carries the one nested structure in
the store, and that asymmetry is the design: the bulk data stays flat so any
language can read it, while the handful of facet definitions carry the nesting
that a reader only needs if it is resolving paths.

---

## The contract lives in two places, deliberately

**JSON Schema enforces the fields. A test enforces the flatness. Neither alone
is sufficient, and that seam is a decision rather than an oversight.**

| Enforced by | What it catches |
| --- | --- |
| `SCHEMA/*.json` | required keys, types, patterns, ranges, unknown keys |
| a test over the raw front matter | any value that is not a scalar or a list of scalars |

JSON Schema cannot say *"no value anywhere may be a mapping"*. It can only say
so key by key, which means an exhaustive list of every scalar-typed field and a
schema edit for every new one. That is a worse failure than a documented seam:
a contract that must be edited to add a field will eventually not be edited.

**The consequence, which is real and worth knowing.** The flatness test works on
raw text — it rejects a line beginning with `-`, and a line whose value is
empty. An *inline* mapping slips past it:

```yaml
parent: { id: "psmodule:X" }     # flatness test: passes. schema: rejects.
```

The schema rejects that because `parent` is declared `type: string`. So the two
together are sound and **either alone is not**. A change that weakens one must
check what the other still covers.

There is a third enforcement point on the write side:
`ConvertTo-FlatKnowledgeYaml` throws rather than rendering a nested value, so a
malformed record cannot reach a file in the first place. That is a belt, not a
replacement — it only guards records this module writes, and the store is meant
to be written by other things too.

## Versioning below 1.0.0

**Decision, 2026-08-26 (ledger `0002`).** The original rule — patch for a normal
implementation, minor for a facet added or split, major when the schema changes
shape — breaks below `1.0.0`. Under it, `v0.1.0` reshaping the subject and
assignment schemas would have been `v1.0.0`, which would announce a stable format
on the second day of its existence.

**Below `1.0.0`:**

| Change | Bump |
| --- | --- |
| A schema changes shape | **minor** |
| A facet added, split, merged or renamed | **minor** |
| Everything else | **patch** |

**`1.0.0` is when the store has been read by a second implementation, in any
language.** Not when it feels finished, not when the schemas stop moving — when
something that is not this PowerShell module has read it. Until then the format
is not stable, and a major version claiming otherwise would be a lie told in a
number, which is the hardest kind to notice.

That criterion is deliberately outside this repository's control. It cannot be
satisfied by deciding it has been, which is the property a stability claim needs.

## Ledger body sections

Five, all required, all short. Named exactly:

```
## What changed
## What I learned
## What I could not verify
## Dimensional impact
## Open threads
```

`What I could not verify` is the Skeptic persona's output and is never omitted,
never empty, and never "nothing". There is always something.

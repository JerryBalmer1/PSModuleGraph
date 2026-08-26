# Naming

**Version 0.1.0.** This document is itself versioned, because a naming
convention that changes silently is worse than one that is merely wrong.

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

---

## Subjects are URNs

```
<namespace>:<path>
```

The identifier must be resolvable without knowing what wrote it. That is the
whole test: someone reading `psgallery:Pester` in a file, in another language, in
another repository, should be able to say what it points at.

```
psmodule:PSModuleGraph
psmodule:PSModuleGraph/function/Get-PSModuleClass
psgallery:Pester
concept:static-analysis
facet:structure
```

`facet:structure` is not a special case. A facet is a subject, which is what
lets one facet classify another — see `meta/`.

**Namespace segment** — lowercase, starts with a letter, `[a-z0-9-]`.
**Path segment** — `[A-Za-z0-9._/-]`, case preserved. A PowerShell function is
`Get-PSModuleClass`, not `get-psmoduleclass`; lowercasing it would make the
identifier stop matching the thing it names.

`/` separates containment within a namespace. It is not a facet separator and
carries no hierarchy meaning beyond "this is inside that".

### The namespace set is data

`psmodule`, `psgallery`, `concept` and `facet` are the namespaces in use today.

**This list is data, not an enum in a `.ps1`, and must never become one.** Any
reader needing to know whether a namespace is valid must read it from data.

It is *not yet a facet*, and the proposal to make one was **withdrawn** in
`ledger/0002` under the reflection evidence rule: every subject in the store is
`psmodule:`, so no pair of subjects exists that `namespace` would distinguish
and the existing facets would not. It returns when a second namespace does. A
dimension with one value is not a dimension.

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

Filenames are `<id>.md` for facets and `NNNN-slug.md` for ledger entries. Under
`subjects/` and `assignments/` the path is the URN with `:` replaced by `/`, so
the tree mirrors the identifier.

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

The file layout mirrors the URN, so a reader finds a file from an identifier
without an index:

```
psmodule:PSModuleGraph/function/Get-PSModuleClass
  -> subjects/psmodule/PSModuleGraph/function/Get-PSModuleClass.md
  -> assignments/psmodule/PSModuleGraph/function/Get-PSModuleClass/structure.md
```

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

---

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

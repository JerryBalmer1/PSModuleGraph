# Naming

**Version 0.0.1.** This document is itself versioned, because a naming
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

**This list is data, not an enum in a `.ps1`, and must never become one.** It is
destined to be the `namespace` facet — a file under `facets/`, extensible by
adding a path, with no code change and no release. It is not that yet only
because v0.0.1 ships exactly two facets and this is not one of them; see the open
threads in `ledger/0001`.

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
| `subjects/` | things that can be classified | `subject.schema.json` |
| `assignments/` | subject x facet -> path | `assignment.schema.json` |
| `ledger/` | one implementation per file | `ledger-entry.schema.json` |

Filenames are `<id>.md` for facets and `NNNN-slug.md` for ledger entries. Bulk
files under `subjects/` and `assignments/` are named for what generated them,
with `:` and `/` replaced by `-`, because those characters are not portable in a
filename and this store is meant to travel.

**Every file is Markdown with YAML front matter.** The front matter is for the
machine and is schema-validated; the body is for the human and is not optional.
A facet whose body does not say what *does not* belong on it will absorb its
neighbours, and that is the failure mode that makes a taxonomy useless.

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

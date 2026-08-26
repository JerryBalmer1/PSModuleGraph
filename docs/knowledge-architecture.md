# Knowledge subsystem architecture

Read this before planning work on `Private/Knowledge/` or on `knowledge/`.
`knowledge/NAMING.md` is the authority for the **store**; this is the authority
for the **code that reads and writes it**. Backfilled at v0.3.0.

## Target

**The store outlives the module.** Done means `knowledge/` is lifted into its own
repository, `Private/Knowledge/` is deleted, and a reader written in another
language from `NAMING.md` and the schemas alone agrees with what PowerShell read.
`readers/read_store.py` is the down payment and already agrees exactly — 97
subjects, 188 assignments, 81 below full confidence. The directory boundary is the
mechanism: `knowledge/` sits at the repository root and **must never move under
`src/`**, which keeps the target one `git mv` away.

## The seam

**`Read-KnowledgeFile` and `Write-KnowledgeRecord` are the only functions that
know what a knowledge file looks like on disk.** Above them — the
`Import-Knowledge*` readers, `Get-FacetHealthAssessment`, `Update-KnowledgeStore`
— everything is records: ordered dictionaries and a body string. Below them —
`ConvertFrom-KnowledgeFrontMatter`, `ConvertTo-FlatKnowledgeYaml`,
`Test-KnowledgeDocument`, `New-KnowledgeStorePath` — it is a parser and a
serialiser.

The seam is directional as well as structural: **PowerShell is a tenant, not the
owner.** No `.psd1`, no `PSTypeName`, no serialised object may reach a stored
file. The test is in `CLAUDE.md`: if a Python or Go implementation would have to
reshape the data to read it, it is wrong.

## File layout

```
knowledge/                     <- lifts out; the deliverable
  NAMING.md  SCHEMA/*.json     its own authority, and the contract in JSON Schema
  facets/ subjects/ assignments/ meta/ ledger/ patterns/
  readers/read_store.py        the neutrality proof
src/PSModuleGraph/Private/Knowledge/   the seam pair, the subset parser, the
  schema check, the store-root resolver, three readers, two writers, one grader
src/PSModuleGraph/Public/Update-KnowledgeStore.ps1   the write path
```

## The rule that pays for this

> **The parser is a subset and must not grow. If a knowledge file needs more
> grammar than scalars, inline lists, and one level of block list-of-mappings,
> THE FILE is wrong rather than the parser.**

v0.0.1 proved it the hard way: records were written with nested lists and
mappings, so the store could not be read back by its own reader — not an untested
round trip but an impossible one. The data was reshaped flat rather than the
parser grown: a subset parser behind a JSON Schema is a defensible trade and a
hand-rolled general YAML parser is not.

The corollary belongs here: **the store has a hand-authored half and a generated
half, and only the generated half round trips.** `Write-KnowledgeRecord` throws
on any nested value, so facets, ledger entries and patterns are hand-written,
and `read_store.py` reads only the flat half. Deliberate; nothing announces it.

## What the parent rules mean here

- **Renames never delete.** The old name becomes an alias with a `since` marker;
  removal is not an operation this store has, which is why `instruction-prune`
  does not apply to `knowledge/`.
- **"Could not check" is not "checked and passed".** `Test-KnowledgeDocument`
  returns `IsValid = $null` on a host without `Test-Json -SchemaFile`, never
  `$true`, and `confidence` is required and never defaults to 1.
- **Separate discovery from action.** Reflection proposes, the next
  implementation disposes; `Update-KnowledgeStore` validates every record against
  its schema *before* writing any of it.
- **Report, do not drop.** A file that will not validate names itself and its
  schema; a record silently skipped is a store that quietly disagrees with the
  module it describes.
- **Generation is reproducible.** `-GeneratedAt` and `-Prompt` are stamps, not
  clocks, which lets staleness be found by comparing trees.

## Kaizen in this subsystem

Better shaped means **less that a second reader must be told out of band.**

1. **Would another language need this fact, and is it in `NAMING.md` or a
   schema?** Two are not: directory-to-record-type, and which fields are
   numbers. Both readers hardcode both.
2. **Is this contract in the schema, or only in a Pester test?** Front matter is
   schema-governed; body sections are governed from `tests/`, so a lifted store
   loses half its contract at the boundary.
3. **Is anything PowerShell-shaped leaking into a stored file, and did the
   parser grow?** If it grew, the file that motivated it is the bug.

## Extraction checklist

- [x] `knowledge/` at the repository root, not under `src/`
- [x] No PowerShell types, `.psd1`, or serialised objects in any stored file
- [x] Every record type has a JSON Schema, and a non-PowerShell reader agrees
- [ ] Record type derivable from a file's content, not only its directory, and
      field types derivable from the schema rather than from a reader knowing
- [ ] Body-section contracts live with the store rather than in `tests/`
- [ ] The hand-authored/generated split stated in `NAMING.md`
- [ ] `readers/read_store.py` covers `ledger/` and `patterns/`

## Decisions made and why

Append only. Do not re-litigate these.

**2026-08-26 — `Read-KnowledgeFile` and `Write-KnowledgeRecord` are named as the
seam.** They were already the only format-aware functions, but nothing said so —
a new reader parsing its own front matter would have passed review.

**2026-08-26 — `patterns/` gets a JSON Schema, but patterns are not subjects and
carry no URN.** An area exempt from the store's contract makes the contract
optional, and the two-scale bar erodes without a `minItems` behind it. Going
further and classifying patterns by facets would be a taxonomy decision taken in
the same turn the population was created; ledger 0004 opens a thread instead.

**2026-08-26 — The hand-authored/generated asymmetry is documented, not
removed.** Growing the writer to emit nested YAML grows it toward the general
serialiser this subsystem already refused once; stating the division is cheaper
and keeps the v0.0.1 failure out of reach.

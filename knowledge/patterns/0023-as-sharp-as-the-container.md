---
ledger: "0023"
tag: v0.16.1
scales: [graph node index, knowledge store subject id, ledger continuity gate]
confidence: 0.75
supersedes: []
---

# An identity is only as sharp as the container you put it in

## The pattern

An identifier is built with care. Somebody decides that case matters, writes it
into the naming rules, gives the id a grammar, and preserves the original
casing on purpose because it is what a reader sees. Then the id is put into a
PowerShell hashtable, or run through `Sort-Object -Unique`, or compared with
`-eq`, and every one of those folds case by default. The distinction survives
the whole design and is discarded at the one moment it is used.

What makes it hard to see is that **the code looks correct and the data looks
correct.** The ids in the store are distinct. The nodes in the graph are
distinct. Only the index is not, and an index is invisible: nothing prints it,
no schema validates it, and the wrong answer it produces is a plausible number
rather than an error.

The tell is a sentence of the form *"X and Y are two things"* in a design
document, next to code that stores X and Y in something that cannot tell them
apart. `knowledge/NAMING.md` says a URN path segment preserves case.
`New-GraphNodeId` says the name keeps its original casing. Both were true. Both
were then keyed on `@{}`.

The general shape: **a container's default comparer is a decision, and it is
one nobody made.** Four containers in one function can hold four different
opinions about what equality means, and PowerShell will not mention it.

Measured, on `@('Get-Foo', 'get-foo')`:

| What you wrote | Distinct | Folds case |
| --- | --- | --- |
| `@{}` (hashtable keys) | 1 | yes |
| `Sort-Object -Unique` | 1 | yes |
| `Group-Object` | 1 | yes |
| `-eq` | `True` | yes |
| `-contains` | found | yes |
| `Select-Object -Unique` | 2 | **no** |
| `Group-Object -CaseSensitive` | 2 | no |
| `HashSet[string]::new()`, no comparer | 2 | no |
| `-ceq` | `False` | no |

**`Sort-Object -Unique` folds and `Select-Object -Unique` does not.** Two
cmdlets, one word, opposite answers — and there is nothing at the call site to
tell you which you picked. That single row would have put a handful of wrong
"fixes" in if it had been assumed instead of measured.

Every `Select-Object -Unique` in either repository is therefore **already
correct and must be left alone** — `ConvertTo-GraphDot`'s external-name list,
`Extraction.Semantic`'s lost/gained line sets, `PatternLog`'s scale count, both
`Instructions` suites, `Get-RenderTemplateSet`'s unresolved-slot list,
`NoProducerKinds`' offender lists, and `Render.Infrastructure`'s kind list. They
are named by what they do rather than by line, because line numbers in a pattern
file are stale by the next edit — this paragraph's first version cited five and
three of the five had already moved.

There is a second half, and it is the one that decides the remedy. **A name and
a path are not the same kind of identity.** A PowerShell command name really is
case-insensitive, so folding it is correct — `$nodeIndex` lowercases deliberately
and must keep doing so. A file path is case-insensitive on one operating system
and not on another, so folding it is right on Windows and wrong on Linux, and
the answer is a decision about which filesystem the tool assumes, not a comparer
swap. Only an opaque identifier is unambiguous: it is distinct or it is not, on
every platform, and ordinal is the only comparer that says so.

## Where it was seen

**The graph's node index, v0.11.0.** A node's identity was its lowercased bare
name. Two `Get-TargetResource` definitions in two folders were two nodes and one
addressable target: 144 of SqlServerDsc's 496 nodes could not be reached by any
edge, and the report then labelled them roots — *"entry point or dead code"*.
The fix qualified the id with kind and file. It did not touch `$inbound`,
`$outbound`, `$edgeSeen` or the metric maps, all of which are `@{}` keyed on
that carefully-built id, so the same collapse survived one level down in the
degree counts that decide which nodes are roots.

**The knowledge store's subject id, v0.16.0.** The same migration, five years of
project-time later and in a different subsystem: a subject id named every
definition sharing a name, and 256 records moved to fix it. The gate written to
prove aliases still resolve was built on `@{}` and stayed green while the alias
builder was deliberately broken to lowercase every name it produced — v0.16.0
made that gate ordinal. The *writer* that produces the aliases the gate reads
was left folding them, at `Write-SubjectRecord`, twice in one line.

**The ledger continuity gate.** Thread ids like `0014-t2` are an identity, and
the gate that proves no thread silently left the ledger holds them in an ordinal
`HashSet` and two case-insensitive hashtables and one `-notcontains`, in the
same twenty lines. Nothing has ever exercised the difference, which is why it is
the third scale rather than the first: it is what the pattern looks like before
it costs anything.

## Handoff

**Do not sweep this with a regex and a replace-all.** You will find perhaps
thirty candidates and roughly a third of them are correct as written. Sort them
into three piles before you touch anything:

1. **Opaque identifiers** — node ids, subject URNs, edge keys, thread ids.
   Ordinal, always, both platforms. These are the ones to fix.
2. **PowerShell command names** — `$nodeIndex`, `$ignoreCommands`, the export
   name sets. Case-insensitive is the *correct* semantics because that is how
   the language resolves them. Leave them, and leave the comment saying why, or
   somebody will "fix" them next pass.
3. **File paths** — `$scriptNodes`, the file inventory's `$seen`. These are a
   decision, not a bug: lowercasing is required on Windows, where the same file
   arrives under two casings from a manifest and from an enumeration, and wrong
   on Linux, where two casings are two files. Raise it. Do not quietly pick one.

Measure the container before you change it — the table above cost one minute
and removed a third of the work. The thing you will get wrong is assuming the
container tells you which pile it is in. It does not. `Get-GraphNodeMetric`
holds ordinal `HashSet`s of targets inside case-insensitive hashtables of
sources — the values were right and the index was wrong, in adjacent lines,
written in one sitting. Read what the key *means*, not what the collection is.

**You cannot show any of this red against the corpus, and you should know that
before you try.** Every module the gallery can parse had its node ids, node
paths, node names and `"$Source->$Target"` edge keys counted distinct under
`Ordinal` and under `OrdinalIgnoreCase`: posh-git 94, ImportExcel 243,
Az.Accounts 7, Pester 422, Crescendo 46, SqlServerDsc 532, Az 3 — **1,347
nodes, and every collision count on every axis is zero.** Seven, not eight:
PSDepend does not parse on this machine at all. Every defect in this class is
latent. A green corpus run is not evidence that a fix worked, and it was not
evidence of anything before the fix either.

What would be evidence is a purpose-built fixture, because **two functions
differing only in case in one file is legal PowerShell** — measured: the
parser returns two `FunctionDefinitionAst` nodes, one `Path`, names `Foo` and
`foo`, and does not dedupe them. That produces
two node ids differing only in case on Windows, and it exercises `$edgeSeen`,
`$inbound`/`$outbound`, `Get-GraphNodeMetric` and `New-KnowledgeStorePath`'s
`$byId` at once. Nothing like it exists.

Pile three's two sites cannot be reproduced on Windows **at all**:
`Get-PSModuleFileInventory`'s `$seen`, and `Get-PSModuleDependencyGraph`'s
`$scriptNodes`, both keyed on a `.ToLowerInvariant()` of a file path. On a
case-sensitive
filesystem `Foo.PS1` and `foo.ps1` are two files, and the inventory one drops
the second from the inventory entirely — so it is never parsed, and nothing
downstream can notice a file that was never offered. Windows cannot exhibit
either by construction. The Ubuntu leg is the only place they are falsifiable.

And when you fix one, look for its producer. The store's gate was made ordinal
one iteration before its writer was, and for that iteration the store had a
correct check over incorrect data.

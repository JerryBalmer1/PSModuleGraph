---
id: "0013"
tag: v0.11.0
date: 2026-08-27
prompt_intent: Make a node's identity its qualified path rather than its lowercased bare name, follow the blast radius wherever the collision was being leaned on, re-run the corpus and diff every result against its committed record.
personas: [integrator, taxonomist, skeptic]
open_threads: [0013-t1, 0013-t2, 0013-t3]
closes: [0012-t5, 0010-t1]
carries_forward: [0012-t1, 0012-t2, 0012-t3, 0012-t4, 0011-t1, 0011-t2, 0010-t2, 0009-t1, 0009-t3, 0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0013 — a name is not an identity

## What changed

**A node's id is `kind:module/relative/path:Name`.** Kind for the existing
discriminator, the path relative to `ModuleBase` with forward slashes so the id
carries neither the machine nor the operating system, the name at its original
casing. `node.name` is untouched: the id got longer, the label did not.

**A call by name no longer has one answer, and the edge says which it got.**
`Unique`, `SameFile`, or `Ambiguous`. Ambiguous emits an edge to every candidate.

**One `<script>` node per file** instead of one per module.

**Two fixes outside the identity.** The `Dependencies` task now checks the
version of the renderer it resolved. Four `Get-Variable` probes stopped writing
an error record for an absence that is ordinary.

**The contract is untouched.** `node.id` is "a string, unique within the
payload, opaque to the renderer" — a longer opaque string satisfies it as
written. `ConvertTo-GraphJson` and the HTML seam list payload fields explicitly,
so `Resolution` and `TargetCandidates` on an edge cannot leak. `Stats` gained two
counts and does reach the payload, under the clause that calls `meta.stats`
"deliberately unconstrained… no backend reads it".

**BREAKING at the prompt**, and the version says so below.

## What I learned

**The eight diffs. A module that did not move is as informative as one that
did.**

| module | nodes | edges | roots | unresolved | what moved it |
| --- | --- | --- | --- | --- | --- |
| SqlServerDsc | 496 → 532 | 605 → 1271 | 186 → 252 | 528 → 807 | the collision, and the script split |
| ImportExcel | 105 → 243 | 148 → 401 | 35 → 173 | 295 → 707 | the script split, almost entirely |
| posh-git | 87 → 94 | 77 → 78 | 44 → 51 | 193 → 201 | the script split |
| Crescendo | 42 → 46 | 11 → 19 | 28 → 32 | 30 → 46 | the script split |
| Az.Accounts | 4 → 7 | 3 → 3 | 1 → 4 | 38 → 47 | the script split |
| Pester | 421 → 422 | 597 → 597 | 122 → 123 | **19 → 19** | one file's top level |
| Az | 3 → 3 | 2 → 2 | 1 → 1 | 23 → 23 | nothing |
| PSDepend | failed | failed | failed | failed | still two root manifests |

Every module's diagnostics went 1 → 0.

**Roots went up, and I expected them to go down.** That is the finding. 144
nodes were roots *because their name was shadowed*, and I read that as "144
false roots that will disappear". They did not disappear: they were roots
already, for the wrong reason, and the fix did not remove them — it moved the
inbound edges onto the right nodes and made the reason inspectable. SqlServerDsc:
186 of 496 roots became 252 of 532, and the composition is now checkable — 62 are
`*-TargetResource`, 37 are file top levels, and only 44 edges in the whole module
target a `-TargetResource` at all, because the LCM calls them and the LCM is not
in the module. A number that rose is the honest answer; a number that fell would
have needed explaining.

**Six of eight modules moved for the script-node split, not the collision.**
ImportExcel's entire +138 is file top levels that had been collapsed into a
single node reporting the path of whichever file was parsed first. Only
SqlServerDsc really exercises the name collision. That is worth knowing about
the corpus as much as about the fix: the finding was measured on one module and
the fix is being validated on one module.

**The ambiguity found something no one was looking for.** 702 of SqlServerDsc's
1,271 edges are ambiguous, and they are not the DSC entry points — they are
`Get-ComputerName` (190 edges), `New-InvalidOperationException` (110),
`New-ErrorRecord` (74), each with exactly two definitions. Checked by hand:
SqlServerDsc ships **two copies of DscResource.Common 0.24.5**, one at
`Modules/DscResource.Common/` and one nested inside
`Modules/DscResource.Base/2.0.0/Modules/DscResource.Common/0.24.5/`. Same file,
same line numbers, two copies on disk, and which one wins depends on load order.
The collapsing index hid it completely. This is also the `using module` chain
`0012` predicted, arriving as a physical nesting rather than a reference.

**Pester's 19 unresolved entries are still 19, and that is the right answer.**
Its single duplicated name, `ConvertTo-HumanTime`, produces no ambiguous edge;
its 597 edges are 596 `Unique` and one `SameFile`. The one new node is
`script:Pester.ps1:<script>`, which had been sharing a node with
`script:Pester.psm1`. Pester's problem is the sigil filter that drops 491 call
sites, which this iteration did not touch, and the corpus says so by not moving.

**Az.Accounts went 4 → 7 and nobody predicted it.** The three new nodes are
`StartupScripts/AzError.ps1`, `InitializeAssemblyResolver.ps1` and
`InitializePSStyle.ps1` — three files whose top-level code had been folded into
one node carrying one of their paths. It is the same collision in the one place
it is guaranteed. The empty-graph signal is unchanged and slightly louder: 47
declared exports against three real functions.

**The fixture proved the change is inert where the collision was absent.**
SampleModule: 9 nodes, 5 edges, 4 roots before and after. Only the ids and the
two new stats moved. A fix that changed a module with no duplicate names would
have been the wrong fix.

**Two things were leaning on the collision that I did not expect.** The
extraction golden compares byte for byte and every id in it changed, so it had to
be re-recorded — which ends its provenance as the artefact rendered from a
pristine pre-move worktree, and its comment no longer claims otherwise.
`0011-t2` said a re-recorded golden only catches accidents; it is now realised
rather than hypothetical. And the semantic comparison keyed nodes and links on
the id, so it would have asserted the old collision was correct; it is re-keyed
on kind and name, with the two gained stats named as a closed list the way that
file already handles gained payload fields.

**The version gate would not have caught what prompted it, and says so.**
`RequiredModules` declares `ModuleVersion = '0.3.0'`, a floor. The drift that
cost a worktree was a renderer at 0.6.0, which satisfies a floor. Proved both
directions: 0.2.0 is now refused by name, 0.6.0 still passes. Making it catch
the real case means turning the floor into a pin, which changes what a consumer
of the manifest is promised. Logged as `0013-t2`.

**The error record meant nothing, measured rather than assumed.** Exactly one per
session, on the first call, for the absence the lazy initialiser handles.
`-ErrorAction SilentlyContinue` suppresses the display and still writes to
`$Error` and to any `-ErrorVariable`; `Ignore` does neither. Four probes had it,
not one.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**A candidate, and this iteration is the evidence for it.** `resolution` — how a
reference was tied to what it names: uniquely, by locality, or not decidably.
It changes what a reader can see and do: 702 of SqlServerDsc's edges are
ambiguous and the report draws them identically to the 432 that are not. It is a
property of an edge, and the store has no shape for classifying edges, which is
the same wall `0012` hit. Two iterations now want it. Not created — proposed.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?**
**Yes, and `0012` predicted it.** A subject is a name, so 32 definitions of
`Get-TargetResource` would collapse in the store exactly as they collapsed in
the node index. The graph no longer collapses them and the store still would.
`Update-KnowledgeStore` has never been run against a corpus module, so this
remains predicted rather than observed. Opened as `0013-t1`.

**5. Could this facet classify facets?** Not applicable this iteration.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged.

## What I could not verify

The Skeptic's section. It is never empty.

- **That the numbers moved to the RIGHT numbers.** A diff shows movement. Five
  nodes were checked against source by hand: `Get-TargetResource` has 32
  definitions in SqlServerDsc, each id names a real `function Get-TargetResource`
  at the file and line the record gives, and
  `function:DSCResources/DSC_SqlAG/DSC_SqlAG.psm1:Get-TargetResource` has exactly
  one inbound edge, from `Test-TargetResource` at `DSC_SqlAG.psm1:700`, which
  reads `$getTargetResourceResult = Get-TargetResource @getTargetResourceParameters`
  — the same file, resolved `SameFile`. Five of 532 nodes and one of 1,271 edges.
  The other 527 and 1,270 are unchecked.
- **That emitting an edge to every ambiguous candidate is right.** It is a
  defensible answer to an undecidable question and it is not the only one. It
  inflates SqlServerDsc's edge count by 666, and a reader looking at the drawing
  sees 702 edges that mean "one of these" rendered exactly like edges that mean
  "this one". Opened as `0013-t3`.
- **That preferring the same file is a rule rather than a heuristic.** PowerShell
  gives every function in a module one scope; the file is not a scope. It is
  right for the shape the corpus contains — a resource per file calling its own
  neighbours — and it would be wrong for a module that deliberately shadows a
  helper from elsewhere and expects the later definition to win. Nothing in the
  corpus does that, which is not the same as nothing doing it.
- **That the id is stable across machines.** It is built from a path relative to
  the module base with separators normalised, which is designed for it, and every
  result in `gallery/results/` has still only ever been produced on one machine.
  `0012-t1` and this are the same gap seen twice.
- **That the fix generalises.** One module in eight exercises the collision at any
  scale. SqlServerDsc has 53 duplicated names; the next largest is Crescendo with
  four.
- **That the golden still detects anything worth detecting.** It was re-recorded
  from the output of the code it is meant to be checking. It catches an
  accidental change from here on and it proves nothing about the extraction any
  more, and no other artefact took over that job.
- **That two stats fields are the only payload change.** They are the only ones I
  added. `ConvertTo-GraphJson` was read to confirm the edge fields cannot leak;
  nothing enforces that, and the next field added to `Stats` will reach the
  payload the same way with nobody deciding it should. 

## Open threads

1. **[0013-t1] The knowledge store still collapses what the graph stopped
   collapsing.** A subject is a name, so 32 definitions of `Get-TargetResource`
   would be one subject. Predicted from the code, not observed:
   `Update-KnowledgeStore` has never been pointed at a corpus module.
2. **[0013-t2] The renderer requirement is a floor and the repository treats it
   as a pin.** The gate refuses a version below it and accepts every version
   above it, including the one that broke the goldens. CI checks out an exact
   ref and `PreTag` asserts the two agree; the build cannot use either. Turning
   the floor into a pin changes what the manifest promises a consumer.
3. **[0013-t3] An ambiguous edge is drawn like a certain one.** 702 of
   SqlServerDsc's 1,271 edges mean "one of these, undecidably". The producer now
   knows which; the payload does not carry it and the report cannot show it, and
   saying it would be a contract change.

Carried: **[0012-t1]** the corpus is a hypothesis with eight instances;
**[0012-t2]** `timeout` and `missing` have never executed; **[0012-t3]** nothing
validates a result against its schema; **[0012-t4]** the lock has only been
checked by the session that wrote it; **[0011-t1]** nobody has asked what a JSON
consumer reads; **[0011-t2]** a re-recorded golden only catches accidents — now
realised; **[0010-t2]** a test scoped to a module that no longer holds what it
tests still passes; **[0009-t1]** one fixture proves the move; **[0009-t3]**
nothing proves the dependency is really required; **[0008-t1]** nothing has been
trained on the corpus; **[0008-t2]** the section headings are hardcoded;
**[0008-t3]** `corpus/` and `gallery/` are outside lint and the charter test;
**[0007-t1]** hot and external are nearly the same colour; **[0007-t2]** should
the store hold measurements; **[0006-t1]** the http-origin editor-link claim is
unverified; **[0005-t1]** skill descriptions are unbudgeted; **[0005-t2]** the
ceiling's headroom is a guess; **[0005-t3]** nothing measures whether an
on-demand file is read; **[0004-t1]** should patterns be subjects;
**[0004-t4]** `iteration-close` is model-invocable and it pushes; **[0003-t1]**
`facet-health` grades itself flatteringly; **[0003-t2]** coverage conflates
unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.

Closed: **[0012-t5]** a node's identity was its name — it is now its qualified
path, and the 144 unaddressable nodes in SqlServerDsc are addressable.
**[0010-t1]** nothing told this repository the renderer's surface had moved — the
build now names the version it resolved and refuses one below the requirement,
which is less than the thread asked for and is why `0013-t2` opens.

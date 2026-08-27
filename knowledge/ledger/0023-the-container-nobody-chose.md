---
id: "0023"
tag: v0.16.1
date: 2026-08-27
prompt_intent: Close the CRLF finding by deciding which line ending the store writes, record the checkout-depth ceiling where a person would look, rule on whether an alias may be followed twice, and sweep both repositories for every other place a name was used where an identity was needed.
personas: [integrator, taxonomist, skeptic]
open_threads: [0023-t1, 0023-t2, 0023-t3, 0023-t4, 0023-t5]
closes: [0022-t1, 0022-t2, 0022-t3]
carries_forward: [0001-t7, 0003-t1, 0003-t2, 0005-t1, 0006-t1, 0008-t2, 0008-t3, 0009-t3, 0010-t2, 0012-t2, 0012-t3, 0012-t4, 0013-t2, 0014-t2, 0014-t3, 0015-t1, 0018-t1, 0018-t2, 0018-t3, 0019-t1, 0019-t2, 0019-t3, 0020-t1, 0021-t1, 0022-t4, 0022-t5]
recovers_threads: []
accepts_threads: []
prune_proposals: []
supersedes: []
---

# 0023 — the container nobody chose

## What changed

**The store writes LF, and the freshness test can now see that it does.**
`.gitattributes` already said `*.md text eol=lf` and `Write-KnowledgeRecord`'s
own docstring already claimed LF endings; neither was true of the bytes. The
body arrives as a here-string carrying its source file's endings, and joining
the *lines* with LF settles what is between them and nothing about what is
inside. Every record in the store was LF front matter over a CRLF body, and the
committed blobs were LF only because git normalised on the way in.

The body is normalised now. Front matter deliberately is not: a scalar holding a
carriage return is a record this store's own reader cannot read, and normalising
it would hide that rather than fix it. `KnowledgeRoundTrip` reads with
`ReadAllText` and compares as read.

**`0022-t3` is ruled a limit, not a defect.** An alias is followed once. The
argument that decides it is not that chaining is hard — it is that chaining is
**the wrong fix for a second rename**. `aliases` is a set and the store is
generated, so a twice-renamed subject should carry *both* former ids, written by
a builder that knows the whole history. One hop over N aliases is the same
information with a bounded read and no cycles; N hops is rename history as a
graph, in which a name renamed away and back is a loop. The limit is on the
resolver and **the obligation is on the writer** — which is the part that would
have been missed by filing it as a defect, because it points the next migration
at the wrong file. `docs/constraints.md`, and the resolver says it too.

**The checkout-depth ceiling is written down with its number and its date.**
The longest repo-relative store path is 163 characters, which leaves **95** for
the checkout root against `MAX_PATH` 260; the gate at 180 guarantees **78** into
the future. The assertion now names both figures and what to do, because the
person who meets this is reading a red line, not this entry.

**The sweep. Fifteen candidates, three piles, eleven changed.** See
`knowledge/patterns/0023`.

**The gallery was re-run, all eight, because the graph changed.** Every count in
every committed record is identical at `0.16.1`. PSDepend fails to parse and
already did at `HEAD`, for a reason that has nothing to do with this iteration.

## What I learned

**A gate can be fixed one iteration before its producer is.** v0.16.0 made the
alias containment ordinal after breaking the frozen builder and watching the
whole `Describe` stay green. `Write-SubjectRecord`, which *writes* the aliases
that gate reads, kept `-ne` and `Sort-Object -Unique` — two case-folding
operations in one line. For one tag this repository had a correct check over
data produced incorrectly, and nothing about the green build could say so.

**The values were right and the index was wrong, in adjacent lines.**
`Get-GraphNodeMetric` held ordinal `HashSet`s of targets inside case-insensitive
hashtables of sources. `HashSet[string]` defaults to ordinal and `@{}` does not,
so one author writing one function in one sitting produced two different
opinions about equality without choosing either. That is the pattern's whole
mechanism: **a container's default comparer is a decision, and it is one nobody
made.**

**Three piles, and only one of them is a bug.** Command names must fold —
PowerShell resolves them case-insensitively, so `$nodeIndex` lowercasing is
correct and stays. File paths are a *decision*: lowercasing is required on
Windows, where the same file arrives under two casings from a manifest and from
an enumeration, and wrong on Linux, where two casings are two files. Only opaque
identifiers are unambiguous. `$scriptNodes` and the file inventory's `$seen` were
left alone and raised rather than swapped. `0023-t2`.

**PSGraphRender's product code is clean, and not by luck.** Its PowerShell never
indexes a node id, because the core constraint is that it does not know what a
node is. The ids pass through to JavaScript, whose object and `Map` keys are
ordinal. A rule written for one reason paid out for another. Only its copy of
the ledger gate needed the fix.

**Proved red, then green, on the line-ending half.** `KnowledgeRoundTrip` went
red naming all 282 records once the normalisation was removed, and green after
`./build.ps1 -Task Knowledge` rewrote them. The committed blobs did not move,
which is exactly what `0022-t2` predicted.

**Git Bash `grep` translates carriage returns on Windows.** Searching for one
reported zero matches in a file that was 213 lines of CRLF, while `file` and
Python both reported it correctly. An investigation into line endings nearly
concluded from a tool that could not see them.

## Dimensional impact

**1. Did this reveal a distinction the design could not express?** Yes. *A name*
and *an identity* were one word in the code. Three piles is the distinction the
design now has and did not.

**2. Is an existing seam doing two jobs?** Yes, and it stays that way for now:
a node id embeds a file path, so its case-sensitivity is an identifier question
wearing a filesystem question's clothes. Resolved here by ruling the id opaque,
which the renderer's contract already said it was.

**3. Did two seams turn out to be the same thing?** Yes. The graph's node index
and the store's subject id are the same defect at two scales, five tags and two
subsystems apart, found independently both times.

**4. Did anything land at a depth the design did not anticipate?** Yes. The
v0.11.0 fix stopped at the id and never reached the degree counters the id feeds,
so the defect it closed survived one level below where it was looking.

**5. Could this classify itself?** Partly. The sweep found the store's own
grading function, `Get-FacetHealthAssessment`, miscounting coverage by the same
mechanism — so the thing that grades the store was subject to it.

### Prune, this iteration

**A move: none.** **A deletion proposal: none.**

## What I could not verify

The Skeptic's section. It is never empty.

- **Nothing has ever consulted an alias in anger, and this store never had the
  defect the migration fixes.** Standing from `0022`. Every subject here carries
  exactly one alias and every one of them resolves; the one-to-many case is
  exercised by a six-file fixture and one hand-run.
- **No case-only collision exists anywhere in the corpus, and that is now
  measured on this machine.** Node ids, node paths, node names and
  `"$Source->$Target"` edge keys, counted distinct under `Ordinal` and under
  `OrdinalIgnoreCase`, for every module the gallery can parse: posh-git 94,
  ImportExcel 243, Az.Accounts 7, Pester 422, Crescendo 46, SqlServerDsc 532,
  Az 3 — **1,347 nodes, and every collision count on every axis is zero.**
  Seven, not eight: PSDepend does not parse here at all, and did not at
  `HEAD` either, with the identical diagnostic *"Multiple manifests found …
  Pass a specific .psd1 path"*. A peer session reported 1,418 including
  PSDepend at 71; that figure does not reproduce on this machine and I have
  not used it.

  So every fix in this sweep reasons from a comparer to a consequence and
  **not one of them can be shown red against real data.** The one behavioural
  thing ever observed — the v0.16.0 gate staying green under a deliberately
  broken builder — is the reason to believe the reasoning, and it is one
  observation. Closing this needs a fixture, not a corpus: two functions
  differing only in case in one file is legal PowerShell and nothing in either
  repository builds one. `0023-t5`.
- **The sweep did not run on Linux, which is the only platform where most of
  this can bite.** Windows cannot hold `Foo.ps1` and `foo.ps1` in one directory,
  so a large part of the defect class is unreachable on the machine that fixed
  it. Every claim here about what happens on Linux is a claim about a platform
  no leg of this build has run. `0023-t3`.
- **"8 tasks, 0 errors" describes one run, not the build.** PSGraphRender's
  `Test` leg failed five containers on Pester's escaped-`break` guard once at
  `d8e8dde` — the commit `v0.13.1` tags — and has not since. That is
  PSGraphRender's thread and it is written down there, in its `0016`; noted here
  only because this entry's sibling tag rests on the same run.
- **The three piles are my judgement and nothing enforces them.** Nothing stops
  the next `@{}` keyed on an identity, and nothing stops somebody "fixing"
  `$nodeIndex` into ordinal and quietly breaking call resolution for every
  differently-cased call site in a real module. The pattern file's handoff is
  the whole defence and it is prose.
- **The corpus run says nothing moved; it does not say nothing can.** All eight
  vendored modules were re-run against their committed records and every count
  in every record is **identical** — nodes, edges, roots, leaves, unresolved,
  functions, classes, enums, files, assemblies, declared exports. That is real
  evidence the eleven changes are behaviour-preserving on real modules, and it
  is *only* that: with zero case-only collisions in the corpus, an identical
  result is also exactly what a set of no-op changes would produce. The two
  hypotheses are indistinguishable here. `0023-t5`.
- **That the checkout ceiling is 95 and not something else.** It is 259 minus a
  separator minus the longest path, computed on one machine with one checkout
  root, and `MAX_PATH` behaviour differs by API and by whether a call goes
  through the Unicode long-path form. The number is a budget, not a measurement
  of the failure.

## Open threads

1. **[0023-t1] The alias builder owes every former id and nothing says so in
   code.** Ruling `0022-t3` a limit put an obligation on
   `Get-LegacyKnowledgeSubjectId`: after a second rename it must emit *every*
   former shape, not the most recent. It is written in `docs/constraints.md` and
   in a docstring, and no gate can fail because the case does not exist yet.
2. **[0023-t2] Path case-sensitivity is a decision that has not been made.**
   `$scriptNodes` and `Get-PSModuleFileInventory`'s `$seen` lowercase a file
   path. That is required on Windows and wrong on Linux, and the fix is a
   comparer chosen once from a platform assumption this project has never
   stated. Raised rather than taken.
3. **[0023-t3] Every claim in this entry about Linux is untested.** Most of the
   defect class needs a filesystem that distinguishes `Foo.ps1` from `foo.ps1`,
   and no leg of this build runs on one.
4. **[0023-t4] The gallery baseline is stamped four minors stale, deliberately.**
   The committed records say `parserVersion 0.12.0`, `parserCommit 95ba3a2`, and
   the re-run at `0.16.1` reproduced every count exactly. The results were
   **reverted rather than re-stamped**: the only thing that would have changed is
   provenance, and `docs/constraints.md` already records that a golden which gets
   re-recorded whenever it is touched only catches accidents. The cost is that
   the baseline now claims an older toolchain than the newest run that matched
   it, and nothing anywhere says the two are the same recording.
5. **[0023-t5] Nothing in either repository can make this defect class fail.**
   The corpus holds 1,347 parseable nodes and zero case-only collisions on any
   axis, so eleven fixes
   were made and none of them could be shown red first — the inverse of what
   `.claude/skills/gate-falsifiability` asks for. Two functions differing only
   in case in one file is legal PowerShell and would exercise `$edgeSeen`,
   `$inbound`/`$outbound`, `Get-GraphNodeMetric` and `New-KnowledgeStorePath`'s
   `$byId` at once. The fixture is the close.

Carried: **[0001-t7]** the facet seam in the report, designed and not built;
**[0003-t1]** `facet-health` grades itself flatteringly; **[0003-t2]** coverage
conflates unassigned with inapplicable; **[0005-t1]** skill descriptions are
unbudgeted; **[0006-t1]** the origin claim is unverified; **[0008-t2]** the
section headings are hardcoded; **[0008-t3]** `corpus/` is outside lint and the
charter test; **[0009-t3]** nothing proves the dependency is really required;
**[0010-t2]** a test scoped to a module that no longer holds what it tests still
passes; **[0012-t2]** two failure outcomes have never executed; **[0012-t3]**
nothing validates a result against its schema; **[0012-t4]** the lock has only
been checked by the session that wrote it; **[0013-t2]** the renderer
requirement is a floor treated as a pin; **[0014-t2]** the golden's name claims a
provenance it lost; **[0014-t3]** JSON and CSV describe the same graph
differently; **[0015-t1]** three whole-document comparisons are skipped;
**[0018-t1]** the verdicts were proposed in one pass; **[0018-t2]** a drop judged
over the whole chain cannot be told from a cover-up; **[0018-t3]** a merge across
repositories has no id grammar; **[0019-t1]** thirty-eight verdicts were applied
in one pass; **[0019-t2]** the publishing gate exempts `knowledge/` and
`CHANGELOG.md`; **[0019-t3]** a thread cannot move to the repository that can act
on it; **[0020-t1]** a Close records a reason and nothing checks the reason;
**[0021-t1]** a re-record is a decision the first time and a habit by the third;
**[0022-t4]** the alias scan reads every subject in the store; **[0022-t5]** the
one-to-many shape is tested at three.

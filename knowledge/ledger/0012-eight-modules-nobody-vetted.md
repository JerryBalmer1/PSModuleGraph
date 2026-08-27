---
id: "0012"
tag: v0.10.0
date: 2026-08-27
prompt_intent: Give the parser real input - five to eight gallery modules chosen for what each is expected to break - and a committed shape for recording what happens, then report the failures rather than fixing them.
personas: [integrator, archivist, skeptic]
open_threads: [0012-t1, 0012-t2, 0012-t3, 0012-t4, 0012-t5]
closes: []
carries_forward: [0011-t1, 0011-t2, 0010-t1, 0010-t2, 0009-t1, 0009-t3, 0008-t1, 0008-t2, 0008-t3, 0007-t1, 0007-t2, 0006-t1, 0005-t1, 0005-t2, 0005-t3, 0004-t1, 0004-t4, 0003-t1, 0003-t2, 0003-t3, 0001-t7]
prune_proposals: []
supersedes: []
---

# 0012 — eight modules nobody vetted

## What changed

**`gallery/`** — eight modules from the PowerShell Gallery, pinned by version,
each chosen because it breaks something the others do not. Source is never
committed: `corpus.json` names them and what was predicted of each,
`corpus.lock.json` pins a URI and a SHA-256 per package, and `fetch.ps1` refuses
bytes that do not match.

**A result contract.** `gallery/contract/run-result.schema.json`, one JSON file
per module per run under `gallery/results/`, committed. Module, source, hash,
toolchain, UTC start, wall time, the five counts, and every error or warning the
run raised. Git is the history; there is no database.

**A run that throws still produces a record.** `run.ps1` gives every module its
own process with a timeout and writes the failure record itself when the worker
dies without writing one. `failed`, `timeout` and `missing` are outcomes, not
absences.

**Two fixes, out of nine findings.** `using module` and
`Add-Type -Path (expression)` each took the whole graph down and each is
unambiguously wrong. The rest are logged with the module that surfaced them.

**Not in `corpus/`.** That directory is chartered as the development-LOOP corpus
and is meant to leave by `git mv corpus/`. Two meanings of one word in one tree,
and a lift that stops working. `gallery/` is named for where the modules come
from.

## What I learned

**The failure list, worst first — and worst is not loudest.**

| # | What it does | Measured on |
| --- | --- | --- |
| 1 | 144 of 496 nodes cannot be addressed by any edge, and are therefore reported as roots | SqlServerDsc 17.5.1 |
| 2 | 491 of 1,552 call sites are dropped by a filter and reported nowhere | Pester 5.7.1 |
| 3 | Inheritance that crosses a module boundary vanishes rather than becoming unresolved | SqlServerDsc 17.5.1 |
| 4 | 47 declared exports, 4 nodes, outcome `ok` | Az.Accounts 5.5.2 |
| 5 | 4 of 19 "unresolved targets" hold multi-line script blocks where a command name should be | Pester 5.7.1 |
| 6 | `using module` takes the whole graph down — **fixed** | SqlServerDsc 17.5.1 |
| 7 | `Add-Type -Path (expression)` takes the whole graph down — **fixed** | Az.Accounts 5.5.2 |
| 8 | Two root manifests in a version-named directory refuse to resolve — **not fixed** | PSDepend 0.5.0 |
| 9 | An error record on the first file of every module, on every run | all eight |

**The node index is keyed by a bare name and the last definition wins.** Two
functions called `Get-TargetResource` in two resource folders are two nodes and
one index entry, so every edge to that name points at whichever was parsed last
and the other node can never be an edge target. SqlServerDsc has 53 duplicated
names and **144 shadowed nodes, 29% of the graph**. They are then reported as
roots — 186 roots of which 144 are artefacts. The report's word for a root is
"entry point or dead code", and it is neither. This is the worst thing in the
list because it is not an error, a warning or a gap: it is a confident answer.

**A third of Pester's call sites are removed by one line.** Pester dispatches
almost everything through `& $SafeCommands['Get-Content']`. `GetCommandName()`
returns null, the fallback takes the extent text, and the graph's
`^[$.@]` filter drops it. **491 of 1,552 sites, 127 distinct expressions, none
of them surfaced as unresolved.** The rule in `CLAUDE.md` is that a dynamic
invocation appears in the output as unresolved rather than being filtered away,
and this filter is the thing the rule was written against. The graph reports
Pester's entire external surface as 19 entries.

**The same filter's leftovers are unreadable.** Four of those 19 have thirty
lines of script block in `TargetName`. The rule was obeyed in the letter — it was
reported — and the report cannot be read.

**Inheritance stops at the module edge silently.** SqlServerDsc has 18 classes,
9 of them with a base type, and 7 `Inherits` edges. The two missing bases are
defined in `DscResource.Base`, vendored inside SqlServerDsc and reached by
`using module .\Modules\DscResource.Base`. The `using module` is now reported.
The inheritance across it is dropped — not reported as unresolved, which is what
the same rule requires of an unresolvable call.

**The empty graph the corpus was built to catch is Az.Accounts.** 47 declared
exports, four nodes, `outcome: ok`, no diagnostic. Every command it exports is a
C# cmdlet in one of 73 DLLs. Nothing in `Stats` can say so — `NodeCount` is 4 and
that is a true statement about what was found. It is legible only because the
result record puts `declaredExports` next to `nodes`, which was added for exactly
this and is the one thing in the contract that earns its place twice.

**And it has a control.** `Az` 16.2.0 reports three nodes and is correct: a
rollup with a near-empty `.psm1` and nothing else. Two modules that both report
almost nothing, one wrongly. The pair is why the corpus needed both.

**Three predictions were wrong, and two of them were wrong about the module
rather than about the parser.**

- Pester was predicted the slowest run "by a wide margin" and was fourth at
  2.7 s, because it is three files. **ImportExcel is the slowest at 6.3 s for
  215 files.** Size in functions is not what costs; size in files is.
- Pester was predicted to show node inflation "several times over" from nested
  functions. It is five. Across the corpus the largest is two. The mechanism is
  real and the magnitude was invented.
- `Az` was predicted to show around eighty `RequiredModule` entries. Its manifest
  says `RequiredModules = @()`; the rollup declares its dependencies in the
  `.nuspec`, which is not a manifest and which nothing here will ever read. The
  parser was right and the prediction was about a module I had not opened.
- PSDepend was predicted to succeed with a confidently wrong graph. It threw
  before reaching one.

**A prediction that was right by the wrong route.** Az.Accounts' empty graph was
predicted precisely. The first run never got there — it crashed in
`Get-PSModuleAssembly` for an unrelated reason. Had the crash not been fixed, the
prediction would have been scored as confirmed by a module that never produced a
graph at all.

**Two fixes, and both were invisible to a nine-node fixture for a reason.**
`UsingStatementAst` has no `ModuleName` property; the fixture has
`using namespace` and no `using module`, so five tags went past a line that takes
the whole graph down the moment it is reached. `Split-Path` is provider-aware, so
the extent text of `([System.IO.Path]::Combine(...))` is read as a provider
name — nothing that reads other people's source may hand a path cmdlet text that
has not been shown to be a path.

**The parser emits an error record on the first file of every module.**
`Get-Variable -Scope Script -ErrorAction SilentlyContinue` suppresses the action
and still records the error, so every one of the eight result files carries it
and a caller running with `$ErrorActionPreference = 'Stop'` cannot use the
command at all. Left in place deliberately: it is uniform across the corpus,
which makes it the cheapest possible demonstration that the diagnostics channel
is wired.

**Nothing was absurdly slow and nothing timed out.** Eight modules, 730 files,
under twenty seconds in total. The timeout exists because "absurdly long" has to
be a number before a corpus can record it, not because anything reached it.

**Building the corpus caught something the corpus is not about.** The suite went
red on two renderer tests before any parser change: the sibling PSGraphRender
checkout is at v0.6.0 and this module pins v0.3.0, and the build resolves
whatever is built next door rather than what the manifest names. The pin held
once a v0.3.0 worktree was built and pointed at. `0010-t1` says nothing tells
this repository when the renderer's surface moves; this is that thread arriving
as a red build with a misleading cause.

## What I could not verify

The Skeptic's section. It is never empty.

- **That eight modules chosen for what they were expected to stress are a
  sample.** They are a hypothesis with eight instances, and they confirmed it
  more readily than they surprised me — six of eight behaved close to prediction.
  What a random eight would have found is unknown and stays unknown. The user's
  own line, adopted. Opened as `0012-t1`.
- **That the shadowed-node count means what I say it means.** 144 nodes cannot be
  an edge target, which is arithmetic. That every one of them is *wrongly*
  reported as a root is an inference: some may genuinely have no caller. Nothing
  separates the two, and nothing can without deciding what a node's identity is.
- **That 491 dropped call sites are 491 lost facts.** They deduplicate; the
  distinct expression count is 127; how many of those resolve to a command the
  graph could have named is unmeasured. The claim that survives is that the
  number reported is zero.
- **That the counts are comparable across machines.** Every result in
  `gallery/results/` was produced by one PowerShell on one Windows machine
  against one set of vendored bytes. `toolchain` records enough to notice a
  difference and nothing has yet been run twice.
- **That a timeout would be recorded correctly.** The path is written and has
  never executed — nothing in the corpus takes more than seven seconds against a
  300-second limit. The same is true of `missing`. The one failure path proven is
  the one the parser took on its own. Opened as `0012-t2`.
- **That the schema is enforced.** Nothing validates a result file against
  `run-result.schema.json`. The writer and the schema were written together,
  which is precisely the arrangement that stops being true on the second writer.
  Opened as `0012-t3`.
- **That `gallery/` is any more covered by the build than `corpus/` is.** Neither
  is linted, neither is exercised by `./build.ps1`, and `0008-t3` has said so
  about one of them for four tags. It now applies to two.
- **That Crescendo has no enums.** It reports zero and there are zero `enum`
  declarations in its `.psm1`, which agree — but they agree because I counted
  with the same naive assumption both times.
- **That the corpus is reproducible.** `fetch.ps1` verifies against the lock and
  has only ever run in the direction that wrote it. Nobody has fetched from a
  clean tree against a lock they did not just produce. Opened as `0012-t4`.

## Dimensional impact

Five questions, under the evidence rule.

**1. Did this reveal a dimension that does not exist yet?**
**A candidate, not taken.** Every module in the corpus has a *dispatch style* —
direct call, call through a variable, name-based lookup of a file, cmdlets in an
assembly — and it is the single best predictor of how wrong the graph will be.
Pester and PSDepend are unlike posh-git in exactly that way, and the graph cannot
say so. It is a property of a call site rather than of a subject, though, and a
facet that classifies edges is not something this store has a shape for. Logged
rather than created: the test is whether it changes what someone can see or do in
the report, and nothing in the report distinguishes an edge by how it was
reached.

**2. Is an existing facet doing two jobs?** No.

**3. Did two facets turn out to be the same thing?** No.

**4. Did anything classify at a depth the facet did not anticipate?**
**Yes, and it is finding 1.** `surface:internal` and `structure:function` are
assigned per subject, and a subject is a name — so 53 pairs of same-named
functions in SqlServerDsc would collapse in the store the same way they collapse
in the node index. Nothing has run `Update-KnowledgeStore` against a corpus
module, so this is predicted rather than observed, and it is the same root as
`0012-t5`.

**5. Could this facet classify facets?** Not applicable this iteration.

### Prune, this iteration

A move: none. A deletion proposal: none.

### Always-loaded bytes

**18,546 / 19,000.** Unchanged: `gallery/README.md` is on-demand and `CLAUDE.md`
gained nothing.

## Open threads

1. **[0012-t1] The corpus is a hypothesis with eight instances.** Chosen for what
   each was expected to stress, and six of eight did roughly what was predicted.
   A sample that agrees with its selector has not been tested against anything.
2. **[0012-t2] Two of the three failure outcomes have never happened.** `timeout`
   and `missing` are written and unexecuted. A record shape nobody has produced
   is a record shape nobody has read.
3. **[0012-t3] Nothing validates a result against the schema that describes it.**
   Written together by one author in one pass, which is the arrangement that
   holds exactly until there is a second writer.
4. **[0012-t4] The lock has never been checked by anyone who did not write it.**
   Verification and generation have only ever run in the same session.
5. **[0012-t5] A node's identity is its name, and that is a data shape.**
   Findings 1 and 3 both come from it, and so does the roots count the report
   opens on. Large: logged, not taken.

Carried: **[0011-t1]** nobody has asked what a JSON consumer reads;
**[0011-t2]** a re-recorded golden only catches accidents; **[0010-t1]** nothing
tells this repository the renderer's surface moved — seen again this iteration as
a red build with a misleading cause; **[0010-t2]** a test scoped to a module that
no longer holds what it tests still passes; **[0009-t1]** one fixture proves the
move; **[0009-t3]** nothing proves the dependency is really required;
**[0008-t1]** nothing has been trained on the corpus; **[0008-t2]** the section
headings are hardcoded; **[0008-t3]** `corpus/` is outside lint and the charter
test, and now `gallery/` is too; **[0007-t1]** hot and external are nearly the
same colour; **[0007-t2]** should the store hold measurements; **[0006-t1]** the
http-origin editor-link claim is unverified; **[0005-t1]** skill descriptions are
unbudgeted; **[0005-t2]** the ceiling's headroom is a guess; **[0005-t3]** nothing
measures whether an on-demand file is read; **[0004-t1]** should patterns be
subjects; **[0004-t4]** `iteration-close` is model-invocable and it pushes;
**[0003-t1]** `facet-health` grades itself flatteringly; **[0003-t2]** coverage
conflates unassigned with inapplicable; **[0003-t3]** `structure:external` has no
assignments; **[0001-t7]** the facet seam in the report.

# Improvement backlog

The improvement loop's backlog, its rules, and its memory. `CLAUDE.md` carries
the standing instruction in three sentences; everything that makes it
cumulative rather than a good intention repeated every session is here.

Append only, except to move an item to **Done** or to delete one that turned out
to be wrong. Each entry: what was noticed, why it matters, and how big it is.
Size is the whole point — it decides whether an agent may take it unprompted.

- **Small** — fits inside work already happening, no new decision. Take it.
- **Medium** — its own change with its own commit. Propose in one line, take it
  if the owner is quiet, and say clearly that you did.
- **Large** — changes a contract, a shape, or the user's mental model. Log it and
  stop. Do not take it unprompted.

## On every iteration

1. **Notice one thing.** While reading code for whatever the task actually is,
   something will be shaped worse than it could be: a branch that wants to be a
   registry, a literal that wants to be data, a message that lies, a panel that
   is nearly general. You do not have to hunt. It presents itself.
2. **Classify it honestly** as Small, Medium or Large, by the rules at the top of
   `docs/improvements.md`. The classification decides what you may do:
   - **Small** - fits inside work already happening and needs no new decision.
     Do it. Mention it in one line.
   - **Medium** - its own change, its own commit. Say in one line that you are
     doing it and why, then do it.
   - **Large** - changes a contract, a data shape, or the user's mental model.
     **Log it and stop.** Do not take it unprompted. This is the boundary that
     keeps this loop from becoming scope creep.
3. **Record it either way.** Something you did goes to **Done** with what
   prompted it. Something you did not goes to **Open** under its size. An
   improvement noticed and not written down is an improvement lost.
4. **Prefer extensibility over the feature.** When the same shape appears a
   second time, the improvement is usually not "add the second one" but "make
   adding the third one one entry". `NODE_ACTIONS`, `SELECTION_FACTS`,
   `SELECTION_ACTIONS` and `FLOW_LAYOUT` all came from this and all read the
   same way, deliberately.

## What good looks like here

The question to hold is not *what else could I build* - it is **what would make
the next change to this cheaper**. Three concrete tests:

- **Would a second one of these be one entry, or a second branch?** If a branch,
  the registry is the improvement.
- **Is this text, number or colour a decision, or data?** If a user would ever
  want it different, it belongs in a `.psd1`, not in a `.js` or `.ps1`.
- **Does this message say something true?** A banner that names the wrong cause
  is worse than no banner, because it is confidently wrong and people act on it.

## What this loop is not

- **Not a licence to refactor code you are not otherwise touching.** Read it,
  log it, move on.
- **Not a reason to add options nobody asked for.** A new setting is a new
  decision imposed on the reader; extensibility is not the same as configurability.
- **Not exempt from the standing directives.** The HTML subsystem's rules still
  hold, `docs/html-architecture.md` is still the authority, and an improvement
  that contradicts a recorded decision is an amendment to propose, not to make.
- **Not a running commentary.** One line per improvement taken. The backlog
  carries the detail; the response does not.

---

## Open

### Small

- **The `template-notice` partial names PSModuleGraph commands.** Below the seam,
  which the extraction checklist forbids. The fix is the pattern the banner
  already uses: pass the command through config and interpolate. *Noticed while
  externalising strings.*
- **`Show-RenderDocument`, `Get-PSModuleGraphAsset` and
  `Get-PSModuleGraphAssetPath` carry graph vocabulary in their names.** On the
  checklist already; listed here so it is not forgotten between passes.

### Medium

- **`PreTag` here has no guard against selecting nothing.** It filters by tag and
  reports success on whatever it finds; a filter that matches zero tests would
  pass. It selected three this iteration, so nothing is wrong today. The sibling
  repository shipped four tags behind exactly this before anyone noticed, which
  is the argument for the guard rather than for watching the number.
- **A "root" can be an artefact of the name index.** `Get-PSModuleDependencyGraph`
  keys the node index on the lowercased bare name, so the last definition parsed
  wins and every earlier one becomes unreachable by any edge — then reported as a
  root. SqlServerDsc 17.5.1: 53 duplicated names, 144 of 496 nodes shadowed, 186
  roots. The narrow fix is to detect the collision and say so; the real fix is
  `0012-t5`, which is Large. *Ledger `0012`.*
- **The unresolved report drops a third of Pester's call sites.** A call through
  a variable yields no command name, the fallback takes the extent text, and the
  graph's leading-sigil filter removes it — 491 of 1,552 sites, reported nowhere.
  "Report, do not drop" names this case explicitly. The leftovers are worse: four
  "command names" hold thirty lines of script block. *Ledger `0012`.*
- **A base type outside the module is dropped, not surfaced.** SqlServerDsc has 9
  classes with a base type and 7 `Inherits` edges; the two crossing a
  `using module` boundary vanish. An unresolvable call becomes an `Unresolved`
  entry and an unresolvable base type becomes nothing, which is the same rule
  applied twice with two answers. *Ledger `0012`.*
- **Two root manifests in a version-named directory refuse to resolve.**
  `Resolve-PSModuleTarget` falls back to matching the manifest against the
  containing folder name, which for an installed module is the version. PSDepend
  0.5.0 ships two root manifests and cannot be pointed at. Which one wins is a
  decision — `RootModule` and the parent folder name are both candidates — which
  is why it is here and not fixed. *Ledger `0012`.*
- **The parser writes an error record on the first file of every module.**
  `Get-Variable -Scope Script -ErrorAction SilentlyContinue` suppresses the
  action and still records the error, so `Get-PSModuleDependencyGraph
  -ErrorAction Stop` fails on every input. Every result file in
  `gallery/results/` carries it. *Ledger `0012`.*
- **`gallery/` is outside lint and outside the build, and so is `corpus/`.** Two
  directories of `.ps1` that the analyzer never sees, because it is scoped to
  `src/`. It was one for four tags (`0008-t3`); a second instance is the signal
  that the lint scope is the thing to change rather than the directory.
  *Ledger `0012`.*
- **Hot and external are nearly the same colour.** `External` fill and
  unresolved edges are `#ff7043`; the hot end of `HeatRamp` is `#ff3b2f`.
  Colouring by a metric makes a heavily depended-on internal function look like
  an unresolved external one. Both are data, so the fix is a data change - but
  which one moves is a design call. *Ledger `0007-t1`.*
- **The heat scale was compared against linear and nothing else.** Square-root
  or log would keep some proportionality while still spreading the skewed tail.
  Rank is better than linear; whether it is best is untested. *Ledger `0007`.*
- **Skill descriptions are always-loaded and outside the budget.** Every skill's
  `description` and `when_to_use` sit in the listing in every session whether or
  not the skill runs - about 800 bytes across four. `tests/Instructions.Tests.ps1`
  enumerates files, so adding a skill grows the always-loaded surface without
  touching the gate. Either count them or state deliberately that they are cheap
  enough not to. *Ledger `0005-t1`.*
- **Nothing measures whether an on-demand file is ever read.** Two `docs/` files
  were created rather than reused at v0.4.0, and an unread doc is the on-demand
  tier's version of the accretion the tiering exists to stop. The only signal
  available from inside the repository is whether anything links to it, which is
  weak. *Ledger `0005-t3`.*
- **The store's neutrality guard cannot tell data from prose about data.**
  `Import-KnowledgeFacet.Tests.ps1` greps every `.md` under `knowledge/` for
  `PSTypeName` and exempts `NAMING.md` by name. A seeded pattern quoting the rule
  was failed by the rule. Every prose file the store gains - ledger entries,
  patterns - will eventually trip it, and an exemption list is not a principle.
  Scope the grep to the file kinds that carry data instead. *Noticed when it
  fired. Ledger `0004-t3`.*
- **`read_store.py` reads a shrinking fraction of the store.** It covers
  `subjects/` and `assignments/` and now misses `ledger/` and `patterns/` as well
  as `facets/`. The neutrality proof did not get weaker; the thing being proved
  got bigger, and nothing says so at the point of proof. *Noticed while adding
  `patterns/`.*
- **Partial markup still carries its own user-visible text.** The scripts are
  fully externalised; the partials are not, so half the report's wording is data
  and half is markup. Doing it needs a substitution pass over partials, which is
  why it was not folded into the string work. *Checklist item.*
- **The details panel and the selection panel compute overlapping facts.** Both
  answer "what does this rest on" for a different arity. One registry taking a
  collection, with the single-item panel passing a collection of one, would make
  a new fact appear in both places at once.
- **Focus works on one node.** `focused` is a single node while selection is a
  collection, so focusing the neighbourhood of several things is not expressible.
  The selection panel makes the gap obvious.
- **Colours are still literals in the scripts.** `KIND_HEX`, the legend chips and
  the Cytoscape stylesheet all carry hex codes that belong in `theme.psd1`.
  *Checklist item: "All colours externalised".*

### Large

- **A node's identity is its name.** The node index maps a lowercased bare name
  to one id, so two definitions of `Get-TargetResource` are two nodes and one
  addressable target. Everything downstream rests on it: edges, roots, leaves,
  the metrics, and the view the report opens in. Changing it changes the payload
  and the user's mental model of what a node is. *Ledger `0012-t5`.*
- **The token contract is still `__GRAPH_*__`.** Renaming is a breaking change to
  the template contract and belongs in one deliberate pass. *Checklist item.*
- **Should the graph types be real PowerShell classes?** Open decision in
  `CLAUDE.md`; listed here so the improvement loop does not rediscover it as if
  it were new.
- **Should the subsystem's tests run without building a dependency graph?**
  Checklist item, and the last real dependency between the renderer and this
  module's data.

---

## Done

- **The context menu was markup.** Became the `NODE_ACTIONS` registry, so a new
  action is one entry with a `check` that greys it out with a reason rather than
  hiding it. This is the shape the other registries copy.
- **The info panel was a title and a block of text.** Now takes rows, text and
  actions, which is what let the selection panel exist without a second overlay.
  *Noticed by the owner looking at the Diagnostics panel and saying "that's a
  template".*
- **Every user-visible string in the scripts was a literal.** Now
  `strings.psd1`, so wording is a data change.
- **The starting view was a `checked` attribute in markup.** Now `DefaultFlow`
  in `settings.psd1`, so the setting is not decorative.
- **The graph showed magnitude and could not colour it.** Some nodes obviously
  matter more - the foundation view puts them at the bottom - and nothing said
  so in the fill. A facet classifies and a metric measures; `ColorBy` now takes
  either, and `blastRadius` paints what everything rests on. The options are
  built from the payload, so a facet joins the same registry when one exists -
  which is the seam `0001-t7` was waiting for. *Noticed by the owner looking at
  five screenshots and saying "there's something of a heat map in there".*
- **`borderFor` claimed to be the blast radius and counted direct callers.** The
  label was wrong, and the gap is where the interesting nodes live. Border now
  says direct callers; fill carries the transitive measure. *Ledger `0007`.*
- **`instruction-prune` could not win.** It proposed deletions for a later
  iteration to apply, while every iteration also added - one turn behind, and
  worse, proposing the one move that is almost always correctly refused. A prune
  is now a **move down a tier**, applied in-turn because it loses nothing;
  `tests/Instructions.Tests.ps1` caps the always-loaded tier; and a genuine
  deletion proposal a second iteration ignores blocks the tag. 46,681 -> 18,546
  bytes with nothing deleted. *Logged as Large in `0004`, taken in `0005`.*
- **The neutrality guard's exemption list became a principle.** It greps for
  PowerShell type names across the store and exempted `NAMING.md` by name; it
  then fired twice on prose that quoted the rule. Now scoped to the areas that
  carry data, so `ledger/`, `patterns/` and `NAMING.md` fall outside it by being
  what they are. *Ledger `0004-t3`, closed in `0005`.*
- **The charter line ceiling opposed the tier move.** 119 lines for a non-Html
  charter, written one iteration before charters became the destination for
  moved detail. Replaced by an assertion that a charter states what the parent
  rules mean locally, which is what the cap was really guarding. *Ledger `0005`.*
- **Two subsystems had no charter and nothing noticed.** `Private/EditorLink/`
  and `Private/Knowledge/` went two versions as the same shape as
  `Private/Html/` with no `docs/*-architecture.md`. Backfilled, and
  `tests/Private/SubsystemCharter.Tests.ps1` now fails by name at three files.
  The rule stopped depending on a person remembering it. *Ledger `0004`.*
- **The commit ritual was unwritten.** Staging, message style, tag and push were
  habit; `git add -A` had already swept a gitignored `coverage.xml` into a commit
  titled `asdf`. Now the `Commit` section of `CLAUDE.md`, with the order of
  operations in `.claude/skills/iteration-close/`. *Ledger `0004`.*
- **`isEmbeddedContext()` only looked for frames.** An editor preview pane is
  top-level and was reported as a browser blocking the scheme, which sent a
  round of diagnosis at the wrong layer.

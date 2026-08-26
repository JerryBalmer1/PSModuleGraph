# Improvement backlog

The standing list kaizen works against. See the **Kaizen** section in
`CLAUDE.md` for the rules; this file is the memory that makes them cumulative
rather than a good intention repeated every session.

Append only, except to move an item to **Done** or to delete one that turned out
to be wrong. Each entry: what was noticed, why it matters, and how big it is.
Size is the whole point — it decides whether an agent may take it unprompted.

- **Small** — fits inside work already happening, no new decision. Take it.
- **Medium** — its own change with its own commit. Propose in one line, take it
  if the owner is quiet, and say clearly that you did.
- **Large** — changes a contract, a shape, or the user's mental model. Log it and
  stop. Do not take it unprompted.

---

## Open

### Small

- **The `template-notice` partial names PSModuleGraph commands.** Below the seam,
  which the extraction checklist forbids. The fix is the pattern the banner
  already uses: pass the command through config and interpolate. *Noticed while
  externalising strings.*
- **`Show-GraphDocument`, `Get-PSModuleGraphAsset` and
  `Get-PSModuleGraphAssetPath` carry graph vocabulary in their names.** On the
  checklist already; listed here so it is not forgotten between passes.

### Medium

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
- **`isEmbeddedContext()` only looked for frames.** An editor preview pane is
  top-level and was reported as a browser blocking the scheme, which sent a
  round of diagnosis at the wrong layer.

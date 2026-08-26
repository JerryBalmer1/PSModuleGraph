# HTML subsystem architecture

Read this before planning work on the HTML layer. Do not read the templates to
work out the design; the design is here.

## Target

A generic, data-driven report renderer that PSModuleGraph happens to use. Done
means: `git mv` the subsystem into its own repository and it builds, tests, and
renders a report with no reference to nodes, edges, modules, or ASTs.

## The seam

`ConvertTo-GraphHtml` is the only function that knows what a dependency graph
is. It converts a graph into a generic view model and hands that off. The
renderer receives a view model, a template set, and a resolved configuration,
and has no idea what any of it means. Nothing below the seam may reference
`Node`, `Edge`, `Module`, `Ast`, or any PSModuleGraph type — in code, in
comments, in file names, or in setting names.

Above the seam: `ConvertTo-GraphHtml`, and the graph getters that feed it.
Below the seam: everything in `Assets/Html/` and the private functions that
resolve, assemble, and validate it.

## File layout

```
src/PSModuleGraph/
  Assets/Html/                  <- moves out at extraction
    Templates/
      layout.html               shell, slot tokens only
      partials/*.html           one concern each
      styles/*.css
      scripts/*.js
    Config/
      settings.psd1             current values
      settings.schema.psd1      types, defaults, ranges, groups, constraints
      theme.psd1                colours, fonts, spacing
      strings.psd1              user-visible strings
  Private/Html/                 <- moves out at extraction, minus the seam
    Get-HtmlTemplateSet.ps1
    Resolve-HtmlConfiguration.ps1
    Resolve-HtmlString.ps1
    ConvertTo-EscapedHtml*.ps1
    Show-GraphDocument.ps1
    ConvertTo-GraphHtml.ps1     <- STAYS. This is the seam.
```

`ConvertTo-GraphJson`, `ConvertTo-GraphDot`, and the other serialisers are not
part of this subsystem and do not move.

## The four data files

| File | Holds | Never holds |
| --- | --- | --- |
| `settings.psd1` | current values | descriptions, ranges |
| `settings.schema.psd1` | type, default, range, group, description, constraints | current values |
| `theme.psd1` | colours, fonts, spacing | behaviour |
| `strings.psd1` | every user-visible string | markup |

Settings are behaviour: what the page does. Theme is appearance: what it looks
like. When a value could be either, ask which one a user would change to alter
*what happens* versus *how it reads*.

Schema types: `Number`, `Integer`, `Boolean`, `String`, `Color`, `Enum`.
Each has one validator, dispatched from the entry's `Type`.

## The rule that pays for this

> Adding a new setting must require editing data files only. If it requires
> editing a `.ps1`, the design is wrong. Report that as a bug; do not work
> around it.

## Facets at the seam — designed, not built

Dimensions arrive at the renderer as **generic facet data through the seam that
already exists**. `ConvertTo-GraphHtml` knows what a facet is; nothing below it
does. The renderer receives axes, paths and values exactly as it currently
receives `editorLinkHelpCommand` without knowing what a PSModuleGraph command
is. **The renderer must not learn what a facet means** — not in code, not in a
setting name, not in a string key.

This is a map for the next implementation to land on. None of it is built, and
building it is not licence granted by writing it down.

**`Kind` becomes the first facet rather than a special case.** The `KINDS`
checkbox group in the sidebar is already a facet selector wearing one facet's
clothes: a list of paths, each with a count and a swatch, that the user filters
by. Generalising the *shape* means that group is rendered from a facet
descriptor rather than from `KIND_HEX` and a hardcoded `kind` field — one group
per facet the payload carries, with `structure` supplying today's behaviour
unchanged. The feature is not new filtering; it is the same filtering with the
facet id passed in rather than assumed.

**Colour-by, group-by and filter-by all take a facet id.** Today all three take
`Kind` implicitly — `KIND_HEX` colours it, the layout does not group by it, and
`applyFilters` reads `n.data('kind')` directly. Each becomes a setting naming a
facet, which is a data change under the existing rule. The colours then belong
to the facet's paths rather than to a `KIND_HEX` literal, which also closes the
open "all colours externalised" checklist item rather than working around it.

**A heatmap is two facets crossed with a count.** Rows are the paths of one
facet, columns the paths of another, cells the number of subjects carrying both.
That is the whole definition and it needs no new data beyond what a `facets`
block already carries. Stating it is the deliverable here; implementing it is
explicitly out of scope, and it should not be attempted before a facet exists
that a reader would actually want crossed with `structure`.

**The payload gains a `facets` block alongside `nodes` and `links`.** Sketch,
not contract:

```
facets: [
  { id, label, kind, separator,
    paths: [ { path, label, color?, count } ] }
]
```

and each node gains `facets: { <facetId>: [ <path>, ... ] }` — an array because a
facet is multi-valued even where today's data never uses more than one. Nothing
emits this yet, and `ConvertTo-GraphJson` remains the single serialiser: when the
block is built it is built there, not in a second one for the page.

**The one trap.** `nodes[].kind` is load-bearing in `elements.js`, `render.js`,
`filters.js` and `sidebar.js`. Replacing it with `facets.structure` in a single
pass would be a rename spread across four files with no way to verify behaviour
was unchanged — the same argument already recorded against half-renames. The
first implementation should emit `facets` *alongside* `kind`, prove the page
reads the same, and remove `kind` in a later pass.

## Local rules for the export

`Export-PSModuleDependencyGraph -Format Html` renders a self-contained page.
Rules that are easy to violate:

- **HTML-related PowerShell lives in `Private/Html/`**, not directly in
  `Private/`. `Private/` is enumerated recursively by both loaders, so a new
  subfolder needs no registration — but `Public/` is deliberately *not*
  recursive, because the export list is derived from its filenames.
- **Assets live in `src/PSModuleGraph/Assets/`** and are loaded with
  `Get-PSModuleGraphAsset`. The template is a static file that ships as-is;
  there is no bundler, no npm, and no build step for it.
- **Resolve assets from `$script:ModuleRoot`, never `$PSScriptRoot`.**
  `$PSScriptRoot` is per-file: under the dev loader a file in `Private/Html`
  sees that folder, while in the built module the same code has been
  concatenated into a `.psm1` at the module root. Either loader would work and
  the other would break, and the break only shows up in the built module.
- **Token substitution uses `[string]::Replace()`, never the `-replace`
  operator.** `-replace` is regex. Both the embedded JSON and the CSS contain
  `$` and `\`, which the regex engine treats as substitution patterns and eats.
  The result is subtly corrupted output rather than an error.
- **There is exactly one serialiser.** The HTML payload comes from
  `ConvertTo-GraphJson`. Do not write a second one for the page — the JSON
  export and the HTML payload must not be able to drift apart.
- Embedded JSON escapes `<` as `\u003c`, so a `</script>` in a path or extent
  cannot terminate the script block. HTML is written UTF-8 **without** a BOM; a
  BOM ahead of `<!DOCTYPE html>` can trigger quirks mode.
- **Configuration is four data files under `Assets/Html/Config/`**, resolved by
  `Resolve-HtmlConfiguration`. Adding a setting is a data change: an entry in
  `settings.schema.psd1`, a value in `settings.psd1` or `theme.psd1`, and a
  `cfg('Key', fallback)` in the template. Needing to edit a `.ps1` means the
  design has broken — report it. See `docs/html-architecture.md`.

  The JS fallbacks in `cfg()` are unreachable in a generated report — the page
  bails out earlier when `GRAPH_DATA` is null — and exist only so a missing key
  cannot become `NaN` in a layout calculation.

  `Import-PowerShellDataFile` needs `-ErrorAction Stop`. A `.psd1` that will not
  parse raises a **non-terminating** error, so without it the `catch` never runs
  and a broken config falls back in total silence.
- Paths in the HTML payload are module-relative. Generated reports get attached
  to PRs and tickets, where absolute paths leak usernames. The JSON export keeps
  them absolute.
- **Node context-menu actions live in the `NODE_ACTIONS` registry** in
  `scripts/menu.js`, not in markup. An entry is `{ id, label, check, href, run }`, where
  `label` may be a function of the node and `check` returns `null` when the
  action applies or the reason it does not — an inapplicable action greys out
  with that reason rather than disappearing. Adding an action means adding one
  entry; nothing else needs touching.
  An action that hands a URI to another application must use `href`, never
  `run` with `window.location`. Chrome discards a scripted navigation to a
  custom scheme in total silence — the handler runs, the URI is correct, and
  nothing happens — while a link the user clicked is the supported route.
  Because a refused or unregistered scheme reports nothing back either, any such
  action needs a non-scheme fallback beside it; `Copy Path` is that fallback.
- **The page rebuilds absolute paths in the browser** from `meta.moduleRoot`,
  which is how the `vscode://file/` link works while payload paths stay
  relative. Note that `meta.moduleRoot` is itself absolute, so the "no absolute
  paths in a shared report" rule above is already weaker than it sounds — a
  report does carry the module's own base path. Do not add absolute paths to
  `nodes`/`links` on the assumption that it makes no difference.
- **`-Show` always hands the report to the OS default handler**, never to the
  editor. See "Looks like a bug, but is not" below before changing that.
  `Get-VSCodeLauncher` still requires BOTH a VS Code environment marker and the
  `code` CLI — finding the executable only proves VS Code is installed, not that
  the user is sitting in it — but it now only gates a `-Verbose` hint. The CLI
  has no `--command` and no `--uri` flag, so an extension's preview pane cannot
  be opened from PowerShell - do not add code that pretends otherwise.
- `tests/Module.Quality.Tests.ps1` asserts that every file the template set
  manifest names, and all three config files, reach the built module. That is
  the only thing standing between a build change and a runtime failure in the
  export.

Watch for parameter shadowing: PowerShell variable names are case-insensitive,
so a local `$name` **is** the `$Name` parameter. Assigning to it re-runs the
parameter's validation attributes, and `$name = $null` against a
`[ValidateNotNullOrEmpty()]` parameter throws at that assignment. Name locals
distinctly (`$usingName`, `$nestedName`).

## Gravity

**What everything rests on goes at the bottom, and the report opens that way.**

This is a standing invariant, not a preference and not a default someone picked.
A dependency graph has a direction whether or not the layout admits it: the
things with the most inbound edges are the things everything else is built on
top of, and a reader looking for what to trust, what to test first, or what
breaks the most if it changes is looking for exactly those. Putting them at the
foot of a vertical stack makes that structural, so it reads correctly before any
label is read at all.

The rules:

- **`DefaultFlow` in `settings.psd1` is `foundation`, and stays `foundation`.**
  Do not change the shipped default to `testorder` or `callflow` as a side
  effect of other work. Changing which view a report opens in is a deliberate
  decision, and this one is made.
- **Foundation is vertical, and it is not laid out by dagre.** `scripts/foundation.js`
  assigns layers itself, because the width of a layer has to be bounded and no
  dagre ranker can bound it. `longest-path` pins every node with no dependencies
  to one extreme layer: on this module that was 29 of 62 nodes in a single row,
  drawn at 11:1 and illegible once fitted to a window. Switching ranker only
  moves it to 24. Bounding the layer and letting the layer count grow is the
  standard answer, and takes the same graph to 10 layers of 7 at 1.3:1.

  **Do not "simplify" this back to a dagre ranker.** It has been measured in
  both directions. The other two views still use dagre and should.
- **Layer capacity is derived from the container's aspect** unless
  `FoundationLayerCapacity` pins it. That is what keeps the drawing near the
  screen's own shape on a laptop and on a wall display without a second setting.
- **Layer 0 is the foundation and takes the largest y.** Cytoscape's y grows
  downward, so `layers.length - 1 - at` is what puts it at the bottom. Inverting
  that puts the foundation in the air; it is the bug to watch for.
- **The arrowhead follows the reading direction.** Foundation reads bottom to
  top, so the arrow sits on the source end: it means "this one first, then the
  one it points at". Only `callflow` keeps the arrow on the callee.
- **The layout table is `FLOW_LAYOUT` in `scripts/render.js`.** A new view is one
  entry. Do not add a branch beside it.
- **Fitting is floored at `MinReadableZoom`.** A graph large enough to fit only
  at 15% is a graph nobody can read; past the floor the view stops shrinking and
  the reader pans. A legible part beats an illegible whole.
- **Nothing may leave the starting view to the markup.** The radios carry no
  `checked` attribute; `controls.js` sets it from config. A `checked` in the
  partial would make editing the `.psd1` silently do nothing.

Extend gravity to anything else that gains a spatial arrangement - a tree, a
list, a timeline. Foundation at the bottom, dependents above. Consistency across
views is the point; a second view that stacks the other way costs the reader
more than it gains.

## Looks like a bug, but is not

**`Show-GraphDocument` always opens the browser, never the editor** — even when
the session is running inside VS Code, and even though `Get-VSCodeLauncher` is
still called. That is not an oversight, and the launcher is not vestigial: it
decides whether to print a `-Verbose` hint naming the command that would open
the source.

Opening the report in VS Code shows the HTML source, so the user reaches for a
preview extension. Every one of those is a webview, and a webview sandboxes
custom-scheme navigation — a `vscode://file/...` URI never leaves one. The
page's own "Open File Location" action is dead in exactly that environment, so
routing the report into the editor disables the feature most worth having.

**This reverses an earlier implementation that preferred the editor.** It has
been optimised in both directions already; do not do it a third time. If the
editor path looks like an obvious improvement, it is the same one that was
removed.

**`isEmbeddedContext()` checks the user agent for `Electron/`, and that check is
not redundant.** An editor preview pane is genuinely top-level, is served over
`file:`, and reports no ancestor origins, so the frame check, the
`vscode-webview:` check and the `ancestorOrigins` check all pass it as a normal
browser. It is not one: the Electron host swallows a custom scheme with no
prompt and no error, which is the same silence a refusing browser produces.

Diagnosing this as a browser policy problem cost a full round. Before concluding
that a browser is blocking the scheme, **read `navigator.userAgent` in the
Diagnostics block.** A real browser never reports `Electron/`. Matched
generically rather than on a product name, both because every Electron host has
this limitation and because naming VS Code below the seam would violate the
HTML subsystem directive.

## Token discipline

1. Read `docs/html-architecture.md`, not the templates, when planning.
2. Never rewrite an asset file wholesale to change part of it. Targeted edits.
3. Never re-derive the architecture. It is written down. To disagree, propose an
   amendment in one paragraph and wait — do not silently build to a different
   design.
4. Do not restate the plan before starting. The prompt is the plan.
5. One architectural delta paragraph, then code. No plan documents, no phased
   roadmaps, no summaries of what you are about to do.
6. Do not add comments explaining what the architecture document already
   explains. Link to it. Long comment blocks re-justifying settled decisions are
   a cost paid on every read.
7. When something is ambiguous, ask one specific question. Do not implement both
   options, and do not implement the safer one and mention the other.

This directive stays until the repository owner removes it.

## Kaizen in this subsystem

The general rule is the **Improvement loop** in `CLAUDE.md`, with its detail
in `docs/improvements.md`. Here it has a
specific shape, because this subsystem is being built toward extraction and
"better shaped" has a definition: **closer to a renderer that knows nothing
about dependency graphs.**

Every pass through this code should ask, in this order:

1. **Does this belong above the seam?** Any graph vocabulary below it -
   in code, comments, file names, setting names, or a string that names a
   PSModuleGraph command - is the improvement. The banner's
   `editorLinkHelpCommand` is the pattern: the caller supplies it, the renderer
   interpolates it.
2. **Is this a decision or is it data?** Text belongs in `strings.psd1`,
   colours in `theme.psd1`, behaviour in `settings.psd1`, and their types in
   `settings.schema.psd1`. **If adding a setting requires editing a `.ps1`, that
   is a bug in the design - report it, do not work around it.**
3. **Would a second one of these be one entry?** The registries here -
   `NODE_ACTIONS`, `SELECTION_FACTS`, `SELECTION_ACTIONS`, `FLOW_LAYOUT` -
   exist because the answer was no and became yes. New surfaces should join
   them rather than sit beside them as branches.
4. **Does an overlay, panel or control want to be general?** The info panel took
   a title and a block of text until the selection panel needed rows and
   actions; generalising it was cheaper than a second overlay and is why a third
   caller needs no markup.
5. **What does the checklist below still say is open?** It is the backlog for
   this subsystem specifically. `docs/improvements.md` carries the rest.

Anything taken gets a line in the decision log below. Anything noticed and not
taken gets a line in `docs/improvements.md`. **An improvement that contradicts a
decision already in this log is an amendment to propose in one paragraph, not a
change to make quietly.**

## Extraction checklist

- [ ] No graph vocabulary below the seam  (setting names, template ids, GRAPH_* tokens, partials/template-notice.html)
- [x] Schema is data, not a hashtable in a `.ps1`
- [ ] All user-visible strings externalised to `strings.psd1`  (scripts done; partial markup still carries its own text)
- [ ] All colours externalised to `theme.psd1`
- [x] No partial over 250 lines
- [x] Template set resolvable from a caller-supplied directory
- [ ] Token contract named generically (not `__GRAPH_*__`)
- [ ] Renderer functions named without `Graph` or `PSModule`  (Get-PSModuleGraphAsset, Get-PSModuleGraphAssetPath, Show-GraphDocument remain)
- [ ] Tests for the subsystem run without building a dependency graph

## Decisions made and why

Append only. Each entry two or three sentences. Do not re-litigate these.

**2026-08-25 — `ConvertTo-GraphHtml` is the seam, not a new adapter function.**
It already builds the payload and is already the only place that reads graph
shape. Adding a separate adapter would create two functions that both half-know
about graphs, which is worse than one that fully does.

**2026-08-25 — Config lives under `Assets/Html/Config/`, not beside the module
manifest.** Everything that moves out at extraction time lives under one root,
so extraction is a single `git mv` rather than a scavenger hunt.

**2026-08-25 — The token contract keeps its `__GRAPH_*__` names for now.**
Renaming is a breaking change to the template contract and is worth doing in one
deliberate pass, not as a side effect of splitting files. It is on the checklist.

**2026-08-25 — `NodeFontSize` is theme; `FocusDepth` is a setting.** Font size
changes how the page reads and nothing about what it does. Focus depth changes
which data the page shows. That is the test to apply to future values.

**2026-08-25 — Settings keep their current names during the split.** Renaming
`NodeSep` to something graph-free is a checklist item, not a splitting concern;
doing both at once would make the "behaviour unchanged" verification impossible.

**2026-08-25 — The script split follows the existing `// ---- ` section markers.**
Those markers already record how the author divided the concerns; inventing a
different division during a pure move would hide behaviour changes inside a
refactor.

**2026-08-25 — The script split produced nine files, not the five first
sketched.** The 250-line ceiling forced it: a five-way split left `menu.js` and
`render.js` over. `bootstrap.js` carries slots for the others rather than being
split into head and tail fragments, so it stays a single readable entry point.

**2026-08-25 — Template parts are read verbatim and must not end with a
trailing newline.** Stripping one on read is indistinguishable from deleting a
deliberately blank last line, and ten of the original slices have one. Verified
by reassembling to a byte-identical document.

**2026-08-25 — One schema covers both value files; each entry declares `In`.**
A value in the wrong file still applies but is reported. Two schemas would let
the two halves drift; no placement rule at all would make the settings/theme
split decorative.

**2026-08-25 — `Boolean`, `String`, `Color` and `Enum` validators exist with no
shipped setting using them.** They are tested directly rather than by inventing
settings to exercise them: the type machinery is the deliverable, and a new
option nobody asked for is a behaviour change.

**2026-08-25 — Setting names keep `Node`, `Edge` and `Rank` for now.** Renaming
them is a checklist item and belongs in one deliberate pass. A half-rename -
`NodeLimit` to `ItemLimit` while `NodeFontSize` and `NodeSep` stay - is worse
than either end state.

**2026-08-25 - `strings.psd1` sits outside `settings.schema.psd1`.** The schema
exists to type and range-check values, and a schema entry per string would hold
a `Default` that is a second copy of the string itself. The schema covers the
two value files; strings are the third kind and are resolved separately by
`Resolve-HtmlString`.

**2026-08-25 - A string the page asks for and cannot find renders as its own
key in brackets.** Every call site carrying its own fallback would put each
string in the script as well as the data file, which defeats externalising
them. A visible `[MenuCopyPath]` is diagnosable; a silently blank label is the
one failure mode nobody notices.

**2026-08-25 - Caller tokens are filled in PowerShell, display-time tokens in
the page.** `{editorLinkHelpCommand}` is configuration and is substituted at
render time; `{count}` and `{name}` are only known in the browser and are left
for `fmt()`. A token nobody fills stays as written rather than collapsing to
nothing, so the gap shows up.

**2026-08-25 - `editorLinkHelpCommand` has no default in `strings.psd1`.** It
is vocabulary belonging to whatever program generated the report, and giving
the renderer a default would be the renderer knowing it. When nothing supplies
one the page uses a second message that does not mention a command, rather than
rendering "Run  in PowerShell".

**2026-08-25 - Emphasis in a message belongs to the page, not the string.**
`strings.psd1` holds no markup, so the dependency-cycle notice is two strings
that the page wraps and escapes. A string that could carry an element would be
an injection point wherever the page assigns `innerHTML`.

**2026-08-26 - The report opens on a vertical foundation view, and that default
lives in `settings.psd1`.** Edges point caller to callee and dagre ranks a
target below its source, so `rankDir: 'TB'` sinks what everything rests on to
the foot of the page. See the gravity rule in CLAUDE.md: it is an invariant to
extend to future views, not a default to revisit.

**2026-08-26 - `DefaultFlow` is the first shipped `Enum` setting, and it needed
`cfgText()`.** `cfg()` returns numbers only, so a valid string would have failed
its `isFinite` test and fallen back on every load. The Enum validator already
existed; the page simply had no way to read a non-numeric setting. Adding the
setting itself stayed a data change, which is the rule holding.

**2026-08-26 - The flow radios carry no `checked` attribute.** `controls.js`
sets the starting view from config, so editing the `.psd1` actually changes what
the report opens on. Markup deciding it would make the setting decorative -
present, validated, and ignored.

**2026-08-26 - The third radio's label stays in the partial with its two
siblings.** Partial text is one open checklist item and belongs in one pass;
migrating one of three labels to `strings.psd1` while the others stay in markup
is the half-rename this log has already rejected once.

**2026-08-26 - The foundation view lays itself out; the other two stay on
dagre.** No dagre ranker bounds the width of a layer, and that is the whole
problem: `longest-path` put 29 of 62 nodes in one row for an 11:1 drawing, and
`network-simplex` only reached 24. `scripts/foundation.js` assigns layers under
a capacity and reduces crossings with a median sweep, reaching 10 layers of 7 at
1.3:1 on the same graph. Measured in both directions before choosing.

**2026-08-26 - Layer capacity is solved from the container's aspect, not
configured.** Width is capacity x stepX and height is (count / capacity) x
stepY, so setting their ratio to the container's gives the capacity directly.
A fixed number would be wrong on either a laptop or a wall display, and one
setting per screen size is not a design.

**2026-08-26 - `fitVisible()` will not zoom below `MinReadableZoom`.** Fitting a
large graph to the window is what turns labels into dashes, and a report nobody
can read has failed whatever its layout. Past the floor the view stops shrinking
and the reader pans; foundation opens at the bottom, where reading starts.

**2026-08-26 - The info panel takes rows, text and actions instead of only
text.** The selection panel needed label/value pairs and buttons, and a second
overlay would have duplicated the head, the copy button and the dismiss
handling. Generalising the one that existed was smaller than adding another, and
a third caller now needs no markup at all.

**2026-08-26 - Selection facts and actions are registries taking a collection.**
The interesting questions about several items are the ones a single item cannot
answer - what they all rest on, what they break between them - so the contract
takes the collection rather than iterating one at a time. Same `check` returning
null-or-reason as `NODE_ACTIONS`, so an inapplicable action greys out with the
reason.

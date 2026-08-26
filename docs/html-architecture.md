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

## Kaizen in this subsystem

The general rule is the **Kaizen** section of `CLAUDE.md`. Here it has a
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

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

## Extraction checklist

- [ ] No graph vocabulary below the seam  (setting names, template ids, GRAPH_* tokens)
- [x] Schema is data, not a hashtable in a `.ps1`
- [ ] All user-visible strings externalised to `strings.psd1`
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

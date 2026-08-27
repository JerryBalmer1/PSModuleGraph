# PSModuleGraph

Static inspection of PowerShell modules through the AST. Nothing is imported,
dot-sourced, or executed — every result traces back to a file and a line number.

> Repository: [PSModuleGraph](https://github.com/JerryBalmer1/PSModuleGraph)

## Quick start

```powershell
git clone https://github.com/JerryBalmer1/PSModuleGraph.git
cd PSModuleGraph
./build.ps1 -Bootstrap          # installs InvokeBuild, Pester 6.1.0, PSScriptAnalyzer
./build.ps1                     # Clean, Lint, Build, Test
./build.ps1 -Task Import        # load the built module into the current session
```

## Commands

| Command | Returns |
| --- | --- |
| `Get-PSModuleFunction` | Functions and filters, with export status resolved from the manifest |
| `Get-PSModuleClass` | Classes, base types, interfaces, DSC attribution |
| `Get-PSModuleEnum` | Enums with labels and underlying values |
| `Get-PSModuleManifest` | Parsed `.psd1` surface and declared dependencies |
| `Get-PSModuleSourceFile` | Every `.ps1`/`.psm1`/`.psd1` in the module, with parse status |
| `Get-PSModuleAssembly` | `RequiredAssemblies`, binary `NestedModules`, `Add-Type` sites, loose `.dll`s |
| `Get-PSModuleUsingStatement` | `using module` / `namespace` / `assembly` |
| `Get-PSModuleCommandReference` | Raw call sites attributed to the enclosing function |
| `Get-PSModuleDependencyGraph` | Node/edge model with roots, leaves, unresolved targets |
| `Export-PSModuleDependencyGraph` | JSON, Graphviz DOT, Mermaid, or CSV edge list |
| `Test-PSModuleGraphEditorLink` | Why `vscode://` links do or do not open from a browser. Read-only |
| `Enable-PSModuleGraphEditorLink` | Grants Chrome or Edge permission to open them. Prompts; `-Revert` undoes it |
| `Update-KnowledgeStore` | Regenerates a module's records in `knowledge/`. Prompts; `-WhatIf` lists every file. **See the caveat below** |

**`Update-KnowledgeStore` records one subject per NAME, and a name is not an
identity.** Run against SqlServerDsc it writes 327 subjects for 469 function
definitions - 142 get no record at all - and the one that survives names an
arbitrary file: `Get-TargetResource` is recorded as living in
`DSC_SqlWindowsFirewall`, for a function that exists in 32 files. That is a wrong
path rather than a missing one, and following it lands you in the wrong resource.
The graph stopped collapsing same-named definitions in v0.11.0; the store has not
caught up. Open, with the measurement, as ledger `0014-t1`.

## Parameter sets

Every command accepts the same three:

```powershell
Get-PSModuleFunction -Name PSReadLine                    # loaded first, then PSModulePath
Get-PSModuleFunction -Name PSReadLine -RequiredVersion 2.3.4
Get-PSModuleFunction -Path ./src/PSModuleGraph             # dir, .psd1, or .psm1
Get-Module PSReadLine | Get-PSModuleFunction             # PSModuleInfo from the pipeline
```

## Graph output

```powershell
Get-PSModuleDependencyGraph -Path ./src/PSModuleGraph |
    Export-PSModuleDependencyGraph -Format Dot -OutputPath ./output/graph.dot
dot -Tsvg ./output/graph.dot -o graph.svg
```

### A node's identity is its qualified path

**Changed in v0.11.0, and it is breaking.** A node's `Id` was `kind:name`. It is
now `kind:module/relative/path:Name`:

```
function:public/Get-SampleThing.ps1:Get-SampleThing
class:classes/SampleTypes.ps1:SampleBase
script:SampleModule.psm1:<script>
```

Anything that built or matched an id by hand — `Where-Object Id -eq
'function:Foo'` — stops matching. `Name` is untouched: the id got longer, the
label did not, and matching on `Name` behaves as it always did.

The old form could not tell two definitions apart. SqlServerDsc has **32
functions called `Get-TargetResource`**, one per DSC resource; under the old
identity they were 32 nodes and one addressable target, every edge landed on
whichever was parsed last, and the other 31 could not be reached by anything.

Because two definitions can now share a name, a call by name does not always
have one answer — PowerShell gives every function in a module one scope and the
last loaded wins, and load order is not in the source. Each edge says which it
got:

| `Resolution` | Meaning |
| --- | --- |
| `Unique` | One definition carries the name. |
| `SameFile` | Several do, and the calling file has one of its own. That one. |
| `Ambiguous` | Several do and none is in the calling file. **An edge is emitted to every candidate.** |

`$graph.AmbiguousNames` lists the names this applies to, and
`$graph.Stats.AmbiguousEdgeCount` counts the edges. On SqlServerDsc that is 702
of 1,271 — and the reason is worth knowing: it ships two copies of
`DscResource.Common`, so `Get-ComputerName` genuinely has two definitions and
which one runs depends on load order.

### Roots are not the same thing as dead code

`Roots` are nodes with **no inbound edge from inside this module**. That is all
it means. It is not the same as "entry points, or dead code", and on a real
module the difference matters: SqlServerDsc reports 252 roots, of which **62 are
`*-TargetResource` functions called by the DSC engine**, which is not in the
module and never will be. They are entry points in the truest sense and nothing
in the graph can see the caller.

A root is one of:

- something outside the module calls it — a DSC engine, a task scheduler, a
  user at a prompt;
- it is exported, and the caller is whoever imported the module;
- it is a file's top level, which runs at import;
- it is genuinely unreachable.

The graph cannot tell you which. Cross-check `IsExported` and the module's
purpose before deleting anything.

`Unresolved` holds call targets not defined inside the module. They are surfaced
rather than dropped, because the interesting bugs live there — and so are
`RequiredModules` entries and `using module` statements, which are dependencies
the graph cannot follow.

## HTML reports

**The renderer is a separate module.** `PSGraphRender` is a `RequiredModules`
entry, so importing PSModuleGraph requires it on `PSModulePath`; the build
resolves a sibling checkout or `$env:PSGRAPHRENDER_MODULE_PATH` and **fails by
name naming the version it found** if it does not satisfy the manifest.

```powershell
Get-PSModuleDependencyGraph -Path ./src/PSModuleGraph |
    Export-PSModuleDependencyGraph -Format Html -Show
```

Everything below the seam — the layout, the colours, the wording, which
JavaScript library draws the graph — belongs to that module and none of it knows
what a PowerShell module is. This one builds a **view model** and hands it over
in one call. The boundary is
[`contract/viewmodel.schema.json`](https://github.com/JerryBalmer1/PSGraphRender/blob/main/contract/viewmodel.schema.json),
currently 1.1.0, and a producer in any language can satisfy it. See
[PSGraphRender's README](https://github.com/JerryBalmer1/PSGraphRender#readme)
for the page itself, its settings and how to change how it looks.

What this module puts in the payload:

- one node per function, class and enum, plus one per file that has top-level
  code, each with its qualified id, its path and its line;
- edges, with the `Resolution` above carried as `links[].resolution`, so an
  uncertain edge is **drawn differently rather than identically** to a certain
  one;
- per-node measurements — direct dependents and dependencies, and the transitive
  `blastRadius` and `reach`;
- unresolved targets, when you pass `-IncludeUnresolved` - see the limitation
  below.

Without `-OutputPath` the page is written under `output/reports/` in the current
directory, which a local dev server can serve; with it, wherever you say. Omit
`-Show` to get the document back as a string.

```powershell
Get-PSModuleDependencyGraph -Path ./src/PSModuleGraph |
    Export-PSModuleDependencyGraph -Format Html -OutputPath ./output/graph.html
```

> **`-Format Html -IncludeUnresolved` currently fails** for any module with a
> `RequiredModules` entry or a `using module` statement. Those unresolved records
> have no line number to carry, and the view model contract types
> `unresolved[].startLine` as an integer, so the payload is refused at the seam.
> The other four formats take `-IncludeUnresolved` without complaint. The error
> suggests `-SkipValidation`, which is a `New-RenderDocument` parameter this
> command does not expose, so there is no way past it from here. Found while
> checking this README; logged as ledger `0016-t1`, not fixed in a docs pass.

### Clicking through to the source

Right-click a node for **Open File Location**, which hands the file and line to
VS Code over a `vscode://file/` URI. The absolute path is rebuilt in the browser
from the module root, so the payload keeps relative paths. **Copy Path** sits
below it, because a browser that refuses the scheme reports nothing back and the
page cannot tell you it was blocked.

No embedded viewer can follow a `vscode://` link — Live Preview, Simple Browser,
a notebook output cell — because the page is sandboxed and the URI never reaches
the OS. The page detects embedding, says so in a banner, and greys the menu item
with the reason. `-Show` always hands the report to the OS default handler, which
for `.html` is your browser, including when you run it from inside VS Code —
opening it in the editor would kill its own click-to-source.

#### If Open File Location does nothing

Nothing opening is the expected failure, not an unexpected one: a browser that
refuses a custom scheme reports nothing back to the page. Two things suppress it,
and they are independent - fixing one does not fix the other.

```powershell
Test-PSModuleGraphEditorLink            # read-only; says which of the two it is
Enable-PSModuleGraphEditorLink          # prompts before changing anything
```

Read `SchemeExclusionState` first. **Declined** means a prompt was shown once,
you said no, and the browser has remembered: no prompt will ever appear again.
**NeverAsked** means the key was never written, so a prompt *should* still be
appearing. **Allowed** means the scheme is not blocked in that profile.

`Enable-PSModuleGraphEditorLink` grants the `AutoLaunchProtocolsFromOrigins`
policy under `HKCU` and, with the browser closed and your confirmation, clears a
remembered refusal. It merges rather than replacing, so a grant already there for
Teams or Zoom survives. It never writes `HKLM` and never elevates. `-Revert`
puts back exactly what was there, including removing the value when there was
none.

**Restart the browser completely afterwards** - every window, not just the tab.

Note on origins: the default grant is scoped to `file:///*` and
`http://127.0.0.1:*`. Microsoft's Edge policy reference states that this policy
does not work as expected with `file://` wildcards, so the scoped default may
apply cleanly and still not be honoured. `-AllowedOrigin` takes whatever pattern
turns out to work for your setup; `-AllowAnyOrigin` grants the protocol from
every origin and is deliberately opt-in.

Either way, **Copy Editor Link** always works: paste the URI into the Run dialog.

### What the page does with the graph

Three orderings, and the page opens in **Foundation**: vertical, with what
everything else rests on at the bottom. **Test order** lays dependencies out
left to right, so a node's column is the step it belongs to — step 1 is
everything that depends on nothing internal, and testing in that order means the
first failure is the cause rather than an echo. **Call flow** points caller to
callee.

Anything caught in a dependency cycle has no valid position in an order, so it
is called out separately rather than silently given one.

Colour, wording, spacing, the default view and how an uncertain edge is drawn
are all settings and theme data in the renderer, not in this module and not in
the page's markup. `PSGraphRender`'s README says where they live and how to
change them.

The page is fully self-contained — its libraries are vendored, so it needs no
network at any point.

## The corpus

`gallery/` holds eight real modules from the PowerShell Gallery, pinned by
version and chosen because each breaks something the others do not: shipped
assemblies, an Azure module whose exports are C# cmdlets, a generated
single-file `.psm1`, class-based DSC resources with a `using module` chain, a
module built on name-based dispatch, and a manifest with no code at all.

**The source is never committed.** `corpus.lock.json` pins a URI and a SHA-256
per package; `gallery/fetch.ps1` refuses bytes that do not match.

```powershell
./gallery/fetch.ps1          # download and verify
./build.ps1 -Task Build
./gallery/run.ps1            # one result file per module under gallery/results/
```

Results are committed, one JSON per module per run, shaped by
`gallery/contract/run-result.schema.json`. A run that throws, hangs or was never
fetched still produces a record with the failure in it — a corpus where failures
are absent measures only the modules that worked.

Read `counts.nodes` next to `counts.declaredExports`. A module declaring 47
exports and yielding four nodes has not been understood, whatever `outcome`
says; one declaring none and yielding none may be perfectly described. Nothing
else in the record separates those two.

**Nothing in `gallery/` imports a corpus module.** These are modules nobody
vetted, which is exactly the situation a user is in.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.4+ (Pester 6 dropped everything else)
- [PSGraphRender](https://github.com/JerryBalmer1/PSGraphRender) 0.7.0 or newer,
  for `-Format Html`. It is a `RequiredModules` entry, so it must be resolvable
  before this module will import at all.
- Build-time: InvokeBuild, Pester 6.1.0, PSScriptAnalyzer
- `gallery/` needs network access the first time, and nothing after that

## License

MIT

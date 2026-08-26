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

`Roots` are nodes with no inbound internal edge — entry points, or dead code.
`Unresolved` holds call targets that are not defined inside the module; they are
surfaced rather than silently dropped, because the interesting bugs live there.

### Interactive HTML

```powershell
Get-PSModuleDependencyGraph -Path ./src/PSModuleGraph |
    Export-PSModuleDependencyGraph -Format Html -Show
```

Produces a single self-contained page: search, filter by kind or export status,
click a node to focus its neighbourhood at a chosen depth in either direction —
*Dependents* (what breaks if I change this) or *Dependencies* (what this needs).
Border thickness tracks how many things depend on a node, so the heavy-bordered
ones are the risky ones.

The divider between the sidebar and the graph is draggable — the test-order list
holds long function names that do not fit 300px. Double-click it to reset, or
focus it and use the arrow keys.

Arrows follow the reading order: in **Test order** an arrow means "test this one
first, then the one it points at"; in **Call flow** it points caller to callee.
Selecting a node dims everything outside its neighbourhood rather than hiding
it, so the names around it stay readable. Inside the neighbourhood the
connections are drawn bright and thick, and each node shades one step darker
per hop from the one you clicked, so the chain reads as a sequence. Nodes
connected the other way round - a dependency when you asked about dependents -
keep their colour too, darker still: related, but not the answer.

Right-click a node for **Open File Location**, which hands the file and line to
VS Code over a `vscode://file/` URI. The absolute path is rebuilt in the browser
from the module root, so the payload itself keeps relative paths. On an
unresolved external target the item reads *Open Call Site* — the only path the
page has for one is where it is called from. **Copy Path** sits below it: a
browser that refuses the `vscode://` scheme reports nothing back, so the page
cannot tell you it was blocked.

Note that no embedded viewer can follow a `vscode://` link — Live Preview, Simple
Browser, a notebook output cell — because the page is sandboxed and the URI never
reaches the OS. The page detects any embedding, says so in a banner on load, and
greys the menu item with the reason. Open the report in a real browser for it to
work, which is what `-Show` does.

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

#### Changing the page defaults

The page's starting values live in `Assets/graph.defaults.psd1` inside the
installed module — zoom speed and its slider range, node type size and width
cap, layout spacing, the large-graph threshold, sidebar geometry, and focus
depth. It is read with `Import-PowerShellDataFile`, so it is parsed as data and
never executed.

Every key is range-checked. A value that is missing, non-numeric, out of range,
or misspelled falls back to the built-in default with a warning naming the key,
and a file that will not parse warns and falls back whole rather than failing
the export. Zoom speed, sidebar width, and focus depth are all adjustable in the
page itself; the file sets where they start.

#### Test order is the default view

The page opens in **Test order**: dependencies first, laid out left to right, so
a node's column is the step it belongs to. Step 1 is everything that depends on
nothing internal and can be tested in isolation; nothing in a step depends on
anything in a later one.

The sidebar lists the steps in order, ready to drive a Pester run. Test in that
order and the first failure is the cause rather than an echo — you stop sifting
a wall of red to find what actually broke. Switch to **Call flow** for the
opposite orientation, callers first.

Anything caught in a dependency cycle has no valid position in the order, so it
is called out separately rather than silently given one.

`-Show` always hands the report to the OS default handler, which for `.html` is
your browser — including when you run it from inside VS Code.

That is deliberate. An HTML preview inside the editor is a webview, and a webview
sandboxes custom-scheme navigation, so a `vscode://` URI never reaches the OS
from one. Opening the report in the editor would therefore kill its own
click-to-source. Run from inside VS Code, `-Show` opens the browser and mentions
under `-Verbose` the command that would show the source instead.

Without `-OutputPath` the page goes to `<temp>/PSModuleGraph/<ModuleName>.html`
and is overwritten every run, so an already-open tab or editor just needs a
refresh rather than accumulating a new file each time. With `-OutputPath` it is
written there:

```powershell
Get-PSModuleDependencyGraph -Path ./src/PSModuleGraph |
    Export-PSModuleDependencyGraph -Format Html -OutputPath ./output/graph.html -IncludeUnresolved
```

Omit `-Show` to get the HTML back as a string instead. The page pulls Cytoscape
from a CDN, so it needs internet access the first time it is opened; it says so
plainly rather than rendering blank if it cannot.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.4+ (Pester 6 dropped everything else)
- Build-time: InvokeBuild, Pester 6.1.0, PSScriptAnalyzer

## License

MIT

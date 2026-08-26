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
per hop from the one you clicked, so the chain reads as a sequence.

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

`-Show` opens the report where you already are. Run from inside VS Code, it opens
the file in your existing window; click the editor's preview button to render it.
The VS Code CLI has no flag for running an extension command, so the preview pane
cannot be opened automatically, and VS Code has no built-in HTML preview - that
needs an extension such as Live Preview (`ms-vscode.live-server`). Anywhere else,
`-Show` hands the file to the OS default handler, which for `.html` is your
browser.

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

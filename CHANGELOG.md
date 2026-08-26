# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **The report opens on a vertical Foundation view.** What everything rests on
  is stacked at the bottom and its dependents rise above it, so the shape of the
  module reads before a single label does. The two previous horizontal views,
  Test order and Call flow, are unchanged and one radio away.

  Which view a report opens in is now the `DefaultFlow` setting in
  `settings.psd1` — the first shipped `Enum` setting — rather than a `checked`
  attribute in the markup, so changing it is a data change. See the gravity rule
  in `CLAUDE.md`: foundation-at-the-bottom is an invariant meant to extend to
  anything else that gains a spatial arrangement, not a default to revisit.
- **`Test-PSModuleGraphEditorLink`** — says why **Open File Location** does or
  does not open VS Code. Read-only, with no `ShouldProcess`, because there is
  nothing to confirm: it reports whether the `vscode` scheme is registered, what
  command is behind it, the default browser, and per browser the policy path,
  whether the scheme is granted and from which origins, whether a machine policy
  would override the user one, and whether the browser has remembered a decision.

  `SchemeExclusionState` is tri-state and the third state is the useful one.
  **Declined** means a prompt was shown once, refused, and will never be shown
  again. **NeverAsked** means the key was never written, so a prompt *should*
  still be appearing — if none is, neither mechanism explains the silence.
  **Allowed** means the scheme is not blocked in that profile. It also reports
  `ExternalProtocolDialogShowAlwaysOpenCheckbox` from both the user and machine
  policy keys: it does not suppress the prompt, but when it is disabled the user
  cannot grant a per-site exemption either.

  On macOS and Linux it returns the object with the platform set and warns, since
  automatic configuration is Windows-only. Firefox has no equivalent policy and
  is reported as unsupported rather than half-handled.
- **`Enable-PSModuleGraphEditorLink`** — the opt-in fix. It and its `-Revert` are
  the only things in the module that change machine state, and it is built to be
  boring about it: `ConfirmImpact = 'High'` so it prompts by default, `-WhatIf`
  prints the registry path, value name, old value and new value, `HKCU` only with
  no elevation, and a machine-wide policy that would win is reported rather than
  worked around.

  It **merges**: a policy value already granting Teams or Zoom is carried through
  untouched, because clobbering it would break that software with no symptom
  pointing back here. `-Revert` restores exactly what was there, including
  removing the value entirely when there was none before.

  A refusal remembered in the browser's `Local State` is cleared only with the
  browser closed and your confirmation, and the file is backed up alongside
  itself first. Chrome and Edge rewrite `Local State` from memory on exit, so the
  command detects the running process, names it and asks — it never kills it.
  `ConvertFrom-Json -AsHashtable` is PowerShell 7 only; on 5.1 it reports the file
  and key for you to edit by hand.

  `-AllowedOrigin` takes the origin list. The scoped default is `file:///*` and
  `http://127.0.0.1:*` — but Microsoft's Edge policy reference states that this
  policy does not work as expected with `file://` wildcards, while Chrome accepts
  `file:///*` as valid syntax. The entry may therefore apply cleanly and be
  ignored, so which pattern works is a parameter rather than a constant.
  `-AllowAnyOrigin` grants the protocol from every origin and never engages on
  its own; passing it together with `-AllowedOrigin` is refused rather than one
  of them silently winning.
- **The no-launch banner names the command that fixes it**, with a button that
  copies the command to the clipboard. A browser that refuses a custom scheme
  reports nothing back, so the page watches for focus loss and, when none comes,
  says what to run. Another link would be no use — the one it replaces has just
  been shown not to work.
- **Every user-visible string in the report now lives in
  `Assets/Html/Config/strings.psd1`**, the fourth data file, resolved by
  `Resolve-HtmlString`. Wording is a data change. The command name in the banner
  is passed down through config as a generic `editorLinkHelpCommand`, so the
  renderer interpolates a string it was handed and still knows nothing about
  PSModuleGraph. A string the page asks for and cannot find renders as its own
  key in brackets rather than as nothing.

- **Right-click a node for a context menu**, starting with **Open File
  Location** — hands the file and line to VS Code over a `vscode://file/` URI.
  Actions come from a registry in the template rather than from markup, so a
  second one is a single entry: a label, a rule for when it applies, and what it
  does. An action that does not apply greys out with the reason rather than
  disappearing.

  On an unresolved external target the item reads **Open Call Site**, because
  the only path the page has for one is where it is called from — its definition
  is precisely what static analysis could not find.
- **Connections the other way round from the chosen direction get their own
  tier.** Asking *Dependents* ("what breaks if I change this") used to leave the
  node's own dependencies in the same grey as things with no connection at all.
  They now keep their kind colour, darkened past the focused chain, with a
  legible label - related, but plainly not the answer to the question asked.
  `RelatedShadeBase` and `RelatedShadeMax` are settable in
  `graph.defaults.psd1`. *Both* has no opposite, so nothing changes there.
- **Focused nodes shade by hop distance.** The selected node keeps its full
  colour and each hop away is a step darker, so a focused chain reads as a
  sequence instead of one flat block of blue. Shading darkens each node through
  its own kind colour rather than recolouring it, so a class or an enum in the
  chain stays a class or an enum. `FocusShadeStep` and `FocusShadeMax` are
  settable in `graph.defaults.psd1`.
- **Focused connections are highlighted, not merely undimmed.** Selecting a node
  now draws the edges inside its neighbourhood in a near-white blue at roughly
  double thickness, above the dimmed ones. An edge with only one end inside the
  neighbourhood stays dimmed - drawing it bright would imply a link to something
  that is not part of the answer. `EdgeWidth` and `FocusEdgeWidth` are settable
  in `graph.defaults.psd1`.
- **`Assets/graph.defaults.psd1`** — the HTML page's starting values in one
  editable data file instead of scattered through the template: zoom speed and
  its slider range, node type size and width cap, dagre spacing, the large-graph
  threshold, sidebar geometry, and focus depth. Read with
  `Import-PowerShellDataFile`, so it is parsed as restricted data and never
  executed. Every key is validated against a range; anything missing,
  non-numeric, out of range, or misspelled falls back with a warning naming the
  key, and a file that will not parse at all warns and falls back whole rather
  than failing the export.
- **Uniform node boxes in the HTML page.** Every node is now the width of the
  longest label in the graph instead of being sized to its own, so the boxes
  line up in columns rather than jittering with name length. The width is
  measured on a canvas in the font the renderer uses, not estimated from a
  character count. A name too long to fit a 340px box ellipsises on the node;
  the full name stays in search, the test-order list, and Details.
- **A draggable splitter between the HTML page's sidebar and the graph.** The
  sidebar was a fixed 300px, which truncates the long function names in the
  test-order list. Drag the divider to resize, double-click it to reset to
  300px, or focus it and use the arrow keys. The sidebar clamps at 200px and
  never squeezes the graph below 320px.
- **`Export-PSModuleDependencyGraph -Format Html`** — a single self-contained
  interactive page. Search, filter by node kind or export status, optionally show
  unresolved targets, and click any node to focus its neighbourhood at a chosen
  depth in either direction: *Dependents* (what breaks if I change this) or
  *Dependencies* (what this needs). Node size tracks inbound edge count, exported
  functions are marked with a border rather than a fill so the cue survives
  greyscale, and above 400 nodes the view starts filtered to exported functions
  behind a dismissible banner.

  The page renders with Cytoscape and cytoscape-dagre loaded from a CDN with
  Subresource Integrity, so it needs internet access the first time it is opened
  and says so plainly rather than rendering blank. Paths in the embedded payload
  are relative to the module root, so a report can be attached to a PR without
  leaking usernames or directory layout.
- **`-Show`** on `Export-PSModuleDependencyGraph`, which opens the generated page
  where you already are: inside VS Code it opens in the existing window, and the
  editor's preview button renders it, since the VS Code CLI exposes no way to
  trigger an extension's preview pane. Everywhere else the OS default handler
  gets it, which for `.html` is the browser. Valid only with `-Format Html`; any
  other format is a terminating error.

  With no `-OutputPath` the page goes to
  `<temp>/PSModuleGraph/<ModuleName>.html` — one stable file per module,
  overwritten on every run, so an already-open tab or editor only needs a
  refresh instead of a new file piling up each time.
- **`-Title`** on `Export-PSModuleDependencyGraph`, for the page heading.
  Defaults to `<ModuleName> dependency graph`.
- **Test order as the HTML page's default view.** Nodes are ranked by a
  topological sort of the dependency edges: step 1 depends on nothing internal
  and can be tested in isolation, and nothing in a step depends on anything in a
  later step. The layout puts step 1 leftmost so a node's column is its step, and
  the sidebar lists the steps in order for driving a Pester run. Testing in that
  order means the first failure is the cause rather than an echo of something
  earlier. A **Call flow** toggle gives the opposite orientation, callers first.

  Ordering uses Kahn's algorithm, so a dependency cycle cannot hang it: members
  of a cycle have no valid position and are reported separately instead of being
  given a misleading one.

- Initial command set, all static: nothing is imported, dot-sourced, or
  executed, and every result carries a file path and line number.
  - `Get-PSModuleFunction` — functions and filters, with export status resolved
    from the manifest.
  - `Get-PSModuleClass` — classes, base types, interfaces, DSC attribution.
  - `Get-PSModuleEnum` — enums with labels and underlying values.
  - `Get-PSModuleManifest` — parsed `.psd1` surface and declared dependencies.
  - `Get-PSModuleSourceFile` — every `.ps1`/`.psm1`/`.psd1` in the module, with
    parse status.
  - `Get-PSModuleAssembly` — `RequiredAssemblies`, binary `NestedModules`,
    `Add-Type` sites, loose `.dll`s.
  - `Get-PSModuleUsingStatement` — `using module` / `namespace` / `assembly`.
  - `Get-PSModuleCommandReference` — raw call sites attributed to the enclosing
    function.
  - `Get-PSModuleDependencyGraph` — node/edge model with roots, leaves, and
    unresolved targets.
  - `Export-PSModuleDependencyGraph` — JSON, Graphviz DOT, Mermaid, or CSV edge
    list.
- Three parameter sets on every module-inspecting command: `ByName` (with
  `-RequiredVersion`), `ByPath`, and `ByModuleInfo` from the pipeline.
- `-NoCache` on the internal parsed-file helper, bypassing AST memoisation.
- `about_PSModuleGraph` help topic covering the parameter sets and the
  no-execution guarantee.
- `Requirements.psd1` as the single source of truth for build dependencies.
- `PSScriptAnalyzerSettings.psd1`, including `PSUseCompatibleSyntax` against
  PowerShell 5.1 and 7.4.
- JaCoCo code coverage in the build, written to `output/coverage.xml`.

### Changed

- **Graph edges use `Source`/`Target` instead of `From`/`To`.** Edge objects now
  expose `Source`, `Target`, `SourceName`, and `TargetName`; unresolved
  references expose `Source` and `SourceName`. The JSON export renames the
  `edges` key to `links` and emits `source`/`target` on each element, which is
  the node-link shape D3, NetworkX, and Cytoscape consume directly with no
  transform step. The CSV header is now
  `Source,Target,SourceName,TargetName,Kind,Path,StartLine`.

  `Roots` and `Leaves` remain full node objects on the PowerShell object and
  bare id strings in JSON; that asymmetry is deliberate.

- Parsed ASTs are memoised on file path plus last write time, so a graph build
  parses each file once instead of once per getter.
- Graph serialisation helpers moved from `Public/` to `Private/`, one function
  per file. The exported surface is unchanged at ten commands.
- The dev loader and the build now enumerate `Private/` recursively, so helpers
  can be grouped into subfolders. `Public/` stays flat, because the export list
  is derived from its filenames. Both loaders set `$script:ModuleRoot` at import
  so assets resolve identically from source and from the built module, and the
  build copies `Assets/` into the output.
- Test run uses Pester's `Run.Throw` rather than `Run.Exit`, so a failing suite
  cannot terminate the host process running the build.
- Classic Pester v5 `Should -Be` assertions are disabled; the suite uses the
  hyphenated `Should-*` form.

### Fixed

- **A report opened in a VS Code preview pane claimed the browser was blocking
  `vscode://` links.** It was not; no browser was involved. An editor preview
  runs the page in the editor's own Electron renderer, which swallows a custom
  scheme with no prompt and no error - the same silence a refusing browser
  produces, and indistinguishable from it without looking at the user agent.

  `isEmbeddedContext()` missed it because the page is genuinely top-level
  (`window.top === window.self`), served over `file:` rather than
  `vscode-webview:`, and reports no ancestor origins. Every check it had was
  looking for a frame. It now also treats any user agent reporting `Electron/`
  as embedded, matched generically rather than on a product name because every
  Electron host has the same limitation.

  The consequence was not cosmetic. The banner named a command that fixes a
  browser policy, in an environment where no browser policy applies, sending a
  whole round of diagnosis at the wrong layer. The message now says what is
  actually true: the viewer cannot hand the URI to the operating system, so
  re-open the report in a real browser or use **Copy Editor Link**.
- **A stray coverage report was tracked at the repository root.** The build has
  always written coverage under `output/`; the root copy came from a bare
  `Invoke-Pester`, which defaults to the working directory. That is what the
  "never call `Invoke-Pester` directly" rule exists to prevent. The file is
  removed from tracking and `.gitignore` now names it, so a future stray one
  stays untracked rather than being swept up by a wildcard `git add`.

  It reached the repository in commit `34a4193`, whose message is `asdf`. That
  commit is pushed and is not being rewritten. What it carried that matters is
  `tests/Public/EditorLink.Tests.ps1` - the suite covering the two editor-link
  commands, which runs entirely against `TestRegistry:` and `TestDrive:` and
  touches no real registry key or browser profile. Noted here because the commit
  message records none of it.
- **`Open File Location` did nothing when clicked, and the page did not say
  why.** Two compounding causes, both fixed.

  `-Show` opened the report inside VS Code when run from there, which shows the
  HTML source, so the report was viewed through a preview extension. Every one
  of those is a webview, and a webview sandboxes custom-scheme navigation — a
  `vscode://file/...` URI never leaves one. The tool was routing its own output
  into the single environment where its own link cannot work. Reports now always
  open in the default browser; inside VS Code, `-Verbose` names the command that
  would show the source instead.

  The page's own guard did not fire either. It tested `location.protocol` for
  `vscode-webview:` and scanned `ancestorOrigins`, but Live Preview serves over
  `http://127.0.0.1` and a nested cross-origin frame reports opaque origins, so
  detection returned false and the item rendered enabled. It now checks first
  whether the page is framed at all, which catches every embedded viewer without
  sniffing for any one of them, and says so in a banner on load rather than only
  in the context menu.
- **Menu actions that hand a URI to another application are real links.** The
  first version of `Open File Location` assigned
  `window.location.href` to the `vscode://` URI, which Chrome discards in
  silence — no navigation, no error, nothing in the console. Menu actions that
  hand a URI to another application now render as real links, which is the
  supported route. A **Copy Path** item sits underneath, because a refused or
  unregistered protocol launch reports nothing back and the page has no way to
  detect it.
- The HTML page's focus mode faded every out-of-focus node and its label to 0.15
  opacity, which reads as gone. Losing the surrounding names loses the context
  that makes a focused neighbourhood mean anything. Out-of-focus nodes now take
  a muted fill with a legible label, so they stay readable while the focused
  ones carry the colour.
- Arrowheads in the HTML page's **Test order** view pointed against the reading
  order. Test order ranks right-to-left so the page reads left-to-right in the
  order to test, but the arrows still pointed at the callee. They now sit on the
  other end in that view, so an arrow means "test this one first, then the one
  it points at". **Call flow** is unchanged and still points caller to callee.
- The HTML page's sidebar and test-order list used the platform default
  scrollbar — a thin overlay bar that fades out — which was close to impossible
  to grab with a mouse. Both now draw a 14px track with an always-visible thumb
  that has a minimum height, so a long list still leaves something to drag.
- `Get-PSModuleFileInventory` matched its `.git`/`output`/`tests`/`.tools`
  exclusion list against the absolute path, so a module located under a
  directory with one of those names lost its entire filesystem scan and
  reported almost nothing. Exclusions now match the path relative to the module
  base.
- `Get-PSModuleUsingStatement` and `Get-PSModuleAssembly` assigned to a local
  `$name`, which is the same variable as the `$Name` parameter because
  PowerShell variable names are case-insensitive. Each assignment re-ran the
  parameter's `[ValidateNotNullOrEmpty()]` attribute and threw. This also took
  down `Get-PSModuleDependencyGraph`, which calls the former.

[Unreleased]: https://github.com/JerryBalmer1/PSModuleGraph/commits/main

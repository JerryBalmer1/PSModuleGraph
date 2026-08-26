# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
  in the default web browser — not VS Code, which has no built-in HTML preview.
  Valid only with `-Format Html`; any other format is a terminating error. With
  no `-OutputPath` the page goes to a temp file that is opened and returned.
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

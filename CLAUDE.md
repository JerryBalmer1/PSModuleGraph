# CLAUDE.md — working rules for PSModuleGraph

Guidance for an agent editing this repository. It covers only what is easy to
get wrong here. General PowerShell practice is assumed and not repeated.

## The core constraint

**This module never runs the code it analyses.** No `Import-Module`, no
dot-sourcing, no `Invoke-Expression`, no reflection load, no `Add-Type` against
the target, and no invocation of anything the target defines. Every fact comes
from the AST, `Import-PowerShellDataFile`, or the filesystem.

Users point this at repositories they have not read and do not trust. Importing
a module executes its top level, its `ScriptsToProcess`, and any class static
constructors — that is arbitrary code execution on the user's machine.

If answering a question would require importing the target, **return less
information instead**. An incomplete-but-honest result is correct; an accurate
result obtained by executing untrusted code is a security bug. When something
cannot be resolved statically, report it as unresolved rather than resolving it
dynamically.

The one deliberate exception is `Import-PowerShellDataFile`, which parses
`.psd1` as restricted data and does not execute it. Do not replace it with
`Invoke-Expression` or with dot-sourcing the manifest.

`Get-Module -ListAvailable` is also fine: it reads manifest metadata and does
not import. `Resolve-PSModuleTarget` uses it for path discovery only — never
call `Import-Module` to "just check" something.

## Build

```powershell
./build.ps1 -Bootstrap      # install InvokeBuild, Pester 6.1.0, PSScriptAnalyzer
./build.ps1                 # default task: Clean, Lint, Build, Test
./build.ps1 -Task Import    # load the built module into this session
./build.ps1 -Task Lint      # analyzer only
```

**Never call `Invoke-Pester` or `Invoke-Build` directly.** `build.ps1` pins
Pester to exactly 6.1.0 and verifies it before handing off. Pester 5 and Pester
6 disagree on assertion syntax, discovery, and mocking, and several 5.x versions
are usually also installed — a bare `Invoke-Pester` will silently pick the wrong
one and produce results that mean nothing. `build.ps1` is the only supported
entry point.

Build dependency versions live in `Requirements.psd1`. Change them there, not in
`build.ps1`.

## Layout

```
build.ps1                        bootstrap + dispatch (the entry point)
PSModuleGraph.build.ps1          InvokeBuild tasks: Clean, Lint, Build, Test, Import
Requirements.psd1                pinned build dependencies
PSScriptAnalyzerSettings.psd1    lint rules (passed via -Settings)
src/PSModuleGraph/
  PSModuleGraph.psd1             the manifest; FunctionsToExport is explicit
  PSModuleGraph.psm1             dev-time loader only — see below
  Public/                        one exported function per file; NOT recursive
  Private/                       helpers; not exported; enumerated recursively
    Html/                        everything behind -Format Html
  Assets/                        static files shipped as-is (graph.html)
  en-US/                         about_ help topic
tests/
  Public/  Private/              mirror the src layout
  Module.Quality.Tests.ps1       asserts on the BUILT module, not source
  fixtures/SampleModule/         the module under analysis in tests
output/                          build artifact, gitignored, never edited
```

`src/PSModuleGraph/PSModuleGraph.psm1` is a **development loader**. It
dot-sources `Private/` then `Public/` at import time so the source tree can be
imported directly. It is *not* what ships. The `Build` task concatenates every
`Private/` file then every `Public/` file into a brand new
`output/PSModuleGraph/PSModuleGraph.psm1` with a generated
`Export-ModuleMember` at the end.

Consequences:

- **Never edit anything under `output/`.** It is regenerated on every build and
  wiped by `Clean`. Edits there vanish and mislead.
- Tests import the built module from `output/` when it exists and fall back to
  `src/` otherwise (`tests/TestHelpers.ps1`). A stale `output/` will therefore
  mask source edits — run `./build.ps1` rather than testing against a stale
  artifact.
- `Private/` is dot-sourced before `Public/` in both loaders, so a public
  function may call any private helper with no import ceremony and no ordering
  work. That ordering is load-bearing; do not reorder it.
- The generated `.psm1` exports exactly the `Public/*.ps1` basenames. A function
  is exported by virtue of *where its file is*, so a private helper sitting in
  `Public/` gets exported by accident. Helpers belong in `Private/`.
- The manifest's `FunctionsToExport` is an explicit list. Adding a file to
  `Public/` is not enough — add the name to the manifest too, or it builds
  clean and is unavailable to users.

## Parsing

**Always `[Parser]::ParseFile`, never `[Parser]::ParseInput`.** `ParseInput`
leaves `$ast.Extent.File` null, so every node parsed that way loses its path and
every downstream record reports a null `Path`. The entire value proposition here
is that a result traces back to a file and a line number.

All parsing goes through `Get-PSModuleParsedFile` (Private). Do not call the
parser directly from a public command. It normalises the path, returns tokens
and parse errors alongside the AST, and memoises on path plus last-write time,
so an unchanged file is parsed once no matter how many getters ask for it, while
an edited file is re-parsed. Pass `-NoCache` to bypass.

The cache matters: `Get-PSModuleDependencyGraph` calls seven getters, each of
which walks every file in the module.

`Get-PSModuleScriptAstFile` wraps it to yield parsed ASTs for a whole target.
Prefer it over hand-rolling an inventory walk.

Parse errors are data, not failures. A file that does not parse is reported with
`IsParsed = $false` and its errors attached; it does not abort the run. A module
with one broken file still yields results for the others.

`.psd1` files are parsed but skipped by most walkers — the usual guard is
`if ($file.Path -like '*.psd1') { continue }`. Manifest *content* comes from
`Get-ManifestDataSafe` / `Import-PowerShellDataFile`, not from walking its AST.

## Adding or changing a public command

**One exported function per file, and the filename must equal the function
name.** The build derives both the export list and the module surface from
`Public/*.ps1` basenames, so a mismatch produces a module that exports a name
nothing defines.

**Every module-inspecting command implements the same three parameter sets:**

| Set | Parameters | Notes |
| --- | --- | --- |
| `ByName` | `-Name` (Mandatory, Position 0), `-RequiredVersion` | the default set |
| `ByPath` | `-Path` (Mandatory) | directory, `.psd1`, `.psm1`, or `.ps1` |
| `ByModuleInfo` | `-ModuleInfo` (Mandatory, `ValueFromPipeline`) | accepts `PSModuleInfo` from the pipeline |

Declare them with `[CmdletBinding(DefaultParameterSetName = 'ByName')]`, then in
`process` resolve the target in one step and do nothing else:

```powershell
$target = Resolve-BoundParameter -Name $Name -RequiredVersion $RequiredVersion -Path $Path -ModuleInfo $ModuleInfo -ParameterSetName $PSCmdlet.ParameterSetName
```

**All target resolution lives in `Resolve-PSModuleTarget` and
`Resolve-BoundParameter`, and nowhere else.** Do not re-implement name lookup,
version selection, manifest discovery, or path probing in a public command. If
resolution needs to change, change it in those two files so every command
changes together.

`Export-PSModuleDependencyGraph` is the deliberate exception — it consumes a
graph object, not a module, so it has no parameter sets.

Naming: **approved verbs** (`Get-Verb`) and **singular nouns**.
`Get-PSModuleFunction`, not `Get-PSModuleFunctions`. The analyzer enforces both
and there are no suppressions — if `PSUseSingularNouns` fires, the name is
wrong, so fix the name rather than the settings file.

Emit `pscustomobject` with a `PSTypeName` of `PSModuleGraph.<Thing>`. Every
record carries `Path` and `StartLine`.

## The HTML export

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
- **Page defaults live in `src/PSModuleGraph/Assets/graph.defaults.psd1`**, not
  in the template. `Get-GraphPageDefault` reads it with
  `Import-PowerShellDataFile` — the same restricted-data exception the module
  already makes for manifests — validates every key against a range, and warns
  and falls back rather than throwing. Adding a setting means: a key in the
  `.psd1`, a row in that function's `$schema` (a key absent from `$schema` is
  not a setting, whatever the file says), and a `cfg('Key', fallback)` in the
  template. The JS fallbacks are unreachable in a generated report — the page
  bails out earlier when `GRAPH_DATA` is null — and exist only so a missing key
  cannot become `NaN` in a layout calculation.

  `Import-PowerShellDataFile` needs `-ErrorAction Stop` there. A `.psd1` that
  will not parse raises a **non-terminating** error, so without it the `catch`
  never runs and a broken config falls back in total silence.
- Paths in the HTML payload are module-relative. Generated reports get attached
  to PRs and tickets, where absolute paths leak usernames. The JSON export keeps
  them absolute.
- **Node context-menu actions live in the `NODE_ACTIONS` registry** in
  `graph.html`, not in markup. An entry is `{ id, label, check, run }`, where
  `label` may be a function of the node and `check` returns `null` when the
  action applies or the reason it does not — an inapplicable action greys out
  with that reason rather than disappearing. Adding an action means adding one
  entry; nothing else needs touching.
- **The page rebuilds absolute paths in the browser** from `meta.moduleRoot`,
  which is how the `vscode://file/` link works while payload paths stay
  relative. Note that `meta.moduleRoot` is itself absolute, so the "no absolute
  paths in a shared report" rule above is already weaker than it sounds — a
  report does carry the module's own base path. Do not add absolute paths to
  `nodes`/`links` on the assumption that it makes no difference.
- **`-Show` opens VS Code when the session is in VS Code**, otherwise the OS
  default handler. `Get-VSCodeLauncher` requires BOTH a VS Code environment
  marker and the `code` CLI: finding the executable only proves VS Code is
  installed, not that the user is sitting in it. The CLI has no `--command` and
  no `--uri` flag, so an extension's preview pane cannot be opened from
  PowerShell - do not add code that pretends otherwise.
- `tests/Module.Quality.Tests.ps1` asserts `Assets/graph.html` reaches the built
  module. That is the only thing standing between a build change and a runtime
  failure in the export.

Watch for parameter shadowing: PowerShell variable names are case-insensitive,
so a local `$name` **is** the `$Name` parameter. Assigning to it re-runs the
parameter's validation attributes, and `$name = $null` against a
`[ValidateNotNullOrEmpty()]` parameter throws at that assignment. Name locals
distinctly (`$usingName`, `$nestedName`).

## Report, do not drop

Anything that cannot be resolved statically is **surfaced**, never silently
discarded. A dynamic invocation, a call to a command defined outside the module,
a `RequiredModules` entry, a `using module` — all of these appear in the output
as unresolved rather than being filtered away. The bugs users are hunting live
precisely in the things that could not be resolved, so dropping them defeats the
tool.

In the graph, `Unresolved` holds call targets not defined inside the module,
each with the call site that produced it. Silence there is a bug.

The one legitimate filter is the language-keyword ignore list in
`Get-PSModuleDependencyGraph` (`if`, `foreach`, `return`, and so on), which
suppresses parser artefacts rather than real call targets.

## Pester 6

The suite runs on Pester 6.1.0 exactly. Pester 6 is not Pester 5.

- **Discovery and run happen per file.** Every test file must carry its own
  `BeforeAll` that dot-sources `tests/TestHelpers.ps1` and imports the module.
  Nothing leaks between files — there is no shared setup to lean on.
- Variables shared from `BeforeAll` into `It` need the `$script:` scope.
- **Use hyphenated `Should-*` assertions**, not `Should -Be`. So `Should-Be`,
  `Should-BeGreaterThan`, `Should-NotBeNull`, `Should-ContainCollection`,
  `Should-MatchString`, `Should-HaveType`. The build sets
  `Should.DisableV5 = $true`, so classic `Should -Be` throws rather than
  quietly working.
- **There is no `Should-NotThrow`.** To assert something does not throw, just
  call it — an exception fails the test on its own. Do not wrap it in
  `try`/`catch` and assert in the catch, which passes when the code is broken in
  a different way. `Should-Throw` does exist.
- **`-ForEach @()` or `-ForEach $null` fails discovery**, not the test, unless
  you also pass `-AllowNullOrEmptyForEach`. A `-ForEach` fed from a computed
  collection needs that switch, or an empty result takes down the whole file.
- **Mocks no longer fall through to the real command when a `-ParameterFilter`
  does not match.** In Pester 5 a missed filter called the original; in 6 it
  does not. Verify filters rather than assuming a fallthrough.
- **`Assert-MockCalled` is gone.** Use `Should-Invoke` / `Should-NotInvoke`.
- Coverage runs against the built `output/PSModuleGraph/PSModuleGraph.psm1`, not
  `src/`, so line numbers in coverage reports refer to the generated file.
  `CoverageGutters` was removed in Pester 6 — do not add it back.

A terminating error thrown inside a `BeforeAll` surfaces as a confusing
"a 'break' or 'continue' statement ... escaped from your code" failure on the
whole `Describe`, not as the underlying exception. When a `Describe` fails that
way, call the code under test directly to find the real error.

## Looks like a bug, but is not

`tests/fixtures/SampleModule` is a deliberately imperfect module. It is input
data, not a module anyone maintains. **It is never imported and never executed**
— tests only ever pass its *path*. Do not "fix" the following:

- **`RequiredModules` pins `Pester 5.0.0`** while this repo builds on 6.1.0.
  Nothing installs or loads it. It exists so the graph has a `RequiredModule`
  entry to surface under `Unresolved`. Bumping it to 6.1.0 changes nothing and
  loses the version-mismatch shape.
- **Three of its five functions are absent from `FunctionsToExport`.**
  `ConvertTo-SampleName`, `New-SampleThing`, and `Test-SampleThing` are private
  on purpose, so `IsExported` is exercised in both states. Exporting them makes
  those assertions vacuous.
- **`Invoke-SampleWorkflow` calls `Get-Date` for no reason.** That is the
  external, out-of-module call target the `Unresolved` tests assert on.
- **`Test-SampleThing` throws.** It never runs. It is there to be parsed.
- **`SampleThing : SampleBase` inheritance and the `SampleStatus` enum** exist to
  produce exactly 2 classes, 1 enum, and one `Inherits` edge. Several tests
  assert those exact counts, so adding a class or enum to the fixture breaks
  tests that are not obviously related to it.
- **The fixture lives under `tests/`**, which is also a name in the inventory
  exclusion list in `Get-PSModuleFileInventory`. That exclusion is matched
  against the path **relative to the module base**, deliberately. Reverting it to
  match the absolute `FullName` makes the scan drop every file in the fixture —
  and every file of any real module a user keeps under a directory named
  `tests`, `output`, or `.tools`. The suite fails loudly if this regresses.

Elsewhere: `Get-HashtableValue` exists because `Set-StrictMode -Version Latest`
turns a missing key or property into a terminating error. Reading manifest data
with a plain property access will throw on any manifest that omits an optional
key. Use the helper.

## Open decisions

Not settled. Do not resolve one of these unilaterally as part of an unrelated
change — raise it first.

- **Should the graph recurse into `RequiredModules`?** Today they are reported
  as unresolved external references and not followed. Following them would mean
  resolving and parsing other modules on disk, which widens the blast radius and
  the runtime considerably.
- **Should there be a `-Depth` parameter for transitive walks?** Related to the
  above, and meaningless until recursion exists. The open question is whether
  depth should count module hops, call-graph hops, or both.
- **Should the graph types become real PowerShell classes** instead of
  `pscustomobject` with `PSTypeName`? Classes would give real type safety and
  cheaper construction, but they complicate the dot-source-and-concatenate build
  (classes are not visible across dot-sourced files the way functions are),
  interact badly with module reloading, and would need `using module` at every
  call site.

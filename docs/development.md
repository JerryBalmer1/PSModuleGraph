# Development

On-demand. Read this when changing the module's shape - adding a file, adding a
command, touching the build, or parsing something new. `CLAUDE.md` carries the
invariants; this carries the mechanics behind them.

Subsystem detail lives in the charters: `docs/html-architecture.md`,
`docs/editorlink-architecture.md`, `docs/knowledge-architecture.md`. Tests are
`docs/testing.md`.

## Build

```powershell
./build.ps1 -Bootstrap      # install InvokeBuild, Pester 6.1.0, PSScriptAnalyzer
./build.ps1                 # default task: Clean, Lint, Build, Test
./build.ps1 -Task PreTag    # the gates that seal a finished iteration
./build.ps1 -Task Knowledge # regenerate the knowledge store
./build.ps1 -Task Import    # load the built module into this session
./build.ps1 -Task Lint      # analyzer only
```

**Never call `Invoke-Pester` or `Invoke-Build` directly** - see `docs/testing.md`
for why. Build dependency versions live in `Requirements.psd1`, not in
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
  Assets/Html/                   the report renderer - see docs/html-architecture.md
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

## Strict mode and manifest data

`Get-HashtableValue` exists because `Set-StrictMode -Version Latest`
turns a missing key or property into a terminating error. Reading manifest data
with a plain property access will throw on any manifest that omits an optional
key. Use the helper.

## Serving reports locally

`.vscode/settings.json` points Live Server (`ritwickdey.LiveServer`) at
`/output/reports` rather than the workspace root, so a hand-typed
`127.0.0.1:5500` lands on a list of reports instead of a listing of the whole
repository. Setting names were checked against the extension's own
`docs/settings.md`; `liveServer.settings.file` exists but names a single
entry-point file for a single-page app, which cannot fit report names that carry
a timestamp.

`-Show` does not go via any listing. It probes 127.0.0.1 on 5500, 3000, 8080 and
8000, works out whether the report is under a served root, and hands the browser
the exact document URL. Changing `liveServer.settings.root` requires stopping
and restarting Live Server - the probe follows either way, because it infers the
root rather than being told it.

## Tooling traps

These cost a round each and are not discoverable from the error message.

**The Bash tool collapses a doubled backslash to a single one inside a quoted
heredoc.** A JSON Schema written that way reaches disk with `\.` where it needed
`\\.`, which is not valid JSON. **Write JSON schemas with the Write tool, or with
a short script, rather than with a heredoc.** This paragraph was itself mangled
by the trap on its first attempt, which is the shortest available proof.

**`Test-Json` will not tell you where.** A schema it cannot parse produces
exactly `Cannot parse the JSON schema` - no line, no position, no field name.
To find the actual fault, round-trip the file through `ConvertFrom-Json` first,
which does report a path and a position. A validator that will not say *where*
costs more than one that says nothing, because the first sends you looking at
the document instead of the schema.

**`Import-PowerShellDataFile` needs `-ErrorAction Stop`.** A `.psd1` that will
not parse raises a **non-terminating** error, so without it the `catch` never
runs and a broken config falls back in total silence.

**A `-WhatIf` that reaches only half an operation is worse than none.**
`New-Item -ItemType Directory` supports ShouldProcess; `[System.IO.File]::WriteAllText`
does not. A command with no ShouldProcess of its own that calls both under a
session with `$WhatIfPreference` set skips the directory and then fails on the
write. Create a directory that a non-gated write depends on with
`[System.IO.Directory]::CreateDirectory`, and gate the step the user is actually
asking about.

**Parameter shadowing is case-insensitive.** A local `$name` **is** the `$Name`
parameter. Assigning to it re-runs the parameter's validation attributes, and
`$name = $null` against a `[ValidateNotNullOrEmpty()]` parameter throws at that
assignment. Name locals distinctly (`$usingName`, `$nestedName`).


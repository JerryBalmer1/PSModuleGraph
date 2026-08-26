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

## Working with the machine owner

This repository is developed on the owner's own desktop. Some work needs their
screen, keyboard, mouse or focus, and taking those without warning corrupts both
the measurement and their afternoon. This protocol is permanent.

### Status line

**Every response begins with one of these, on its own line, before anything
else.** No exceptions — including one-line responses and responses that are only
a question.

```
🟢 MACHINE FREE — nothing I'm doing needs your screen, keyboard, or mouse.
🔴 HANDS OFF — I need exclusive control. Details below.
🙋 YOUR TURN — I need you to do something. Details below.
❓ BLOCKED — I need an answer before I can continue.
```

A response that ends a hands-off period uses 🟢 and says so in its first
sentence: *"Done with the machine — it's yours."*

### Gates

A gate is a full stop. Post it and **wait for a reply.** Never post a gate and
keep working underneath it.

**🔴 HANDS OFF** — exclusive control of focus, the foreground window, the
clipboard, or the browser. State:

- what is about to run, in one sentence
- **exactly what not to do** — not "please avoid interacting" but "do not click
  anything, do not switch windows, do not type, do not move the mouse over the
  browser window"
- how long, as a number: "about 90 seconds", never "a short while"
- what breaks on a slip, so the cost of touching it is known
- to reply `go` when ready

**🙋 YOUR TURN** — something physical only they can do. Numbered steps, one
action each, in order, and what to report back. Recurring cases here: closing
every browser window so `Local State` can be written, clicking a link and
describing a dialog that cannot be screenshotted, reading back what an OS prompt
said.

**❓ BLOCKED** — exactly one question. Not a list. Three questions means the one
that actually blocks has not been identified yet.

**✅ RELEASE** — every 🔴 HANDS OFF is closed by an explicit release. If a run
ends while one is notionally open, close it before anything else in the
response. Never leave the owner guessing whether they can use their computer.

### Classify before running

Before executing anything, ask whether it depends on any of:

- window focus or blur events
- which window is in the foreground
- the clipboard
- launching, or being able to see, another application
- a browser being open, or being closed
- an OS or browser dialog appearing
- screenshot timing

If yes it is focus-sensitive and goes behind 🔴 HANDS OFF. **When in doubt,
gate.** An unnecessary gate costs ten seconds; a silently corrupted measurement
costs a whole round, which has already happened once.

### Batch

Five interruptions are worse than one interruption five times as long.

- Do **all** headless work first: code, tests, build, documentation, anything
  needing nothing from the owner.
- Gather every focus-sensitive step into **one** 🔴 HANDS OFF block and run them
  back to back.
- Then release.

If a result forces a second hands-off window, say so at the release — *"I may
need one more hands-off window after I look at this"* — rather than implying the
first was the last.

### Say what cannot be seen

When something is outside observation — browser chrome, an OS dialog, a focus
event that cannot be attributed — **say so and hand it over.** Do not substitute
a weaker proxy signal and report it as though it settled the question.

`PageBlurred: True` means *something* took focus. It does not mean VS Code
opened. Reporting the first as evidence of the second is the failure that
produced this section.

### Never assume the machine is free

Absence of a reply is not consent. A posted gate with no reply means wait. Not
"the work seemed low-risk, so I continued".

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

> Before planning any work here, read **"HTML subsystem — standing directive"**
> below and `docs/html-architecture.md`. This subsystem is being built toward
> extraction; the rules in this section are the local details, not the design.

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

## The two commands that write

`Test-PSModuleGraphEditorLink` and `Enable-PSModuleGraphEditorLink` are the only
commands in the module that touch machine state. Everything else reads. The
rules on them are not negotiable and are not stylistic:

- **`Enable-` keeps `ConfirmImpact = 'High'`.** It prompts by default. Do not
  lower the impact to make a test or an example quieter; pass `-Confirm:$false`
  at the call site instead.
- **`HKCU` only.** Never `HKLM`, never elevate, never add an admin requirement.
  `Get-BrowserDwordPolicy` reads `HKLM` to report that a machine policy would
  win. That is the only `HKLM` access in the module and it is read-only.
- **Merge, never overwrite.** `AutoLaunchProtocolsFromOrigins` may already grant
  Teams or Zoom. `Get-AutoLaunchPlan` handles this and is correct; leave it
  alone.
- **`-Revert` restores exactly**, including removing the value when there was
  none. The backup is written once and never overwritten, so a second `Enable-`
  run cannot record its own output as the thing to revert to.
- **Never edit `Local State` while the browser runs.** Chrome and Edge rewrite it
  from memory on exit and the edit is discarded in silence. Detect, name the
  process, ask. Never kill it.
- **No test may write to the real `HKCU:\SOFTWARE\Policies` tree or touch a real
  `Local State`.** Both commands take `-PolicyRoot`, `-LocalStateRoot` and
  `-BackupRoot` for exactly this reason, and the tests point them at
  `TestRegistry:` and `TestDrive:`. Those parameters are not a convenience and
  are not to be removed.

`SchemeExcluded` is **tri-state** and the third state carries the information.
`$true` is a declined prompt, `$false` an explicit allow, `$null` nobody was ever
asked. Collapsing `$null` into `$false` hides the only case where neither
mechanism explains a link that does nothing.

## Kaizen

**Every iteration leaves this repository slightly better shaped than it found
it, and writes down what it noticed but did not do.**

This is a standing instruction. It applies to every task, whether or not the
prompt mentions it, and it is not licence to widen scope - it is the opposite.
Scope creep is doing extra work nobody asked for. Kaizen is *noticing* while you
work, taking only what is genuinely small, and recording the rest so the next
pass starts ahead of where this one did. The backlog is `docs/improvements.md`.

### On every iteration

1. **Notice one thing.** While reading code for whatever the task actually is,
   something will be shaped worse than it could be: a branch that wants to be a
   registry, a literal that wants to be data, a message that lies, a panel that
   is nearly general. You do not have to hunt. It presents itself.
2. **Classify it honestly** as Small, Medium or Large, by the rules at the top of
   `docs/improvements.md`. The classification decides what you may do:
   - **Small** - fits inside work already happening and needs no new decision.
     Do it. Mention it in one line.
   - **Medium** - its own change, its own commit. Say in one line that you are
     doing it and why, then do it.
   - **Large** - changes a contract, a data shape, or the user's mental model.
     **Log it and stop.** Do not take it unprompted. This is the boundary that
     keeps kaizen from becoming scope creep.
3. **Record it either way.** Something you did goes to **Done** with what
   prompted it. Something you did not goes to **Open** under its size. An
   improvement noticed and not written down is an improvement lost.
4. **Prefer extensibility over the feature.** When the same shape appears a
   second time, the improvement is usually not "add the second one" but "make
   adding the third one one entry". `NODE_ACTIONS`, `SELECTION_FACTS`,
   `SELECTION_ACTIONS` and `FLOW_LAYOUT` all came from this and all read the
   same way, deliberately.

### What good looks like here

The question to hold is not *what else could I build* - it is **what would make
the next change to this cheaper**. Three concrete tests:

- **Would a second one of these be one entry, or a second branch?** If a branch,
  the registry is the improvement.
- **Is this text, number or colour a decision, or data?** If a user would ever
  want it different, it belongs in a `.psd1`, not in a `.js` or `.ps1`.
- **Does this message say something true?** A banner that names the wrong cause
  is worse than no banner, because it is confidently wrong and people act on it.

### What kaizen is not

- **Not a licence to refactor code you are not otherwise touching.** Read it,
  log it, move on.
- **Not a reason to add options nobody asked for.** A new setting is a new
  decision imposed on the reader; extensibility is not the same as configurability.
- **Not exempt from the standing directives.** The HTML subsystem's rules still
  hold, `docs/html-architecture.md` is still the authority, and an improvement
  that contradicts a recorded decision is an amendment to propose, not to make.
- **Not a running commentary.** One line per improvement taken. The backlog
  carries the detail; the response does not.

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

**The scoped `file:///*` origin default is a hypothesis, not a fact.** Chrome's
URL pattern reference accepts `file:///*` as the only valid file wildcard, so it
parses and the policy applies cleanly. Microsoft's Edge policy reference states
separately that `AutoLaunchProtocolsFromOrigins` does not work as expected with
`file://` wildcards. Both can be true: the entry is accepted and then ignored,
which looks exactly like a successful configuration that changed nothing.

Do not "fix" this by widening the default to `*`. That grants the protocol from
every website the user visits and is a security decision belonging to the
repository owner, which is why it is behind `-AllowAnyOrigin` and why that switch
never engages on its own. Do not remove the doubt from the comment either, and do
not re-derive it: it is written down here so the next reader does not have to
find the documentation again.

The two mechanisms are **independent**. The policy has no effect on a refusal a
user has already remembered, and clearing that refusal grants no policy. If a
link does nothing and nothing prompts either, `excluded_schemes` is the
hypothesis the evidence supports; test it first and alone.

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

## HTML subsystem — standing directive

`docs/html-architecture.md` is the authority for this subsystem. **Read that
file, not the templates, before planning any work here.** Open a partial only
when editing that partial.

The subsystem is being built toward extraction into its own repository. It is
not finished when the build is green; it is finished when the extraction
checklist in that document is fully ticked.

**The seam.** `ConvertTo-GraphHtml` is the only function that knows what a
dependency graph is; nothing below it may reference `Node`, `Edge`, `Module`,
`Ast`, or any PSModuleGraph type.

**Data files only.** Adding a new setting must require editing data files only.
If it requires editing a `.ps1`, the design is wrong — report that as a bug
rather than working around it.

**Every change opens with a one-paragraph architectural delta** — what it moves
toward or away from the target state — before any code. One paragraph, not a
plan document.

### Token discipline

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

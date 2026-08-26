# Testing

On-demand. Read this when writing or changing a test, not before every session.
`CLAUDE.md` carries only the two facts an agent needs before it starts: run
`./build.ps1`, and never `Invoke-Pester` or `Invoke-Build` directly.

## Running the suite

```powershell
./build.ps1 -Bootstrap      # install InvokeBuild, Pester 6.1.0, PSScriptAnalyzer
./build.ps1                 # default task: Clean, Lint, Build, Test
./build.ps1 -Task PreTag    # the gates that seal an iteration; see below
./build.ps1 -Task Lint      # analyzer only
```

`build.ps1` pins Pester to exactly 6.1.0 and verifies it before handing off.
Pester 5 and Pester 6 disagree on assertion syntax, discovery, and mocking, and
several 5.x versions are usually also installed - a bare `Invoke-Pester` will
silently pick the wrong one and produce results that mean nothing. Dependency
versions live in `Requirements.psd1`, not in `build.ps1`.

## The two gates in the default build

**Coverage.** `CoveragePercentTarget` only *reports*; the `throw` in the `Test`
task is what fails the run. It sat at 74.88% against a target of 75 through
three green builds before that was noticed. Coverage runs against the built
`output/PSModuleGraph/PSModuleGraph.psm1`, so line numbers in coverage reports
refer to the generated file.

**The instruction budget.** `tests/Instructions.Tests.ps1` fails when the
always-loaded tier exceeds its ceiling. See `.claude/skills/instruction-prune/SKILL.md`.

## The `PreTag` gate

`./build.ps1 -Task PreTag` runs only the tests tagged `PreTag`, which the
default `Test` task excludes. They are the seals on a *finished* iteration
rather than checks on work in progress: the build should stay green while an
iteration is half done, and the tag should not.

Today that is one test - an open prune proposal that a second iteration ignored
blocks the next annotated tag. `.claude/skills/iteration-close` runs it at
step 8, before the tag.

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

### The verified assertion list

**These are the `Should-*` assertions Pester 6.1.0 actually exports.** Enumerated
from the installed module, not remembered. **If an assertion is not on this list,
check before writing it** - `Should-Not-BeNullOrEmpty` and then
`Should-NotBeNullOrEmpty` were both invented and both caught at runtime, twice in
one session, and neither exists.

```
Should-All                   Should-Any                   Should-Be
Should-BeAfter               Should-BeBefore              Should-BeCollection
Should-BeEmptyString         Should-BeEquivalent          Should-BeFalse
Should-BeFalsy               Should-BeFasterThan          Should-BeGreaterThan
Should-BeGreaterThanOrEqual  Should-BeHashtable           Should-BeLessThan
Should-BeLessThanOrEqual     Should-BeLikeString          Should-BeNull
Should-BeSame                Should-BeSlowerThan          Should-BeString
Should-BeTrue                Should-BeTruthy              Should-ContainCollection
Should-HaveParameter         Should-HaveType              Should-Invoke
Should-MatchString           Should-NotBe                 Should-NotBeEmptyString
Should-NotBeLikeString       Should-NotBeNull             Should-NotBeSame
Should-NotBeString           Should-NotBeWhiteSpaceString Should-NotContainCollection
Should-NotHaveParameter      Should-NotHaveType           Should-NotInvoke
Should-NotMatchString        Should-Throw
```

To re-derive it after a Pester upgrade:

```powershell
Get-Command -Module Pester -Name 'Should-*' | Select-Object -ExpandProperty Name | Sort-Object
```

Note what is **not** there: no `Should-NotThrow` (just call the code - an
exception fails the test on its own), and **no `Should-NotBeNullOrEmpty`**. For
"not null" use `Should-NotBeNull`; for "not an empty string" use
`Should-NotBeEmptyString`. They are two assertions here, not one.

**Piping an empty array sends nothing down the pipeline.** `@() | Should-NotBeNull`
fails, because the assertion never receives a value at all - it is not asserting
about the array, it is asserting about nothing. This reads as a product bug and
is not one. **Compare, do not pipe:**

```powershell
($null -eq $value) | Should-BeFalse      # right
$value | Should-NotBeNull                # wrong when $value may be @()
```

The same trap applies to any assertion fed from a collection that might be
empty. `@($x).Count | Should-Be 0` is the safe form for asserting emptiness.

A terminating error thrown inside a `BeforeAll` surfaces as a confusing
"a 'break' or 'continue' statement ... escaped from your code" failure on the
whole `Describe`, not as the underlying exception. When a `Describe` fails that
way, call the code under test directly to find the real error.

## The fixture is input data, not a module

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

# EditorLink subsystem architecture

Read this before planning work on `Private/EditorLink/`. Backfilled at v0.3.0
after two versions with no charter; the code was already shaped this way, and
this writes the shape down.

## Target

**A subsystem that can explain why an editor link did nothing, without ever
following one, and that runs against an entirely simulated machine.**

Done means every location it reads or writes arrives as a parameter, so the
whole thing runs on `TestRegistry:` and `TestDrive:` with no real `HKCU`, no
real `Local State`, and no browser installed. This is the one subsystem that
touches machine state, so the module's "never execute the target" constraint
takes the local form "never require the machine you describe."

## The seam

Three bands, and every file belongs to exactly one:

| Band | Files | Machine state |
| --- | --- | --- |
| **Read** | `Get-EditorLinkBrowser`, `Get-EditorLinkState`, `Get-AutoLaunchPolicy`, `Get-BrowserDwordPolicy`, `Get-SchemeExclusion`, `Test-ExcludedSchemeWritable` | reads only |
| **Decide** | `Get-AutoLaunchPlan`, `ConvertTo-AutoLaunchJson` | none |
| **Write** | `Write-AutoLaunchPolicy`, `Clear-ExcludedScheme`, `Save-AutoLaunchBackup` | writes, after the caller's `ShouldProcess` |

The band is the contract. A read-band function that writes, or a write-band
function that decides anything, is the defect to look for — both stay invisible
in a green build, because the tests exercise a fake machine that tolerates
either.

**The `ShouldProcess` gate lives in the two public commands and nowhere below
them.** Write-band functions are mechanics: told what to do, they do it. Pushing
consent downward would put the prompt where its reason is out of scope.

## File layout

```
src/PSModuleGraph/Private/EditorLink/
  Get-EditorLinkBrowser.ps1      <- the only file holding a machine path literal
  Get-EditorLinkState.ps1        <- assembles the whole picture; reads only
  Get-BrowserDwordPolicy.ps1     <- the only HKLM access in the module
  Get-AutoLaunchPolicy.ps1  Get-SchemeExclusion.ps1  Test-ExcludedSchemeWritable.ps1
  Get-AutoLaunchPlan.ps1  ConvertTo-AutoLaunchJson.ps1   <- pure; edit as a value
  Write-AutoLaunchPolicy.ps1  Clear-ExcludedScheme.ps1  Save-AutoLaunchBackup.ps1
src/PSModuleGraph/Public/
  Test-PSModuleGraphEditorLink.ps1     <- read band, exposed
  Enable-PSModuleGraphEditorLink.ps1   <- ConfirmImpact = High
```

## The rule that pays for this

> **Every machine location arrives as a parameter, and `Get-EditorLinkBrowser`
> is the only file allowed to hold one as a literal.**

`-PolicyRoot`, `-LocalStateRoot`, `-MachinePolicyRoot` and `-BackupRoot` are not
a testing convenience. They are the local form of *the consumer names the
contract*: **this subsystem does not know where Windows is; the caller says.**
That property is what makes it runnable against a fake machine, and dropping a
root parameter because only one caller passes it drops the target with it.

## What the parent rules mean here

- **The core constraint.** The module never runs what it analyses; here it never
  *follows* the link it diagnoses. Nothing launches a browser, opens a URI, or
  kills a process. State is read and reported; the user acts.
- **"Could not check" is not "checked and passed".** `SchemeExcluded` is
  tri-state: `$true` a declined prompt, `$false` an explicit allow, `$null`
  nobody was ever asked. Never compute one "the link works" boolean — the two
  mechanisms are independent, and only their combination explains a link that
  does nothing silently.
- **Separate discovery from action.** `Get-AutoLaunchPlan` computes the entire
  edit before anything is written, which is what makes `-WhatIf` show the real
  diff rather than a guess at one.
- **Report, do not drop.** A policy value that will not parse is reported as
  unparsable, not treated as absent. The two lead to different fixes.

## Kaizen in this subsystem

Better shaped means **more of the machine arriving as a parameter, and fewer
facts computed in more than one place.** In order:

1. **Is a machine location a literal outside `Get-EditorLinkBrowser`?** That is
   the improvement, every time.
2. **Which band is this function in, and does it stay inside it?**
3. **Would a third browser be one entry, or a second branch?**
4. **Does this message name the actual cause?** "Policy not set" when the cause
   is a remembered refusal is worse than no message.

## Extraction checklist

Not slated for extraction — Windows-and-Chromium specific, no second consumer.
This measures testability against the target instead.

- [x] Policy, Local State, backup and machine-policy roots are all parameters
- [x] No test touches real `HKCU:\SOFTWARE\Policies` or a real `Local State`
- [ ] Browser definitions are data rather than a function returning literals
- [ ] The read band is provably read-only, asserted by a test rather than review
- [ ] A third browser can be added without editing a `.ps1`

## Decisions made and why

Append only. Do not re-litigate these.

**2026-08-26 — The bands are read, decide, write, and the charter names them.**
The arrangement was already in the code, one doc-comment at a time, so no single
place said every file belongs to exactly one band. A violation is only
recognisable against a stated rule.

**2026-08-26 — Extraction is explicitly not the target here.** Copying the HTML
charter's goal would be the shape without the reason: no second consumer, and
the code is specific to Chromium on Windows. Testability against a simulated
machine is the property that pays, so that is what the checklist measures.

**2026-08-26 — `Get-BrowserDwordPolicy` keeps its `HKLM` read.** It is the only
`HKLM` access in the module and it is read-only. Knowing a machine policy would
override the user one is the difference between "your setting did not apply" and
"your setting is wrong", and neither is guessable from `HKCU` alone.

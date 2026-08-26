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

## The rules on the two commands that write

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

## Looks like a bug, but is not

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

**2026-08-26 - The scoped default already contains `http://127.0.0.1:*`, and
that is not the same as a matchable origin.** Chrome's URL pattern reference
gives the port as a number; `*` in the port position is not a documented form,
so `http://127.0.0.1:*` may be accepted and then ignored - the identical failure
shape already recorded for `file:///*`. A report served from a real port can be
granted exactly, which is why the report now offers
`-AllowedOrigin 'http://127.0.0.1:PORT'` filled in for the origin it was served
from rather than a generic command. Whether the wildcard form works is an
experiment, not a code change; nothing here has been altered on the strength of
it.

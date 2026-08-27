#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Everything here is tagged PreTag and EXCLUDED from the default Test task.
#
# These are seals on a FINISHED iteration, not checks on work in progress. The
# build should stay green while an iteration is half done - that is what makes
# it useful to run - and the tag should not, because the tag is the claim that
# the iteration is done. `./build.ps1 -Task PreTag` runs them, and
# .claude/skills/iteration-close runs that at step 8, before `git tag -a`.

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path $PSScriptRoot -Parent
    $script:LedgerDir = Join-Path $script:Repo 'knowledge/ledger'

    # Overridable so the gate can be proven against a simulated store without
    # writing a fake entry into the real ledger. Same reason
    # Enable-PSModuleGraphEditorLink takes -PolicyRoot.
    if ($env:PSMODULEGRAPH_LEDGER_DIR) { $script:LedgerDir = $env:PSMODULEGRAPH_LEDGER_DIR }

    function Get-LedgerFront {
        param([string] $Path)
        InModuleScope PSModuleGraph -Parameters @{ Path = $Path } {
            param($Path)
            $read = Read-KnowledgeFile -Path $Path -SchemaName 'ledger-entry.schema.json'
            [pscustomobject]@{
                Id             = $read.Data['id']
                Closes         = @(Get-HashtableValue -InputObject $read.Data -Key 'closes' -Default @())
                PruneProposals = @(Get-HashtableValue -InputObject $read.Data -Key 'prune_proposals' -Default @())
            }
        }
    }

    $script:Entries = @(
        Get-ChildItem -Path $script:LedgerDir -Filter '*.md' -File |
            Sort-Object Name |
            ForEach-Object { Get-LedgerFront -Path $_.FullName }
    )
}

Describe 'Sealing an iteration' -Tag 'PreTag' {

    It 'closes every prune proposal the previous entry left open' {
        # THE BACKSTOP. instruction-prune applies a MOVE in-turn, because a move
        # loses nothing and there is nothing to review. A genuine DELETION still
        # proposes and waits - and waiting is free unless something costs.
        #
        # This is the cost. A proposal that survives a second entry unclosed
        # blocks the tag by name. Carrying it forward is not enough: carrying is
        # exactly the idling this mechanism exists to stop.
        #
        # Explicit rejection closes it. "We considered this and it stays,
        # because X" is a decision. Silence is not.
        #
        # Note the shape: this is open-thread continuity at a different scale,
        # which is a point in its favour rather than a coincidence.
        if ($script:Entries.Count -lt 2) {
            Set-ItResult -Skipped -Because 'there is only one entry, so nothing precedes it'
            return
        }

        for ($i = 1; $i -lt $script:Entries.Count; $i++) {
            $previous = $script:Entries[$i - 1]
            $current = $script:Entries[$i]

            $ignored = @($previous.PruneProposals | Where-Object { $current.Closes -notcontains $_ })

            $message = "entry $($current.Id) neither applied nor rejected prune proposal(s) opened by $($previous.Id): $($ignored -join ', '). Apply it, or close it with a reason. Carrying it forward is the idling this gate exists to stop."
            @($ignored).Count | Should-Be 0 -Because $message
        }
    }

    It 'names a prune proposal only where a thread was opened for it' {
        # The mirror. A prune proposal must be a real thread, so the body has to
        # describe it under the same id and LedgerContinuity has to see it.
        foreach ($entry in $script:Entries) {
            foreach ($id in $entry.PruneProposals) {
                $id | Should-BeLikeString "$($entry.Id)-t*" -Because "entry $($entry.Id) lists prune proposal $id, which is not one of its own threads"
            }
        }
    }
}

Describe 'The renderer this module is pinned to' -Tag 'PreTag' {
    It 'agrees between the manifest floor and what CI checks out' {
        # 0009-t2, closed. CI used to track the renderer's default branch, so a
        # green run proved compatibility with whatever was on main that morning
        # rather than with the version the manifest declares - and a change
        # there could turn this red with nothing changed here.
        #
        # Pinning alone would not have been enough. Two numbers that must agree
        # and are edited in different files drift, and the drift is silent
        # because both halves keep working on a machine where the two
        # repositories happen to move together. This is the assertion that makes
        # them one fact.
        $repo = Split-Path -Path $PSScriptRoot -Parent

        $manifest = Import-PowerShellDataFile -LiteralPath (
            Join-Path $repo 'src/PSModuleGraph/PSModuleGraph.psd1')
        $required = @($manifest.RequiredModules | Where-Object { $_.ModuleName -eq 'PSGraphRender' })
        $required.Count | Should-Be 1

        $workflow = Get-Content -LiteralPath (Join-Path $repo '.github/workflows/ci.yml') -Raw
        $match = [regex]::Match($workflow, '(?s)repository:\s*\S*PSGraphRender\s*.*?ref:\s*v(?<version>[0-9.]+)')

        $match.Success | Should-BeTrue -Because 'ci.yml must pin PSGraphRender to a tag, not track a branch'
        $match.Groups['version'].Value | Should-Be $required[0].ModuleVersion
    }
}

Describe 'The version the module reports' -Tag 'PreTag' {
    It 'is the version about to be tagged, and that tag does not exist yet' {
        # THE DRIFT THIS CAUGHT. ModuleVersion said 0.15.0 while v0.15.1 and
        # v0.15.2 were both tagged, so two releases shipped a module reporting a
        # version that was already out - the same defect PSGraphRender found at
        # its v0.13.0, in the same week, for the same reason: nothing read the
        # field.
        #
        # "Matches the tag about to be applied" rather than "no tag exists for
        # this version", and the tag about to be applied IS expressible even
        # though it does not exist yet: the ledger entry being sealed declares
        # it in its own front matter. That is data, written before the tag, by
        # the iteration the tag is for.
        #
        # NOT gated: that CHANGELOG.md names the same version. This repository's
        # CHANGELOG has only an [Unreleased] section and has never carried a
        # released heading, so the check would be asserting a convention rather
        # than enforcing one. Adding that convention is a decision, not a test.
        $repo = Split-Path -Path $PSScriptRoot -Parent

        $newest = @(Get-ChildItem -LiteralPath (Join-Path $repo 'knowledge/ledger') -Filter '*.md' -File |
                Sort-Object Name | Select-Object -Last 1)
        $newest.Count | Should-Be 1

        $front = Get-Content -LiteralPath $newest[0].FullName -Raw
        $declared = [regex]::Match($front, '(?m)^tag:\s*v(?<version>\d+\.\d+\.\d+)\s*$')
        $declared.Success | Should-BeTrue -Because "$($newest[0].Name) must declare the tag it is sealing"
        $intended = $declared.Groups['version'].Value

        $manifest = Import-PowerShellDataFile -LiteralPath (
            Join-Path $repo 'src/PSModuleGraph/PSModuleGraph.psd1') -ErrorAction Stop
        $manifest.ModuleVersion | Should-Be $intended -Because (
            "$($newest[0].Name) is sealing v$intended and the manifest says $($manifest.ModuleVersion)")

        $existing = @(& git -C $repo tag --list "v$intended")
        @($existing).Count | Should-Be 0 -Because (
            "v$intended is already tagged, so this iteration is about to reuse a released version")
    }
}

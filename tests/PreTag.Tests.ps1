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
                Tag            = Get-HashtableValue -InputObject $read.Data -Key 'tag' -Default ''
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

Describe 'The tag before this one' -Tag 'PreTag' {
    It 'is on the remote at the commit it names here' {
        # THE FAILURE THIS PREVENTS. v0.18.0 and v0.18.1 were tagged, a push was
        # authorised for each, and neither reached the remote. Nothing noticed
        # until the remote was read from outside this machine three iterations
        # later, so v0.18.2 was sealed on top of two releases that existed only
        # on this disk. `0031`.
        #
        # A gate cannot verify the push that has not happened yet: publishing is
        # the operator's and runs after the tag. It CAN verify the previous one.
        # That fails one iteration late, which is the honest limit of anything
        # checkable from inside - and one late beats three.
        #
        # THIS MAKES A NETWORK CALL AND FAILS WHEN IT CANNOT. There is no
        # offline expression of "what does the remote hold": remote-tracking
        # refs answer from the last fetch, which is a cache, and a cache would
        # have passed this gate on all three of the iterations above. Skipping
        # when offline would make it a mechanism that reports success where
        # nothing could contradict it - pattern `0017`, the shape this
        # repository deletes. The cost is real and stated in
        # `docs/constraints.md`: tagging now requires a reachable remote.
        #
        # Asserting the COMMIT and not merely the ref is what makes this more
        # than "something called v0.18.1 is up there". A ref cannot exist on a
        # remote without its whole ancestry, so a matching commit proves every
        # commit up to that tag transferred. It does not prove the remote BRANCH
        # advanced to include it - `0031-t1`.
        if ($script:Entries.Count -lt 2) {
            Set-ItResult -Skipped -Because 'there is no previous entry, so no previous tag was cut'
            return
        }

        $previous = $script:Entries[-2]
        $previous.Tag | Should-NotBeEmptyString -Because "entry $($previous.Id) must declare the tag it sealed"

        # Overridable for the same reason PSMODULEGRAPH_LEDGER_DIR is: this has
        # to be provable against a remote that is missing the tag, holds it at
        # the wrong commit, or cannot be reached, and none of the three can be
        # staged on the real one.
        $remote = $env:PSMODULEGRAPH_PUBLISH_REMOTE
        if (-not $remote) { $remote = 'origin' }

        # Without this a remote that wants credentials prompts and the gate
        # hangs, which is worse than either answer it could give.
        $restore = $env:GIT_TERMINAL_PROMPT
        $env:GIT_TERMINAL_PROMPT = '0'
        try {
            # BOTH patterns, deliberately. ls-remote matches the peeled entry
            # by its own name, so asking only for `refs/tags/X` returns the tag
            # object and never `refs/tags/X^{}` - and the commit assertion below
            # would then have nothing to read. Checked against the real remote
            # and against a fixture before being relied on.
            $output = @(& git -C $script:Repo ls-remote --tags $remote `
                    "refs/tags/$($previous.Tag)" "refs/tags/$($previous.Tag)^{}" 2>&1 |
                    ForEach-Object { "$_" })
            $exit = $LASTEXITCODE
        }
        finally {
            if ($null -eq $restore) { Remove-Item -LiteralPath 'Env:\GIT_TERMINAL_PROMPT' -ErrorAction Ignore }
            else { $env:GIT_TERMINAL_PROMPT = $restore }
        }

        $exit | Should-Be 0 -Because (
            "the remote '$remote' could not be read, so whether $($previous.Tag) was published is unknown - and unknown is not a pass. git said: $($output -join ' / ')")

        $pattern = "\srefs/tags/$([regex]::Escape($previous.Tag))(\^\{\})?$"
        $refs = @($output | Where-Object { $_ -match $pattern })
        @($refs).Count | Should-BeGreaterThan 0 -Because (
            "$($previous.Tag) is tagged here and is not on '$remote'. The iteration before this one was never published, and this one is about to be sealed on top of it.")

        # An annotated tag answers twice: the tag object, and ^{} for the commit
        # it peels to. Every tag this repository cuts is annotated.
        $peeled = @($refs | Where-Object { $_ -match '\^\{\}$' })
        @($peeled).Count | Should-Be 1 -Because (
            "$($previous.Tag) on '$remote' must be an annotated tag, as every tag here is")

        $remoteCommit = ($peeled[0] -split '\s+')[0]
        $localCommit = (& git -C $script:Repo rev-list -n1 $previous.Tag)

        $remoteCommit | Should-Be $localCommit -Because (
            "$($previous.Tag) points at $localCommit here and at $remoteCommit on '$remote', so what was published is not what this ledger says was published")
    }
}

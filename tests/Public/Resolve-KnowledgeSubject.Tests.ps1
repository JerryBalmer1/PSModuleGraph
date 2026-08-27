#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:Store = Join-Path $script:Repo 'knowledge'
}

Describe 'Resolve-KnowledgeSubject' {
    # WHAT MAKES AN ALIAS MEAN ANYTHING. Until this shipped, `aliases` was a
    # field the schema allowed, the writer could not write, and no reader
    # consulted - so "a rename never deletes" was true of the data and false of
    # anything anybody could do with it.

    It 'finds a subject by the id it has' {
        $id = 'psmodule:PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass'
        $found = @(Resolve-KnowledgeSubject -Id $id -StoreRoot $script:Store)

        $found.Count | Should-Be 1
        $found[0].Id | Should-Be $id
        $found[0].Resolution | Should-Be 'id'
    }

    It 'finds a subject by an id it used to have' {
        # This exact string is in knowledge/NAMING.md and was the store's worked
        # example of the resolution rule for four versions.
        $found = @(Resolve-KnowledgeSubject -StoreRoot $script:Store `
                -Id 'psmodule:PSModuleGraph/function/Get-PSModuleClass')

        $found.Count | Should-Be 1
        $found[0].Id | Should-Be 'psmodule:PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass'
        $found[0].Resolution | Should-Be 'alias'
    }

    It 'reaches every subject URN the ledger still names' {
        # The ledger is append-only, so these three references were written when
        # they resolved directly and cannot be edited to match the new shape.
        # The alias is the only thing that keeps them alive, and this is the
        # only check that a reader following one gets anywhere.
        $fromLedger = @(
            'psmodule:PSModuleGraph/function/Test-KnowledgeDocument'   # ledger/0004
            'psmodule:PSModuleGraph/function/Get-HashtableValue'       # ledger/0007
            'psmodule:PSModuleGraph/function/ConvertTo-DotId'          # ledger/0007
        )

        foreach ($id in $fromLedger) {
            $found = @(Resolve-KnowledgeSubject -Id $id -StoreRoot $script:Store)
            $found.Count | Should-BeGreaterThan 0 -Because "ledger prose still names $id"
            $found[0].Resolution | Should-Be 'alias'
        }
    }

    It 'returns every subject a collapsed identifier now names, not the one that used to win' {
        # The one-to-many case, which cannot occur in this repository's own
        # store - no module in it has a duplicated name - so it is built here.
        $store = Join-Path $TestDrive 'collide'
        New-Item -ItemType Directory -Path $store -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:Repo 'knowledge/SCHEMA') -Destination $store -Recurse -Force
        Update-KnowledgeStore -Path (Join-Path $script:Repo 'tests/fixtures/CollidingModule') `
            -StoreRoot $store -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null

        $found = @(Resolve-KnowledgeSubject -StoreRoot $store `
                -Id 'psmodule:CollidingModule/function/Compare-State')

        $found.Count | Should-Be 3
        @($found | ForEach-Object { $_.Source } | Sort-Object) | Should-BeCollection @(
            'resources/Alpha/Alpha.psm1', 'resources/Beta/Beta.psm1', 'resources/Gamma/Gamma.psm1')
        @($found | ForEach-Object { $_.Resolution } | Sort-Object -Unique) | Should-BeCollection @('alias')
    }

    It 'tells the difference between two identifiers that differ only in case' {
        # knowledge/NAMING.md: no assumption that keys are case-insensitive. A
        # URN path segment preserves case, and PowerShell's own comparisons do
        # not - which is how a whole Describe stayed green while every alias in
        # the store was lowercased.
        $found = @(Resolve-KnowledgeSubject -StoreRoot $script:Store `
                -Id 'psmodule:psmodulegraph/function/get-psmoduleclass')

        $found.Count | Should-Be 0
    }

    It 'returns nothing, loudly enough to see, for an id nobody ever issued' {
        $found = @(Resolve-KnowledgeSubject -Id 'psmodule:Nowhere/function/Absent' `
                -StoreRoot $script:Store -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })

        $found.Count | Should-Be 1
        [string]$found[0] | Should-MatchString 'psmodule:Nowhere/function/Absent'
    }

    It 'refuses a store root that is not a store, by name' {
        $notAStore = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $notAStore -Force | Out-Null

        { Resolve-KnowledgeSubject -Id 'psmodule:X/function/Y' -StoreRoot $notAStore } |
            Should-Throw -ExceptionMessage '*is not a knowledge store*'
    }
}

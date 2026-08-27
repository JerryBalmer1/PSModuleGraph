#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:Colliding = Join-Path $script:Repo 'tests/fixtures/CollidingModule'
    $script:Sample = Join-Path $script:Repo 'tests/fixtures/SampleModule'
    $script:Src = Join-Path $script:Repo 'src/PSModuleGraph'

    function Get-SubjectIdMap {
        <#
        .SYNOPSIS
            Every node's subject id, in one pass over the real graph.
        #>
        param([string] $ModulePath)

        $graph = Get-PSModuleDependencyGraph -Path $ModulePath
        $name = [string]$graph.ModuleName
        $ids = @(InModuleScope PSModuleGraph -Parameters @{ Nodes = @($graph.Nodes); Name = $name } {
                param($Nodes, $Name)
                foreach ($node in $Nodes) { Get-KnowledgeSubjectId -Node $node -ModuleName $Name }
            })

        [pscustomobject]@{
            ModuleName = $name
            NodeCount  = @($graph.Nodes).Count
            Ids        = $ids
            Distinct   = @($ids | Sort-Object -Unique)
        }
    }
}

Describe 'One definition gets one subject id' {
    # THE ASSERTION THAT WOULD HAVE CAUGHT IT. Count the definitions, count the
    # distinct ids, compare. It costs one pass over a graph the generator has
    # already built, it is exhaustive over the whole population rather than a
    # sample, and had it existed the collapse would have been a refusal at the
    # moment of writing instead of a finding months later.
    #
    # It lands before the fix that makes it pass everywhere, and separately,
    # because it is worth having whether or not the fix follows.

    It 'gives every definition in <_> its own id' -ForEach @('src/PSModuleGraph', 'tests/fixtures/SampleModule') {
        $map = Get-SubjectIdMap -ModulePath (Join-Path $script:Repo $_)

        $map.NodeCount | Should-BeGreaterThan 0
        $map.Distinct.Count | Should-Be $map.NodeCount -Because (
            "$($map.ModuleName) has $($map.NodeCount) definitions and " +
            "$($map.Distinct.Count) distinct subject ids, so the store would " +
            'answer a question about several definitions by naming one file')
    }
}

Describe 'A population that would collapse is refused' {
    # The fixture exists because neither module in this repository's own store
    # has a single duplicated name, so every check here would run green against
    # a store where the bug cannot occur. A gate nobody has seen fail is a gate
    # nobody has tested - see .claude/skills/gate-falsifiability.

    BeforeAll {
        $script:Fixture = Get-SubjectIdMap -ModulePath $script:Colliding
    }

    It 'has a fixture that actually collides' {
        # Guards everything below. If the fixture stops colliding - a rename, a
        # file moved - the refusal tests pass by never being reached.
        $script:Fixture.NodeCount | Should-Be 7
        $script:Fixture.Distinct.Count | Should-Be 4
    }

    It 'names the shared id, how many definitions claim it, and where they are' {
        $store = Join-Path $TestDrive 'knowledge'
        New-Item -ItemType Directory -Path (Join-Path $store 'SCHEMA') -Force | Out-Null

        $failed = $null
        try {
            Update-KnowledgeStore -Path $script:Colliding -StoreRoot $store -Confirm:$false | Out-Null
        }
        catch {
            $failed = $_.Exception.Message
        }

        $failed | Should-NotBeNull -Because 'a population that collapses must be refused, not written'

        # The three collisions sort so that Compare-State is named first, which
        # is the three-way one: two records claiming one id can still be read as
        # a swap and three cannot.
        $failed | Should-MatchString 'psmodule:CollidingModule/function/Compare-State'
        $failed | Should-MatchString 'resources/Alpha/Alpha\.psm1'
        $failed | Should-MatchString 'resources/Beta/Beta\.psm1'
        $failed | Should-MatchString 'resources/Gamma/Gamma\.psm1'
        $failed | Should-MatchString '7 definition\(s\)'
        $failed | Should-MatchString '4 distinct subject id\(s\)'
        $failed | Should-MatchString '3 would be written over'
        $failed | Should-MatchString '1 other id\(s\) are shared as well'
    }

    It 'refuses before it removes the records it was going to replace' {
        # A refusal that has already deleted the tree leaves no store at all,
        # which is worse than the collapse it prevented. The guard runs before
        # the removal and this is what says so.
        $store = Join-Path $TestDrive 'preserved'
        New-Item -ItemType Directory -Path (Join-Path $store 'SCHEMA') -Force | Out-Null
        $owned = Join-Path $store 'subjects/psmodule/CollidingModule'
        New-Item -ItemType Directory -Path $owned -Force | Out-Null
        $canary = Join-Path $owned 'canary.md'
        Set-Content -LiteralPath $canary -Value 'still here' -Encoding utf8

        { Update-KnowledgeStore -Path $script:Colliding -StoreRoot $store -Confirm:$false } | Should-Throw

        Test-Path -LiteralPath $canary | Should-BeTrue -Because 'the guard runs before the removal'
    }
}

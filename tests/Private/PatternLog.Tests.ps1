#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:PatternDir = Join-Path $script:Repo 'knowledge/patterns'
    $script:LedgerDir = Join-Path $script:Repo 'knowledge/ledger'

    function Get-Pattern {
        param([string] $Path)
        InModuleScope PSModuleGraph -Parameters @{ Path = $Path } {
            param($Path)
            $read = Read-KnowledgeFile -Path $Path -SchemaName 'pattern.schema.json' -NumericField 'confidence'
            [pscustomobject]@{
                File       = Split-Path -Path $Path -Leaf
                Ledger     = $read.Data['ledger']
                Scales     = @(Get-HashtableValue -InputObject $read.Data -Key 'scales' -Default @())
                Confidence = $read.Data['confidence']
                Body       = $read.Body
                IsValid    = $read.IsValid
            }
        }
    }

    $script:Patterns = @(
        Get-ChildItem -Path $script:PatternDir -Filter '*.md' -File |
            Sort-Object Name |
            ForEach-Object { Get-Pattern -Path $_.FullName }
    )

    $script:LedgerIds = @(
        Get-ChildItem -Path $script:LedgerDir -Filter '*.md' -File |
            ForEach-Object { $_.Name.Substring(0, 4) }
    )
}

Describe 'The pattern log' {
    It 'has at least one pattern' {
        $script:Patterns.Count | Should-BeGreaterThan 0
    }

    It 'validates every pattern against the schema' {
        foreach ($pattern in $script:Patterns) { $pattern.IsValid | Should-BeTrue }
    }

    It 'observes every pattern at two or more distinct scales' {
        # THE BAR. One observation is an anecdote, and a log that accepts
        # anecdotes fills with profundities inside a month. The schema's
        # minItems already rejects a single scale; this asserts the check is
        # actually reached, and that no two scales are the same place twice.
        foreach ($pattern in $script:Patterns) {
            $distinct = @($pattern.Scales | Select-Object -Unique).Count
            $distinct | Should-BeGreaterThanOrEqual 2 -Because "$($pattern.File) names $distinct distinct scale(s)"
        }
    }

    It 'never records a pattern at full confidence' {
        # Same rule as an assignment: a shape seen twice and named once is not
        # a law. 1 is the value written when nothing better came to mind.
        foreach ($pattern in $script:Patterns) {
            $pattern.Confidence | Should-BeLessThan 1 -Because "$($pattern.File) claims certainty"
        }
    }

    It 'carries the three required body sections in every pattern' {
        foreach ($pattern in $script:Patterns) {
            foreach ($section in 'The pattern', 'Where it was seen', 'Handoff') {
                $pattern.Body | Should-MatchString ([regex]::Escape("## $section")) -Because "$($pattern.File) is missing '## $section'"
            }
        }
    }

    It 'names a ledger entry that exists, and matches its own filename' {
        # The ledger id is the ordering, not a date: two iterations can land the
        # same day. A pattern pointing at no ledger entry has no tag and no
        # position in the sequence.
        foreach ($pattern in $script:Patterns) {
            $script:LedgerIds | Should-ContainCollection $pattern.Ledger
            $pattern.File | Should-BeLikeString "$($pattern.Ledger)-*"
        }
    }
}

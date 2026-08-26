#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:LedgerDir = Join-Path $script:Repo 'knowledge/ledger'

    function Get-LedgerEntry {
        param([string] $Path)
        InModuleScope PSModuleGraph -Parameters @{ Path = $Path } {
            param($Path)
            $read = Read-KnowledgeFile -Path $Path -SchemaName 'ledger-entry.schema.json'
            [pscustomobject]@{
                Id             = $read.Data['id']
                Tag            = $read.Data['tag']
                OpenThreads    = @(Get-HashtableValue -InputObject $read.Data -Key 'open_threads' -Default @())
                Closes         = @(Get-HashtableValue -InputObject $read.Data -Key 'closes' -Default @())
                CarriesForward = @(Get-HashtableValue -InputObject $read.Data -Key 'carries_forward' -Default @())
                Body           = $read.Body
                IsValid        = $read.IsValid
            }
        }
    }

    $script:Entries = @(
        Get-ChildItem -Path $script:LedgerDir -Filter '*.md' -File |
            Sort-Object Name |
            ForEach-Object { Get-LedgerEntry -Path $_.FullName }
    )
}

Describe 'The ledger' {
    It 'has at least one entry' {
        # An implementation that produces no entry did not happen.
        $script:Entries.Count | Should-BeGreaterThan 0
    }

    It 'validates every entry against the schema' {
        foreach ($entry in $script:Entries) { $entry.IsValid | Should-BeTrue }
    }

    It 'carries the five required body sections in every entry' {
        foreach ($entry in $script:Entries) {
            foreach ($section in 'What changed', 'What I learned', 'What I could not verify',
                'Dimensional impact', 'Open threads') {
                $entry.Body | Should-MatchString ([regex]::Escape("## $section"))
            }
        }
    }

    It 'agrees between the front matter thread ids and the body' {
        # Front matter is for the machine and the body is for the human. They
        # are allowed to be two renderings of one fact; they are not allowed to
        # disagree, or the machine half stops describing the entry.
        foreach ($entry in $script:Entries) {
            foreach ($id in $entry.OpenThreads) {
                $entry.Body | Should-MatchString ([regex]::Escape("[$id]"))
            }
        }
    }

    It 'accounts for every thread the previous entry left open' {
        # THE MECHANISM. Presence-checking cannot tell whether "What I could not
        # verify" says anything; open-thread continuity can. The tell of an
        # entry written at the end of a long session is not a short skeptic
        # section - it is the seven threads that quietly vanish.
        if ($script:Entries.Count -lt 2) {
            Set-ItResult -Skipped -Because 'there is only one entry, so nothing precedes it'
            return
        }

        for ($i = 1; $i -lt $script:Entries.Count; $i++) {
            $previous = $script:Entries[$i - 1]
            $current = $script:Entries[$i]

            $accounted = @($current.Closes) + @($current.CarriesForward)
            $dropped = @($previous.OpenThreads | Where-Object { $accounted -notcontains $_ })

            # Named, not counted: the failure has to say which threads vanished
            # or it tells the reader nothing they can act on.
            $message = "entry $($current.Id) dropped thread(s) opened by $($previous.Id): $($dropped -join ', ')"
            @($dropped).Count | Should-Be 0 -Because $message
        }
    }

    It 'closes or carries nothing that was never opened' {
        # The mirror of the rule above. Claiming to close a thread that does not
        # exist is the same failure wearing a coat.
        $opened = @{}
        foreach ($entry in $script:Entries) {
            foreach ($id in $entry.OpenThreads) { $opened[$id] = $true }
        }

        foreach ($entry in $script:Entries) {
            foreach ($id in (@($entry.Closes) + @($entry.CarriesForward))) {
                $opened.ContainsKey($id) | Should-BeTrue -Because "entry $($entry.Id) references unknown thread $id"
            }
        }
    }

    It 'names an annotated tag on every entry' {
        foreach ($entry in $script:Entries) {
            $entry.Tag | Should-MatchString '^v\d+\.\d+\.\d+$'
        }
    }
}

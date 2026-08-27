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
                Supersedes     = @(Get-HashtableValue -InputObject $read.Data -Key 'supersedes_threads' -Default @())
                Accepts        = @(Get-HashtableValue -InputObject $read.Data -Key 'accepts_threads' -Default @())
                Recovers       = @(Get-HashtableValue -InputObject $read.Data -Key 'recovers_threads' -Default @())
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

    It 'accounts for every thread that was still open, not merely for the last ones raised' {
        # THE MECHANISM, and it was broken from v0.1.0 until v0.13.3.
        #
        # It compared entry N against $previous.OpenThreads - the threads the
        # PREVIOUS ENTRY ITSELF RAISED - and never against what that entry was
        # carrying. So a thread was guarded for exactly one iteration and was
        # silently droppable ever after. That is not a weaker version of the
        # rule: it is the rule holding for the case that never happens and
        # failing for the case that does.
        #
        # Two went that way past a green run. `0001-t4` here, and `0002-t4` in
        # PSGraphRender - where entry 0003's PROSE says `0003-t2` is "the open
        # half of 0002-t4" and its front matter dropped the id without a word.
        # The prose knew and the machine half did not, and the machine half is
        # the one anything reads.
        #
        # The open set is carried explicitly:
        #
        #   open(N) = open(N-1) + recovers(N) - closes(N) - supersedes(N)
        #
        # and carries_forward(N) must equal it EXACTLY. Equality rather than
        # containment, because a thread appearing in carries_forward without
        # ever having been open is the same defect pointing the other way.
        #
        # A drop is judged over the WHOLE chain rather than in place, because a
        # gap that a later entry owns up to is a recorded gap and a gap nobody
        # mentions is a lost thread. That costs nothing at the point it matters:
        # a drop made today has no later entry to recover it, so it fails today.
        if ($script:Entries.Count -lt 2) {
            Set-ItResult -Skipped -Because 'there is only one entry, so nothing precedes it'
            return
        }

        $open = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]@($script:Entries[0].OpenThreads), [System.StringComparer]::Ordinal)
        # ORDINAL, like $open above. Three containers held thread ids here and
        # only one could tell '0014-t2' from '0014-T2', so a carry spelled
        # differently from the thread it carried was accepted as the same
        # thread by two of the three. knowledge/patterns/0023.
        $lostAt = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
        $recoveredBy = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
        $phantoms = [System.Collections.Generic.List[string]]::new()

        for ($i = 1; $i -lt $script:Entries.Count; $i++) {
            $current = $script:Entries[$i]

            foreach ($id in $current.Recovers) {
                if (-not $recoveredBy.ContainsKey($id)) { $recoveredBy[$id] = $current.Id }
                [void]$open.Add($id)
            }
            foreach ($id in @($current.Closes) + @($current.Supersedes) + @($current.Accepts)) { [void]$open.Remove($id) }

            $carried = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]@($current.CarriesForward), [System.StringComparer]::Ordinal)

            foreach ($id in @($open)) {
                if (-not $carried.Contains($id)) {
                    if (-not $lostAt.ContainsKey($id)) { $lostAt[$id] = $current.Id }
                    [void]$open.Remove($id)
                }
            }
            foreach ($id in $carried) {
                if (-not $open.Contains($id)) { $phantoms.Add("$id (carried by $($current.Id))") }
            }

            foreach ($id in $current.OpenThreads) { [void]$open.Add($id) }
        }

        # Named, not counted: a failure that does not say which thread vanished
        # and where tells the reader nothing they can act on.
        $unrecovered = @($lostAt.Keys | Where-Object { -not $recoveredBy.ContainsKey($_) } |
                ForEach-Object { "$_ (dropped by $($lostAt[$_]))" } | Sort-Object)
        $message = "thread(s) left the ledger without being closed, superseded or recovered: $($unrecovered -join '; '). Close them, supersede them by id, or - if the record genuinely has a gap - name them in recovers_threads and say so in the body."
        @($unrecovered).Count | Should-Be 0 -Because $message

        $message = "thread(s) carried by an entry that were not open before it: $(@($phantoms) -join '; '). A thread that was dropped needs recovers_threads, which says the record has a gap in it."
        @($phantoms).Count | Should-Be 0 -Because $message
    }
    It 'names in the body every thread it supersedes or recovers' {
        # The half that would have caught 0002-t4 from the other side. An id
        # leaving the open set has to leave a sentence behind saying what
        # replaced it, or what the gap in its record was.
        foreach ($entry in $script:Entries) {
            foreach ($id in @($entry.Supersedes) + @($entry.Recovers) + @($entry.Accepts)) {
                $entry.Body | Should-MatchString ([regex]::Escape("[$id]")) -Because "entry $($entry.Id) retires $id in its front matter and says nothing about it in its body"
            }
        }
    }
    It 'closes or carries nothing that was never opened' {
        # The mirror of the rule above. Claiming to close a thread that does not
        # exist is the same failure wearing a coat.
        # ORDINAL, for the reason above: this gate is about whether an id
        # exists, and a hashtable would answer yes to a differently-cased one.
        $opened = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($entry in $script:Entries) {
            foreach ($id in $entry.OpenThreads) { [void]$opened.Add([string]$id) }
        }

        foreach ($entry in $script:Entries) {
            foreach ($id in (@($entry.Closes) + @($entry.CarriesForward) + @($entry.Supersedes) + @($entry.Recovers) + @($entry.Accepts))) {
                # EXISTENCE, not shape. A pattern match on the id is not this:
                # `Should-BeLikeString "0009-t*"` passed on `0009-t9`, a thread
                # that has never existed, because a fake id of the right shape
                # has the right shape. That cost a break to find and it is why
                # this looks the id up rather than matching it.
                $opened.Contains([string]$id) | Should-BeTrue -Because "entry $($entry.Id) references thread $id, which no entry ever opened"
            }
        }
    }

    It 'names an annotated tag on every entry' {
        foreach ($entry in $script:Entries) {
            $entry.Tag | Should-MatchString '^v\d+\.\d+\.\d+$'
        }
    }
}

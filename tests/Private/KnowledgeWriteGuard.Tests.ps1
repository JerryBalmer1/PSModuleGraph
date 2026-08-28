#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:Knowledge = Join-Path $script:Repo 'knowledge'
    $script:Fixture = Join-Path $script:Repo 'tests/fixtures/SampleModule'

    function New-EmptyStore {
        param([string] $At)
        New-Item -ItemType Directory -Path $At -Force | Out-Null
        foreach ($area in 'SCHEMA', 'facets', 'meta') {
            Copy-Item -LiteralPath (Join-Path $script:Knowledge $area) -Destination $At -Recurse -Force
        }
        $At
    }
}

Describe 'A build that changes nothing writes nothing' {
    # THE DEFECT THIS CLOSES, and it is worth stating because the fix is not
    # where the improvement said it was. The writer looked unconditional, but a
    # guard in the writer alone would never have fired: Update-KnowledgeStore
    # REMOVED the whole owned subtree before writing, so every record was new by
    # the time the writer saw it. Replacement is now write-then-prune.
    #
    # The cost of the old shape was not the writes. It was that 282 records
    # reported modified on every build with identical blob hashes, so a store
    # with three genuinely changed records looked exactly like one with none.

    BeforeAll {
        $script:Store = New-EmptyStore -At (Join-Path $TestDrive 'store')
        $script:First = Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store `
            -GeneratedAt '2026-08-26' -Confirm:$false
        $script:Second = Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store `
            -GeneratedAt '2026-08-26' -Confirm:$false
    }

    It 'writes the population on the first run' {
        $script:First.RecordsWritten | Should-BeGreaterThan 0
        $script:First.RecordsKept | Should-Be $script:First.RecordsWritten
    }

    It 'writes nothing at all on the second' {
        $script:Second.RecordsWritten | Should-Be 0
        $script:Second.RecordsKept | Should-Be $script:First.RecordsKept
    }

    It 'prunes nothing when the population is unchanged' {
        $script:Second.RecordsPruned | Should-Be 0
    }

    It 'leaves every file untouched, which is the property that matters' {
        # Not "wrote zero" - that is the command's own report. This reads the
        # filesystem, because the thing that was wrong was a stat cache, and a
        # rewrite with identical bytes still moves an mtime and still makes git
        # report the file modified.
        #
        # THE WHOLE STORE, not the module subtree. Scoped to subjects/psmodule
        # this passed while nine facet-health assignments were deleted and
        # recreated on every run - Update-FacetHealthRecord kept the delete-first
        # shape until v0.18.1, so the writer's guard could not fire there. A test
        # that measures the subtree the change was made in reports on the change,
        # not on the store. ledger/0029.
        $owned = $script:Store
        $before = @{}
        foreach ($f in (Get-ChildItem -LiteralPath $owned -Filter *.md -File -Recurse)) {
            $before[$f.FullName] = $f.LastWriteTimeUtc.Ticks
        }
        @($before.get_Keys()).Count | Should-BeGreaterThan 0

        Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store `
            -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null

        $moved = [System.Collections.Generic.List[string]]::new()
        foreach ($f in (Get-ChildItem -LiteralPath $owned -Filter *.md -File -Recurse)) {
            if ($before[$f.FullName] -ne $f.LastWriteTimeUtc.Ticks) { $moved.Add($f.Name) }
        }
        @($moved).Count | Should-Be 0
    }
}

Describe 'Replacement still replaces' {
    # The invariant the removal-first shape existed to guarantee. Losing it
    # would be a far worse defect than the churn: the store would keep
    # answering for definitions that no longer exist.

    BeforeAll {
        $script:Store2 = New-EmptyStore -At (Join-Path $TestDrive 'store2')
        Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store2 `
            -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null
    }

    It 'deletes a record this run did not write' {
        $stray = Join-Path $script:Store2 'subjects/psmodule/SampleModule/function/Ghost.md'
        New-Item -ItemType Directory -Path (Split-Path $stray -Parent) -Force | Out-Null
        Set-Content -LiteralPath $stray -Value "---`nid: `"psmodule:SampleModule/function/Ghost`"`n---`n`nnot generated" -Encoding utf8

        $result = Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store2 `
            -GeneratedAt '2026-08-26' -Confirm:$false

        Test-Path -LiteralPath $stray | Should-BeFalse
        $result.RecordsPruned | Should-BeGreaterThan 0
    }

    It 'prunes the directory a deleted record leaves empty' {
        $deep = Join-Path $script:Store2 'subjects/psmodule/SampleModule/function/Gone/Deeper'
        New-Item -ItemType Directory -Path $deep -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $deep 'Orphan.md') -Value "---`nid: `"x`"`n---`n`nbody" -Encoding utf8

        Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store2 `
            -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null

        Test-Path -LiteralPath $deep | Should-BeFalse
        Test-Path -LiteralPath (Split-Path $deep -Parent) | Should-BeFalse
    }

    It 'rewrites a record whose bytes were changed underneath it' {
        # The other direction. A guard that skips a file it should have written
        # is the failure mode this trades against, and it is the one that would
        # be invisible.
        $target = @(Get-ChildItem -LiteralPath (Join-Path $script:Store2 'subjects/psmodule') -Filter *.md -File -Recurse)[0]
        Set-Content -LiteralPath $target.FullName -Value 'corrupted' -Encoding utf8

        $result = Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store2 `
            -GeneratedAt '2026-08-26' -Confirm:$false

        $result.RecordsWritten | Should-BeGreaterThan 0
        (Get-Content -LiteralPath $target.FullName -Raw) | Should-MatchString 'namespace'
    }

    It 'rewrites when the stamp moves, so staleness is still detectable' {
        $result = Update-KnowledgeStore -Path $script:Fixture -StoreRoot $script:Store2 `
            -GeneratedAt '2026-08-27' -Confirm:$false
        $result.RecordsWritten | Should-Be $result.RecordsKept
    }
}

Describe 'The pattern generator skips and prunes the same way' {
    BeforeAll {
        $script:Store3 = New-EmptyStore -At (Join-Path $TestDrive 'store3')
        $script:P1 = Update-KnowledgePatternSubject -Path (Join-Path $script:Knowledge 'patterns') `
            -StoreRoot $script:Store3 -GeneratedAt '2026-08-26' -Confirm:$false
        $script:P2 = Update-KnowledgePatternSubject -Path (Join-Path $script:Knowledge 'patterns') `
            -StoreRoot $script:Store3 -GeneratedAt '2026-08-26' -Confirm:$false
    }

    It 'writes the pattern subjects once' {
        $script:P1.RecordsWritten | Should-BeGreaterThan 0
    }

    It 'writes nothing the second time' {
        $script:P2.RecordsWritten | Should-Be 0
        $script:P2.RecordsKept | Should-Be $script:P1.RecordsKept
    }

    It 'drops a subject whose pattern file is gone' {
        $stray = Join-Path $script:Store3 'subjects/pattern/9999-never-written.md'
        Set-Content -LiteralPath $stray -Value "---`nid: `"pattern:9999-never-written`"`n---`n`nbody" -Encoding utf8

        $result = Update-KnowledgePatternSubject -Path (Join-Path $script:Knowledge 'patterns') `
            -StoreRoot $script:Store3 -GeneratedAt '2026-08-26' -Confirm:$false

        Test-Path -LiteralPath $stray | Should-BeFalse
        $result.RecordsPruned | Should-Be 1
    }
}

Describe 'A write site cannot forget to register what it wrote' {
    # 0028-t1. v0.18.0 traded a filesystem guarantee - the subtree was deleted,
    # so nothing stale could survive - for a $kept list filled in at five call
    # sites, each recomputing the path expression the writer was about to use.
    #
    # WHAT A SIXTH SITE WITHOUT ITS $kept.Add ACTUALLY DID, staged and measured
    # rather than reasoned about: the record was written and then deleted by the
    # prune at the end of the same run, every run, so it never reached the store
    # and the run never became idempotent. Four tests in this file went red. So
    # the omission was detectable, contrary to what 0028-t1 claimed - but only
    # as churn, by tests about something else, and only after the code had been
    # written and run.
    #
    # Registration now happens inside Write-SubjectRecord and
    # Write-AssignmentRecord, from the same variable the write uses, and -Kept
    # is mandatory. The author of the seventh write site is stopped by the
    # parameter binder rather than by a test they have to still be running.

    It 'makes the write log mandatory on both writers' {
        foreach ($name in 'Write-SubjectRecord', 'Write-AssignmentRecord') {
            $parameter = InModuleScope PSModuleGraph -Parameters @{ Name = $name } {
                (Get-Command -Name $Name).Parameters['Kept']
            }
            ($null -ne $parameter) | Should-BeTrue -Because "$name must take a write log"

            $attribute = @($parameter.Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] })[0]
            $attribute.Mandatory | Should-BeTrue -Because "$name must not let a caller skip registering"
        }
    }

    It 'registers every record the run wrote, without the caller saying so' {
        $store = New-EmptyStore -At (Join-Path $TestDrive 'store4')
        $result = Update-KnowledgeStore -Path $script:Fixture -StoreRoot $store `
            -GeneratedAt '2026-08-26' -Confirm:$false

        # The log is the population, not a count kept alongside it.
        $onDisk = @(Get-ChildItem -LiteralPath (Join-Path $store 'subjects/psmodule') -Filter *.md -File -Recurse) +
            @(Get-ChildItem -LiteralPath (Join-Path $store 'assignments/psmodule') -Filter *.md -File -Recurse)
        $result.RecordsKept | Should-Be @($onDisk).Count
        $result.RecordsPruned | Should-Be 0
    }

    It 'grades facets without deleting their assignments first' {
        # The delete-first shape one subtree over. Nine records were recreated
        # on every build with identical bytes, which is the defect v0.18.0 said
        # it had closed.
        # TWICE before measuring, and the reason is the recursion rather than
        # flakiness: facet-health grades the store including its own
        # assignments, so the first run creates a population the second run
        # grades differently. It reaches a fixed point at the second, and
        # everything after that must move nothing.
        $store = New-EmptyStore -At (Join-Path $TestDrive 'store5')
        foreach ($pass in 1, 2) {
            Update-KnowledgeStore -Path $script:Fixture -StoreRoot $store `
                -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null
        }

        $health = Join-Path $store 'assignments/facet'
        $before = @{}
        foreach ($f in (Get-ChildItem -LiteralPath $health -Filter *.md -File -Recurse)) {
            $before[$f.FullName] = $f.LastWriteTimeUtc.Ticks
        }
        @($before.get_Keys()).Count | Should-BeGreaterThan 0

        Update-KnowledgeStore -Path $script:Fixture -StoreRoot $store `
            -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null

        $moved = [System.Collections.Generic.List[string]]::new()
        foreach ($f in (Get-ChildItem -LiteralPath $health -Filter *.md -File -Recurse)) {
            if ($before[$f.FullName] -ne $f.LastWriteTimeUtc.Ticks) { $moved.Add($f.Name) }
        }
        @($moved).Count | Should-Be 0
    }

    It 'still removes an assignment for a facet that has gone' {
        # The invariant the delete-first shape carried. Pruning is driven from
        # the directories on disk rather than from the facets read this run, so
        # a facet whose file was removed loses its records too.
        $store = New-EmptyStore -At (Join-Path $TestDrive 'store6')
        Update-KnowledgeStore -Path $script:Fixture -StoreRoot $store `
            -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null

        # Copies of real records rather than stubs, so the store still parses
        # when the next run reads it back to compute coverage.
        $health = Join-Path $store 'assignments/facet/structure/facet-health'
        $stray = Join-Path $health 'coverage-none.md'
        Copy-Item -LiteralPath (@(Get-ChildItem -LiteralPath $health -Filter *.md -File)[0].FullName) `
            -Destination $stray -Force
        $ghost = Join-Path $store 'subjects/facet/ghost.md'
        Copy-Item -LiteralPath (Join-Path $store 'subjects/facet/structure.md') -Destination $ghost -Force

        Update-KnowledgeStore -Path $script:Fixture -StoreRoot $store `
            -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null

        Test-Path -LiteralPath $stray | Should-BeFalse
        Test-Path -LiteralPath $ghost | Should-BeFalse
    }
}

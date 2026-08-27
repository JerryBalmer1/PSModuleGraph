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
        $base = [string]$graph.ModuleBase

        # -ModuleBase, not omitted. Without it the id falls back to its
        # unqualified form, which is the shape being replaced - and every
        # assertion below would then be checking the old builder while claiming
        # to check the new one.
        $ids = @(InModuleScope PSModuleGraph -Parameters @{ Nodes = @($graph.Nodes); Name = $name; Base = $base } {
                param($Nodes, $Name, $Base)
                foreach ($node in $Nodes) { Get-KnowledgeSubjectId -Node $node -ModuleName $Name -ModuleBase $Base }
            })

        $former = @(InModuleScope PSModuleGraph -Parameters @{ Nodes = @($graph.Nodes); Name = $name } {
                param($Nodes, $Name)
                foreach ($node in $Nodes) { Get-LegacyKnowledgeSubjectId -Node $node -ModuleName $Name }
            })

        [pscustomobject]@{
            ModuleName = $name
            NodeCount  = @($graph.Nodes).Count
            Ids        = $ids
            Distinct   = @($ids | Sort-Object -Unique)
            Former     = $former
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

Describe 'A name in two folders is two subjects, and the old id reaches both' {
    # CollidingModule is the shape SqlServerDsc has and neither module in this
    # store does. Before the qualified id it collapsed; here it is the proof
    # that it no longer does, and the only place the one-to-many alias is
    # exercised at all - every alias in the committed store is 1:1.

    BeforeAll {
        $script:Fixture = Get-SubjectIdMap -ModulePath $script:Colliding

        # New-Item first, then copy INTO it. Copying a directory to a path that
        # does not exist makes the destination a copy of SCHEMA rather than a
        # store containing one, and New-KnowledgeStorePath then refuses it.
        $store = Join-Path $TestDrive 'collide'
        New-Item -ItemType Directory -Path $store -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:Repo 'knowledge/SCHEMA') -Destination $store -Recurse -Force

        Update-KnowledgeStore -Path $script:Colliding -StoreRoot $store -GeneratedAt '2026-08-26' -Confirm:$false | Out-Null

        $script:FixtureSubjects = @(InModuleScope PSModuleGraph -Parameters @{ Root = $store } {
                param($Root)
                Import-KnowledgeSubject -Path (Join-Path $Root 'subjects')
            })
    }

    It 'has a fixture that would have collapsed under the old id' {
        # Guards everything below. If the fixture stops sharing names the split
        # tests pass by never meeting one.
        $script:Fixture.NodeCount | Should-Be 7
        @($script:Fixture.Former | Sort-Object -Unique).Count | Should-Be 4
    }

    It 'gives all seven definitions their own id now' {
        $script:Fixture.Distinct.Count | Should-Be 7
    }

    It 'has the three-way split claim one former id three times' {
        # A two-way split can still be read as a swap; three cannot. This is the
        # case NAMING.md 0.2.0 was written for.
        $former = 'psmodule:CollidingModule/function/Compare-State'
        $claimants = @($script:FixtureSubjects | Where-Object { @($_.Aliases) -contains $former })

        @($claimants).Count | Should-Be 3 -Because (
            'the old id meant whichever of the three was written last, which was never a fact about any of them')

        @($claimants | ForEach-Object { $_.Source } | Sort-Object) | Should-BeCollection @(
            'resources/Alpha/Alpha.psm1', 'resources/Beta/Beta.psm1', 'resources/Gamma/Gamma.psm1')
    }

    It 'has the two-way split claim its former id twice and the unique one once' {
        $two = @($script:FixtureSubjects | Where-Object {
                @($_.Aliases) -contains 'psmodule:CollidingModule/function/Get-TargetResource' })
        @($two).Count | Should-Be 2

        $one = @($script:FixtureSubjects | Where-Object {
                @($_.Aliases) -contains 'psmodule:CollidingModule/function/Get-CollidingThing' })
        @($one).Count | Should-Be 1
    }
}

Describe 'A population that would still collapse is refused' {
    # THE GUARD AFTER THE FIX. Qualifying an id with its path removed the name
    # collision, so CollidingModule no longer trips the guard - and a guard that
    # nothing can trip is a guard nobody can test.
    #
    # AmbiguousPathModule is the hazard the qualified id does NOT remove: two
    # folder names differing only by a character the URN grammar cannot carry,
    # which the slug reduces to one. See ConvertTo-SubjectSlug, which says
    # plainly that replacement narrows the collisions rather than ending them.

    BeforeAll {
        $script:Ambiguous = Join-Path $script:Repo 'tests/fixtures/AmbiguousPathModule'
    }

    It 'names the shared id, how many definitions claim it, and where they are' {
        $store = Join-Path $TestDrive 'knowledge'
        New-Item -ItemType Directory -Path (Join-Path $store 'SCHEMA') -Force | Out-Null

        $failed = $null
        try {
            Update-KnowledgeStore -Path $script:Ambiguous -StoreRoot $store -Confirm:$false | Out-Null
        }
        catch {
            $failed = $_.Exception.Message
        }

        $failed | Should-NotBeNull -Because 'a population that collapses must be refused, not written'

        $failed | Should-MatchString 'psmodule:AmbiguousPathModule/function/res-one/Res\.psm1/Get-Ambiguous'
        $failed | Should-MatchString 'res one/Res\.psm1'
        $failed | Should-MatchString 'res-one/Res\.psm1'
        $failed | Should-MatchString '3 definition\(s\)'
        $failed | Should-MatchString '2 distinct subject id\(s\)'
        $failed | Should-MatchString '1 would be written over'
    }

    It 'refuses before it removes the records it was going to replace' {
        # A refusal that has already deleted the tree leaves no store at all,
        # which is worse than the collapse it prevented. The guard runs before
        # the removal and this is what says so.
        $store = Join-Path $TestDrive 'preserved'
        New-Item -ItemType Directory -Path (Join-Path $store 'SCHEMA') -Force | Out-Null
        $owned = Join-Path $store 'subjects/psmodule/AmbiguousPathModule'
        New-Item -ItemType Directory -Path $owned -Force | Out-Null
        $canary = Join-Path $owned 'canary.md'
        Set-Content -LiteralPath $canary -Value 'still here' -Encoding utf8

        { Update-KnowledgeStore -Path $script:Ambiguous -StoreRoot $store -Confirm:$false } | Should-Throw

        Test-Path -LiteralPath $canary | Should-BeTrue -Because 'the guard runs before the removal'
    }
}

Describe 'Every identifier this store used to issue still reaches something' {
    # THE MIGRATION'S OWN CHECK. Not a spot-check of the ids I thought to look
    # at: both containments over the WHOLE population, which is available
    # because the former id is a pure function of the node rather than
    # something recovered from a tree that no longer exists.
    #
    # 87 subjects moved and none of them was wrong beforehand - neither module
    # in this store has a duplicated name - so nothing here can show the fix
    # working. It can only show the move losing nothing. What shows the fix
    # working is CollidingModule above and SqlServerDsc, which is not committed.

    BeforeAll {
        $script:Store = Join-Path $script:Repo 'knowledge'
        $script:Written = @(InModuleScope PSModuleGraph -Parameters @{ Root = $script:Store } {
                param($Root)
                Import-KnowledgeSubject -Path (Join-Path $Root 'subjects')
            })
        # ORDINAL, not a hashtable. PowerShell hashtable keys are
        # case-insensitive and knowledge/NAMING.md forbids assuming they are:
        # a URN's path segment preserves case, so Get-PSModuleClass and
        # get-psmoduleclass are two identifiers. Written as @{} first, this
        # whole Describe stayed green while the frozen alias builder was
        # deliberately changed to lowercase every name it produced.
        $script:Claimed = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new(
            [System.StringComparer]::Ordinal)
        foreach ($subject in $script:Written) {
            foreach ($alias in @($subject.Aliases)) {
                if (-not $alias) { continue }
                if (-not $script:Claimed.ContainsKey($alias)) {
                    $script:Claimed[$alias] = [System.Collections.Generic.List[string]]::new()
                }
                $script:Claimed[$alias].Add($subject.Id)
            }
        }
    }

    It 'read a store with aliases in it at all' {
        # Guards both containments. Two empty sets contain each other.
        $script:Written.Count | Should-BeGreaterThan 0
        $script:Claimed.Keys.Count | Should-BeGreaterThan 0
    }

    It 'has every former id of <_> claimed by some record' -ForEach @('src/PSModuleGraph', 'tests/fixtures/SampleModule') {
        $map = Get-SubjectIdMap -ModulePath (Join-Path $script:Repo $_)

        # A former id equal to the id it replaced is deliberately not recorded -
        # a script node at the module root did not move - so those are excluded
        # rather than expected.
        $unchanged = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]$map.Ids, [System.StringComparer]::Ordinal)
        $moved = @($map.Former | Where-Object { -not $unchanged.Contains($_) } | Sort-Object -Unique)
        $moved.Count | Should-BeGreaterThan 0

        # Counted with a sample rather than asserted as a collection: broken,
        # this names all 87 in one line, and a wall of ids hides the count that
        # says what happened. Same reasoning as Format-Sample in
        # KnowledgeRoundTrip.Tests.ps1.
        $orphaned = @($moved | Where-Object { -not $script:Claimed.ContainsKey($_) })
        $orphaned.Count | Should-Be 0 -Because (
            "an id nothing claims is an id that stopped resolving. $($orphaned.Count) of " +
            "$($moved.Count) unclaimed, first: $(($orphaned | Select-Object -First 5) -join ', ')")
    }

    It 'claims no alias the old generator would never have issued' {
        # The reverse containment, and the one a sample cannot give. Without it
        # a mistyped alias passes as long as the real one is also present, and
        # the store asserts an identifier that never existed.
        $issued = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($module in 'src/PSModuleGraph', 'tests/fixtures/SampleModule') {
            foreach ($id in (Get-SubjectIdMap -ModulePath (Join-Path $script:Repo $module)).Former) {
                $issued.Add($id) | Out-Null
            }
        }

        $invented = @($script:Claimed.Keys | Where-Object { -not $issued.Contains($_) } | Sort-Object)
        $invented.Count | Should-Be 0 -Because (
            'an alias that was never an id resolves, wrongly, and says the store used to call it that. ' +
            "$($invented.Count) invented, first: $(($invented | Select-Object -First 5) -join ', ')")
    }

    It 'resolves every alias it claims to at least one record on disk' {
        $missing = @()
        foreach ($alias in @($script:Claimed.Keys)) {
            foreach ($id in $script:Claimed[$alias]) {
                $file = InModuleScope PSModuleGraph -Parameters @{ Id = $id; Root = $script:Store } {
                    param($Id, $Root)
                    ConvertTo-KnowledgeFilePath -Id $Id -Root $Root -Area 'subjects'
                }
                if (-not (Test-Path -LiteralPath $file)) { $missing += "$alias -> $id" }
            }
        }
        @($missing) | Should-BeCollection @()
    }
}

Describe 'A module with no duplicate names keeps its count and loses every path' {
    # THE SECOND CORPUS, and the assertion is the PAIR. "The count does not
    # move" alone is satisfied perfectly by a migration that did nothing, which
    # is the failure with no symptom. What says it ran is that every path moved.
    #
    # corpus/PSCorpus is the right module for it: nineteen definitions, no
    # duplicated name anywhere, and not in the committed store - so nothing it
    # says here is a fact about a tree this iteration wrote.

    BeforeAll {
        $script:Corpus = Get-SubjectIdMap -ModulePath (Join-Path $script:Repo 'corpus/PSCorpus')
    }

    It 'has nothing to repair in the first place' {
        $script:Corpus.NodeCount | Should-Be 19
        @($script:Corpus.Former | Sort-Object -Unique).Count | Should-Be 19
    }

    It 'writes exactly as many subjects as it did before' {
        $script:Corpus.Distinct.Count | Should-Be $script:Corpus.NodeCount
        $script:Corpus.Distinct.Count | Should-Be @($script:Corpus.Former | Sort-Object -Unique).Count
    }

    It 'moves every definition that had a path to move to' {
        # The script node at the module root is the one that legitimately does
        # not move: its old id was the file leaf and its new id is the file
        # path, and at the root those are the same string. Everything else must
        # differ, or the id was never qualified.
        $unmoved = @(0..($script:Corpus.NodeCount - 1) |
                Where-Object { $script:Corpus.Ids[$_] -eq $script:Corpus.Former[$_] } |
                ForEach-Object { $script:Corpus.Ids[$_] })

        @($unmoved) | Should-BeCollection @('psmodule:PSCorpus/script/PSCorpus.psm1') -Because (
            'a count that held while no path moved is a migration that did not run')
    }
}

Describe 'The move itself did not lose or duplicate a file' {
    # Two hazards that are not id collisions and that a count of records cannot
    # see. Both are the same shape as the defect being fixed: the migration
    # writing fewer files than it believes it did.

    BeforeAll {
        $script:Store = Join-Path $script:Repo 'knowledge'
    }

    It 'has one file on disk per record, so no two ids met in the filesystem' {
        # Windows is case-insensitive and strips trailing dots, so two ids that
        # differ can still want one path. The id set being distinct does not
        # settle it; the tree has to be counted.
        $subjects = @(InModuleScope PSModuleGraph -Parameters @{ Root = $script:Store } {
                param($Root)
                Import-KnowledgeSubject -Path (Join-Path $Root 'subjects')
            })
        $files = @(Get-ChildItem -LiteralPath (Join-Path $script:Store 'subjects') -Filter *.md -File -Recurse)

        $files.Count | Should-BeGreaterThan 0
        $subjects.Count | Should-Be $files.Count

        $ids = @($subjects | ForEach-Object { $_.Id } | Sort-Object -Unique)
        $ids.Count | Should-Be $files.Count -Because (
            'two records sharing a file is a collision the id set cannot show')
    }

    It 'keeps every store path inside a ceiling, rather than discovering MAX_PATH' {
        # Qualifying an id with its file lengthened every path in the tree, and
        # this is not a hypothetical: checking this commit out into a worktree
        # 121 characters deep failed with "Filename too long" before git had
        # written the store. A write that fails at 260 leaves a store missing
        # records, which is this migration's own version of the defect it fixes.
        #
        # Measured REPO-relative rather than store-relative, because 260 is
        # spent by the checkout root too and the store-relative number cannot
        # see that. 180 here leaves 80 characters for wherever the repository
        # sits, which 'C:\__Code\PSModuleGraph' spends 23 of.
        #
        # git core.longpaths lifts this and is unset on the machine that took
        # the measurement, so it is not something to rely on.
        #
        # The failure NAMES the ceiling, because the person who meets this is
        # not reading this comment - they are reading a red line after adding a
        # function with a long name, and the number they need is how much room
        # a checkout has left. docs/constraints.md carries the same two figures.
        $ceiling = 180
        $maxPath = 260

        $repo = $script:Repo
        $longest = @(Get-ChildItem -LiteralPath $script:Store -Filter *.md -File -Recurse |
                ForEach-Object { $_.FullName.Substring($repo.Length).TrimStart([char]92, [char]47) } |
                Sort-Object { $_.Length } -Descending)

        $longest.Count | Should-BeGreaterThan 0
        $longest[0].Length | Should-BeLessThan $ceiling -Because (
            "the longest repo-relative store path is $($longest[0].Length) characters: " +
            "'$($longest[0])'. The ceiling is $ceiling, which reserves " +
            "$($maxPath - 1 - $ceiling) characters of checkout root against MAX_PATH $maxPath; " +
            "today's longest leaves $($maxPath - 1 - $longest[0].Length). Shorten the id or " +
            'clone somewhere shallower - see docs/constraints.md, "The store".')
    }
}

#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest

    $script:Repo = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $script:Knowledge = Join-Path $script:Repo 'knowledge'

    # Read the whole store back through the shipped readers. This is the test
    # the substrate exists to pass: v0.0.1 could WRITE a store it could not
    # READ, and writable and readable are different properties. The
    # language-neutrality claim rests on the second.
    $script:Subjects = @(InModuleScope PSModuleGraph -Parameters @{ Root = $script:Knowledge } {
            param($Root)
            Import-KnowledgeSubject -Path (Join-Path $Root 'subjects')
        })
    $script:Assignments = @(InModuleScope PSModuleGraph -Parameters @{ Root = $script:Knowledge } {
            param($Root)
            Import-KnowledgeAssignment -Path (Join-Path $Root 'assignments')
        })

    # What the generator intended, recomputed from the same source it used.
    $script:Graph = Get-PSModuleDependencyGraph -Path (Join-Path $script:Repo 'src/PSModuleGraph')
}

Describe 'The store is current' {
    # Separate from the round-trip below, and failing for a different reason.
    # Round-trip asks "is what was written what is read". Freshness asks "does
    # the store still describe the source". Conflating them produces a failure
    # that says the reader broke when the truth is that someone added a
    # function - which happened on the first run of this suite.
    #
    # WHEN THIS FAILS: regenerate the store. It does not mean the reader is
    # broken. Regenerating is still a scratch script; see ledger 0001-t4.

    It 'holds one subject per definition, plus the module itself' {
        $expected = @($script:Graph.Nodes).Count + 1
        $script:Subjects.Count | Should-Be $expected
    }

    It 'holds every assignment the facets imply' {
        # structure for every definition, surface for functions only. A class,
        # an enum or top-level script code has no export status.
        $nodes = @($script:Graph.Nodes)
        $functions = @($nodes | Where-Object { $_.Kind -eq 'Function' })
        $expected = $nodes.Count + $functions.Count

        $script:Assignments.Count | Should-Be $expected
    }
}

Describe 'The store reads itself back' {
    It 'read something at all' {
        # Guards the assertions below: every "foreach over an empty collection"
        # test passes vacuously, and a reader that returned nothing would sail
        # through all of them.
        $script:Subjects.Count | Should-BeGreaterThan 0
        $script:Assignments.Count | Should-BeGreaterThan 0
    }

    It 'validates every file it read' {
        foreach ($subject in $script:Subjects) { $subject.IsValid | Should-BeTrue }
        foreach ($assignment in $script:Assignments) { $assignment.IsValid | Should-BeTrue }
    }

    It 'brings Get-PSModuleClass back with both its classifications' {
        # The spot-check. An exported public function: structure:function at
        # confidence 1 read off the AST, surface:exported at confidence 1 read
        # off the manifest.
        $id = 'psmodule:PSModuleGraph/function/Get-PSModuleClass'

        $subject = @($script:Subjects | Where-Object { $_.Id -eq $id })
        $subject.Count | Should-Be 1
        $subject[0].Name | Should-Be 'Get-PSModuleClass'
        $subject[0].Namespace | Should-Be 'psmodule'
        $subject[0].Parent | Should-Be 'psmodule:PSModuleGraph'

        $mine = @($script:Assignments | Where-Object { $_.Subject -eq $id })
        @($mine.FacetPath | Sort-Object) | Should-BeCollection @('structure:function', 'surface:exported')

        $structure = @($mine | Where-Object { $_.Facet -eq 'structure' })[0]
        $structure.FacetPath | Should-Be 'structure:function'
        $structure.Confidence | Should-Be 1
        $structure.EvidenceKind | Should-Be 'ast'

        $surface = @($mine | Where-Object { $_.Facet -eq 'surface' })[0]
        $surface.FacetPath | Should-Be 'surface:exported'
        $surface.Confidence | Should-Be 1
        $surface.EvidenceKind | Should-Be 'manifest-entry'
    }

    It 'brings an internal function back at the confidence its evidence earns' {
        # surface:internal rests on an ABSENCE from FunctionsToExport, which is
        # weaker than a presence. If this comes back as 1 the store has lost the
        # distinction it exists to record.
        $id = 'psmodule:PSModuleGraph/function/Get-HashtableValue'

        $surface = @($script:Assignments |
                Where-Object { $_.Subject -eq $id -and $_.Facet -eq 'surface' })
        $surface.Count | Should-Be 1
        $surface[0].FacetPath | Should-Be 'surface:internal'
        $surface[0].Confidence | Should-Be 0.9
        $surface[0].EvidenceKind | Should-Be 'manifest-absence'
    }

    It 'reads confidence as a number, not the string the parser produced' {
        # The front-matter parser keeps numerals as strings on purpose so a
        # facet's 'version: 1.0' never becomes the integer 1. Confidence is
        # coerced by its reader instead, and a comparison would silently do the
        # wrong thing if it came back a string.
        foreach ($assignment in $script:Assignments) {
            $assignment.Confidence | Should-HaveType ([double])
        }

        $low = @($script:Assignments | Where-Object { $_.Confidence -lt 1 })
        $low.Count | Should-BeGreaterThan 0
    }

    It 'points every assignment at a subject that exists' {
        # A dangling assignment is the store having an opinion about something
        # it cannot name.
        $known = @{}
        foreach ($subject in $script:Subjects) { $known[$subject.Id] = $true }

        $dangling = @($script:Assignments | Where-Object { -not $known.ContainsKey($_.Subject) })
        @($dangling | ForEach-Object { $_.Subject }) | Should-BeCollection @()
    }

    It 'points every assignment at a path its facet defines' {
        $facets = @{}
        foreach ($file in (Get-ChildItem -Path (Join-Path $script:Knowledge 'facets') -Filter *.md -File)) {
            $facet = InModuleScope PSModuleGraph -Parameters @{ Path = $file.FullName } {
                param($Path)
                Import-KnowledgeFacet -Path $Path
            }
            $facets[$facet.Id] = @($facet.Paths | ForEach-Object { $_['path'] })
        }

        foreach ($assignment in $script:Assignments) {
            $facets.ContainsKey($assignment.Facet) | Should-BeTrue
            $facets[$assignment.Facet] | Should-ContainCollection $assignment.FacetPath
        }
    }

    It 'keeps every subject file flat' {
        # The reshape is the contract, not a formatting preference. A nested
        # value here is a file this reader cannot read, which is the defect
        # v0.1.0 exists to close.
        $files = Get-ChildItem -Path (Join-Path $script:Knowledge 'subjects') -Filter *.md -File -Recurse
        $files.Count | Should-BeGreaterThan 0

        foreach ($file in $files) {
            $split = InModuleScope PSModuleGraph -Parameters @{ Text = (Get-Content -LiteralPath $file.FullName -Raw) } {
                param($Text)
                Split-FrontMatter -Text $Text
            }
            # A block list or a nested mapping shows up as a line whose value is
            # empty, or as a line starting with a dash.
            foreach ($line in ($split.FrontMatter -split "`n")) {
                $line | Should-NotMatchString '^\s*-\s'
                $line | Should-MatchString ':\s*\S'
            }
        }
    }
}

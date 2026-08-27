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
    # Regenerate into TestDrive and compare trees. The v0.1.0 version of this
    # asserted counts against the live graph, which meant adding a private
    # function turned the build red with a fix that lived outside the
    # repository - the shape of test people delete.
    #
    # Comparing trees is the same guarantee with an actionable failure, and it
    # catches what counting could not: a record whose CONTENT drifted while the
    # count stayed the same.

    It 'matches what the generator would write today' {
        $stamp = $script:Assignments[0].ProvenanceAt
        $prompt = $script:Assignments[0].ProvenancePrompt

        $fresh = Join-Path $TestDrive 'knowledge'
        New-Item -ItemType Directory -Path $fresh -Force | Out-Null
        foreach ($area in 'SCHEMA', 'facets', 'meta') {
            Copy-Item -LiteralPath (Join-Path $script:Knowledge $area) -Destination $fresh -Recurse -Force
        }

        foreach ($module in 'src/PSModuleGraph', 'tests/fixtures/SampleModule') {
            Update-KnowledgeStore -Path (Join-Path $script:Repo $module) -StoreRoot $fresh `
                -GeneratedAt $stamp -Prompt $prompt -Confirm:$false | Out-Null
        }

        # Compared by relative path and content, so the failure names the file
        # rather than reporting that two directories differ.
        #
        # Read as written and compared as read. This used to normalise CRLF to
        # LF first, which made both sides agree about an inconsistency neither
        # could then report: the writer emitted LF front matter over a CRLF
        # body for every record in the store, and the committed blobs were LF
        # only because .gitattributes normalises on the way in. A test that
        # normalises the thing the writer claims to guarantee is not checking
        # that guarantee. 0022-t2.
        #
        # Ordinal, because a relative path is an identity here, and two records
        # differing only in case are two records on the platform half of this
        # store's readers are on.
        function Get-Fingerprint {
            param([string] $Root)
            $map = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
            foreach ($area in 'subjects', 'assignments') {
                $base = Join-Path $Root $area
                if (-not (Test-Path -LiteralPath $base)) { continue }
                foreach ($file in (Get-ChildItem -LiteralPath $base -Filter *.md -File -Recurse)) {
                    $relative = $file.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
                    $map[$relative] = [System.IO.File]::ReadAllText($file.FullName)
                }
            }
            , $map
        }

        $committed = Get-Fingerprint -Root $script:Knowledge
        $regenerated = Get-Fingerprint -Root $fresh

        $stale = 'The knowledge store is stale. Run: ./build.ps1 -Task Knowledge'

        # Naming five is actionable; naming ninety-five is a wall of text that
        # hides the count, which is the part that tells you what happened.
        function Format-Sample {
            param([string[]] $Name)
            if ($Name.Count -le 5) { return ($Name -join ', ') }
            "$(($Name | Select-Object -First 5) -join ', ') and $($Name.Count - 5) more"
        }

        $missing = @($regenerated.Keys | Where-Object { -not $committed.ContainsKey($_) } | Sort-Object)
        @($missing) | Should-BeCollection @() -Because "$stale Not committed: $(Format-Sample -Name $missing)"

        $extra = @($committed.Keys | Where-Object { -not $regenerated.ContainsKey($_) } | Sort-Object)
        @($extra) | Should-BeCollection @() -Because "$stale No longer generated: $(Format-Sample -Name $extra)"

        $changed = @($committed.Keys | Where-Object {
                $regenerated.ContainsKey($_) -and $regenerated[$_] -ne $committed[$_]
            } | Sort-Object)
        @($changed) | Should-BeCollection @() -Because "$stale Content differs: $(Format-Sample -Name $changed)"
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
        $id = 'psmodule:PSModuleGraph/function/Public/Get-PSModuleClass.ps1/Get-PSModuleClass'

        $subject = @($script:Subjects | Where-Object { $_.Id -eq $id })
        $subject.Count | Should-Be 1
        $subject[0].Name | Should-Be 'Get-PSModuleClass'
        $subject[0].Namespace | Should-Be 'psmodule'
        $subject[0].Parent | Should-Be 'psmodule:PSModuleGraph'

        # The identifier this subject used to have, still resolving. Nothing in
        # the ordinary course of work reads an alias, so the only thing standing
        # between a broken one and a reader six months from now is this.
        @($subject[0].Aliases) | Should-BeCollection @('psmodule:PSModuleGraph/function/Get-PSModuleClass')

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
        $id = 'psmodule:PSModuleGraph/function/Private/Get-HashtableValue.ps1/Get-HashtableValue'

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
        $facetFiles = @(Get-ChildItem -Path (Join-Path $script:Knowledge 'facets') -Filter *.md -File) +
                      @(Get-ChildItem -Path (Join-Path $script:Knowledge 'meta') -Filter *.md -File)
        foreach ($file in $facetFiles) {
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

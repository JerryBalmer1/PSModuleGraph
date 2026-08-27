#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:GoldenPath = Join-Path $PSScriptRoot 'fixtures/golden/SampleModule.html'

    function ConvertTo-ComparableDocument {
        <#
        .SYNOPSIS
            Strips the three things that vary for reasons the renderer does not
            control, and nothing else.
        .DESCRIPTION
            Everything removed here is a property of the machine or the moment,
            not of the rendering. Nothing is removed because it was inconvenient:

            1. generatedAt   - a wall-clock stamp, different on every run.
            2. the fixture's - an absolute path. Taken from the document's own
               own location     meta.rootPath and then replaced everywhere it
                                appears, rather than field by field: it shows up
                                in meta.moduleRoot and in the payload's
                                moduleBase, and a list of field names would have
                                to grow every time another one appeared. One
                                rule, stated once.
            3. line endings  - ConvertTo-Json emits the platform newline, so the
                               four embedded JSON blocks are CRLF on Windows and
                               LF elsewhere. It is the same serialiser on both
                               sides of this comparison; only the machine the
                               golden was recorded on differs.

            Nothing else. If a fourth thing ever has to be normalised, find out
            why it varies first. A comparison that normalises away a real
            difference proves nothing.
        #>
        param([Parameter(Mandatory)][string] $Text)

        $normalised = $Text.Replace("`r`n", "`n")
        $normalised = [regex]::Replace($normalised, '"generatedAt": "[^"]*"', '"generatedAt": "<normalised>"')

        # The document says where it was rendered from. Read it back out and
        # blank every occurrence, in the JSON-escaped form the payload carries.
        #
        # `rootPath` FIRST, `moduleRoot` second. The field was renamed at
        # renderer v0.3.0 and this matched only the old name, so from that
        # version until v0.15.0 THIS NORMALISATION DID NOTHING - and nothing
        # said so, because the golden had always been re-recorded in the same
        # directory the test runs in, so the two paths were identical and there
        # was nothing to normalise. It surfaced the first time a golden was
        # recorded from a detached worktree, which is what
        # .claude/skills/golden-recording asks for and exactly the class of
        # error it says a worktree exists to expose.
        #
        # Both names are matched rather than the old one dropped: a golden
        # recorded before v0.3.0 is still a document this may be pointed at.
        foreach ($field in 'rootPath', 'moduleRoot') {
            $rootMatch = [regex]::Match($normalised, "`"$field`": `"([^`"]*)`"")
            if ($rootMatch.Success -and $rootMatch.Groups[1].Value) {
                $normalised = $normalised.Replace($rootMatch.Groups[1].Value, '<root>')
            }
        }

        $normalised
    }
}

Describe 'The extraction of the renderer into PSGraphRender' {
    It 'renders the sample module byte for byte as it was last recorded' {
        # A REGRESSION DETECTOR. It was the acceptance test for the extraction
        # and it is not any more, and the difference matters.
        #
        # It was recorded from a pristine worktree of the last commit before the
        # renderer moved out, so for four tags a byte-for-byte match was evidence
        # that the move had changed nothing. That evidence ended at v0.11.0: a
        # node's identity became its qualified path rather than its bare name,
        # every id in the document changed by design, and the golden was
        # re-recorded. What it now proves is that the document has not changed
        # since someone last decided it should - which catches an accident and
        # proves nothing about the extraction.
        #
        # When this fails: find the cause. Do not re-record the golden and do
        # not loosen ConvertTo-ComparableDocument. Re-recording turns the one
        # artifact that can detect a regression into a description of it.
        #
        # RECORDING LOG - what this file is a recording OF, which is the half
        # that evaporates. See .claude/skills/golden-recording.
        #
        #   v0.9.0  the last commit before the renderer moved out. A match was
        #           evidence the move changed nothing.
        #   v0.11.0 every node id changed shape by design.
        #   v0.12.0 links gained a resolution field.
        #   v0.13.0 the renderer pin moved.
        #   v0.15.0 The renderer's heat-ramp comment was corrected - it
        #           described an intention where a measurement was needed - and
        #           the comment is inlined into the document. Rendered from a
        #           detached worktree of 0edaca4 against PSGraphRender 0.11.0.
        #           A cosmetic change to a vendored comment, caught by this
        #           test, which is the smallest thing it has ever caught and
        #           exactly what it is for now.
        #   v0.15.1 THIS ONE. PSGraphRender 0.12.0 fixed four visual defects:
        #           a node revealed after the first paint is laid out rather
        #           than left at the origin, a label shared by two nodes is
        #           qualified, the banner stopped promising a view the page
        #           will not give, and the colour encoding is stated where the
        #           colour is chosen. That is one stylesheet rule, five
        #           strings, one partial and three scripts, all inlined here.
        #           Rendered from a detached worktree of f93c70d against
        #           PSGraphRender 0.12.0. Decided there, recorded here.
        Import-PSModuleGraphUnderTest

        $graph = Get-PSModuleDependencyGraph -Path (Get-SampleModulePath)
        $actual = Export-PSModuleDependencyGraph -InputObject $graph -Format Html

        $expected = [System.IO.File]::ReadAllText($script:GoldenPath)

        $actualNormalised = ConvertTo-ComparableDocument -Text $actual
        $expectedNormalised = ConvertTo-ComparableDocument -Text $expected

        if ($actualNormalised -cne $expectedNormalised) {
            # Say where, not just that. A 120 KB diff reported as "not equal" is
            # a test that fails without telling anyone anything.
            $a = $actualNormalised -split "`n"
            $e = $expectedNormalised -split "`n"
            $limit = [math]::Min($a.Count, $e.Count)
            $firstDiff = -1
            for ($i = 0; $i -lt $limit; $i++) {
                if ($a[$i] -cne $e[$i]) { $firstDiff = $i; break }
            }

            $detail = if ($firstDiff -ge 0) {
                "first difference at line $($firstDiff + 1):`n  expected: $($e[$firstDiff])`n  actual:   $($a[$firstDiff])"
            }
            else {
                "documents agree for $limit lines then differ in length: expected $($e.Count) lines, actual $($a.Count)"
            }

            throw "The rendered document no longer matches tests/fixtures/golden/SampleModule.html. $detail"
        }

        $actualNormalised.Length | Should-Be $expectedNormalised.Length
    }
}

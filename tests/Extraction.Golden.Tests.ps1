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
               own location     meta.moduleRoot and then replaced everywhere it
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
        $rootMatch = [regex]::Match($normalised, '"moduleRoot": "([^"]*)"')
        if ($rootMatch.Success -and $rootMatch.Groups[1].Value) {
            $normalised = $normalised.Replace($rootMatch.Groups[1].Value, '<root>')
        }

        $normalised
    }
}

Describe 'The extraction of the renderer into PSGraphRender' {
    It 'renders the sample module byte for byte as it did before the move' {
        # THE ACCEPTANCE TEST FOR THE EXTRACTION.
        #
        # tests/fixtures/golden/SampleModule.html was rendered from a pristine
        # worktree of the last commit before the renderer moved out. Everything
        # below the seam now lives in another repository and another module. If
        # a single byte of the document changed, the move changed behaviour, and
        # a move that changes behaviour is not a move.
        #
        # When this fails: find the cause. Do not re-record the golden and do
        # not loosen ConvertTo-ComparableDocument. Re-recording turns the one
        # artifact that can detect a regression into a description of it.
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

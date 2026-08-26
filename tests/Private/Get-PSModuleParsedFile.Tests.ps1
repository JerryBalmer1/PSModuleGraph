#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath
    $script:SampleFile = Join-Path $script:Sample 'public\Get-SampleThing.ps1'
}

Describe 'Get-PSModuleParsedFile' {
    It 'returns the same AST instance for an unchanged file' {
        $pair = & (Get-Module PSModuleGraph) {
            param($p)
            [pscustomobject]@{
                First  = Get-PSModuleParsedFile -FilePath $p
                Second = Get-PSModuleParsedFile -FilePath $p
            }
        } $script:SampleFile

        $pair.First.Ast | Should-NotBeNull
        [object]::ReferenceEquals($pair.First.Ast, $pair.Second.Ast) | Should-BeTrue
    }

    It 'bypasses the cache with -NoCache' {
        $pair = & (Get-Module PSModuleGraph) {
            param($p)
            [pscustomobject]@{
                Cached = Get-PSModuleParsedFile -FilePath $p
                Fresh  = Get-PSModuleParsedFile -FilePath $p -NoCache
            }
        } $script:SampleFile

        $pair.Fresh.Ast | Should-NotBeNull
        [object]::ReferenceEquals($pair.Cached.Ast, $pair.Fresh.Ast) | Should-BeFalse
    }

    It 're-parses a file whose write time changed' {
        $copy = Join-Path $TestDrive 'Cached-Sample.ps1'
        Set-Content -LiteralPath $copy -Value 'function Test-CacheOne { }'

        $first = & (Get-Module PSModuleGraph) {
            param($p) Get-PSModuleParsedFile -FilePath $p
        } $copy

        Set-Content -LiteralPath $copy -Value 'function Test-CacheTwo { }'
        (Get-Item -LiteralPath $copy).LastWriteTimeUtc = (Get-Item -LiteralPath $copy).LastWriteTimeUtc.AddSeconds(5)

        $second = & (Get-Module PSModuleGraph) {
            param($p) Get-PSModuleParsedFile -FilePath $p
        } $copy

        [object]::ReferenceEquals($first.Ast, $second.Ast) | Should-BeFalse
        $second.Ast.Extent.Text | Should-MatchString 'Test-CacheTwo'
    }

    It 'keeps the file path on the AST extent' {
        # ParseFile, not ParseInput: ParseInput would leave Extent.File null.
        $parsed = & (Get-Module PSModuleGraph) {
            param($p) Get-PSModuleParsedFile -FilePath $p
        } $script:SampleFile

        $parsed.Ast.Extent.File | Should-Be $parsed.Path
        $parsed.IsParsed | Should-BeTrue
    }
}

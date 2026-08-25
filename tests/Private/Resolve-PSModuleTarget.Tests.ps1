#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleAstUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Resolve-PSModuleTarget' {
    It 'resolves a directory path' {
        $t = & (Get-Module PSModuleAst) { param($p) Resolve-PSModuleTarget -Path $p } $script:Sample
        $t.Name | Should-Be 'SampleModule'
        $t.ManifestPath | Should-MatchString 'SampleModule\.psd1$'
        $t.ModuleBase | Should-Be (Get-Item -LiteralPath $script:Sample).FullName
    }

    It 'resolves a .psd1 path' {
        $psd1 = Join-Path $script:Sample 'SampleModule.psd1'
        $t = & (Get-Module PSModuleAst) { param($p) Resolve-PSModuleTarget -Path $p } $psd1
        $t.Name | Should-Be 'SampleModule'
        $t.Version | Should-Be ([version]'1.2.3')
    }

    It 'throws for missing path' {
        { & (Get-Module PSModuleAst) { Resolve-PSModuleTarget -Path 'C:\no\such\module-path-xyz' } } |
            Should-Throw
    }
}

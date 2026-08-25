#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleAstUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleManifest' {
    It 'parses manifest metadata and required modules' {
        $m = Get-PSModuleManifest -Path $script:Sample
        $m.HasManifest | Should-BeTrue
        $m.ParseSucceeded | Should-BeTrue
        $m.ModuleVersion | Should-Be ([version]'1.2.3')
        $m.RootModule | Should-Be 'SampleModule.psm1'
        $m.FunctionsToExport | Should-ContainCollection 'Get-SampleThing'
        $m.RequiredModules.Name | Should-ContainCollection 'Pester'
    }
}

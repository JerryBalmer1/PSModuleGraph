#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleSourceFile' {
    It 'lists script files with parse status' {
        $files = @(Get-PSModuleSourceFile -Path $script:Sample)
        $files.Count | Should-BeGreaterThan 3
        $files.RelativePath | Should-ContainCollection 'SampleModule.psd1'
        $files.RelativePath | Should-ContainCollection 'public\Get-SampleThing.ps1'
        ($files | Where-Object { $_.Extension -eq '.ps1' } | Select-Object -First 1).IsParsed | Should-BeTrue
    }
}

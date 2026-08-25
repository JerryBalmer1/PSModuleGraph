#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleAstUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleEnum' {
    It 'returns enum labels and values' {
        $enums = @(Get-PSModuleEnum -Path $script:Sample)
        $enums.Count | Should-Be 1
        $enums[0].Name | Should-Be 'SampleStatus'
        $labels = $enums[0].Labels.Name
        $labels | Should-ContainCollection 'Unknown'
        $labels | Should-ContainCollection 'Ready'
        $labels | Should-ContainCollection 'Failed'

        $ready = $enums[0].Labels | Where-Object Name -EQ 'Ready'
        $ready.Value | Should-Be 1
    }
}

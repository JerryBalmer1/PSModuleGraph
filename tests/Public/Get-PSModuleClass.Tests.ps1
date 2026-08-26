#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleClass' {
    It 'finds classes and base types' {
        $classes = @(Get-PSModuleClass -Path $script:Sample)
        $classes.Name | Should-ContainCollection 'SampleBase'
        $classes.Name | Should-ContainCollection 'SampleThing'

        $thing = $classes | Where-Object Name -EQ 'SampleThing'
        $thing.BaseTypes | Should-ContainCollection 'SampleBase'
    }

    It 'does not report enums as classes' {
        $classes = @(Get-PSModuleClass -Path $script:Sample)
        ($classes.Name -contains 'SampleStatus') | Should-BeFalse
    }
}

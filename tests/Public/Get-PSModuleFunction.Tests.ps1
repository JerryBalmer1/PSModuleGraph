#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleFunction' {
    It 'discovers functions from a module path' {
        $fns = @(Get-PSModuleFunction -Path $script:Sample)
        $fns.Count | Should-BeGreaterThan 0
        $names = $fns.Name
        $names | Should-ContainCollection 'Get-SampleThing'
        $names | Should-ContainCollection 'ConvertTo-SampleName'
        $names | Should-ContainCollection 'Invoke-SampleWorkflow'
    }

    It 'marks exported functions from the manifest' {
        $fns = @(Get-PSModuleFunction -Path $script:Sample)
        ($fns | Where-Object Name -EQ 'Get-SampleThing').IsExported | Should-BeTrue
        ($fns | Where-Object Name -EQ 'ConvertTo-SampleName').IsExported | Should-BeFalse
    }

    It 'includes file path and line numbers' {
        $fn = Get-PSModuleFunction -Path $script:Sample | Where-Object Name -EQ 'Get-SampleThing'
        $fn.Path | Should-MatchString 'Get-SampleThing\.ps1$'
        $fn.StartLine | Should-BeGreaterThan 0
    }

    It 'accepts a .psd1 path' {
        $psd1 = Join-Path $script:Sample 'SampleModule.psd1'
        $fns = @(Get-PSModuleFunction -Path $psd1)
        $fns.Name | Should-ContainCollection 'Test-SampleThing'
    }
}

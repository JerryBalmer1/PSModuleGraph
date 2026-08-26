#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleUsingStatement' {
    It 'finds using namespace statements' {
        $usings = @(Get-PSModuleUsingStatement -Path $script:Sample)
        $usings.Count | Should-BeGreaterThan 0
        $ns = $usings | Where-Object Kind -EQ 'Namespace'
        $ns.Name | Should-MatchString 'System\.Collections\.Generic'
    }
}

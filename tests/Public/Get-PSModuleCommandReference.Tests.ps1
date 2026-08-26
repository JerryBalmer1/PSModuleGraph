#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
    $script:Sample = Get-SampleModulePath
}

Describe 'Get-PSModuleCommandReference' {
    It 'attributes call sites to enclosing functions' {
        $refs = @(Get-PSModuleCommandReference -Path $script:Sample)
        $fromGet = $refs | Where-Object {
            $_.EnclosingFunction -eq 'Get-SampleThing' -and $_.UnqualifiedName -eq 'ConvertTo-SampleName'
        }
        $fromGet | Should-NotBeNull
        $fromGet[0].IsInternal | Should-BeTrue
        $fromGet[0].StartLine | Should-BeGreaterThan 0
    }

    It 'marks external commands as not internal' {
        $refs = @(Get-PSModuleCommandReference -Path $script:Sample)
        $ext = $refs | Where-Object {
            $_.EnclosingFunction -eq 'Invoke-SampleWorkflow' -and $_.UnqualifiedName -eq 'Get-Date'
        }
        $ext | Should-NotBeNull
        $ext[0].IsInternal | Should-BeFalse
    }
}

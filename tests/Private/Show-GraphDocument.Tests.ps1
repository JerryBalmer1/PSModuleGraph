#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
}

Describe 'Show-GraphDocument' {
    # Nothing here may launch a browser or an editor. Both exit paths run through
    # Start-Process, which is mocked throughout; a real launch would hang CI.
    It 'opens in VS Code when running inside VS Code' {
        $probe = Join-Path $TestDrive 'report.html'
        Set-Content -LiteralPath $probe -Value '<!DOCTYPE html><html></html>'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { 'C:\fake\code.cmd' }
            Mock Start-Process { }

            Show-GraphDocument -Path $Probe

            Should-Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'C:\fake\code.cmd' -and
                $ArgumentList -contains '--reuse-window' -and
                $ArgumentList -contains $Probe
            }
        }
    }

    It 'falls back to the OS handler when not inside VS Code' {
        $probe = Join-Path $TestDrive 'report2.html'
        Set-Content -LiteralPath $probe -Value '<!DOCTYPE html><html></html>'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { $null }
            Mock Start-Process { }

            Show-GraphDocument -Path $Probe

            # The OS handler is invoked with the file itself and no editor flags.
            Should-Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq $Probe
            }
        }
    }

    It 'falls back to the OS handler when the editor launch throws' {
        $probe = Join-Path $TestDrive 'report3.html'
        Set-Content -LiteralPath $probe -Value '<!DOCTYPE html><html></html>'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { 'C:\fake\code.cmd' }
            Mock Start-Process { throw 'launch failed' } -ParameterFilter { $FilePath -eq 'C:\fake\code.cmd' }
            Mock Start-Process { } -ParameterFilter { $FilePath -eq $Probe }

            # A failed editor launch must not fail the export.
            Show-GraphDocument -Path $Probe

            Should-Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq $Probe }
        }
    }

    It 'does nothing under -WhatIf' {
        $probe = Join-Path $TestDrive 'report4.html'
        Set-Content -LiteralPath $probe -Value '<!DOCTYPE html><html></html>'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { 'C:\fake\code.cmd' }
            Mock Start-Process { }

            Show-GraphDocument -Path $Probe -WhatIf

            Should-NotInvoke Start-Process
        }
    }

    It 'throws when the file does not exist' {
        InModuleScope PSModuleGraph {
            Mock Start-Process { }
            { Show-GraphDocument -Path 'TestDrive:\definitely-missing.html' } | Should-Throw
        }
    }
}

Describe 'Get-VSCodeLauncher' {
    It 'returns null when no VS Code marker is present' {
        InModuleScope PSModuleGraph {
            $saved = @{
                Term = $env:TERM_PROGRAM
                Pid  = $env:VSCODE_PID
                Ipc  = $env:VSCODE_GIT_IPC_HANDLE
                Inj  = $env:VSCODE_INJECTION
            }
            try {
                $env:TERM_PROGRAM = 'not-vscode'
                $env:VSCODE_PID = ''
                $env:VSCODE_GIT_IPC_HANDLE = ''
                $env:VSCODE_INJECTION = ''

                # Installed-but-not-running-in must not count as "in VS Code".
                Get-VSCodeLauncher | Should-BeNull
            }
            finally {
                $env:TERM_PROGRAM = $saved.Term
                $env:VSCODE_PID = $saved.Pid
                $env:VSCODE_GIT_IPC_HANDLE = $saved.Ipc
                $env:VSCODE_INJECTION = $saved.Inj
            }
        }
    }
}

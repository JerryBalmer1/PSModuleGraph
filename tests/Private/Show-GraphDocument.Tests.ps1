#Requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..\TestHelpers.ps1')
    Import-PSModuleGraphUnderTest
}

Describe 'Show-GraphDocument' {
    # Nothing here may launch a browser or an editor. Every exit path runs
    # through Start-Process, which is mocked throughout; a real launch hangs CI.
    It 'opens the OS handler even when running inside VS Code' {
        $probe = Join-Path $TestDrive 'report.html'
        Set-Content -LiteralPath $probe -Value '<!DOCTYPE html><html></html>'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            # Being inside VS Code must NOT divert the report into the editor.
            # A webview cannot follow a vscode:// URI, so opening the report
            # there would disable the page's own click-to-source.
            Mock Get-VSCodeLauncher { 'C:\fake\code.cmd' }
            Mock Start-Process { }

            Show-GraphDocument -Path $Probe

            Should-Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq $Probe
            }
            Should-NotInvoke Start-Process -ParameterFilter {
                $FilePath -eq 'C:\fake\code.cmd'
            }
        }
    }

    It 'writes a verbose hint when running inside VS Code' {
        $probe = Join-Path $TestDrive 'report5.html'
        Set-Content -LiteralPath $probe -Value '<!DOCTYPE html><html></html>'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { 'C:\fake\code.cmd' }
            Mock Start-Process { }

            # The hint names the command rather than running it.
            $output = Show-GraphDocument -Path $Probe -Verbose 4>&1
            ($output | Out-String) | Should-MatchString 'code'
        }
    }

    It 'writes no verbose hint outside VS Code' {
        $probe = Join-Path $TestDrive 'report6.html'
        Set-Content -LiteralPath $probe -Value '<!DOCTYPE html><html></html>'

        InModuleScope PSModuleGraph -Parameters @{ Probe = $probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { $null }
            Mock Start-Process { }

            # Nothing to suggest: the user is not in an editor to open it in.
            $output = Show-GraphDocument -Path $Probe -Verbose 4>&1
            ($output | Out-String) | Should-NotMatchString 'reuse-window'
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

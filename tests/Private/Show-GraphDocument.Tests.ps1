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
            Mock Resolve-LoopbackDocumentUrl { }

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
            Mock Resolve-LoopbackDocumentUrl { }

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
            Mock Resolve-LoopbackDocumentUrl { }

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
            Mock Resolve-LoopbackDocumentUrl { }

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
            Mock Resolve-LoopbackDocumentUrl { }

            Show-GraphDocument -Path $Probe -WhatIf

            Should-NotInvoke Start-Process
        }
    }

    It 'throws when the file does not exist' {
        InModuleScope PSModuleGraph {
            Mock Start-Process { }
            Mock Resolve-LoopbackDocumentUrl { }
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

Describe 'Show-GraphDocument routing' {
    BeforeEach {
        $script:Probe = Join-Path $TestDrive 'routed.html'
        Set-Content -LiteralPath $script:Probe -Value '<!DOCTYPE html><html></html>'
    }

    It 'opens the served URL rather than the file when a server has it' {
        InModuleScope PSModuleGraph -Parameters @{ Probe = $script:Probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { }
            Mock Start-Process { }
            Mock Resolve-LoopbackDocumentUrl {
                [pscustomobject]@{
                    Url          = 'http://127.0.0.1:5500/output/reports/routed.html'
                    Origin       = 'http://127.0.0.1:5500'
                    RelativePath = 'output/reports/routed.html'
                }
            }

            Show-GraphDocument -Path $Probe

            # The document, never the directory - and on an origin a browser
            # policy can match, which is what lets the page's own links work.
            Should-Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
                $FilePath -eq 'http://127.0.0.1:5500/output/reports/routed.html'
            }
        }
    }

    It 'says which route it took, either way' {
        InModuleScope PSModuleGraph -Parameters @{ Probe = $script:Probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { }
            Mock Start-Process { }
            Mock Resolve-LoopbackDocumentUrl {
                [pscustomobject]@{
                    Url = 'http://127.0.0.1:5500/routed.html'; Origin = 'http://127.0.0.1:5500'
                    RelativePath = 'routed.html'
                }
            }

            $served = @(Show-GraphDocument -Path $Probe -Verbose 4>&1 |
                    Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
            ($served -join ' ') | Should-MatchString 'served over http://127\.0\.0\.1:5500'
            ($served -join ' ') | Should-MatchString 'editor links will work'
        }

        InModuleScope PSModuleGraph -Parameters @{ Probe = $script:Probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { }
            Mock Start-Process { }
            Mock Resolve-LoopbackDocumentUrl { }

            $disk = @(Show-GraphDocument -Path $Probe -EditorLinkHelpCommand 'Test-Thing' -Verbose 4>&1 |
                    Where-Object { $_ -is [System.Management.Automation.VerboseRecord] })
            ($disk -join ' ') | Should-MatchString 'from disk'
            # The command is supplied by the caller, not known here. See the
            # seam note in docs/html-architecture.md.
            ($disk -join ' ') | Should-MatchString 'Test-Thing'
        }
    }

    It 'skips the probe entirely with -NoServe' {
        InModuleScope PSModuleGraph -Parameters @{ Probe = $script:Probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { }
            Mock Start-Process { }
            Mock Resolve-LoopbackDocumentUrl { throw 'the probe must not run under -NoServe' }

            Show-GraphDocument -Path $Probe -NoServe

            Should-NotInvoke Resolve-LoopbackDocumentUrl
            Should-Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $FilePath -eq $Probe }
        }
    }

    It 'passes a supplied BaseUrl through to the probe' {
        InModuleScope PSModuleGraph -Parameters @{ Probe = $script:Probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { }
            Mock Start-Process { }
            Mock Resolve-LoopbackDocumentUrl { }

            Show-GraphDocument -Path $Probe -BaseUrl 'http://127.0.0.1:9999'

            Should-Invoke Resolve-LoopbackDocumentUrl -Times 1 -Exactly -ParameterFilter {
                $BaseUrl -eq 'http://127.0.0.1:9999'
            }
        }
    }

    It 'names the URL it would open under -WhatIf, not the file it came from' {
        InModuleScope PSModuleGraph -Parameters @{ Probe = $script:Probe } {
            param($Probe)

            Mock Get-VSCodeLauncher { }
            Mock Start-Process { }
            Mock Resolve-LoopbackDocumentUrl {
                [pscustomobject]@{
                    Url = 'http://127.0.0.1:5500/routed.html'; Origin = 'http://127.0.0.1:5500'
                    RelativePath = 'routed.html'
                }
            }

            Show-GraphDocument -Path $Probe -WhatIf
            Should-NotInvoke Start-Process
        }
    }
}

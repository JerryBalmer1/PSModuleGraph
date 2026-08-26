function Get-EditorLinkBrowser {
    <#
    .SYNOPSIS
        Describes the Chromium browsers this module can configure.
    .DESCRIPTION
        One definition per supported browser. Every path is derived from the two
        roots rather than hardcoded, which is what lets the tests run against
        TestRegistry: and TestDrive: without touching the real machine.

        Firefox is deliberately absent: it has no equivalent policy and is
        reported as unsupported rather than half-handled.
    .PARAMETER PolicyRoot
        Registry root holding vendor policy keys.
    .PARAMETER LocalStateRoot
        Directory root holding each browser's User Data.
    .PARAMETER MachinePolicyRoot
        Machine-wide policy root, read ONLY to warn that it would win. Never
        written; see the safety rules in CLAUDE.md.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string] $PolicyRoot = 'HKCU:\SOFTWARE\Policies',

        [Parameter()]
        [string] $LocalStateRoot = $env:LOCALAPPDATA,

        [Parameter()]
        [string] $MachinePolicyRoot = 'HKLM:\SOFTWARE\Policies'
    )

    $definitions = @(
        @{
            Name        = 'Chrome'
            Vendor      = 'Google\Chrome'
            UserData    = 'Google\Chrome\User Data'
            ProcessName = 'chrome'
            Executables = @(
                "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
            )
        }
        @{
            Name        = 'Edge'
            Vendor      = 'Microsoft\Edge'
            UserData    = 'Microsoft\Edge\User Data'
            ProcessName = 'msedge'
            Executables = @(
                "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
                "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
            )
        }
    )

    foreach ($definition in $definitions) {
        $exe = $definition.Executables | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
        $localState = if ($LocalStateRoot) {
            Join-Path (Join-Path $LocalStateRoot $definition.UserData) 'Local State'
        }
        else { $null }

        [pscustomobject]@{
            PSTypeName        = 'PSModuleGraph.EditorLinkBrowser'
            Name              = $definition.Name
            PolicyPath        = Join-Path $PolicyRoot $definition.Vendor
            MachinePolicyPath = Join-Path $MachinePolicyRoot $definition.Vendor
            LocalStatePath    = $localState
            ProcessName       = $definition.ProcessName
            ExecutablePath    = $exe
        }
    }
}

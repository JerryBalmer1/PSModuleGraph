function Test-PSModuleGraphEditorLink {
    <#
    .SYNOPSIS
        Reports whether this machine can open vscode:// links from a browser.
    .DESCRIPTION
        Read-only. Changes nothing, on any code path, and deliberately has no
        ShouldProcess: there is nothing to confirm.

        Run this when "Open File Location" in an HTML report does nothing. The
        usual causes are a browser that has never been granted permission to
        launch the scheme, or one that remembers a declined prompt and now fails
        in silence. Enable-PSModuleGraphEditorLink fixes both.

        On macOS and Linux the object comes back with Platform set and the rest
        null, plus a warning. Automatic configuration is Windows-only.
    .PARAMETER Protocol
        Scheme to check. Defaults to vscode.
    .PARAMETER PolicyRoot
        Registry root holding vendor policy keys. Exists so the tests can run
        against TestRegistry: rather than the real machine; leave it alone.
    .PARAMETER LocalStateRoot
        Directory root holding each browser's User Data. Same purpose.
    .EXAMPLE
        Test-PSModuleGraphEditorLink

        Reports protocol registration, per-browser policy, and whether either
        browser has remembered a refusal.
    .EXAMPLE
        (Test-PSModuleGraphEditorLink).Browsers | Format-Table Name, AutoLaunchConfigured, SchemeExcluded
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Protocol = 'vscode',

        [Parameter()]
        [string] $PolicyRoot = 'HKCU:\SOFTWARE\Policies',

        [Parameter()]
        [string] $LocalStateRoot = $env:LOCALAPPDATA
    )

    Get-EditorLinkState -Protocol $Protocol -PolicyRoot $PolicyRoot -LocalStateRoot $LocalStateRoot
}

function Get-EditorLinkState {
    <#
    .SYNOPSIS
        Builds the editor-link status object. Reads only; changes nothing.
    .DESCRIPTION
        Shared by Test-PSModuleGraphEditorLink and by
        Enable-PSModuleGraphEditorLink, which returns the same shape after
        changing anything, so before and after are directly comparable.
    .PARAMETER Protocol
        Scheme to look for in the policy.
    .PARAMETER PolicyRoot
        Registry root holding vendor policy keys.
    .PARAMETER LocalStateRoot
        Directory root holding each browser's User Data.
    .PARAMETER MachinePolicyRoot
        Machine policy root, read only to warn that it would win.
    .PARAMETER ClassesRoot
        Registry root holding scheme registrations.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string] $Protocol = 'vscode',

        [Parameter()]
        [string] $PolicyRoot = 'HKCU:\SOFTWARE\Policies',

        [Parameter()]
        [string] $LocalStateRoot = $env:LOCALAPPDATA,

        [Parameter()]
        [string] $MachinePolicyRoot = 'HKLM:\SOFTWARE\Policies',

        [Parameter()]
        [string] $ClassesRoot = 'HKCU:\SOFTWARE\Classes'
    )

    $onWindows = if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        $IsWindows
    }
    else {
        $PSVersionTable.PSEdition -eq 'Desktop'
    }

    if (-not $onWindows) {
        $platform = if ((Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) -and $IsMacOS) { 'macOS' }
        elseif ((Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) -and $IsLinux) { 'Linux' }
        else { 'Unknown' }

        Write-Warning ("Automatic editor-link configuration is Windows-only. On $platform, grant the " +
            "browser permission to open ${Protocol}:// links yourself, or use Copy Editor Link in the report.")

        return [pscustomobject]@{
            PSTypeName         = 'PSModuleGraph.EditorLinkState'
            Platform           = $platform
            Protocol           = $Protocol
            ProtocolRegistered = $null
            ProtocolCommand    = $null
            DefaultBrowser     = $null
            Browsers           = @()
            Ready              = $false
        }
    }

    $protocolKey = Join-Path $ClassesRoot $Protocol
    $commandKey = Join-Path $protocolKey 'shell\open\command'
    $registered = Test-Path -LiteralPath $protocolKey
    $command = $null
    if (Test-Path -LiteralPath $commandKey) {
        $command = (Get-ItemProperty -LiteralPath $commandKey -ErrorAction SilentlyContinue).'(default)'
    }

    $userChoice = 'HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice'
    $defaultBrowser = $null
    if (Test-Path -LiteralPath $userChoice) {
        $defaultBrowser = (Get-ItemProperty -LiteralPath $userChoice -ErrorAction SilentlyContinue).ProgId
    }
    if ($defaultBrowser -and $defaultBrowser -match 'Firefox') {
        Write-Warning ("Firefox is the default browser. It has no AutoLaunchProtocolsFromOrigins " +
            "equivalent, so this module cannot configure it; use Copy Editor Link in the report.")
    }

    $browsers = foreach ($browser in Get-EditorLinkBrowser -PolicyRoot $PolicyRoot -LocalStateRoot $LocalStateRoot -MachinePolicyRoot $MachinePolicyRoot) {
        $policy = Get-AutoLaunchPolicy -PolicyPath $browser.PolicyPath
        $entry = $policy.Entries | Where-Object { $_.protocol -eq $Protocol } | Select-Object -First 1

        $machinePolicy = $false
        if (Test-Path -LiteralPath $browser.MachinePolicyPath) {
            $machineItem = Get-ItemProperty -LiteralPath $browser.MachinePolicyPath -Name 'AutoLaunchProtocolsFromOrigins' -ErrorAction SilentlyContinue
            $machinePolicy = $null -ne $machineItem
        }

        $excluded = $null
        if ($browser.LocalStatePath -and (Test-Path -LiteralPath $browser.LocalStatePath)) {
            $excluded = Test-SchemeExcluded -LocalStatePath $browser.LocalStatePath -Protocol $Protocol
        }

        [pscustomobject]@{
            PSTypeName           = 'PSModuleGraph.EditorLinkBrowserState'
            Name                 = $browser.Name
            Detected             = [bool]$browser.ExecutablePath -or
                                   ($browser.LocalStatePath -and (Test-Path -LiteralPath $browser.LocalStatePath))
            ExecutablePath       = $browser.ExecutablePath
            PolicyPath           = $browser.PolicyPath
            AutoLaunchConfigured = $null -ne $entry
            AllowedOrigins       = if ($entry) { @($entry.allowed_origins) } else { @() }
            MachinePolicyPresent = $machinePolicy
            MachinePolicyPath    = $browser.MachinePolicyPath
            LocalStatePath       = $browser.LocalStatePath
            SchemeExcluded       = $excluded
            Running              = [bool](Get-Process -Name $browser.ProcessName -ErrorAction SilentlyContinue)
        }
    }

    $browsers = @($browsers)
    $detected = @($browsers | Where-Object { $_.Detected })
    $ready = $registered -and $detected.Count -gt 0 -and
        -not (@($detected | Where-Object { -not $_.AutoLaunchConfigured -or $_.SchemeExcluded -eq $true }).Count)

    [pscustomobject]@{
        PSTypeName         = 'PSModuleGraph.EditorLinkState'
        Platform           = 'Windows'
        Protocol           = $Protocol
        ProtocolRegistered = $registered
        ProtocolCommand    = $command
        DefaultBrowser     = $defaultBrowser
        Browsers           = $browsers
        Ready              = [bool]$ready
    }
}

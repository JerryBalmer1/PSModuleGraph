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
    .PARAMETER AllowedOrigin
        Origins the caller intends to grant. When supplied, each browser reports
        whether what is configured matches, so a stale or partial grant is
        visible rather than passing as "configured".
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
        [string] $ClassesRoot = 'HKCU:\SOFTWARE\Classes',

        [Parameter()]
        [AllowNull()]
        [string[]] $AllowedOrigin
    )

    # Ignore, not SilentlyContinue: the automatic variable is absent on 5.1 by
    # design, and recording that as an error trains a reader to skip errors.
    $onWindows = if (Get-Variable -Name IsWindows -ErrorAction Ignore) {
        $IsWindows
    }
    else {
        $PSVersionTable.PSEdition -eq 'Desktop'
    }

    if (-not $onWindows) {
        $platform = if ((Get-Variable -Name IsMacOS -ErrorAction Ignore) -and $IsMacOS) { 'macOS' }
        elseif ((Get-Variable -Name IsLinux -ErrorAction Ignore) -and $IsLinux) { 'Linux' }
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

        $exclusion = Get-SchemeExclusion -LocalStatePath $browser.LocalStatePath -Protocol $Protocol

        # Does not suppress the prompt, but when it is Disabled the user cannot
        # grant a per-site exemption from the prompt either - which changes what
        # advice is worth giving.
        $checkbox = Get-BrowserDwordPolicy -UserPolicyPath $browser.PolicyPath `
            -MachinePolicyPath $browser.MachinePolicyPath `
            -Name 'ExternalProtocolDialogShowAlwaysOpenCheckbox'

        $configuredOrigins = if ($entry) { @($entry.allowed_origins) } else { @() }
        # $null when nothing was asked for, or when nothing is configured to
        # compare against. Order-insensitive: the policy does not care.
        $originsMatch = $null
        if ($AllowedOrigin -and $entry) {
            $wanted = @($AllowedOrigin | Sort-Object)
            $have = @($configuredOrigins | Sort-Object)
            $originsMatch = ($wanted.Count -eq $have.Count) -and
                -not @(Compare-Object -ReferenceObject $wanted -DifferenceObject $have).Count
        }

        [pscustomobject]@{
            PSTypeName           = 'PSModuleGraph.EditorLinkBrowserState'
            Name                 = $browser.Name
            Detected             = [bool]$browser.ExecutablePath -or
                                   ($browser.LocalStatePath -and (Test-Path -LiteralPath $browser.LocalStatePath))
            ExecutablePath       = $browser.ExecutablePath
            PolicyPath           = $browser.PolicyPath
            AutoLaunchConfigured = $null -ne $entry
            AllowedOrigins       = $configuredOrigins
            AllowedOriginsMatch  = $originsMatch
            MachinePolicyPresent = $machinePolicy
            MachinePolicyPath    = $browser.MachinePolicyPath
            ExternalProtocolDialogShowAlwaysOpenCheckbox = $checkbox.Value
            ExternalProtocolDialogCheckboxSource         = $checkbox.Source
            LocalStatePath       = $browser.LocalStatePath
            SchemeExcluded       = $exclusion.Excluded
            SchemeExclusionState = $exclusion.State
            SchemeExclusionReason = $exclusion.Reason
            Running              = [bool](Get-Process -Name $browser.ProcessName -ErrorAction SilentlyContinue)
        }
    }

    $browsers = @($browsers)
    $detected = @($browsers | Where-Object { $_.Detected })
    # SchemeExcluded is tri-state: only $true is a refusal. $null means nobody
    # was ever asked, which does not by itself make the machine not ready.
    $blocked = @($detected | Where-Object {
            -not $_.AutoLaunchConfigured -or
            $_.SchemeExcluded -eq $true -or
            $_.AllowedOriginsMatch -eq $false
        })
    $ready = $registered -and $detected.Count -gt 0 -and -not $blocked.Count

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

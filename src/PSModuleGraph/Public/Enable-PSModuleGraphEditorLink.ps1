function Enable-PSModuleGraphEditorLink {
    <#
    .SYNOPSIS
        Grants Chrome or Edge permission to open vscode:// links without a prompt.
    .DESCRIPTION
        This and its -Revert are the only things in the module that change
        machine state. User-scope (HKCU) only, reversible, never elevates, and
        prompts by default.

        Two mechanisms, both opt-in:

        The AutoLaunchProtocolsFromOrigins policy grants the protocol from named
        origins. Entries for other software are merged, never replaced.

        A refusal remembered in the browser's Local State is cleared only when
        the browser is closed and you confirm. A declined prompt is never shown
        again, which is why the failure looks like nothing happening at all.

        Every decision is made before anything is written, so -WhatIf prints the
        registry path, the value name, the old value and the new one.

        Restart the browser fully afterwards - every window, not just the tab.
    .PARAMETER Browser
        Which browsers to configure.
    .PARAMETER Protocol
        Scheme to grant. Defaults to vscode.
    .PARAMETER AllowAnyOrigin
        Grants the protocol from ANY origin instead of the scoped defaults. Use
        only if scoped origins are proven not to work: scoped to this one
        protocol, but any site you visit could then launch the editor without a
        prompt.
    .PARAMETER Revert
        Undoes what this command added, restoring the prior policy value or
        removing it if there was none.
    .PARAMETER PolicyRoot
        Registry root holding vendor policy keys. Exists so the tests can run
        against TestRegistry: rather than the real machine; leave it alone.
    .PARAMETER LocalStateRoot
        Directory root holding each browser's User Data. Same purpose.
    .PARAMETER BackupRoot
        Registry key under which the prior policy value is recorded for -Revert.
    .EXAMPLE
        Enable-PSModuleGraphEditorLink -WhatIf

        Prints every intended change without making any.
    .EXAMPLE
        Enable-PSModuleGraphEditorLink -Browser Chrome
    .EXAMPLE
        Enable-PSModuleGraphEditorLink -Revert
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('Chrome', 'Edge', 'All')]
        [string] $Browser = 'All',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Protocol = 'vscode',

        [Parameter()]
        [switch] $AllowAnyOrigin,

        [Parameter()]
        [switch] $Revert,

        [Parameter()]
        [string] $PolicyRoot = 'HKCU:\SOFTWARE\Policies',

        [Parameter()]
        [string] $LocalStateRoot = $env:LOCALAPPDATA,

        [Parameter()]
        [string] $BackupRoot = 'HKCU:\SOFTWARE\PSModuleGraph\EditorLinkBackup'
    )

    $state = Get-EditorLinkState -Protocol $Protocol -PolicyRoot $PolicyRoot -LocalStateRoot $LocalStateRoot
    if ($state.Platform -ne 'Windows') { return $state }

    if (-not $state.ProtocolRegistered) {
        Write-Warning ("No handler is registered for '${Protocol}://' on this machine. Granting a browser " +
            'permission to launch it will not help until VS Code registers the scheme.')
    }

    # Scoped by default: file:/// covers a report opened straight from disk,
    # 127.0.0.1 one served by a local preview extension.
    $origins = if ($AllowAnyOrigin) { @('*') } else { @('file:///*', 'http://127.0.0.1:*') }

    if ($AllowAnyOrigin -and -not $Revert) {
        Write-Warning ("-AllowAnyOrigin grants '${Protocol}://' from EVERY origin: any website you visit " +
            'will be able to launch it without a prompt. It is scoped to this one protocol, but not to ' +
            'any site. Prefer the scoped default unless it has been proven not to work.')
    }

    $wanted = if ($Browser -eq 'All') { @('Chrome', 'Edge') } else { @($Browser) }
    $changed = $false

    foreach ($browserState in $state.Browsers) {
        if ($wanted -notcontains $browserState.Name) { continue }

        if (-not $browserState.Detected) {
            Write-Verbose "$($browserState.Name) is not installed; skipping."
            continue
        }

        if ($browserState.MachinePolicyPresent) {
            Write-Warning ("$($browserState.Name) has a machine-wide AutoLaunchProtocolsFromOrigins policy " +
                "at '$($browserState.MachinePolicyPath)'. A machine policy overrides the per-user one, so " +
                'changing it here would have no effect. Ask whoever administers this machine. Skipping.')
            continue
        }

        $policy = Get-AutoLaunchPolicy -PolicyPath $browserState.PolicyPath
        $backupKey = Join-Path $BackupRoot $browserState.Name
        $backup = if (Test-Path -LiteralPath $backupKey) {
            Get-ItemProperty -LiteralPath $backupKey -ErrorAction SilentlyContinue
        }
        else { $null }

        $plan = Get-AutoLaunchPlan -Policy $policy -Protocol $Protocol -AllowedOrigin $origins `
            -Revert:$Revert -Backup $backup

        if ($plan.Action -eq 'None') {
            Write-Verbose "$($browserState.Name): no change - $($plan.Reason)."
        }
        else {
            $target = "$($browserState.PolicyPath)\AutoLaunchProtocolsFromOrigins"
            $action = "$($plan.Action) - $($plan.Reason). Old: $($plan.OldValue) New: $($plan.NewValue)"

            if ($PSCmdlet.ShouldProcess($target, $action)) {
                if (-not $Revert) {
                    Save-AutoLaunchBackup -BackupRoot $BackupRoot -BrowserName $browserState.Name -Policy $policy
                }
                Write-AutoLaunchPolicy -PolicyPath $browserState.PolicyPath -Plan $plan
                if ($Revert -and (Test-Path -LiteralPath $backupKey)) {
                    Remove-Item -LiteralPath $backupKey -Recurse -Force -ErrorAction SilentlyContinue
                }
                $changed = $true
            }
        }

        if (-not $Revert -and $browserState.SchemeExcluded -eq $true) {
            $definition = Get-EditorLinkBrowser -PolicyRoot $PolicyRoot -LocalStateRoot $LocalStateRoot |
                Where-Object { $_.Name -eq $browserState.Name }
            $writable = Test-ExcludedSchemeWritable -LocalStatePath $browserState.LocalStatePath `
                -ProcessName $definition.ProcessName

            if (-not $writable.CanWrite) {
                Write-Warning ("$($browserState.Name) remembers a declined prompt for '${Protocol}://' in " +
                    "'$($browserState.LocalStatePath)', and it cannot be cleared: $($writable.Reason).")
            }
            elseif ($PSCmdlet.ShouldProcess($browserState.LocalStatePath,
                    "Set protocol_handler.excluded_schemes.$Protocol to false (a backup is written alongside)")) {
                Clear-ExcludedScheme -LocalStatePath $browserState.LocalStatePath -Protocol $Protocol | Out-Null
                $changed = $true
            }
        }
    }

    if ($changed) {
        Write-Information -MessageData 'Restart your browser completely for this to take effect - every window, not just the tab.' -InformationAction Continue
    }

    Get-EditorLinkState -Protocol $Protocol -PolicyRoot $PolicyRoot -LocalStateRoot $LocalStateRoot
}

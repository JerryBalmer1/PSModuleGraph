function Get-AutoLaunchPlan {
    <#
    .SYNOPSIS
        Works out what would change in one browser's policy, without changing it.
    .DESCRIPTION
        Pure. Decides the whole edit up front so the caller can put the old and
        new values into its ShouldProcess message - which is what makes -WhatIf
        show the actual change rather than a summary of one.

        Merge, never overwrite: entries for other protocols are carried through
        untouched. The value may already grant Teams or Zoom, and clobbering it
        would break them with no symptom pointing back here.
    .PARAMETER Policy
        The record from Get-AutoLaunchPolicy.
    .PARAMETER Protocol
        Scheme being granted or removed.
    .PARAMETER AllowedOrigin
        Origins to grant from. Ignored when -Revert.
    .PARAMETER Revert
        Plan the removal rather than the grant.
    .PARAMETER Backup
        The recorded pre-change state, when one exists.
    .OUTPUTS
        Action is Set, Remove or None.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [ValidateNotNull()] $Policy,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Protocol,
        [Parameter()] [string[]] $AllowedOrigin = @(),
        [Parameter()] [switch] $Revert,
        [Parameter()] [AllowNull()] $Backup
    )

    $old = if ($Policy.Exists) { $Policy.Raw } else { '(no value)' }

    if (-not $Policy.IsParsable) {
        return [pscustomobject]@{ Action = 'None'; OldValue = $old; NewValue = $old
            Reason = 'the existing value is not valid JSON' }
    }

    if ($Revert) {
        # A recorded backup is exact. Without one, remove only this protocol and
        # leave anything else alone - something other than this module may have
        # written the value.
        if ($Backup -and $Backup.Recorded) {
            if ($Backup.ValueExisted) {
                return [pscustomobject]@{ Action = 'Set'; OldValue = $old
                    NewValue = [string]$Backup.PriorValue; Reason = 'restoring the recorded prior value' }
            }
            return [pscustomobject]@{ Action = 'Remove'; OldValue = $old; NewValue = '(no value)'
                Reason = 'no value existed before this module added one' }
        }

        if (-not $Policy.Exists) {
            return [pscustomobject]@{ Action = 'None'; OldValue = $old; NewValue = $old
                Reason = 'nothing to revert' }
        }

        $kept = @($Policy.Entries | Where-Object { $_.protocol -ne $Protocol })
        if ($kept.Count -eq 0) {
            return [pscustomobject]@{ Action = 'Remove'; OldValue = $old; NewValue = '(no value)'
                Reason = "removing the only entry, '$Protocol'" }
        }
        return [pscustomobject]@{ Action = 'Set'; OldValue = $old
            NewValue = (ConvertTo-AutoLaunchJson -Entry $kept); Reason = "removing the '$Protocol' entry" }
    }

    $entries = @($Policy.Entries | Where-Object { $_.protocol -ne $Protocol })
    $entries += [pscustomobject]@{ protocol = $Protocol; allowed_origins = @($AllowedOrigin) }
    $new = ConvertTo-AutoLaunchJson -Entry $entries

    if ($Policy.Exists -and $Policy.Raw -eq $new) {
        return [pscustomobject]@{ Action = 'None'; OldValue = $old; NewValue = $new
            Reason = 'already configured' }
    }

    [pscustomobject]@{ Action = 'Set'; OldValue = $old; NewValue = $new
        Reason = "granting '$Protocol' from $($AllowedOrigin -join ', ')" }
}

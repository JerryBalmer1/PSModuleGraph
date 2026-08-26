function Write-AutoLaunchPolicy {
    <#
    .SYNOPSIS
        Applies a plan from Get-AutoLaunchPlan to the registry.
    .DESCRIPTION
        Mechanics only. Every decision, and the ShouldProcess gate that consents
        to it, belongs to the calling public command; this runs after that gate
        has already passed.
    .PARAMETER PolicyPath
        Registry key to write.
    .PARAMETER Plan
        The plan to apply.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $PolicyPath,
        [Parameter(Mandatory)] [ValidateNotNull()] $Plan
    )

    if ($Plan.Action -eq 'Remove') {
        if (Test-Path -LiteralPath $PolicyPath) {
            Remove-ItemProperty -LiteralPath $PolicyPath -Name 'AutoLaunchProtocolsFromOrigins' `
                -Force -ErrorAction SilentlyContinue
        }
        return
    }

    if ($Plan.Action -ne 'Set') { return }

    if (-not (Test-Path -LiteralPath $PolicyPath)) {
        New-Item -Path $PolicyPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $PolicyPath -Name 'AutoLaunchProtocolsFromOrigins' `
        -Value $Plan.NewValue -PropertyType String -Force | Out-Null
}

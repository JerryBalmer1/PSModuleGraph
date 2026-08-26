function Get-BrowserDwordPolicy {
    <#
    .SYNOPSIS
        Reads one DWORD browser policy from the user and machine keys.
    .DESCRIPTION
        A machine policy overrides a user one, so the effective value is the
        HKLM value when there is one. Both are reported: knowing that a setting
        came from the machine is what tells the user whether they can change it.

        Returns $null for Value when neither key sets it. Absent is not the same
        as Disabled - the browser's own default applies - and reporting it as a
        boolean either way would be a guess dressed as a fact.

        Never writes. HKLM is read here and nowhere else in this module.
    .PARAMETER UserPolicyPath
        HKCU policy key for the browser.
    .PARAMETER MachinePolicyPath
        HKLM policy key for the browser.
    .PARAMETER Name
        Policy value to read.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $UserPolicyPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $MachinePolicyPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Name
    )

    $readValue = {
        param([string] $Path)
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
        if (-not $item) { return $null }
        Get-HashtableValue -InputObject $item -Key $Name
    }

    $user = & $readValue $UserPolicyPath
    $machine = & $readValue $MachinePolicyPath

    $effective = if ($null -ne $machine) { $machine } elseif ($null -ne $user) { $user } else { $null }
    $source = if ($null -ne $machine) { 'Machine' } elseif ($null -ne $user) { 'User' } else { $null }

    [pscustomobject]@{
        Name         = $Name
        Value        = if ($null -eq $effective) { $null } else { [bool][int]$effective }
        Source       = $source
        UserValue    = $user
        MachineValue = $machine
    }
}
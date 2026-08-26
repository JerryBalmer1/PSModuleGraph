function Save-AutoLaunchBackup {
    <#
    .SYNOPSIS
        Records the pre-change AutoLaunchProtocolsFromOrigins value once.
    .DESCRIPTION
        Written before the first change and never overwritten, so a second
        Enable- run cannot record its own output as the thing to revert to.
        Absence of a prior value is itself recorded, so -Revert knows to remove
        the value rather than restore an empty string.
    .PARAMETER BackupRoot
        Registry key under which backups are kept.
    .PARAMETER BrowserName
        Keys the backup.
    .PARAMETER Policy
        The policy record read before the change.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $BackupRoot,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $BrowserName,
        [Parameter(Mandatory)] [ValidateNotNull()] $Policy
    )

    $key = Join-Path $BackupRoot $BrowserName
    if (Test-Path -LiteralPath $key) {
        $existing = Get-ItemProperty -LiteralPath $key -Name 'Recorded' -ErrorAction SilentlyContinue
        if ($existing) { return }
    }

    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name 'Recorded' -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name 'ValueExisted' `
        -Value ([int][bool]$Policy.Exists) -PropertyType DWord -Force | Out-Null
    New-ItemProperty -LiteralPath $key -Name 'PriorValue' `
        -Value ([string]$Policy.Raw) -PropertyType String -Force | Out-Null
}

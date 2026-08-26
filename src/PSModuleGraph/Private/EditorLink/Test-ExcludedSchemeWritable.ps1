function Test-ExcludedSchemeWritable {
    <#
    .SYNOPSIS
        Reports whether the remembered refusal can be cleared right now.
    .DESCRIPTION
        Separate from the write so the caller can refuse before prompting, and
        so the reason can be reported instead of a silent no-op.

        The running-browser check is the important one: Chrome and Edge rewrite
        Local State from memory on exit, so an edit made while one is running is
        discarded without a word. This module names the process and asks; it
        never kills it.
    .PARAMETER LocalStatePath
        Path to Local State.
    .PARAMETER ProcessName
        Browser process to look for.
    .OUTPUTS
        CanWrite plus the Reason it cannot.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string] $LocalStatePath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $ProcessName
    )

    if (-not $LocalStatePath -or -not (Test-Path -LiteralPath $LocalStatePath)) {
        return [pscustomobject]@{ CanWrite = $false; Reason = "no Local State file at '$LocalStatePath'" }
    }

    if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
        return [pscustomobject]@{ CanWrite = $false
            Reason = "'$ProcessName' is running; it rewrites Local State on exit, so close every window and run this again"
        }
    }

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        return [pscustomobject]@{ CanWrite = $false
            Reason = 'this needs PowerShell 7; on 5.1 edit the file by hand'
        }
    }

    [pscustomobject]@{ CanWrite = $true; Reason = $null }
}

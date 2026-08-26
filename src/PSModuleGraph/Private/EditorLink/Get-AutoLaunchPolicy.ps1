function Get-AutoLaunchPolicy {
    <#
    .SYNOPSIS
        Reads and parses AutoLaunchProtocolsFromOrigins from one policy key.
    .DESCRIPTION
        Returns the raw string and the parsed entries. A value that will not
        parse is reported as unparsable rather than treated as absent: silently
        replacing something unreadable is how unrelated software gets broken.
    .PARAMETER PolicyPath
        Registry key holding the value.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PolicyPath
    )

    $raw = $null
    if (Test-Path -LiteralPath $PolicyPath) {
        $item = Get-ItemProperty -LiteralPath $PolicyPath -Name 'AutoLaunchProtocolsFromOrigins' -ErrorAction SilentlyContinue
        if ($item) { $raw = $item.AutoLaunchProtocolsFromOrigins }
    }

    $entries = @()
    $parsable = $true
    if ($raw) {
        try { $entries = @($raw | ConvertFrom-Json -ErrorAction Stop) }
        catch {
            $parsable = $false
            Write-Warning "AutoLaunchProtocolsFromOrigins at '$PolicyPath' is not valid JSON; it will not be modified."
        }
    }

    [pscustomobject]@{
        PolicyPath = $PolicyPath
        Exists     = $null -ne $raw
        Raw        = $raw
        Entries    = $entries
        IsParsable = $parsable
    }
}

function ConvertTo-AutoLaunchJson {
    <#
    .SYNOPSIS
        Serialises AutoLaunchProtocolsFromOrigins entries as a JSON array.
    .DESCRIPTION
        Built by hand rather than with ConvertTo-Json on the whole collection.
        Windows PowerShell 5.1 unwraps a single-element array into a bare
        object, which the policy parser rejects, and the failure would only show
        up as the policy silently not applying.
    .PARAMETER Entry
        The entries to serialise.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        $Entry
    )

    $parts = @($Entry) | Where-Object { $null -ne $_ } | ForEach-Object {
        $_ | ConvertTo-Json -Depth 5 -Compress
    }

    '[' + ($parts -join ',') + ']'
}

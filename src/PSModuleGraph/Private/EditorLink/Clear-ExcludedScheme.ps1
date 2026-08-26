function Clear-ExcludedScheme {
    <#
    .SYNOPSIS
        Clears a remembered scheme refusal in a browser's Local State.
    .DESCRIPTION
        Mechanics only; the caller has already gated on ShouldProcess. Use
        Test-ExcludedSchemeWritable first - this assumes the browser is closed
        and the host is PowerShell 7.

        Backs the file up alongside itself before touching it. Local State
        carries the whole profile's settings, and a bad write is not something
        the user can reconstruct.
    .PARAMETER LocalStatePath
        Path to Local State.
    .PARAMETER Protocol
        Scheme to un-exclude.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $LocalStatePath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Protocol
    )

    $backup = "$LocalStatePath.psmodulegraph.bak"
    Copy-Item -LiteralPath $LocalStatePath -Destination $backup -Force
    Write-Verbose "Backed up Local State to '$backup'."

    $data = Get-Content -LiteralPath $LocalStatePath -Raw | ConvertFrom-Json -AsHashtable
    if (-not $data.ContainsKey('protocol_handler')) { $data['protocol_handler'] = @{} }
    if (-not $data['protocol_handler'].ContainsKey('excluded_schemes')) {
        $data['protocol_handler']['excluded_schemes'] = @{}
    }
    $data['protocol_handler']['excluded_schemes'][$Protocol] = $false

    # Depth 100: Local State nests deeply and the default of 2 would silently
    # flatten the rest of the profile's settings into strings.
    $data | ConvertTo-Json -Depth 100 -Compress |
        Set-Content -LiteralPath $LocalStatePath -Encoding utf8 -NoNewline

    $true
}

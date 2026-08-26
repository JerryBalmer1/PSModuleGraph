function Test-SchemeExcluded {
    <#
    .SYNOPSIS
        Reports whether a browser has remembered a refusal for a scheme.
    .DESCRIPTION
        Both Chrome and Edge persist protocol_handler.excluded_schemes in the
        profile's Local State once a prompt is declined. After that no prompt is
        ever shown again and the launch fails in complete silence, which is what
        makes this worth reading.

        Returns $null when the answer cannot be determined - an unreadable or
        unparsable file is not the same as "not excluded", and reporting it as
        false would be a guess dressed as a fact.
    .PARAMETER LocalStatePath
        Path to the browser's Local State file.
    .PARAMETER Protocol
        Scheme to look for.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $LocalStatePath,

        [Parameter()]
        [string] $Protocol = 'vscode'
    )

    if (-not (Test-Path -LiteralPath $LocalStatePath)) { return $null }

    try {
        $json = Get-Content -LiteralPath $LocalStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not read '$LocalStatePath': $($_.Exception.Message)"
        return $null
    }

    $handler = Get-HashtableValue -InputObject $json -Key 'protocol_handler'
    if (-not $handler) { return $false }
    $excluded = Get-HashtableValue -InputObject $handler -Key 'excluded_schemes'
    if (-not $excluded) { return $false }

    [bool](Get-HashtableValue -InputObject $excluded -Key $Protocol -Default $false)
}

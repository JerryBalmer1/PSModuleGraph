function Test-StaleProbe {
    <#
    .SYNOPSIS
        Temporary probe. Removed immediately after proving the stale-store test.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $true
}

function ConvertTo-SampleName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    return $Name.Trim().ToUpperInvariant()
}

function Get-SampleThing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $normalized = ConvertTo-SampleName -Name $Name
    $thing = New-SampleThing -Name $normalized
    Write-Verbose "Created $($thing.Name)"
    return $thing
}

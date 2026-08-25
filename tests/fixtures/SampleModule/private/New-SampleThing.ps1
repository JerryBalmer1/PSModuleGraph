function New-SampleThing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    return [SampleThing]::new($Name)
}

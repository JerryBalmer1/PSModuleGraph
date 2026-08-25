function Invoke-SampleWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )

    $thing = Get-SampleThing -Name $Name
    $null = Test-SampleThing -InputObject $thing
    Get-Date | Out-Null
    return $thing
}

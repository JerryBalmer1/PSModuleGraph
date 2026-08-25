function Test-SampleThing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [SampleThing] $InputObject
    )

    if ($InputObject.Status -eq [SampleStatus]::Failed) {
        throw "Sample thing '$($InputObject.Name)' is failed."
    }

    return $true
}

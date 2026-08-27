function Get-TargetResource {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Name)

    return @{ Name = $Name; Resource = 'Beta' }
}

function Compare-State {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Name)

    return (Get-TargetResource -Name $Name)
}

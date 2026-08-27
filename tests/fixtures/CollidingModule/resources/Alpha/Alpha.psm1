function Get-TargetResource {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Name)

    return @{ Name = $Name; Resource = 'Alpha' }
}

function Compare-State {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Name)

    return (Get-TargetResource -Name $Name)
}

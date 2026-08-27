function Compare-State {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Name)

    return @{ Name = $Name; Resource = 'Gamma' }
}

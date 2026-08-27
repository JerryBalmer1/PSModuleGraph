function Get-CollidingThing {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Name)

    return (Compare-State -Name $Name)
}

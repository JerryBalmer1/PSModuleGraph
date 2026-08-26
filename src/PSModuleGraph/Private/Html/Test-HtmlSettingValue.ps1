function Test-HtmlSettingValue {
    <#
    .SYNOPSIS
        Validates one configuration value against its schema entry.
    .DESCRIPTION
        One validator per type, dispatched from the entry's Type. See
        docs/html-architecture.md.
    .PARAMETER Value
        The value as read from the data file.
    .PARAMETER Entry
        The schema entry: Type, and whichever of Min, Max and Values apply.
    .OUTPUTS
        A record with IsValid, Value (coerced) and Reason.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Entry
    )

    function New-Result {
        param([bool] $Ok, $Coerced, [string] $Why)
        [pscustomobject]@{ IsValid = $Ok; Value = $Coerced; Reason = $Why }
    }

    $type = Get-HashtableValue -InputObject $Entry -Key 'Type' -Default 'Number'
    $min = Get-HashtableValue -InputObject $Entry -Key 'Min'
    $max = Get-HashtableValue -InputObject $Entry -Key 'Max'

    switch ($type) {

        { $_ -in 'Number', 'Integer' } {
            $number = $Value -as [double]
            if ($null -eq $number) {
                return New-Result $false $null "'$Value' is not a number"
            }
            if ($type -eq 'Integer' -and [Math]::Floor($number) -ne $number) {
                return New-Result $false $null "$number is not a whole number"
            }
            if ($null -ne $min -and $number -lt $min) {
                return New-Result $false $null "$number is below the minimum of $min"
            }
            if ($null -ne $max -and $number -gt $max) {
                return New-Result $false $null "$number is above the maximum of $max"
            }
            return New-Result $true $(if ($type -eq 'Integer') { [int]$number } else { $number }) ''
        }

        'Boolean' {
            if ($Value -is [bool]) { return New-Result $true $Value '' }
            return New-Result $false $null "'$Value' is not `$true or `$false"
        }

        'String' {
            if ($Value -is [string]) { return New-Result $true $Value '' }
            return New-Result $false $null "'$Value' is not a string"
        }

        'Color' {
            # Hex only. A named colour or a CSS function would have to be
            # validated against a list this file has no business carrying.
            if ($Value -is [string] -and $Value -match '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$') {
                return New-Result $true $Value ''
            }
            return New-Result $false $null "'$Value' is not a hex colour such as #4da3ff"
        }

        'ColorList' {
            # A ramp is one decision, not five, so it is one entry. Adding a
            # TYPE is a schema extension and needs a validator here; adding a
            # SETTING must not, and still does not. The distinction matters:
            # the rule in docs/html-architecture.md is that a new value is a
            # data change, and every type in this switch was added the same way.
            #
            # MinCount rather than an exact length: a two-stop ramp and a
            # nine-stop ramp are both legitimate, and pinning the count would
            # make the number of colours a code change.
            $minCount = Get-HashtableValue -InputObject $Entry -Key 'MinCount' -Default 2
            $items = @($Value)
            if ($items.Count -lt $minCount) {
                return New-Result $false $null "expected at least $minCount colours, got $($items.Count)"
            }
            foreach ($item in $items) {
                if (-not ($item -is [string] -and $item -match '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$')) {
                    return New-Result $false $null "'$item' is not a hex colour such as #4da3ff"
                }
            }
            return New-Result $true ([string[]]$items) ''
        }

        'Enum' {
            $allowed = @(Get-HashtableValue -InputObject $Entry -Key 'Values' -Default @())
            if ($allowed -contains $Value) { return New-Result $true $Value '' }
            return New-Result $false $null "'$Value' is not one of: $($allowed -join ', ')"
        }

        default {
            return New-Result $false $null "schema declares unknown type '$type'"
        }
    }
}

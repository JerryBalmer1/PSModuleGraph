function Test-KnowledgeDocument {
    <#
    .SYNOPSIS
        Validates a parsed knowledge document against its JSON Schema.
    .DESCRIPTION
        The store is language-neutral, so its contract is JSON Schema rather
        than anything PowerShell-shaped. This converts the parsed front matter
        back to JSON and hands it to Test-Json.

        Test-Json gained -SchemaFile in PowerShell 6. On Windows PowerShell 5.1
        there is no schema validation in the box, and this reports IsValid as
        $null with the reason - not $true. "Could not check" and "checked and
        passed" are different facts, and returning the second for the first is
        how an invalid store gets committed.
    .PARAMETER InputObject
        Parsed document.
    .PARAMETER SchemaPath
        JSON Schema file to validate against.
    .OUTPUTS
        IsValid as $true, $false, or $null when validation was unavailable.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SchemaPath
    )

    if (-not (Test-Path -LiteralPath $SchemaPath)) {
        return [pscustomobject]@{ IsValid = $null; Reason = "no schema at '$SchemaPath'" }
    }

    if (-not (Get-Command Test-Json -ErrorAction SilentlyContinue).Parameters.ContainsKey('SchemaFile')) {
        return [pscustomobject]@{
            IsValid = $null
            Reason  = 'Test-Json has no -SchemaFile on this host; schema validation needs PowerShell 6 or later'
        }
    }

    try {
        $json = $InputObject | ConvertTo-Json -Depth 12 -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{ IsValid = $false; Reason = "could not serialise: $($_.Exception.Message)" }
    }

    try {
        $json | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop | Out-Null
        [pscustomobject]@{ IsValid = $true; Reason = $null }
    }
    catch {
        [pscustomobject]@{ IsValid = $false; Reason = $_.Exception.Message }
    }
}

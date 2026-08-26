function Get-KnowledgeStoreRoot {
    <#
    .SYNOPSIS
        Finds the store root by walking up until a SCHEMA directory appears.
    .DESCRIPTION
        Subjects nest as deeply as their URN does - knowledge/subjects/psmodule/
        PSModuleGraph/function/Get-PSModuleClass.md - so the root cannot be a
        fixed number of levels above the file. Walking up until SCHEMA is found
        means a store that has been lifted somewhere else still validates
        without being told where it went, which is the point of the directory
        boundary.
    .PARAMETER Path
        Any file inside the store.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $current = Split-Path -Path $Path -Parent
    while ($current) {
        if (Test-Path -LiteralPath (Join-Path $current 'SCHEMA')) { return $current }
        $parent = Split-Path -Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }
    $null
}

function Read-KnowledgeFile {
    <#
    .SYNOPSIS
        Reads one knowledge file: front matter parsed and validated, body intact.
    .DESCRIPTION
        Shared by every Import-Knowledge* reader so the parse, the schema lookup
        and the failure message are written once. See knowledge/NAMING.md.

        Numeric coercion is the caller's job, not the parser's. The front-matter
        parser keeps every numeric-looking value a string on purpose - a facet's
        'version: 1.0' silently becoming the number 1 would break a 'since'
        comparison - so a reader whose schema declares a number names that field
        here and it is converted just before validation.
    .PARAMETER Path
        The file to read.
    .PARAMETER SchemaName
        File name under the store's SCHEMA directory.
    .PARAMETER NumericField
        Front matter keys the schema declares as numbers.
    .PARAMETER SkipValidation
        Parse without validating. For diagnosing a file that will not validate.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Path,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $SchemaName,
        [Parameter()] [string[]] $NumericField = @(),
        [Parameter()] [switch] $SkipValidation
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Knowledge file not found: '$Path'."
    }

    $split = Split-FrontMatter -Text (Get-Content -LiteralPath $Path -Raw)
    if ($null -eq $split) {
        throw "'$Path' has no YAML front matter. Every file in the knowledge store carries it; see knowledge/NAMING.md."
    }

    $data = ConvertFrom-KnowledgeFrontMatter -Text $split.FrontMatter

    foreach ($field in $NumericField) {
        if (-not $data.Contains($field)) { continue }
        $parsed = 0.0
        if ([double]::TryParse([string]$data[$field], [System.Globalization.NumberStyles]::Float,
                [cultureinfo]::InvariantCulture, [ref]$parsed)) {
            $data[$field] = $parsed
        }
        # Left as the original string when it will not parse, so the schema
        # reports "should be number" naming the field rather than this throwing
        # a less useful error one layer earlier.
    }

    $valid = $null
    $reason = $null
    if (-not $SkipValidation) {
        $root = Get-KnowledgeStoreRoot -Path $Path
        if (-not $root) {
            throw "No SCHEMA directory above '$Path'. Is this file inside a knowledge store?"
        }
        $schemaPath = Join-Path (Join-Path $root 'SCHEMA') $SchemaName
        $result = Test-KnowledgeDocument -InputObject $data -SchemaPath $schemaPath
        $valid = $result.IsValid
        $reason = $result.Reason
        if ($false -eq $valid) {
            throw "'$Path' does not satisfy '$schemaPath': $reason"
        }
    }

    [pscustomobject]@{
        Data    = $data
        Body    = $split.Body
        Path    = (Resolve-Path -LiteralPath $Path).ProviderPath
        IsValid = $valid
        Reason  = $reason
    }
}

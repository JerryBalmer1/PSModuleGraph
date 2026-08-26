function Import-KnowledgeFacet {
    <#
    .SYNOPSIS
        Reads one facet file from the knowledge store and validates it.
    .DESCRIPTION
        See knowledge/NAMING.md and the "Kaizen: the knowledge substrate"
        section of CLAUDE.md.

        A facet file is Markdown with YAML front matter: front matter for the
        machine, prose for the human. This reads the front matter, validates it
        against knowledge/SCHEMA/facet.schema.json, and returns it as an object.
        The prose body is returned unparsed, because it is for a person.

        PowerShell is the first reader of this store. It is not its owner, and
        nothing here writes: v0.0.1 reads only. The store lives at the
        repository root rather than inside the module precisely so it can be
        lifted out and read by something else, which is why -Path is mandatory
        and there is no resolution back into the module's own asset tree.

        The YAML parsed here is a deliberately small subset - scalars, inline
        lists, and one level of block list-of-mappings - which is all a facet
        file is allowed to contain. It is not a general YAML parser and must not
        grow into one. The schema is what makes that safe: a parse that
        misreads the file produces a shape the schema rejects, so the failure is
        loud rather than silent.
    .PARAMETER Path
        The facet file. Mandatory: the store is not addressable from inside the
        built module and guessing at a location would defeat the point.
    .PARAMETER SchemaPath
        The JSON Schema to validate against. Defaults to
        <store>/SCHEMA/facet.schema.json, derived from the facet's own location.
    .PARAMETER SkipValidation
        Parse without validating. For diagnosing a file that will not validate;
        never for routine reads.
    .EXAMPLE
        Import-KnowledgeFacet -Path ./knowledge/facets/structure.md
    .OUTPUTS
        PSModuleGraph.KnowledgeFacet
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName')]
        [string] $Path,

        [Parameter()]
        [string] $SchemaPath,

        [Parameter()]
        [switch] $SkipValidation
    )

    process {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Facet file not found: '$Path'."
        }

        $text = Get-Content -LiteralPath $Path -Raw
        $split = Split-FrontMatter -Text $text
        if ($null -eq $split) {
            throw "'$Path' has no YAML front matter. Every file in the knowledge store carries it; see knowledge/NAMING.md."
        }

        $data = ConvertFrom-FacetFrontMatter -Text $split.FrontMatter

        $valid = $null
        $reason = $null
        if (-not $SkipValidation) {
            if (-not $SchemaPath) {
                # <store>/facets/x.md and <store>/meta/x.md both resolve to
                # <store>/SCHEMA. Derived rather than configured so a lifted copy
                # of the store validates without being told where it went.
                $storeRoot = Split-Path -Path (Split-Path -Path $Path -Parent) -Parent
                $SchemaPath = Join-Path (Join-Path $storeRoot 'SCHEMA') 'facet.schema.json'
            }

            $result = Test-KnowledgeDocument -InputObject $data -SchemaPath $SchemaPath
            $valid = $result.IsValid
            $reason = $result.Reason
            if ($false -eq $valid) {
                throw "'$Path' does not satisfy '$SchemaPath': $reason"
            }
        }

        [pscustomobject]@{
            PSTypeName = 'PSModuleGraph.KnowledgeFacet'
            Id         = Get-HashtableValue -InputObject $data -Key 'id'
            Version    = Get-HashtableValue -InputObject $data -Key 'version'
            Kind       = Get-HashtableValue -InputObject $data -Key 'kind'
            Separator  = Get-HashtableValue -InputObject $data -Key 'separator'
            Paths      = @(Get-HashtableValue -InputObject $data -Key 'paths' -Default @())
            Supersedes = @(Get-HashtableValue -InputObject $data -Key 'supersedes' -Default @())
            IsMeta     = [bool](Get-HashtableValue -InputObject $data -Key 'meta' -Default $false)
            Body       = $split.Body
            Path       = (Resolve-Path -LiteralPath $Path).ProviderPath
            IsValid    = $valid
            Reason     = $reason
        }
    }
}

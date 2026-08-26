function Import-KnowledgeAssignment {
    <#
    .SYNOPSIS
        Reads one assignment file, or every assignment under a directory.
    .DESCRIPTION
        See knowledge/NAMING.md. subject x facet -> path, with evidence, one per
        file and flat.

        Evidence was a nested list of objects in v0.0.1 and is now three
        scalars. The consequence is deliberate: a subject with two independent
        pieces of evidence for the same path is two assignments rather than one
        assignment with two evidence items - which is the better shape anyway,
        because each piece of evidence then carries its own confidence, and a
        shared list could not express that.

        Confidence is the one numeric field, and it is coerced from the string
        the front-matter parser produces before the schema sees it. The parser
        keeps numerals as strings on purpose; see Read-KnowledgeFile.
    .PARAMETER Path
        An assignment file, or a directory to search recursively.
    .PARAMETER SkipValidation
        Parse without validating. For diagnosing a file that will not validate.
    .EXAMPLE
        Import-KnowledgeAssignment -Path ./knowledge/assignments |
            Where-Object { $_.Confidence -lt 1 }

        The assignments the store is least sure of, which is the set worth
        reviewing first.
    .OUTPUTS
        PSModuleGraph.KnowledgeAssignment
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName')]
        [string] $Path,

        [Parameter()]
        [switch] $SkipValidation
    )

    process {
        $files = if (Test-Path -LiteralPath $Path -PathType Container) {
            @(Get-ChildItem -LiteralPath $Path -Filter *.md -File -Recurse | Sort-Object FullName)
        }
        else {
            @([pscustomobject]@{ FullName = $Path })
        }

        foreach ($file in $files) {
            $read = Read-KnowledgeFile -Path $file.FullName -SchemaName 'assignment.schema.json' `
                -NumericField 'confidence' -SkipValidation:$SkipValidation
            $data = $read.Data

            [pscustomobject]@{
                PSTypeName       = 'PSModuleGraph.KnowledgeAssignment'
                Subject          = Get-HashtableValue -InputObject $data -Key 'subject'
                Facet            = Get-HashtableValue -InputObject $data -Key 'facet'
                FacetPath        = Get-HashtableValue -InputObject $data -Key 'path'
                Confidence       = Get-HashtableValue -InputObject $data -Key 'confidence'
                EvidenceKind     = Get-HashtableValue -InputObject $data -Key 'evidence_kind'
                EvidenceValue    = Get-HashtableValue -InputObject $data -Key 'evidence_value'
                EvidenceSource   = Get-HashtableValue -InputObject $data -Key 'evidence_source'
                ProvenanceBy     = Get-HashtableValue -InputObject $data -Key 'provenance_by'
                ProvenancePrompt = Get-HashtableValue -InputObject $data -Key 'provenance_prompt'
                ProvenanceAt     = Get-HashtableValue -InputObject $data -Key 'provenance_at'
                Body             = $read.Body
                Path             = $read.Path
                IsValid          = $read.IsValid
                Reason           = $read.Reason
            }
        }
    }
}

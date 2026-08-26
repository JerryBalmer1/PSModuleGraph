function Import-KnowledgeSubject {
    <#
    .SYNOPSIS
        Reads one subject file, or every subject under a directory.
    .DESCRIPTION
        See knowledge/NAMING.md. A subject is one file with flat front matter -
        every value a scalar or a list of scalars, nothing nested. That is what
        makes the language-neutrality claim testable rather than asserted: a
        reader in another language needs about thirty lines, and this reader
        proves the store can be read back by the same code base that wrote it.

        v0.0.1 held all subjects in one collection document with a list of
        mappings, which this reader could not parse. Writable and readable are
        different properties and only the first had been demonstrated.
    .PARAMETER Path
        A subject file, or a directory to search recursively.
    .PARAMETER SkipValidation
        Parse without validating. For diagnosing a file that will not validate.
    .EXAMPLE
        Import-KnowledgeSubject -Path ./knowledge/subjects
    .OUTPUTS
        PSModuleGraph.KnowledgeSubject
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
            $read = Read-KnowledgeFile -Path $file.FullName -SchemaName 'subject.schema.json' `
                -SkipValidation:$SkipValidation
            $data = $read.Data

            [pscustomobject]@{
                PSTypeName  = 'PSModuleGraph.KnowledgeSubject'
                Id          = Get-HashtableValue -InputObject $data -Key 'id'
                Namespace   = Get-HashtableValue -InputObject $data -Key 'namespace'
                Name        = Get-HashtableValue -InputObject $data -Key 'name'
                Parent      = Get-HashtableValue -InputObject $data -Key 'parent'
                Source      = Get-HashtableValue -InputObject $data -Key 'source'
                Aliases     = @(Get-HashtableValue -InputObject $data -Key 'aliases' -Default @())
                GeneratedBy = Get-HashtableValue -InputObject $data -Key 'generated_by'
                Prompt      = Get-HashtableValue -InputObject $data -Key 'prompt'
                Body        = $read.Body
                Path        = $read.Path
                IsValid     = $read.IsValid
                Reason      = $read.Reason
            }
        }
    }
}

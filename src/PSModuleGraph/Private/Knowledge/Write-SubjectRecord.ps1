function Write-SubjectRecord {
    <#
    .SYNOPSIS
        Writes one subject record.
    .DESCRIPTION
        Optional keys stay ABSENT rather than null. A null 'parent' would be a
        claim that the subject has none, which is true for a module and a lie
        for anything else; absence says "not recorded" and the schema is what
        decides whether that is allowed.
    .PARAMETER Root
        Store root.
    .PARAMETER SchemaPath
        subject.schema.json.
    .PARAMETER Id
        Subject URN.
    .PARAMETER Name
        Human-readable label.
    .PARAMETER Parent
        Containing subject, or empty.
    .PARAMETER Source
        Repository-relative path, or empty.
    .PARAMETER Aliases
        Former identifiers that still resolve. A rename never deletes - see
        knowledge/NAMING.md. An alias equal to the id itself is dropped: a
        record claiming to be its own former name says nothing and would make
        every resolution report two hits for one file.
    .PARAMETER GeneratedAt
        Stamp.
    .PARAMETER Prompt
        Ledger entry.
    .PARAMETER GeneratedBy
        What produced the record, so a reader can tell one generator's output
        from another's. Defaults to the module generator because that wrote
        every record before there was a second producer.
    .PARAMETER Body
        Prose body.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Root,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $SchemaPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Id,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Name,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Parent,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Source,
        [Parameter()] [AllowEmptyCollection()] [string[]] $Aliases = @(),
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $GeneratedAt,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Prompt,
        [Parameter()] [ValidateNotNullOrEmpty()] [string] $GeneratedBy = 'PSModuleGraph Update-KnowledgeStore',
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body
    )

    $document = [ordered]@{
        id        = $Id
        namespace = ($Id -split ':', 2)[0]
        name      = $Name
    }
    if ($Parent) { $document['parent'] = $Parent }
    if ($Source) { $document['source'] = $Source }

    # Sorted and de-duplicated so a regeneration is byte-identical: the order
    # aliases arrive in is an accident of iteration, and staleness is detected
    # by comparing bytes.
    #
    # ORDINAL on both operations. `-ne` and `Sort-Object -Unique` both fold
    # case, and knowledge/NAMING.md says a URN's path segment preserves it, so
    # this line dropped an alias that differed from the current id only in case
    # and then merged two former ids that differed only in case. The gate that
    # reads these was made ordinal at v0.16.0; this is the writer that produces
    # them. knowledge/patterns/0023.
    $distinct = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($alias in $Aliases) {
        if (-not $alias) { continue }
        if ([string]::Equals($alias, $Id, [System.StringComparison]::Ordinal)) { continue }
        [void]$distinct.Add($alias)
    }
    # Sorted ordinally too. Sort-Object is culture-aware even with
    # -CaseSensitive, and these bytes are compared for equality across
    # machines, so the ordering may not depend on a locale. Every subject
    # carries exactly one alias today, which is why this has never shown.
    $former = [string[]]$distinct
    [System.Array]::Sort($former, [System.StringComparer]::Ordinal)
    if ($former.Count) { $document['aliases'] = $former }

    $document['generated_by'] = $GeneratedBy
    $document['generated_at'] = $GeneratedAt
    $document['prompt'] = $Prompt

    $path = ConvertTo-KnowledgeFilePath -Id $Id -Root $Root -Area 'subjects'
    Write-KnowledgeRecord -Path $path -Document $document -Body $Body -SchemaPath $SchemaPath
}

function Write-AssignmentRecord {
    <#
    .SYNOPSIS
        Writes one assignment record.
    .DESCRIPTION
        Flat by contract: evidence is three scalars, not a list of objects. A
        subject with two independent pieces of evidence for one path is two
        assignments, which is the better shape anyway - each then carries its
        own confidence.
    .PARAMETER Root
        Store root.
    .PARAMETER SchemaPath
        assignment.schema.json.
    .PARAMETER Subject
        Subject URN.
    .PARAMETER Facet
        Facet id.
    .PARAMETER FacetPath
        Path on that facet.
    .PARAMETER Confidence
        0 to 1. Never defaulted; the caller decides and says why in the body.
    .PARAMETER EvidenceKind
        What sort of observation this is.
    .PARAMETER EvidenceValue
        What was observed.
    .PARAMETER EvidenceSource
        Which reader observed it.
    .PARAMETER GeneratedAt
        Stamp.
    .PARAMETER Prompt
        Ledger entry.
    .PARAMETER Body
        Prose body.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Root,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $SchemaPath,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Subject,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Facet,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $FacetPath,
        [Parameter(Mandatory)] [ValidateRange(0, 1)] [double] $Confidence,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $EvidenceKind,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $EvidenceValue,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $EvidenceSource,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $GeneratedAt,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Prompt,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body
    )

    $document = [ordered]@{
        subject           = $Subject
        facet             = $Facet
        path              = $FacetPath
        confidence        = $Confidence
        evidence_kind     = $EvidenceKind
        evidence_value    = $EvidenceValue
        evidence_source   = $EvidenceSource
        provenance_by     = 'agent'
        provenance_prompt = $Prompt
        provenance_at     = $GeneratedAt
    }

    $path = ConvertTo-KnowledgeFilePath -Id $Subject -Root $Root -Area 'assignments' `
        -Facet $Facet -FacetPath $FacetPath
    Write-KnowledgeRecord -Path $path -Document $document -Body $Body -SchemaPath $SchemaPath
}

function Update-FacetHealthRecord {
    <#
    .SYNOPSIS
        Regrades every facet from the whole store.
    .DESCRIPTION
        The recursion. Each facet becomes the subject 'facet:<id>' and carries
        facet-health assignments on all three axes, computed by
        Get-FacetHealthAssessment rather than declared.

        Run after any module's records change, because coverage is a fact about
        the store rather than about one module in it.
    .PARAMETER Root
        Store root.
    .PARAMETER GeneratedAt
        Stamp.
    .PARAMETER Prompt
        Ledger entry.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Root,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $GeneratedAt,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Prompt
    )

    $schemaDir = Join-Path $Root 'SCHEMA'
    $subjectSchema = Join-Path $schemaDir 'subject.schema.json'
    $assignmentSchema = Join-Path $schemaDir 'assignment.schema.json'

    $facetFiles = @(Get-ChildItem -Path (Join-Path $Root 'facets') -Filter *.md -File -ErrorAction SilentlyContinue) +
        @(Get-ChildItem -Path (Join-Path $Root 'meta') -Filter *.md -File -ErrorAction SilentlyContinue)
    $facets = @($facetFiles | ForEach-Object { Import-KnowledgeFacet -Path $_.FullName })
    if (-not $facets.Count) { return 0 }

    # The store as it now stands, INCLUDING any facet-health assignments from a
    # previous run. Those are about facets, so they widen the eligible
    # population for facet-health itself - which is the recursion behaving.
    $subjectRoot = Join-Path $Root 'subjects'
    $assignmentRoot = Join-Path $Root 'assignments'
    $subjects = @(if (Test-Path -LiteralPath $subjectRoot) { Import-KnowledgeSubject -Path $subjectRoot })
    $assignments = @(if (Test-Path -LiteralPath $assignmentRoot) { Import-KnowledgeAssignment -Path $assignmentRoot })

    $graded = 0
    foreach ($facet in $facets) {
        $id = "facet:$($facet.Id)"
        $stale = Join-Path (Join-Path $Root 'assignments') "facet/$($facet.Id)/facet-health"
        if (Test-Path -LiteralPath $stale) { [System.IO.Directory]::Delete($stale, $true) }
        Write-SubjectRecord -Root $Root -SchemaPath $subjectSchema -Id $id -Name $facet.Id `
            -Parent '' -Source (ConvertTo-SubjectSourcePath -Path $facet.Path -Base $Root) `
            -GeneratedAt $GeneratedAt -Prompt $Prompt -Body @"
# facet:$($facet.Id)

A facet, as a subject. This is what lets one facet classify another: ``facet:`` is
an ordinary namespace and a facet is an ordinary thing to have an opinion about.
"@ | Out-Null
    }

    # Re-read so the facet subjects just written are part of the population the
    # grades are computed over. Grading facets against a store that does not yet
    # contain them would report coverage:none for every meta-facet forever.
    $subjects = @(Import-KnowledgeSubject -Path $subjectRoot)

    $assessments = Get-FacetHealthAssessment -Subject $subjects -Assignment $assignments `
        -FacetId @($facets | ForEach-Object { $_.Id })

    foreach ($assessment in $assessments) {
        $subject = "facet:$($assessment.FacetId)"
        Write-AssignmentRecord -Root $Root -SchemaPath $assignmentSchema -Subject $subject `
            -Facet 'facet-health' -FacetPath $assessment.Path -Confidence $assessment.Confidence `
            -EvidenceKind $assessment.Kind -EvidenceValue $assessment.Value `
            -EvidenceSource 'psmodulegraph-facet-health' -GeneratedAt $GeneratedAt -Prompt $Prompt -Body @"
# facet-health: $($assessment.Axis)

Computed from the store, not declared. Declaring it would be the
``facet-health:evidence:asserted`` failure this facet exists to detect.

Confidence $($assessment.Confidence) reflects how mechanical the computation is.
Coverage is counted, depth is measured, and evidence quality is a judgement
encoded as a rule - the rule cannot read an ``evidence_value`` and know whether it
supports the assignment or merely restates it, so it looks for the shapes that
usually mean each. Treat the evidence axis as a prompt to look rather than a
finding.
"@ | Out-Null
        $graded++
    }

    $graded
}

function Update-KnowledgePatternSubject {
    <#
    .SYNOPSIS
        Generates the subject record for every pattern in the pattern log.
    .DESCRIPTION
        THE SECOND NAMESPACE. Until v0.17.0 every subject in this store was
        `psmodule:` or `facet:`, both written by the module generator, and the
        question of whether anything else could be a subject had come back
        unanswered three times - `0004-t1` for patterns, `0007-t2` for
        measurements, and `0008` for claims.

        Patterns are the one of the three that qualifies, and the criterion is
        in knowledge/NAMING.md under "What may have a URN": an identity must be
        a pure function of the thing's own properties, never of its position in
        a document. A pattern's id is its iteration plus its authored slug -
        `0004-could-not-check-is-not-passed` - which is intrinsic and survives
        every regeneration. A claim's only key is its ordinal in a section of
        prose, which does not.

        The corroboration, and the reason this is not merely a defensible
        choice: `corpus/docker/init/01-schema.sql` reached the identical
        identifier without being told. `pattern.pattern_id` is a TEXT PRIMARY
        KEY holding that same string where every other body in that schema took
        a BIGSERIAL. Two independent derivations of one identifier is the
        strongest evidence available that the identity is in the thing.

        THE SOURCE IS THE PATTERN FILE AND THIS RECORD IS DERIVED. The prose
        lives in knowledge/patterns/; the subject carries a pointer and the
        front matter's facts, and is removed and rewritten on every run like
        every other generated subject. Nothing here is hand-edited.

        NO ASSIGNMENTS ARE WRITTEN, AND THAT IS DELIBERATE. See
        docs/constraints.md, "Patterns are subjects and facet-health does not
        grade them". A facet's eligible population is inferred from the
        namespaces it has actually assigned into, so a namespace with no
        assignments is invisible to grading - which is the mechanism that makes
        the exclusion real today, and exactly why it is written down rather
        than left to be noticed.
    .PARAMETER Path
        The pattern log. Defaults to ./knowledge/patterns.
    .PARAMETER StoreRoot
        The knowledge store. Defaults to ./knowledge.
    .PARAMETER GeneratedAt
        Stamp. Fixed by the build so a regeneration is byte-identical and
        staleness is detected by comparing trees.
    .PARAMETER Prompt
        Ledger entry that produced these records.
    .EXAMPLE
        Update-KnowledgePatternSubject -GeneratedAt 2026-08-26

        Rewrites subjects/pattern/ from knowledge/patterns/.
    .OUTPUTS
        A summary of what was written.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = './knowledge/patterns',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $StoreRoot = './knowledge',

        [Parameter()]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $GeneratedAt = (Get-Date -Format 'yyyy-MM-dd'),

        [Parameter()]
        [ValidatePattern('^ledger/\d{4}$')]
        [string] $Prompt = 'ledger/0024'
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No pattern log at '$Path'."
    }

    $root = (New-KnowledgeStorePath -StoreRoot $StoreRoot).Root
    $subjectSchema = Join-Path (Join-Path $root 'SCHEMA') 'subject.schema.json'

    # Replaced, not merged. A pattern file that has been removed must lose its
    # subject, and merging would leave a record behind as a fact about
    # something that is no longer in the log.
    $owned = Join-Path (Join-Path $root 'subjects') 'pattern'
    if ((Test-Path -LiteralPath $owned) -and
        $PSCmdlet.ShouldProcess($owned, 'Remove pattern subjects before rewriting them')) {
        Remove-Item -LiteralPath $owned -Recurse -Force
    }

    $written = 0
    $files = @(Get-ChildItem -LiteralPath $Path -Filter '*.md' -File | Sort-Object Name)

    foreach ($file in $files) {
        $patternId = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)

        $split = Split-FrontMatter -Text (Get-Content -LiteralPath $file.FullName -Raw)
        if (-not $split) { throw "Pattern '$($file.Name)' has no front matter." }
        $matter = ConvertFrom-KnowledgeFrontMatter -Text $split.FrontMatter

        # The title is the first heading of the body, which is where a pattern
        # states itself. Falling back to the id keeps a nameless record
        # readable rather than refusing to write one.
        $name = $patternId
        $heading = [regex]::Match($split.Body, '(?m)^#\s+(.+?)\s*$')
        if ($heading.Success) { $name = $heading.Groups[1].Value }

        $scales = @()
        if ($matter.Contains('scales')) { $scales = @($matter['scales']) }
        $confidence = if ($matter.Contains('confidence')) { $matter['confidence'] } else { '' }
        $ledgerId = if ($matter.Contains('ledger')) { [string]$matter['ledger'] } else { '' }

        # Repository-relative. An absolute path leaks a username into a file
        # meant to travel - knowledge/NAMING.md.
        $source = "patterns/$($file.Name)"

        $scaleList = if ($scales.Count) { ($scales | ForEach-Object { "``$_``" }) -join ', ' } else { 'none recorded' }
        $body = @"
# $name

A pattern, as a subject. The prose is in ``$source`` and is not duplicated here:
this record exists so the pattern can be *addressed* - by an assignment, by a
ledger entry, or by a reader in another language following a URN out of a
document written months earlier.

Observed at $($scales.Count) scales: $scaleList. Recorded confidence
$confidence, from ``ledger/$ledgerId``.

Carries no assignments. See ``docs/constraints.md``, "Patterns are subjects and
facet-health does not grade them".
"@

        $written += Write-SubjectRecord -Root $root -SchemaPath $subjectSchema `
            -Id "pattern:$patternId" -Name $name -Parent '' -Source $source `
            -GeneratedAt $GeneratedAt -Prompt $Prompt `
            -GeneratedBy 'PSModuleGraph Update-KnowledgePatternSubject' -Body $body
    }

    [pscustomobject]@{
        PSTypeName     = 'PSModuleGraph.KnowledgePatternUpdate'
        StoreRoot      = $root
        PatternsRead   = $files.Count
        RecordsWritten = $written
        GeneratedAt    = $GeneratedAt
    }
}

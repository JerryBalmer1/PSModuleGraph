function Get-FacetHealthAssessment {
    <#
    .SYNOPSIS
        Grades every facet in a store, from the store.
    .DESCRIPTION
        The recursion, exercised rather than described. A facet is a subject -
        'facet:structure' - so facet-health assigns paths to facets the way any
        facet assigns paths to anything.

        Computed, never declared. Declaring these would be exactly the
        facet-health:evidence:asserted failure the facet exists to detect, and
        writing that assessment in the same breath as defining the facet is the
        reason v0.0.1 shipped it with no assignments at all.

        Three axes, three confidences, because they are three different kinds of
        claim:

        COVERAGE is counted. The only judgement is which subjects were eligible,
        and that is inferred from the namespaces a facet has actually assigned
        into rather than declared anywhere - so it is high confidence, not
        certainty. A facet that has assigned nothing has no observed namespace,
        which correctly yields coverage:none.

        DEPTH is measured. Path segment counts either agree or they do not.
        The judgement is that disagreement means the hierarchy is wrong, which
        is usually but not always true.

        EVIDENCE is a judgement encoded as a rule, and it carries the lowest
        confidence of the three by some distance. The rule cannot read an
        evidence_value and know whether it supports the assignment or merely
        restates it; it can only look for the shapes that usually mean each.
        Anyone reading these numbers should treat the evidence axis as a prompt
        to look, not as a finding.
    .PARAMETER Subject
        Every subject in the store.
    .PARAMETER Assignment
        Every assignment in the store.
    .PARAMETER FacetId
        The facets to grade. Each becomes the subject 'facet:<id>'.
    .OUTPUTS
        One record per facet per axis: FacetId, Axis, Path, Confidence, Evidence.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Subject,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Assignment,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string[]] $FacetId
    )

    foreach ($id in $FacetId) {
        $mine = @($Assignment | Where-Object { $_.Facet -eq $id })

        # -- coverage ------------------------------------------------------
        # Eligible population = subjects in the namespaces this facet has been
        # observed to assign into. A facet that grades facets is not failing to
        # cover PowerShell functions; it was never pointed at them.
        $namespaces = @{}
        foreach ($record in $mine) {
            $namespaces[($record.Subject -split ':', 2)[0]] = $true
        }
        $eligible = @($Subject | Where-Object { $namespaces.ContainsKey($_.Namespace) })
        $assigned = @{}
        foreach ($record in $mine) { $assigned[$record.Subject] = $true }
        $covered = @($eligible | Where-Object { $assigned.ContainsKey($_.Id) })

        $coverage = if ($mine.Count -eq 0) { 'none' }
        elseif ($eligible.Count -gt 0 -and $covered.Count -eq $eligible.Count) { 'complete' }
        else { 'partial' }

        [pscustomobject]@{
            FacetId    = $id
            Axis       = 'coverage'
            Path       = "facet-health:coverage:$coverage"
            Confidence = 0.95
            Kind       = 'computed-count'
            Value      = "$($covered.Count) of $($eligible.Count) eligible subject(s) assigned"
        }

        # -- evidence ------------------------------------------------------
        # Shape-matching, not comprehension. 'absence' and 'inferred' name their
        # own weakness; an evidence_value that merely repeats the path is the
        # restatement case; anything else is taken as a direct observation.
        $states = @{}
        foreach ($record in $mine) {
            $kind = [string]$record.EvidenceKind
            $value = [string]$record.EvidenceValue
            $state = if ($kind -match 'absence|inferr|guess|assum') { 'inferred' }
            elseif (-not $value -or $value -eq $record.FacetPath -or $value -eq $record.Facet) { 'asserted' }
            else { 'observed' }
            $states[$state] = $true
        }

        # The weakest state present wins. A facet is only as trustworthy as its
        # worst evidence, and averaging would hide the assignments worth reading.
        $evidence = if ($mine.Count -eq 0) { 'asserted' }
        elseif ($states.ContainsKey('asserted')) { 'asserted' }
        elseif ($states.ContainsKey('inferred')) { 'inferred' }
        else { 'observed' }

        [pscustomobject]@{
            FacetId    = $id
            Axis       = 'evidence'
            Path       = "facet-health:evidence:$evidence"
            Confidence = 0.6
            Kind       = 'computed-rule'
            Value      = "weakest of: $((($states.Keys | Sort-Object) -join ', '))"
        }

        # -- depth ---------------------------------------------------------
        $depths = @{}
        foreach ($record in $mine) {
            $depths[(@($record.FacetPath -split ':').Count)] = $true
        }
        $depth = if ($depths.Keys.Count -le 1) { 'consistent' } else { 'ragged' }

        [pscustomobject]@{
            FacetId    = $id
            Axis       = 'depth'
            Path       = "facet-health:depth:$depth"
            Confidence = 0.8
            Kind       = 'computed-measure'
            Value      = "assigned path depth(s): $((($depths.Keys | Sort-Object) -join ', '))"
        }
    }
}

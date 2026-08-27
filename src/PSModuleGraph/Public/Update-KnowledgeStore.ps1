function Update-KnowledgeStore {
    <#
    .SYNOPSIS
        Regenerates a module's subjects and assignments in the knowledge store.
    .DESCRIPTION
        The store's write path. See knowledge/NAMING.md and the "Kaizen: the
        knowledge substrate" section of CLAUDE.md.

        This was a scratch script until v0.2.0, and hiding it was a mistake with
        a specific cost: the freshness test could turn a build red with a fix
        that lived outside the repository. That is the shape of test people
        delete. The answer to a stale store is now a command in the repository,
        and `./build.ps1 -Task Knowledge` runs it.

        Every record is validated against its JSON Schema BEFORE it is written.
        That ordering caught the array-unrolling bug in v0.0.1 and stays.

        The facet-health assignments are recomputed from the WHOLE store on
        every run, after this module's records are written, because a facet's
        coverage is a fact about the store rather than about any one module in
        it. Running this for one module therefore refreshes the grades for all.

        Generation is reproducible: -GeneratedAt and -Prompt are stamps rather
        than clocks, so regenerating an unchanged store produces byte-identical
        files. That is what lets staleness be detected by comparison instead of
        by counting.
    .PARAMETER Name
        Module to describe, by name.
    .PARAMETER RequiredVersion
        Exact version to select for -Name.
    .PARAMETER Path
        Module to describe, by path on disk.
    .PARAMETER ModuleInfo
        Module to describe, from the pipeline.
    .PARAMETER StoreRoot
        The knowledge store. Defaults to ./knowledge.
    .PARAMETER GeneratedAt
        Stamp written into every record. Defaults to today. Pass the stamp an
        existing store carries to reproduce it exactly.
    .PARAMETER Prompt
        Ledger entry to record as the origin of these records.
    .EXAMPLE
        Update-KnowledgeStore -Path ./src/PSModuleGraph

        Refreshes this module's records, then regrades every facet.
    .EXAMPLE
        Update-KnowledgeStore -Path ./tests/fixtures/SampleModule -WhatIf

        Prints every file that would be written, and writes none.
    .OUTPUTS
        A summary of what was written.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByName')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(ParameterSetName = 'ByName')]
        [version] $RequiredVersion,

        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'ByModuleInfo', ValueFromPipeline)]
        [System.Management.Automation.PSModuleInfo] $ModuleInfo,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $StoreRoot = './knowledge',

        [Parameter()]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $GeneratedAt = (Get-Date -Format 'yyyy-MM-dd'),

        [Parameter()]
        [ValidatePattern('^ledger/\d{4}$')]
        [string] $Prompt = 'ledger/0003'
    )

    process {
        $target = Resolve-BoundParameter -Name $Name -RequiredVersion $RequiredVersion -Path $Path `
            -ModuleInfo $ModuleInfo -ParameterSetName $PSCmdlet.ParameterSetName

        $inspectPath = if ($target.ManifestPath) { $target.ManifestPath } else { $target.ModuleBase }
        $graph = Get-PSModuleDependencyGraph -Path $inspectPath

        $root = (New-KnowledgeStorePath -StoreRoot $StoreRoot).Root
        $schemaDir = Join-Path $root 'SCHEMA'
        $subjectSchema = Join-Path $schemaDir 'subject.schema.json'
        $assignmentSchema = Join-Path $schemaDir 'assignment.schema.json'

        $moduleName = [string]$graph.ModuleName
        $moduleId = "psmodule:$moduleName"
        $written = 0

        # BEFORE the removal below, not after. Every definition must get its own
        # subject id, and a population that collapses is refused rather than
        # written - see Assert-DistinctSubjectId. Refusing after the tree was
        # deleted would replace a wrong store with no store.
        Assert-DistinctSubjectId -Node @($graph.Nodes) -ModuleName $moduleName -ModuleBase $target.ModuleBase

        # Everything this module owns is replaced, not merged: a definition that
        # has been deleted must lose its records, and merging would leave them
        # behind as facts about something that no longer exists.
        foreach ($area in 'subjects', 'assignments') {
            $owned = Join-Path (Join-Path $root $area) "psmodule/$moduleName"
            if ((Test-Path -LiteralPath $owned) -and
                $PSCmdlet.ShouldProcess($owned, 'Remove records this module owns before rewriting them')) {
                Remove-Item -LiteralPath $owned -Recurse -Force
            }
        }

        $moduleRelative = ConvertTo-SubjectSourcePath -Path $target.ManifestPath -Base $target.ModuleBase
        $written += Write-SubjectRecord -Root $root -SchemaPath $subjectSchema -Id $moduleId `
            -Name $moduleName -Parent '' -Source $moduleRelative -GeneratedAt $GeneratedAt -Prompt $Prompt `
            -Body @"
# $moduleName

The module itself, as a subject. Every definition inside it names this as
``parent``, which is what lets a question about a module be answered by rolling up
the assignments of the things it contains.
"@

        foreach ($node in @($graph.Nodes)) {
            $id = Get-KnowledgeSubjectId -Node $node -ModuleName $moduleName -ModuleBase $target.ModuleBase
            $kind = ([string]$node.Kind).ToLowerInvariant()
            $source = ConvertTo-SubjectSourcePath -Path $node.Path -Base $target.ModuleBase

            # A rename never deletes. The former id is COMPUTED from the node
            # rather than read off the tree, which is the only thing that makes
            # this correct: the tree was removed above, and by the time a record
            # is written its predecessor is already gone.
            #
            # Where names collided the map is one-to-many, so every one of the
            # 32 records claims the same former id. That is a SPLIT, not a
            # rename, and an alias resolving to several subjects is the honest
            # answer - see knowledge/NAMING.md.
            $formerId = Get-LegacyKnowledgeSubjectId -Node $node -ModuleName $moduleName

            $written += Write-SubjectRecord -Root $root -SchemaPath $subjectSchema -Id $id `
                -Name ([string]$node.Name) -Parent $moduleId -Source $source -Aliases @($formerId) `
                -GeneratedAt $GeneratedAt -Prompt $Prompt -Body @"
# $($node.Name)

A ``$kind`` defined in ``$moduleName``. Its assignments live one per facet under
``assignments/``, so changing one classification is a one-file diff.
"@

            $written += Write-AssignmentRecord -Root $root -SchemaPath $assignmentSchema -Subject $id `
                -Facet 'structure' -FacetPath "structure:$kind" -Confidence 1 `
                -EvidenceKind 'ast' -EvidenceValue ([string]$node.Kind) -EvidenceSource 'psmodulegraph-parser' `
                -GeneratedAt $GeneratedAt -Prompt $Prompt -Body @"
# structure

Read straight off the AST. Confidence 1 is honest here: the parser saw the
definition and nothing was inferred from a name.
"@

            # surface applies to functions only. A class, an enum or top-level
            # script code has no export status, and inventing surface:internal
            # for them would be an assignment whose evidence restates itself.
            if ($kind -ne 'function') { continue }

            if ($node.IsExported) {
                $written += Write-AssignmentRecord -Root $root -SchemaPath $assignmentSchema -Subject $id `
                    -Facet 'surface' -FacetPath 'surface:exported' -Confidence 1 `
                    -EvidenceKind 'manifest-entry' -EvidenceValue 'FunctionsToExport' `
                    -EvidenceSource 'psmodulegraph-manifest' -GeneratedAt $GeneratedAt -Prompt $Prompt -Body @"
# surface

Named in the manifest's ``FunctionsToExport``. A direct observation, so confidence 1.
"@
            }
            else {
                $written += Write-AssignmentRecord -Root $root -SchemaPath $assignmentSchema -Subject $id `
                    -Facet 'surface' -FacetPath 'surface:internal' -Confidence 0.9 `
                    -EvidenceKind 'manifest-absence' -EvidenceValue 'not listed in FunctionsToExport' `
                    -EvidenceSource 'psmodulegraph-manifest' -GeneratedAt $GeneratedAt -Prompt $Prompt -Body @"
# surface

Deliberately below 1. This rests on an ABSENCE from ``FunctionsToExport``, and an
absence is weaker evidence than a presence: a module may export at runtime through
``Export-ModuleMember``, which this module never evaluates because it never runs
the code it analyses.
"@
            }
        }

        $graded = Update-FacetHealthRecord -Root $root -GeneratedAt $GeneratedAt -Prompt $Prompt

        [pscustomobject]@{
            PSTypeName    = 'PSModuleGraph.KnowledgeStoreUpdate'
            StoreRoot      = $root
            ModuleName     = $moduleName
            RecordsWritten = $written
            FacetsGraded   = $graded
            GeneratedAt    = $GeneratedAt
            Prompt         = $Prompt
        }
    }
}

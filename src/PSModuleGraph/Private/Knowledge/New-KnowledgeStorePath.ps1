function New-KnowledgeStorePath {
    <#
    .SYNOPSIS
        Resolves a store root and asserts it looks like a store.
    .DESCRIPTION
        A store is a directory containing SCHEMA. Checking that before writing
        turns "-StoreRoot pointed somewhere wrong" into an error naming the path
        rather than a tree of records scattered into an unrelated directory.
    .PARAMETER StoreRoot
        Directory holding SCHEMA, facets, subjects, assignments, meta, ledger.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $StoreRoot
    )

    if (-not (Test-Path -LiteralPath $StoreRoot)) {
        throw "No knowledge store at '$StoreRoot'."
    }
    $full = (Resolve-Path -LiteralPath $StoreRoot).ProviderPath
    if (-not (Test-Path -LiteralPath (Join-Path $full 'SCHEMA'))) {
        throw "'$full' has no SCHEMA directory, so it is not a knowledge store."
    }

    [pscustomobject]@{ Root = $full }
}

function ConvertTo-SubjectSourcePath {
    <#
    .SYNOPSIS
        Makes a path relative to the thing that contains it.
    .DESCRIPTION
        Records must never carry an absolute path: they leak a username into
        files meant to travel.

        Relative to the CONTAINING artefact - a module's base for a definition
        inside it, the store root for a facet file - rather than to the store's
        parent directory. That difference is load-bearing. Store-parent
        relativity made a record's content depend on where the store happened to
        sit, so regenerating the same source into a different directory produced
        different files, and the freshness test could not tell a real drift from
        a different working directory.
    .PARAMETER Path
        Path on disk.
    .PARAMETER Base
        Directory the path should be expressed relative to.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string] $Path,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Base
    )

    if (-not $Path) { return '' }
    $full = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($Base)
    if ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    }
    # Outside the base: the file name alone, because the alternative is an
    # absolute path and there is no honest relative form.
    Split-Path -Path $full -Leaf
}

function ConvertTo-SubjectSlug {
    <#
    .SYNOPSIS
        Makes one URN path segment out of arbitrary text.
    .DESCRIPTION
        The URN grammar allows [A-Za-z0-9._/-]; anything else is REPLACED with
        a dash rather than deleted. Deletion is what the pre-0.16.0 id builder
        did and it is lossy in the direction that matters: 'DSC Sql' and
        'DSCSql' collapse to one slug, and a collapse is the defect this whole
        change exists to remove.

        Replacement is not injective either - 'A B' and 'A-B' still meet - so
        this is a reduction in collisions rather than a proof against them.
        Assert-DistinctSubjectId is what makes the remainder loud.
    .PARAMETER Text
        The text to reduce.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [AllowEmptyString()] [AllowNull()] [string] $Text)

    if (-not $Text) { return '' }
    ($Text -replace '[^A-Za-z0-9._/-]', '-')
}

function Get-KnowledgeSubjectId {
    <#
    .SYNOPSIS
        Builds the subject URN for one graph node.
    .DESCRIPTION
        'psmodule:<module>/<kind>/<path-to-the-file>/<name>'.

        THE PATH IS PART OF THE IDENTITY. Without it, every definition sharing
        a name shared a subject: SqlServerDsc's 32 functions named
        Get-TargetResource were one record whose `source:` named one arbitrary
        file, so a reader following it landed in the wrong resource with
        nothing saying the other 31 existed. Confidently wrong rather than
        absent. The graph fixed the same defect in its own node ids at v0.11.0;
        this is the store's side of it.

        Always qualified, never qualified-on-demand. Qualifying only when a
        name happens to collide would make an id depend on what else exists, so
        adding a second definition would silently rename the first - a rename
        with no rename event, on a tree that is regenerated rather than edited.

        Top-level script code has no usable name - the graph calls it
        '<script>' and angle brackets are not valid in a URN - so a script node
        is identified by its file alone, which is unique per file by
        construction and keeps the shape it had before this change.
    .PARAMETER Node
        A graph node.
    .PARAMETER ModuleName
        Module the node belongs to.
    .PARAMETER ModuleBase
        Directory the node's path is expressed relative to. Omitted, the id
        falls back to the unqualified form, which is what the legacy builder
        produced and is only correct when there is no path to qualify with.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [ValidateNotNull()] $Node,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $ModuleName,
        [Parameter()] [AllowEmptyString()] [AllowNull()] [string] $ModuleBase
    )

    $kind = ([string]$Node.Kind).ToLowerInvariant()
    $relative = ''
    if ($Node.Path -and $ModuleBase) {
        $relative = ConvertTo-SubjectSlug -Text (
            ConvertTo-SubjectSourcePath -Path ([string]$Node.Path) -Base $ModuleBase)
    }

    if ($kind -eq 'script') {
        # One script node per file, so the file IS the identity and appending
        # the name would only add a constant.
        $tail = if ($relative) { $relative } else { ConvertTo-SubjectSlug -Text ([string]$Node.Name) }
        if (-not $tail) { $tail = 'unnamed' }
        return "psmodule:$ModuleName/$kind/$tail"
    }

    $slug = ConvertTo-SubjectSlug -Text ([string]$Node.Name)
    if (-not $slug) { $slug = 'unnamed' }

    if ($relative) { return "psmodule:$ModuleName/$kind/$relative/$slug" }
    "psmodule:$ModuleName/$kind/$slug"
}

function Get-LegacyKnowledgeSubjectId {
    <#
    .SYNOPSIS
        Reproduces the subject URN this store issued up to v0.15.2.
    .DESCRIPTION
        FROZEN. This is not a second opinion about how ids should be built; it
        is a record of how they WERE built, and the only reason it exists is to
        compute the alias a record must carry so the old identifier still
        resolves.

        Do not fix it, do not share code with Get-KnowledgeSubjectId, and do not
        make it agree with anything. Improving it makes every alias in the store
        name an identifier that was never issued - which resolves, wrongly, and
        is exactly the failure this store's third rule exists to prevent.

        Note the deletion rather than replacement in the slug, and the leaf-only
        treatment of a script's file. Both are wrong. Both are what happened.
    .PARAMETER Node
        A graph node.
    .PARAMETER ModuleName
        Module the node belongs to.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [ValidateNotNull()] $Node,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $ModuleName
    )

    $kind = ([string]$Node.Kind).ToLowerInvariant()
    $slug = ([string]$Node.Name) -replace '[^A-Za-z0-9._-]', ''
    if ($kind -eq 'script' -or -not $slug) {
        if ($Node.Path) { $slug = Split-Path -Path ([string]$Node.Path) -Leaf }
    }
    if (-not $slug) { $slug = 'unnamed' }

    "psmodule:$ModuleName/$kind/$slug"
}

function Assert-DistinctSubjectId {
    <#
    .SYNOPSIS
        Refuses a population whose definitions do not get one subject id each.
    .DESCRIPTION
        Free, exhaustive and it would have caught the original defect at the
        moment of writing rather than months later by inspection: count the
        definitions, count the distinct ids, and if the two differ say which id
        is shared and by what.

        A store that collapses does not lose the extra definitions quietly. One
        record survives per id and it carries a `source:`, so the store answers
        a question about 32 functions by naming one file - CONFIDENTLY WRONG
        rather than absent, which is the harder failure to notice and the one
        this project keeps finding.

        Called BEFORE the module's existing records are removed. A refusal that
        has already deleted the tree it refused to replace is worse than the
        collapse it prevented.
    .PARAMETER Node
        The graph nodes about to become subjects.
    .PARAMETER ModuleName
        Module the nodes belong to.
    .PARAMETER ModuleBase
        Directory paths are built and reported relative to, so neither an id
        nor a message carries the machine it was produced on.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Node,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $ModuleName,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $ModuleBase
    )

    $byId = @{}
    foreach ($item in $Node) {
        $id = Get-KnowledgeSubjectId -Node $item -ModuleName $ModuleName -ModuleBase $ModuleBase
        if (-not $byId.ContainsKey($id)) {
            $byId[$id] = [System.Collections.Generic.List[object]]::new()
        }
        $byId[$id].Add($item)
    }

    $shared = @($byId.Keys | Where-Object { $byId[$_].Count -gt 1 } | Sort-Object)
    if (-not $shared.Count) { return }

    # One collision completely beats fifty-one partially. The counts say how
    # big the problem is; the named pair says what to look at first.
    $worst = $byId[$shared[0]]
    $where = @($worst | ForEach-Object {
            if ($_.Path) { ConvertTo-SubjectSourcePath -Path $_.Path -Base $ModuleBase } else { '<no file>' }
        } | Sort-Object)

    $lost = $Node.Count - $byId.Keys.Count
    $also = if ($shared.Count -gt 1) { " $($shared.Count - 1) other id(s) are shared as well." } else { '' }

    throw ("'{0}' is the subject id of {1} definitions: {2}. " -f $shared[0], $worst.Count, ($where -join ', ')) +
        ("{0} definition(s) in {1} produce {2} distinct subject id(s), so {3} would be written over." -f
            $Node.Count, $ModuleName, $byId.Keys.Count, $lost) + $also
}

function ConvertTo-KnowledgeFilePath {
    <#
    .SYNOPSIS
        Maps a subject URN onto its place in the tree.
    .DESCRIPTION
        The layout mirrors the identifier, so a reader finds a file from a URN
        without an index. See knowledge/NAMING.md.
    .PARAMETER Id
        Subject URN.
    .PARAMETER Root
        Store root.
    .PARAMETER Area
        'subjects' or 'assignments'.
    .PARAMETER Facet
        For assignments, the facet id.
    .PARAMETER FacetPath
        For assignments, the path assigned. An assignment is keyed by all three
        of subject, facet and path - NOT by subject and facet - because facets
        are multi-valued. facet-health assigns three paths to one facet, and a
        <subject>/<facet>.md layout silently overwrote two of them with the
        third. See ledger/0003.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Id,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Root,
        [Parameter(Mandatory)] [ValidateSet('subjects', 'assignments')] [string] $Area,
        [Parameter()] [string] $Facet,
        [Parameter()] [string] $FacetPath
    )

    $relative = $Id.Replace(':', '/')
    if ($Area -ne 'assignments') {
        return Join-Path (Join-Path $Root $Area) ($relative + '.md')
    }

    # The path with its facet prefix removed, since the facet is already a
    # directory. 'structure:function' under facet 'structure' becomes
    # 'function'; a bare 'structure' becomes '_', which is a legal file name
    # where an empty one is not.
    $tail = $FacetPath
    if ($tail -eq $Facet) { $tail = '_' }
    elseif ($tail.StartsWith("${Facet}:")) { $tail = $tail.Substring($Facet.Length + 1) }
    $tail = ($tail -replace '[^A-Za-z0-9._-]', '-')
    if (-not $tail) { $tail = '_' }

    Join-Path (Join-Path $Root $Area) ($relative + '/' + $Facet + '/' + $tail + '.md')
}

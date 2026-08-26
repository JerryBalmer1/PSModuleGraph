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

function Get-KnowledgeSubjectId {
    <#
    .SYNOPSIS
        Builds the subject URN for one graph node.
    .DESCRIPTION
        'psmodule:<module>/<kind>/<name>'. Top-level script code has no usable
        name - the graph calls it '<script>' and the angle brackets are not
        valid in a URN - so it is identified by its file instead, which is both
        valid and more informative.
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

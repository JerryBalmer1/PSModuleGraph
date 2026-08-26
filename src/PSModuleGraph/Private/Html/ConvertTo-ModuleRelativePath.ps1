function ConvertTo-ModuleRelativePath {
    <#
    .SYNOPSIS
        Rewrites an absolute path as relative to the module root.
    .DESCRIPTION
        Generated reports get attached to PRs and tickets, where an absolute
        path leaks the author's username and directory layout. Falls back to the
        absolute path when the file lies outside the root, which is preferable
        to emitting something misleading.
    #>
    param([string] $Path, [string] $Root)

    if (-not $Path -or -not $Root) { return $Path }

    $normalisedRoot = $Root.TrimEnd('\', '/')
    if (-not $Path.StartsWith($normalisedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path
    }

    $relative = $Path.Substring($normalisedRoot.Length).TrimStart('\', '/')
    if (-not $relative) { return $Path }

    $relative
}

function ConvertTo-GraphHtml {
    <#
    .SYNOPSIS
        Renders a dependency graph as a single self-contained interactive HTML page.
    .DESCRIPTION
        The payload is produced by ConvertTo-GraphJson. There is deliberately only
        one serialiser: if the HTML built its own, the page and the JSON export
        could drift apart without anything failing.

        Paths in the HTML payload are made relative to the module root. A
        generated report gets attached to PRs and tickets, and absolute paths
        leak usernames and directory layout. The JSON export keeps them absolute.
    .PARAMETER Graph
        Graph object from Get-PSModuleDependencyGraph.
    .PARAMETER IncludeUnresolved
        Include unresolved external targets in the payload.
    .PARAMETER Title
        Page heading. Defaults to '<ModuleName> dependency graph'.
    #>
    param($Graph, [switch]$IncludeUnresolved, [string]$Title)

    if (-not $Title) {
        $moduleLabel = if ($Graph.ModuleName) { $Graph.ModuleName } else { 'module' }
        $Title = "$moduleLabel dependency graph"
    }

    $moduleRoot = [string]$Graph.ModuleBase

    # Single source of truth for the payload shape.
    $payload = ConvertTo-GraphJson -Graph $Graph -IncludeUnresolved:$IncludeUnresolved
    $data = $payload | ConvertFrom-Json

    foreach ($collection in @('nodes', 'links', 'unresolved')) {
        $property = $data.PSObject.Properties[$collection]
        if (-not $property -or -not $property.Value) { continue }
        foreach ($item in @($property.Value)) {
            if ($item.PSObject.Properties['path'] -and $item.path) {
                $item.path = ConvertTo-ModuleRelativePath -Path $item.path -Root $moduleRoot
            }
        }
    }

    $meta = [ordered]@{
        moduleName    = $Graph.ModuleName
        moduleVersion = [string]$Graph.ModuleVersion
        generatedAt   = (Get-Date).ToString('o')
        moduleRoot    = $moduleRoot
        stats         = $Graph.Stats
    }

    $dataJson = ConvertTo-EscapedHtmlJson -InputObject $data
    $metaJson = ConvertTo-EscapedHtmlJson -InputObject $meta

    $template = Get-PSModuleGraphAsset -Name 'graph.html'

    # [string]::Replace, never the -replace operator. -replace is regex: the JSON
    # and the CSS both contain '$' and '\', which the regex engine treats as
    # substitution patterns and silently eats. The result would be corrupted
    # output rather than an error.
    $document = $template.Replace('/*__GRAPH_DATA__*/ null', $dataJson)
    $document = $document.Replace('/*__GRAPH_META__*/ null', $metaJson)
    $document = $document.Replace('__PAGE_TITLE__', (ConvertTo-EscapedHtmlText -Text $Title))

    $document
}

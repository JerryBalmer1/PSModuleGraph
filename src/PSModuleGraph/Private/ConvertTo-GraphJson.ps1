function ConvertTo-GraphJson {
    <#
    .SYNOPSIS
        Serialises a dependency graph as node-link JSON.
    .DESCRIPTION
        Emits the node-link shape that mainstream graph libraries expect: a
        'nodes' array plus a 'links' array whose elements carry 'source' and
        'target'. D3's force layout, NetworkX's node_link_graph, and Cytoscape
        all read this directly, with no transform step.
    #>
    param($Graph, [switch]$IncludeUnresolved)

    $payload = [ordered]@{
        moduleName    = $Graph.ModuleName
        moduleVersion = [string]$Graph.ModuleVersion
        moduleBase    = $Graph.ModuleBase
        stats         = $Graph.Stats
        nodes         = @($Graph.Nodes | ForEach-Object {
                [ordered]@{
                    id         = $_.Id
                    name       = $_.Name
                    kind       = $_.Kind
                    isExported = [bool]$_.IsExported
                    path       = $_.Path
                    startLine  = $_.StartLine
                }
            })
        links         = @($Graph.Edges | ForEach-Object {
                [ordered]@{
                    source     = $_.Source
                    target     = $_.Target
                    sourceName = $_.SourceName
                    targetName = $_.TargetName
                    kind       = $_.Kind
                    path       = $_.Path
                    startLine  = $_.StartLine
                }
            })
        # Deliberate asymmetry: the PowerShell object exposes Roots and Leaves as
        # full node objects, but the JSON emits bare id strings. This is not an
        # oversight and should not be "fixed" to match the object.
        #
        # In JSON the node already appears in full inside 'nodes'. Repeating it
        # here would duplicate every field and force a consumer to decide which
        # copy wins. Node-link consumers expect references into 'nodes', and an
        # id string is exactly that reference. On the PowerShell side there is no
        # such duplication concern -- the same object instance is simply
        # referenced twice -- and full objects are what makes
        # `$graph.Roots | Format-Table Name, Path` work at the prompt.
        roots         = @($Graph.Roots | ForEach-Object { $_.Id })
        leaves        = @($Graph.Leaves | ForEach-Object { $_.Id })
    }

    if ($IncludeUnresolved) {
        $payload['unresolved'] = @($Graph.Unresolved | ForEach-Object {
                [ordered]@{
                    source     = $_.Source
                    sourceName = $_.SourceName
                    targetName = $_.TargetName
                    path       = $_.Path
                    startLine  = $_.StartLine
                }
            })
    }

    $payload | ConvertTo-Json -Depth 8
}

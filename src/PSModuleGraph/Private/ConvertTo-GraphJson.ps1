function ConvertTo-GraphJson {
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
        edges         = @($Graph.Edges | ForEach-Object {
                [ordered]@{
                    from      = $_.From
                    to        = $_.To
                    fromName  = $_.FromName
                    toName    = $_.ToName
                    kind      = $_.Kind
                    path      = $_.Path
                    startLine = $_.StartLine
                }
            })
        roots         = @($Graph.Roots | ForEach-Object { $_.Id })
        leaves        = @($Graph.Leaves | ForEach-Object { $_.Id })
    }

    if ($IncludeUnresolved) {
        $payload['unresolved'] = @($Graph.Unresolved | ForEach-Object {
                [ordered]@{
                    from       = $_.From
                    fromName   = $_.FromName
                    targetName = $_.TargetName
                    path       = $_.Path
                    startLine  = $_.StartLine
                }
            })
    }

    $payload | ConvertTo-Json -Depth 8
}

function ConvertTo-GraphMermaid {
    param($Graph, [switch]$IncludeUnresolved)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('flowchart LR')

    foreach ($n in $Graph.Nodes) {
        $id = ConvertTo-MermaidId $n.Id
        $label = switch ($n.Kind) {
            'Function' { if ($n.IsExported) { "$($n.Name)*" } else { $n.Name } }
            default { "$($n.Name) ($($n.Kind))" }
        }
        $shape = switch ($n.Kind) {
            'Class' { '[[{0}]]' -f $label }
            'Enum' { '[({0})]' -f $label }
            'Script' { '(({0}))' -f $label }
            default { '[{0}]' -f $label }
        }
        [void]$sb.AppendLine("    $id$shape")
    }

    foreach ($e in $Graph.Edges) {
        $arrow = if ($e.Kind -eq 'Inherits') { '==>' } else { '-->' }
        [void]$sb.AppendLine(('    {0} {1} {2}' -f (ConvertTo-MermaidId $e.From), $arrow, (ConvertTo-MermaidId $e.To)))
    }

    if ($IncludeUnresolved) {
        foreach ($u in $Graph.Unresolved) {
            if (-not $u.From -or $u.From -like 'module:*' -or $u.From -like 'using:*') { continue }
            $toId = ConvertTo-MermaidId "external:$($u.TargetName)"
            [void]$sb.AppendLine(('    {0}[{1}]' -f $toId, $u.TargetName))
            [void]$sb.AppendLine(('    {0} -.-> {1}' -f (ConvertTo-MermaidId $u.From), $toId))
        }
    }

    $sb.ToString()
}

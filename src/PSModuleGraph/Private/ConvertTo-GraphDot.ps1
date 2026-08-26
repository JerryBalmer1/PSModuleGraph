function ConvertTo-GraphDot {
    param($Graph, [switch]$IncludeUnresolved)

    $sb = [System.Text.StringBuilder]::new()
    $title = if ($Graph.ModuleName) { $Graph.ModuleName } else { 'module' }
    [void]$sb.AppendLine("digraph `"$title`" {")
    [void]$sb.AppendLine('  rankdir=LR;')
    [void]$sb.AppendLine('  node [shape=box, style=rounded, fontname="Segoe UI"];')
    [void]$sb.AppendLine('  edge [fontname="Segoe UI", fontsize=10];')

    foreach ($n in $Graph.Nodes) {
        $label = switch ($n.Kind) {
            'Function' { if ($n.IsExported) { "$($n.Name)*" } else { $n.Name } }
            default { "$($n.Name) <<$($n.Kind)>>" }
        }
        $color = switch ($n.Kind) {
            'Function' { if ($n.IsExported) { 'lightblue' } else { 'white' } }
            'Class' { 'lightgoldenrod1' }
            'Enum' { 'palegreen' }
            'Script' { 'grey90' }
            default { 'white' }
        }
        $safeId = ConvertTo-DotId $n.Id
        [void]$sb.AppendLine(('  {0} [label="{1}", fillcolor="{2}", style="rounded,filled"];' -f $safeId, (ConvertTo-EscapedDotText $label), $color))
    }

    if ($IncludeUnresolved) {
        $externalNames = @($Graph.Unresolved | Select-Object -ExpandProperty TargetName -Unique)
        foreach ($ext in $externalNames) {
            $safeId = ConvertTo-DotId "external:$ext"
            [void]$sb.AppendLine(('  {0} [label="{1}", shape=ellipse, fillcolor="orangered", style="filled", fontcolor="white"];' -f $safeId, (ConvertTo-EscapedDotText $ext)))
        }
        foreach ($u in $Graph.Unresolved) {
            if (-not $u.Source -or $u.Source -like 'module:*' -or $u.Source -like 'using:*') { continue }
            $fromId = ConvertTo-DotId $u.Source
            $toId = ConvertTo-DotId "external:$($u.TargetName)"
            [void]$sb.AppendLine(('  {0} -> {1} [style=dashed, color="orangered"];' -f $fromId, $toId))
        }
    }

    foreach ($e in $Graph.Edges) {
        $style = if ($e.Kind -eq 'Inherits') { 'style=bold, color="darkgoldenrod"' } else { 'color="gray40"' }
        [void]$sb.AppendLine(('  {0} -> {1} [{2}];' -f (ConvertTo-DotId $e.Source), (ConvertTo-DotId $e.Target), $style))
    }

    [void]$sb.AppendLine('}')
    $sb.ToString()
}

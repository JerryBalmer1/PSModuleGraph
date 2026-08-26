function ConvertTo-GraphCsv {
    param($Graph, [switch]$IncludeUnresolved)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('From,To,FromName,ToName,Kind,Path,StartLine')
    foreach ($e in $Graph.Edges) {
        [void]$sb.AppendLine((
                '{0},{1},{2},{3},{4},{5},{6}' -f
                (ConvertTo-EscapedCsvField $e.From),
                (ConvertTo-EscapedCsvField $e.To),
                (ConvertTo-EscapedCsvField $e.FromName),
                (ConvertTo-EscapedCsvField $e.ToName),
                (ConvertTo-EscapedCsvField $e.Kind),
                (ConvertTo-EscapedCsvField $e.Path),
                $e.StartLine
            ))
    }

    if ($IncludeUnresolved) {
        foreach ($u in $Graph.Unresolved) {
            [void]$sb.AppendLine((
                    '{0},{1},{2},{3},{4},{5},{6}' -f
                    (ConvertTo-EscapedCsvField $u.From),
                    (ConvertTo-EscapedCsvField "external:$($u.TargetName)"),
                    (ConvertTo-EscapedCsvField $u.FromName),
                    (ConvertTo-EscapedCsvField $u.TargetName),
                    'Unresolved',
                    (ConvertTo-EscapedCsvField $u.Path),
                    $u.StartLine
                ))
        }
    }

    $sb.ToString()
}

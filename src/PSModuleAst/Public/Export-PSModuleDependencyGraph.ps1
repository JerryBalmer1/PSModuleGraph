function Export-PSModuleDependencyGraph {
    <#
    .SYNOPSIS
        Exports a dependency graph as JSON, Graphviz DOT, Mermaid, or CSV edge list.
    .PARAMETER InputObject
        Graph object from Get-PSModuleDependencyGraph.
    .PARAMETER Format
        Output format.
    .PARAMETER OutputPath
        Optional file path. When omitted, the document is written to the pipeline as a string.
    .PARAMETER IncludeUnresolved
        Include unresolved external targets as nodes/edges where the format allows.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNull()]
        [pscustomobject] $InputObject,

        [Parameter()]
        [ValidateSet('Json', 'Dot', 'Mermaid', 'Csv')]
        [string] $Format = 'Json',

        [Parameter()]
        [string] $OutputPath,

        [Parameter()]
        [switch] $IncludeUnresolved
    )

    process {
        if ($InputObject.PSObject.TypeNames -notcontains 'PSModuleAst.DependencyGraph' -and
            -not ($InputObject.PSObject.Properties['Nodes'] -and $InputObject.PSObject.Properties['Edges'])) {
            throw 'InputObject must be a PSModuleAst dependency graph (from Get-PSModuleDependencyGraph).'
        }

        $document = switch ($Format) {
            'Json' { ConvertTo-GraphJson -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
            'Dot' { ConvertTo-GraphDot -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
            'Mermaid' { ConvertTo-GraphMermaid -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
            'Csv' { ConvertTo-GraphCsv -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
        }

        if ($OutputPath) {
            $resolved = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
            $dir = Split-Path -Path $resolved -Parent
            if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            # PS 5.1: write UTF-8 with BOM explicitly
            if ($PSVersionTable.PSVersion.Major -lt 6) {
                [System.IO.File]::WriteAllText($resolved, $document, [System.Text.UTF8Encoding]::new($true))
            }
            else {
                Set-Content -LiteralPath $resolved -Value $document -Encoding utf8
            }
            Get-Item -LiteralPath $resolved
        }
        else {
            $document
        }
    }
}

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
            if (-not $u.From -or $u.From -like 'module:*' -or $u.From -like 'using:*') { continue }
            $fromId = ConvertTo-DotId $u.From
            $toId = ConvertTo-DotId "external:$($u.TargetName)"
            [void]$sb.AppendLine(('  {0} -> {1} [style=dashed, color="orangered"];' -f $fromId, $toId))
        }
    }

    foreach ($e in $Graph.Edges) {
        $style = if ($e.Kind -eq 'Inherits') { 'style=bold, color="darkgoldenrod"' } else { 'color="gray40"' }
        [void]$sb.AppendLine(('  {0} -> {1} [{2}];' -f (ConvertTo-DotId $e.From), (ConvertTo-DotId $e.To), $style))
    }

    [void]$sb.AppendLine('}')
    $sb.ToString()
}

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

function ConvertTo-DotId {
    param([string]$Id)
    $safe = ($Id -replace '[^A-Za-z0-9_]', '_')
    if ($safe -match '^[0-9]') { $safe = "n_$safe" }
    return $safe
}

function ConvertTo-EscapedDotText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '\\', '\\\\' -replace '"', '\"')
}

function ConvertTo-MermaidId {
    param([string]$Id)
    $safe = ($Id -replace '[^A-Za-z0-9_]', '_')
    if ($safe -match '^[0-9]') { $safe = "n_$safe" }
    return $safe
}

function ConvertTo-EscapedCsvField {
    param($Value)
    $s = if ($null -eq $Value) { '' } else { [string]$Value }
    if ($s -match '[,"\r\n]') {
        return '"' + ($s -replace '"', '""') + '"'
    }
    return $s
}

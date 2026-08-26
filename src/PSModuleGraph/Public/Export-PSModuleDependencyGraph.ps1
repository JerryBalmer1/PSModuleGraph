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
        if ($InputObject.PSObject.TypeNames -notcontains 'PSModuleGraph.DependencyGraph' -and
            -not ($InputObject.PSObject.Properties['Nodes'] -and $InputObject.PSObject.Properties['Edges'])) {
            throw 'InputObject must be a PSModuleGraph dependency graph (from Get-PSModuleDependencyGraph).'
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

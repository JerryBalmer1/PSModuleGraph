function Export-PSModuleDependencyGraph {
    <#
    .SYNOPSIS
        Exports a dependency graph as JSON, Graphviz DOT, Mermaid, CSV edge list, or an interactive HTML page.
    .PARAMETER InputObject
        Graph object from Get-PSModuleDependencyGraph.
    .PARAMETER Format
        Output format. Html produces a single self-contained interactive page.
    .PARAMETER OutputPath
        Optional file path. When omitted, the document is written to the pipeline as a string.
        The exception is -Format Html with -Show, which writes to a temp file so there is
        something to open.
    .PARAMETER IncludeUnresolved
        Include unresolved external targets as nodes/edges where the format allows.
    .PARAMETER Title
        Page heading for -Format Html. Defaults to '<ModuleName> dependency graph'.
        Ignored by the other formats.
    .PARAMETER Show
        Open the generated page in the system default web BROWSER. Only valid with
        -Format Html.

        This opens a browser, not VS Code. VS Code has no built-in HTML preview, so
        opening the file there shows the page source rather than the rendered graph.
        To view it inside the editor instead, use the Live Preview extension.

        With -OutputPath the file is written there and opened. Without -OutputPath it is
        written to a temp file and opened, and the temp FileInfo is returned.
    .EXAMPLE
        Get-PSModuleDependencyGraph -Path ./src/PSModuleGraph |
            Export-PSModuleDependencyGraph -Format Html -Show
    #>
    [CmdletBinding()]
    [OutputType([string], [System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNull()]
        [pscustomobject] $InputObject,

        [Parameter()]
        [ValidateSet('Json', 'Dot', 'Mermaid', 'Csv', 'Html')]
        [string] $Format = 'Json',

        [Parameter()]
        [string] $OutputPath,

        [Parameter()]
        [switch] $IncludeUnresolved,

        [Parameter()]
        [string] $Title,

        [Parameter()]
        [switch] $Show
    )

    process {
        if ($InputObject.PSObject.TypeNames -notcontains 'PSModuleGraph.DependencyGraph' -and
            -not ($InputObject.PSObject.Properties['Nodes'] -and $InputObject.PSObject.Properties['Edges'])) {
            throw 'InputObject must be a PSModuleGraph dependency graph (from Get-PSModuleDependencyGraph).'
        }

        $isHtml = $Format -eq 'Html'

        # A user mistake, not something to silently ignore: the other formats have
        # nothing a browser could usefully render.
        if ($Show -and -not $isHtml) {
            throw '-Show is only valid with -Format Html.'
        }

        $document = switch ($Format) {
            'Json' { ConvertTo-GraphJson -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
            'Dot' { ConvertTo-GraphDot -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
            'Mermaid' { ConvertTo-GraphMermaid -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
            'Csv' { ConvertTo-GraphCsv -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved }
            'Html' { ConvertTo-GraphHtml -Graph $InputObject -IncludeUnresolved:$IncludeUnresolved -Title $Title }
        }

        # Decide where, if anywhere, the document lands on disk.
        $targetPath = $null
        if ($OutputPath) {
            $targetPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        }
        elseif ($isHtml -and $Show) {
            # -Show needs a file to hand the browser.
            $targetPath = New-GraphTempDocumentPath -ModuleName ([string]$InputObject.ModuleName)
        }

        if (-not $targetPath) {
            return $document
        }

        $dir = Split-Path -Path $targetPath -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        if ($isHtml) {
            # UTF-8 without a BOM, always. A BOM ahead of <!DOCTYPE html> puts some
            # browsers into quirks mode. The template declares <meta charset="utf-8">.
            [System.IO.File]::WriteAllText($targetPath, $document, [System.Text.UTF8Encoding]::new($false))
        }
        elseif ($PSVersionTable.PSVersion.Major -lt 6) {
            # PS 5.1: write UTF-8 with BOM explicitly
            [System.IO.File]::WriteAllText($targetPath, $document, [System.Text.UTF8Encoding]::new($true))
        }
        else {
            Set-Content -LiteralPath $targetPath -Value $document -Encoding utf8
        }

        $item = Get-Item -LiteralPath $targetPath

        if ($Show) {
            Show-GraphDocument -Path $targetPath
        }

        $item
    }
}

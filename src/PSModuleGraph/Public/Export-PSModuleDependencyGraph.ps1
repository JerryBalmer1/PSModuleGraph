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
        Open the generated page. Only valid with -Format Html.

        Running inside VS Code, the file is opened in the existing window. That shows
        the page SOURCE - click the editor's preview button to render it. The VS Code
        CLI has no flag for running an extension command, so the preview pane cannot
        be opened automatically; one click is as close as it gets. VS Code has no
        built-in HTML preview, so rendering in the editor needs an extension such as
        Live Preview (ms-vscode.live-server).

        Anywhere else, the system default handler opens it, which for .html is the
        default web browser.

        With -OutputPath the file is written there and opened. Without -OutputPath it
        goes to output/reports/<ModuleName>-<timestamp>.html under the current
        directory - not the system temp directory, which no local server can serve.
        The FileInfo is returned either way.

        The browser is handed the exact document URL when a local static server is
        already serving it, and the file otherwise. See Show-RenderDocument.
    .PARAMETER BaseUrl
        Origin to serve the report from with -Show, skipping the port scan.
    .PARAMETER NoServe
        Always open the report from disk with -Show, skipping the probe.
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
        [switch] $Show,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $BaseUrl,

        [Parameter()]
        [switch] $NoServe
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

        # Both only steer where -Show opens from. Silently ignoring them would
        # let someone believe they had pinned an origin when nothing read it.
        if (($BaseUrl -or $NoServe) -and -not $Show) {
            throw '-BaseUrl and -NoServe are only valid with -Show.'
        }

        if ($BaseUrl -and $NoServe) {
            throw '-BaseUrl and -NoServe cannot be combined: one names an origin to use, the other refuses to use any.'
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
            # -Show needs a file to hand the browser, and it has to be somewhere
            # a local server could serve. The temp directory never is.
            $targetPath = New-RenderDocumentPath -ModuleName ([string]$InputObject.ModuleName) `
                -BasePath $PSCmdlet.SessionState.Path.CurrentFileSystemLocation.ProviderPath
        }

        if (-not $targetPath) {
            return $document
        }

        # Same reason as in New-RenderDocumentPath: this command has no
        # ShouldProcess, so its write is not gated and the directory the write
        # needs must not be either.
        $dir = Split-Path -Path $targetPath -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            [System.IO.Directory]::CreateDirectory($dir) | Out-Null
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
            $open = @{ Path = $targetPath; EditorLinkHelpCommand = 'Test-PSModuleGraphEditorLink' }
            if ($BaseUrl) { $open['BaseUrl'] = $BaseUrl }
            if ($NoServe) { $open['NoServe'] = $true }
            Show-RenderDocument @open
        }

        $item
    }
}

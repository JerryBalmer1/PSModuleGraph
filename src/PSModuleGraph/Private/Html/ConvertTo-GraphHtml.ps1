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

    # meta already carries the module's name, version and base path, and the
    # payload carried all three again - moduleBase and meta.moduleRoot being
    # literally the same string. Nothing in either backend reads any of them:
    # only meta.moduleVersion and meta.moduleRoot are ever looked at.
    #
    # They leave rather than get renamed. They are in ConvertTo-GraphJson
    # because -Format Json wants them at the top of the document it produces,
    # which is a different question from what a renderer needs embedded.
    foreach ($duplicate in 'moduleName', 'moduleVersion', 'moduleBase') {
        if ($data.PSObject.Properties[$duplicate]) {
            $data.PSObject.Properties.Remove($duplicate)
        }
    }

    foreach ($collection in @('nodes', 'links', 'unresolved')) {
        $property = $data.PSObject.Properties[$collection]
        if (-not $property -or -not $property.Value) { continue }
        foreach ($item in @($property.Value)) {
            if ($item.PSObject.Properties['path'] -and $item.path) {
                $item.path = ConvertTo-ModuleRelativePath -Path $item.path -Root $moduleRoot
            }
        }
    }

    # New names only. The renderer still reads moduleName, moduleVersion and
    # moduleRoot and warns when it has to - a rename never deletes - but a
    # producer emitting the name it was told to stop using is a producer keeping
    # the alias alive for nobody's benefit.
    #
    # meta.title rather than meta.moduleName is the whole argument in one field:
    # a payload describing infrastructure was filling moduleName with a region.
    $meta = [ordered]@{
        contractVersion = '1.0.0'
        title           = $Graph.ModuleName
        version         = [string]$Graph.ModuleVersion
        generatedAt     = (Get-Date).ToString('o')
        rootPath        = $moduleRoot
        stats           = $Graph.Stats
    }

    # THE SEAM, and it is one call. Everything below it - escaping, the
    # substitution markers, which backend, where its configuration lives - is
    # the renderer's business and none of it is repeated here.
    #
    # The name of the command that fixes a blocked editor link is handed down as
    # a value. Nothing below the seam may know what a PSModuleGraph command is,
    # so it arrives as a string the renderer interpolates and learns nothing
    # from. {origin} is deliberately left unfilled: only the browser knows what
    # origin the report ended up on, so the page fills that one.
    $strings = @{
        editorLinkHelpCommand          = 'Enable-PSModuleGraphEditorLink'
        editorLinkHelpCommandForOrigin = "Enable-PSModuleGraphEditorLink -AllowedOrigin '{origin}'"
    }

    New-RenderDocument -ViewModel $data -Meta $meta -Strings $strings -Title $Title
}

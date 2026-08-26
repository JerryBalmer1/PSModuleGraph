function Get-PSModuleGraphAsset {
    <#
    .SYNOPSIS
        Returns the raw text of an asset from the module's Assets directory.
    .DESCRIPTION
        Resolves against $script:ModuleRoot, which both the dev loader and the
        generated .psm1 set at import time. Never use $PSScriptRoot here: it is
        per-file, so it points at Private/Html under the dev loader but at the
        module root in the built module. One of those would silently be wrong.

        Assets are UTF-8 and are read verbatim with -Raw.
    .PARAMETER Name
        Asset file name relative to the Assets directory, e.g. 'graph.html'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    if (-not (Get-Variable -Name ModuleRoot -Scope Script -ErrorAction SilentlyContinue) -or
        -not $script:ModuleRoot) {
        throw '$script:ModuleRoot is not set. Both PSModuleGraph.psm1 loaders must set it at import time.'
    }

    $assetPath = Join-Path (Join-Path $script:ModuleRoot 'Assets') $Name

    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw ("Asset '$Name' not found at '$assetPath'. " +
            'The most likely cause is a stale or incomplete build that did not copy the Assets ' +
            'directory into the module output. Re-run ./build.ps1.')
    }

    Get-Content -LiteralPath $assetPath -Raw -Encoding UTF8
}

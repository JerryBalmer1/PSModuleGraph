function Get-PSModuleGraphAsset {
    <#
    .SYNOPSIS
        Returns the raw text of an asset from the module's Assets directory.
    .DESCRIPTION
        Path resolution and its error message live in Get-PSModuleGraphAssetPath,
        shared with the assets that are parsed rather than read as text.

        Assets are UTF-8 and are read verbatim with -Raw.
    .PARAMETER Name
        Asset path relative to the Assets directory, e.g. 'Html/Templates/layout.html'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    Get-Content -LiteralPath (Get-PSModuleGraphAssetPath -Name $Name) -Raw -Encoding UTF8
}

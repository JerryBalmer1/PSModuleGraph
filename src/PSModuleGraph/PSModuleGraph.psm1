#Requires -Version 5.1
# Development loader. The build composes Public/ and Private/ into output/.
Set-StrictMode -Version Latest

# Captured once at import. $PSScriptRoot is per-file: in this dev loader a file
# under Private/Html sees its own folder, while in the built module every file is
# concatenated into a .psm1 at the module root. Asset paths must resolve from
# $script:ModuleRoot so both layouts agree. See Get-PSModuleGraphAsset.
$script:ModuleRoot = $PSScriptRoot

$private = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $private) {
    # Recurse so Private/Html/*.ps1 is loaded. Sorted by FullName so ordering is
    # stable once subfolders are involved.
    Get-ChildItem -Path $private -Filter '*.ps1' -File -Recurse | Sort-Object FullName | ForEach-Object {
        . $_.FullName
    }
}

$public = Join-Path $PSScriptRoot 'Public'
$publicFunctions = @()
if (Test-Path -LiteralPath $public) {
    Get-ChildItem -Path $public -Filter '*.ps1' -File -Recurse | Sort-Object FullName | ForEach-Object {
        . $_.FullName
        $publicFunctions += [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}

if ($publicFunctions.Count -gt 0) {
    Export-ModuleMember -Function $publicFunctions
}

#Requires -Version 5.1
# Development loader. The build composes Public/ and Private/ into output/.
Set-StrictMode -Version Latest

$private = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $private) {
    Get-ChildItem -Path $private -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

$public = Join-Path $PSScriptRoot 'Public'
$publicFunctions = @()
if (Test-Path -LiteralPath $public) {
    Get-ChildItem -Path $public -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
        . $_.FullName
        $publicFunctions += [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    }
}

if ($publicFunctions.Count -gt 0) {
    Export-ModuleMember -Function $publicFunctions
}

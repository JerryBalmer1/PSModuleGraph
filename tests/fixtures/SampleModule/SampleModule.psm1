#Requires -Version 5.1
using namespace System.Collections.Generic

$public = Join-Path $PSScriptRoot 'public'
$private = Join-Path $PSScriptRoot 'private'
$classes = Join-Path $PSScriptRoot 'classes'

. (Join-Path $classes 'SampleTypes.ps1')

Get-ChildItem -Path $private -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
Get-ChildItem -Path $public -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }

Export-ModuleMember -Function Get-SampleThing, Invoke-SampleWorkflow

$script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
$script:FixturePath = Join-Path $PSScriptRoot 'fixtures\SampleModule'
$script:BuiltModulePath = Join-Path $RepoRoot 'output\PSModuleGraph\PSModuleGraph.psd1'
$script:SrcModulePath = Join-Path $RepoRoot 'src\PSModuleGraph\PSModuleGraph.psd1'

function Import-PSModuleGraphUnderTest {
    [CmdletBinding()]
    param()

    Remove-Module -Name PSModuleGraph -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $script:BuiltModulePath) {
        Import-Module -Name $script:BuiltModulePath -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name $script:SrcModulePath -Force -ErrorAction Stop
    }
}

function Get-SampleModulePath {
    $script:FixturePath
}

function Get-BuiltModulePath {
    <#
    .SYNOPSIS
        Path to the built manifest under output/. Tests that must exercise the
        built artifact (asset copying, for instance) use this rather than the
        fallback in Import-PSModuleGraphUnderTest.
    #>
    $script:BuiltModulePath
}

function Get-BuiltModuleRoot {
    Split-Path -Path $script:BuiltModulePath -Parent
}

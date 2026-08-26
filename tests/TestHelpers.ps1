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

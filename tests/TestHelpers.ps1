$script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
$script:FixturePath = Join-Path $PSScriptRoot 'fixtures\SampleModule'
$script:BuiltModulePath = Join-Path $RepoRoot 'output\PSModuleAst\PSModuleAst.psd1'
$script:SrcModulePath = Join-Path $RepoRoot 'src\PSModuleAst\PSModuleAst.psd1'

function Import-PSModuleAstUnderTest {
    [CmdletBinding()]
    param()

    Remove-Module -Name PSModuleAst -Force -ErrorAction SilentlyContinue

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
